import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/connection_status.dart';
import '../../domain/models/hr_sample.dart';
import '../../domain/models/pause_reason.dart';
import '../../domain/models/power_sample.dart';
import '../../domain/models/session_context.dart';
import '../../domain/models/trainer_telemetry.dart';
import '../../domain/models/workout_config.dart';
import '../../domain/models/workout_phase.dart';
import '../../domain/models/workout_summary.dart';
import '../../domain/models/workout_type.dart';
import '../../domain/repositories/hr_monitor_repository.dart';
import '../../domain/repositories/trainer_repository.dart';
import '../../infrastructure/app/app_info.dart';
import '../../infrastructure/diagnostics/diagnostics_store.dart';
import '../../infrastructure/observability/app_telemetry.dart';
import 'hr_averager.dart';
import 'power_averager.dart';
import 'power_adjustment_policy.dart';
import 'workout_analytics.dart';
import 'workout_clock.dart';
import 'workout_session_state.dart';

class WorkoutSessionController extends StateNotifier<WorkoutSessionState> {
  WorkoutSessionController({
    required HrMonitorRepository hrMonitorRepository,
    required TrainerRepository trainerRepository,
    HrAverager hrAverager = const HrAverager(),
    PowerAverager powerAverager = const PowerAverager(),
    PowerAdjustmentPolicy powerAdjustmentPolicy = const PowerAdjustmentPolicy(),
    WorkoutAnalytics workoutAnalytics = const WorkoutAnalytics(),
    WorkoutClock workoutClock = const WorkoutClock(),
    AppTelemetry? telemetry,
    DiagnosticsStore? diagnosticsStore,
    DateTime Function()? nowProvider,
  }) : _hrMonitorRepository = hrMonitorRepository,
       _trainerRepository = trainerRepository,
       _hrAverager = hrAverager,
       _powerAverager = powerAverager,
       _powerAdjustmentPolicy = powerAdjustmentPolicy,
       _workoutAnalytics = workoutAnalytics,
       _workoutClock = workoutClock,
       _telemetry =
           telemetry ?? NoopAppTelemetry(appInfo: AppInfo.placeholder()),
       _diagnosticsStore = diagnosticsStore ?? DiagnosticsStore.inMemory(),
       _now = nowProvider ?? DateTime.now,
       super(const WorkoutSessionState());

  final HrMonitorRepository _hrMonitorRepository;
  final TrainerRepository _trainerRepository;
  final HrAverager _hrAverager;
  final PowerAverager _powerAverager;
  final PowerAdjustmentPolicy _powerAdjustmentPolicy;
  final WorkoutAnalytics _workoutAnalytics;
  final WorkoutClock _workoutClock;
  final AppTelemetry _telemetry;
  final DiagnosticsStore _diagnosticsStore;
  final DateTime Function() _now;

  final List<HrSample> _hrSamples = <HrSample>[];
  final List<PowerSample> _powerSamples = <PowerSample>[];
  final List<PowerSample> _livePowerSamples = <PowerSample>[];

  StreamSubscription<HrSample>? _hrSubscription;
  StreamSubscription<TrainerTelemetry>? _telemetrySubscription;
  StreamSubscription<ConnectionStatus>? _hrStatusSubscription;
  StreamSubscription<ConnectionStatus>? _trainerStatusSubscription;
  Timer? _controlTimer;
  Timer? _countdownTimer;

  int _adjustmentCarryNumerator = 0;
  int? _lastCommandedPower;
  DateTime? _rideStart;
  DateTime? _lastHrSampleAt;
  bool _hadPauseOrDisconnect = false;
  bool _summaryCaptured = false;
  bool _summaryTelemetryCaptured = false;
  String? _sessionId;

  static const Duration _staleHrThreshold = Duration(seconds: 5);

  void initialize() {
    _hrSubscription ??= _hrMonitorRepository.hrSamples.listen(_onHrSample);
    _telemetrySubscription ??= _trainerRepository.telemetry.listen(
      _onTrainerTelemetry,
    );
    _hrStatusSubscription ??= _hrMonitorRepository.connectionStatus.listen((
      status,
    ) {
      state = state.copyWith(hrStatus: status);
      _evaluatePauseState(now: _now());
    });
    _trainerStatusSubscription ??= _trainerRepository.connectionStatus.listen((
      status,
    ) {
      state = state.copyWith(
        trainerStatus: status,
        clearCurrentCadence: status != ConnectionStatus.connected,
      );
      _evaluatePauseState(now: _now());
    });
  }

  void selectWorkoutType(WorkoutType type) {
    if (state.isRunning) {
      return;
    }
    state = state.copyWith(selectedWorkoutType: type, clearError: true);
    _trackWorkoutEvent(
      'workout_selected',
      telemetryProperties: <String, Object?>{'workout_type': type.name},
      diagnosticsData: <String, Object?>{'workout_type': type.name},
      includeSession: false,
    );
  }

  Future<void> startWorkout(WorkoutConfig config) async {
    _resetSessionData();
    _rideStart = _now();

    final initialPhase =
        config.workoutType == WorkoutType.zone2Assessment ||
            config.workoutType == WorkoutType.powerErg
        ? WorkoutPhase.warmup
        : WorkoutPhase.active;
    final int initialPower;
    if (config is Zone2AssessmentConfig) {
      initialPower = config.warmupStartPower;
    } else if (config is PowerErgConfig) {
      initialPower = config.warmupStartPower;
    } else if (config is HrErgConfig) {
      initialPower = config.startingWatts;
    } else {
      state = state.copyWith(error: 'Unsupported workout type.');
      return;
    }
    final initialTargetHr = switch (config) {
      HrErgConfig() => config.targetHr,
      PowerErgConfig() => config.maxHr,
      _ => null,
    };

    state = state.copyWith(
      activeConfig: config,
      phase: initialPhase,
      totalDuration: config.duration,
      remainingDuration: config.duration,
      targetHr: initialTargetHr,
      lastAdjustmentWatts: 0,
      statusLabel: _workoutClock.labelForPhase(
        config.workoutType,
        initialPhase,
      ),
      clearProvisionalSummary: true,
      clearSummary: true,
      clearError: true,
      clearPauseReason: true,
      clearPhaseBeforePause: true,
    );

    await _beginSession(config);

    final started = await _setTargetPowerSafely(
      initialPower,
      reason: 'workout_start',
    );
    if (!started) {
      _trackWorkoutEvent(
        'workout_start_failed',
        telemetryProperties: <String, Object?>{
          'workout_type': config.workoutType.name,
        },
        diagnosticsData: _configDetailsFor(config),
      );
      await _finishSession(outcome: 'start_failed');
      return;
    }

    if (config is HrErgConfig) {
      _controlTimer?.cancel();
      _controlTimer = Timer.periodic(
        Duration(seconds: config.loopSeconds),
        (_) => _runHrErgControlTick(),
      );
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _runCountdownTick(),
    );

    _evaluatePauseState(now: _now());
  }

  Future<void> stopWorkout({bool manual = true}) async {
    final config = state.activeConfig;
    if (config == null) {
      return;
    }

    _captureSummaryIfNeeded(manualStop: manual);

    _controlTimer?.cancel();
    _controlTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    state = state.copyWith(
      phase: WorkoutPhase.completed,
      statusLabel: _workoutClock.labelForPhase(
        config.workoutType,
        WorkoutPhase.completed,
      ),
      clearPauseReason: true,
      clearPhaseBeforePause: true,
    );

    _trackWorkoutEvent(
      manual ? 'workout_manual_stop' : 'workout_completed',
      telemetryProperties: <String, Object?>{
        'result': manual ? 'manual_stop' : 'completed',
      },
      diagnosticsData: <String, Object?>{
        'result': manual ? 'manual_stop' : 'completed',
      },
    );
    await _finishSession(outcome: manual ? 'manual_stop' : 'completed');
  }

  Future<void> updateHrErgTargetHr(int targetHr) async {
    final config = state.activeConfig;
    if (config is! HrErgConfig) {
      return;
    }

    state = state.copyWith(targetHr: targetHr, clearError: true);
    state = state.copyWith(
      activeConfig: HrErgConfig(
        startingWatts: config.startingWatts,
        targetHr: targetHr,
        loopSeconds: config.loopSeconds,
        duration: config.duration,
        minPower: config.minPower,
        maxPower: config.maxPower,
        hrAverageWindow: config.hrAverageWindow,
      ),
    );
  }

  Future<void> updatePowerErgTargetPower(int targetPower) async {
    final config = state.activeConfig;
    if (config is! PowerErgConfig) {
      return;
    }

    final nextConfig = PowerErgConfig(
      targetPower: targetPower,
      maxHr: config.maxHr,
      activeDuration: config.activeDuration,
      loopSeconds: config.loopSeconds,
      hrAverageWindow: config.hrAverageWindow,
      minPower: config.minPower,
    );

    state = state.copyWith(activeConfig: nextConfig, clearError: true);

    if (state.phase == WorkoutPhase.active) {
      await _setTargetPowerSafely(
        nextConfig.steadyPower,
        reason: 'power_erg_target_update',
      );
    }
  }

  void _onHrSample(HrSample sample) {
    _lastHrSampleAt = sample.timestamp;
    _hrSamples.add(sample);
    _trimSamples(now: sample.timestamp);

    final config = state.activeConfig;
    final window = config is HrErgConfig
        ? config.hrAverageWindow
        : const Duration(seconds: 60);
    final averageHr = _hrAverager.average(
      _hrSamples,
      now: sample.timestamp,
      window: window,
    );

    state = state.copyWith(
      currentHr: sample.bpm,
      averageHr: averageHr,
      clearError: true,
    );

    _evaluatePauseState(now: sample.timestamp);
  }

  void _onTrainerTelemetry(TrainerTelemetry telemetry) {
    final sample = PowerSample(
      watts: telemetry.powerWatts,
      timestamp: telemetry.timestamp,
    );
    _powerSamples.add(sample);
    _livePowerSamples.add(sample);
    _trimSamples(now: telemetry.timestamp);
    state = state.copyWith(
      currentPower: telemetry.powerWatts,
      displayPower: _powerAverager.average(
        _livePowerSamples,
        now: telemetry.timestamp,
      ),
      currentCadence: telemetry.cadenceRpm,
      clearCurrentCadence: telemetry.cadenceRpm == null,
    );
    _evaluatePauseState(now: telemetry.timestamp);
  }

  Future<void> _runCountdownTick() async {
    final config = state.activeConfig;
    final remaining = state.remainingDuration;
    if (config == null ||
        remaining == null ||
        !state.isRunning ||
        state.isPaused ||
        state.phase == WorkoutPhase.completed) {
      return;
    }

    final now = _now();
    _evaluatePauseState(now: now);
    if (state.isPaused) {
      return;
    }
    _sampleCurrentPower(now);

    final nextRemaining = remaining - const Duration(seconds: 1);
    final clampedRemaining = nextRemaining.isNegative
        ? Duration.zero
        : nextRemaining;

    state = state.copyWith(remainingDuration: clampedRemaining);

    if (config.workoutType == WorkoutType.hrErg) {
      await _handleHrErgCountdown(remaining: clampedRemaining);
    } else if (config is Zone2AssessmentConfig) {
      await _handleAssessmentCountdown(
        config: config,
        remaining: clampedRemaining,
      );
    } else if (config is PowerErgConfig) {
      _updatePowerErgProvisionalSummary();
      await _handlePowerErgCountdown(
        config: config,
        remaining: clampedRemaining,
      );
    }

    if (clampedRemaining == Duration.zero) {
      await stopWorkout(manual: false);
    }
  }

  Future<void> _handleHrErgCountdown({required Duration remaining}) async {
    _updateHrErgProvisionalSummary();

    if (state.phase == WorkoutPhase.cooldown) {
      return;
    }

    if (_workoutClock.shouldEnterHrErgCooldown(remaining)) {
      _captureSummaryIfNeeded(manualStop: false);
      state = state.copyWith(
        phase: WorkoutPhase.cooldown,
        targetHr: 95,
        statusLabel: _workoutClock.labelForPhase(
          WorkoutType.hrErg,
          WorkoutPhase.cooldown,
        ),
        clearProvisionalSummary: true,
      );
    }
  }

  void _updateHrErgProvisionalSummary() {
    final config = state.activeConfig;
    final rideStart = _rideStart;
    if (config is! HrErgConfig ||
        rideStart == null ||
        state.phase == WorkoutPhase.cooldown ||
        state.phase == WorkoutPhase.completed) {
      return;
    }

    final provisional = _workoutAnalytics.summarizeHrErgProvisional(
      hrSamples: _hrSamples,
      powerSamples: _powerSamples,
      rideStart: rideStart,
      analysisEnd: _now(),
    );
    state = state.copyWith(
      provisionalSummary: provisional.analysisAvailable ? provisional : null,
    );
  }

  void _updatePowerErgProvisionalSummary() {
    final config = state.activeConfig;
    final rideStart = _rideStart;
    if (config is! PowerErgConfig ||
        rideStart == null ||
        state.phase == WorkoutPhase.cooldown ||
        state.phase == WorkoutPhase.completed) {
      return;
    }

    final provisional = _workoutAnalytics.summarizePowerErgProvisional(
      hrSamples: _hrSamples,
      powerSamples: _powerSamples,
      rideStart: rideStart,
      analysisEnd: _now(),
    );
    state = state.copyWith(
      provisionalSummary: provisional.analysisAvailable ? provisional : null,
    );
  }

  Future<void> _handleAssessmentCountdown({
    required Zone2AssessmentConfig config,
    required Duration remaining,
  }) async {
    final elapsed = _workoutClock.elapsed(
      totalDuration: config.duration,
      remainingDuration: remaining,
    );
    final nextPhase = _workoutClock.assessmentPhase(
      config: config,
      elapsed: elapsed,
    );

    if (nextPhase == WorkoutPhase.warmup) {
      final nextWarmupPower = config.warmupPowerAt(elapsed);
      if (nextWarmupPower != _lastCommandedPower) {
        final updated = await _setTargetPowerSafely(
          nextWarmupPower,
          reason: 'assessment_warmup_ramp',
        );
        if (!updated) {
          return;
        }
      }
    }

    if (nextPhase == state.phase) {
      return;
    }

    if (nextPhase == WorkoutPhase.active) {
      final updated = await _setTargetPowerSafely(
        config.steadyPower,
        reason: 'assessment_active_start',
      );
      if (!updated) {
        return;
      }
      state = state.copyWith(
        phase: WorkoutPhase.active,
        statusLabel: _workoutClock.labelForPhase(
          WorkoutType.zone2Assessment,
          WorkoutPhase.active,
        ),
      );
      return;
    }

    if (nextPhase == WorkoutPhase.cooldown) {
      _captureSummaryIfNeeded(manualStop: false);
      final updated = await _setTargetPowerSafely(
        config.cooldownPower,
        reason: 'assessment_cooldown_start',
      );
      if (!updated) {
        return;
      }
      state = state.copyWith(
        phase: WorkoutPhase.cooldown,
        statusLabel: _workoutClock.labelForPhase(
          WorkoutType.zone2Assessment,
          WorkoutPhase.cooldown,
        ),
      );
    }
  }

  Future<void> _handlePowerErgCountdown({
    required PowerErgConfig config,
    required Duration remaining,
  }) async {
    final elapsed = _workoutClock.elapsed(
      totalDuration: config.duration,
      remainingDuration: remaining,
    );
    final nextPhase = _workoutClock.powerErgPhase(
      config: config,
      elapsed: elapsed,
    );

    if (nextPhase == WorkoutPhase.warmup) {
      final nextWarmupPower = config.warmupPowerAt(elapsed);
      if (nextWarmupPower != _lastCommandedPower) {
        final updated = await _setTargetPowerSafely(
          nextWarmupPower,
          reason: 'power_erg_warmup_ramp',
        );
        if (!updated) {
          return;
        }
      }
    }

    if (nextPhase == state.phase) {
      if (nextPhase == WorkoutPhase.active) {
        await _runPowerErgActiveControl(config);
      }
      return;
    }

    if (nextPhase == WorkoutPhase.active) {
      final updated = await _setTargetPowerSafely(
        config.steadyPower,
        reason: 'power_erg_active_start',
      );
      if (!updated) {
        return;
      }
      state = state.copyWith(
        phase: WorkoutPhase.active,
        statusLabel: _workoutClock.labelForPhase(
          WorkoutType.powerErg,
          WorkoutPhase.active,
        ),
      );
      return;
    }

    if (nextPhase == WorkoutPhase.cooldown) {
      _captureSummaryIfNeeded(manualStop: false);
      final updated = await _setTargetPowerSafely(
        config.cooldownPower,
        reason: 'power_erg_cooldown_start',
      );
      if (!updated) {
        return;
      }
      state = state.copyWith(
        phase: WorkoutPhase.cooldown,
        statusLabel: _workoutClock.labelForPhase(
          WorkoutType.powerErg,
          WorkoutPhase.cooldown,
        ),
      );
      _adjustmentCarryNumerator = 0;
      return;
    }

    if (nextPhase == WorkoutPhase.active) {
      await _runPowerErgActiveControl(config);
    }
  }

  Future<void> _runHrErgControlTick() async {
    final config = state.activeConfig;
    if (config is! HrErgConfig ||
        !state.isRunning ||
        state.isPaused ||
        state.phase == WorkoutPhase.completed) {
      return;
    }

    final now = _now();
    _evaluatePauseState(now: now);
    if (state.isPaused) {
      return;
    }

    final avgHr = _hrAverager.average(
      _hrSamples,
      now: now,
      window: config.hrAverageWindow,
    );
    if (avgHr == null || state.targetHr == null) {
      _pause(PauseReason.staleHr);
      return;
    }

    final currentPower = _lastCommandedPower ?? config.startingWatts;
    final result = _powerAdjustment(avgHr - state.targetHr!, config);
    final nextPower = min(
      config.maxPower,
      max(config.minPower, currentPower + result.watts),
    );

    final updated = await _setTargetPowerSafely(
      nextPower,
      reason: 'hr_erg_control_tick',
    );
    if (updated) {
      state = state.copyWith(
        averageHr: avgHr,
        lastAdjustmentWatts: result.watts,
        clearError: true,
      );
    }
  }

  Future<void> _runPowerErgActiveControl(PowerErgConfig config) async {
    if (!state.isRunning ||
        state.isPaused ||
        state.phase != WorkoutPhase.active) {
      return;
    }

    final now = _now();
    _evaluatePauseState(now: now);
    if (state.isPaused) {
      return;
    }

    final avgHr = _hrAverager.average(
      _hrSamples,
      now: now,
      window: config.hrAverageWindow,
    );
    if (avgHr == null || state.targetHr == null) {
      _pause(PauseReason.staleHr);
      return;
    }

    state = state.copyWith(averageHr: avgHr, clearError: true);

    if (avgHr <= state.targetHr!) {
      _adjustmentCarryNumerator = 0;
      state = state.copyWith(lastAdjustmentWatts: 0);
      return;
    }

    final result = _powerAdjustmentPolicy.adjustmentForRate(
      perMinute: PowerAdjustmentPolicy.fixedOverMaxHrRatePerMinute,
      loopSeconds: 1,
      carryNumerator: _adjustmentCarryNumerator,
    );
    _adjustmentCarryNumerator = result.nextCarryNumerator;
    if (result.watts == 0) {
      state = state.copyWith(lastAdjustmentWatts: 0);
      return;
    }

    final currentPower = _lastCommandedPower ?? config.steadyPower;
    final nextPower = max(config.minPower, currentPower + result.watts);

    final updated = await _setTargetPowerSafely(
      nextPower,
      reason: 'power_erg_control_tick',
    );
    if (updated) {
      state = state.copyWith(
        lastAdjustmentWatts: result.watts,
        clearError: true,
      );
    }
  }

  PowerAdjustmentResult _powerAdjustment(double delta, HrErgConfig config) {
    final result = _powerAdjustmentPolicy.adjustmentForLoop(
      delta: delta,
      loopSeconds: config.loopSeconds,
      carryNumerator: _adjustmentCarryNumerator,
    );
    _adjustmentCarryNumerator = result.nextCarryNumerator;
    return result;
  }

  void _evaluatePauseState({required DateTime now}) {
    if (!state.isRunning || state.phase == WorkoutPhase.completed) {
      return;
    }

    final nextReason = _pauseReason(now);
    if (nextReason != null) {
      _pause(nextReason);
      return;
    }

    if (state.isPaused && state.phaseBeforePause != null) {
      final resumePhase = state.phaseBeforePause!;
      final config = state.activeConfig;
      final pauseReason = state.pauseReason;
      if (config == null) {
        return;
      }
      state = state.copyWith(
        phase: resumePhase,
        statusLabel: _workoutClock.labelForPhase(
          config.workoutType,
          resumePhase,
        ),
        clearPauseReason: true,
        clearPhaseBeforePause: true,
      );
      _trackWorkoutEvent(
        'workout_resumed',
        telemetryProperties: <String, Object?>{
          if (pauseReason != null) 'pause_reason': pauseReason.name,
        },
        diagnosticsData: <String, Object?>{
          if (pauseReason != null) 'pause_reason': pauseReason.name,
        },
      );
    }
  }

  PauseReason? _pauseReason(DateTime now) {
    final config = state.activeConfig;
    if (config is PowerErgConfig) {
      if (!state.trainerConnected) {
        return PauseReason.trainerDisconnected;
      }
      if (!state.trainerFresh) {
        return PauseReason.trainerStale;
      }
      if (state.phase != WorkoutPhase.active) {
        return null;
      }
    }
    if (!state.hrConnected) {
      return PauseReason.hrDisconnected;
    }
    if (!state.hrFresh) {
      return PauseReason.staleHr;
    }
    if (!state.trainerConnected) {
      return PauseReason.trainerDisconnected;
    }
    if (!state.trainerFresh) {
      return PauseReason.trainerStale;
    }
    if (_lastHrSampleAt == null ||
        now.difference(_lastHrSampleAt!) > _staleHrThreshold) {
      return PauseReason.staleHr;
    }
    return null;
  }

  void _pause(PauseReason reason) {
    if (state.isPaused && state.pauseReason == reason) {
      return;
    }

    _hadPauseOrDisconnect = true;
    state = state.copyWith(
      phase: WorkoutPhase.paused,
      pauseReason: reason,
      phaseBeforePause: state.isPaused ? state.phaseBeforePause : state.phase,
      statusLabel: _pauseLabel(reason),
    );
    _trackWorkoutEvent(
      'workout_paused',
      telemetryProperties: <String, Object?>{'pause_reason': reason.name},
      diagnosticsData: <String, Object?>{'pause_reason': reason.name},
    );
  }

  String _pauseLabel(PauseReason reason) {
    switch (reason) {
      case PauseReason.hrDisconnected:
        return 'Paused: HR disconnected';
      case PauseReason.trainerDisconnected:
        return 'Paused: trainer disconnected';
      case PauseReason.trainerStale:
        return 'Paused: trainer not responding';
      case PauseReason.staleHr:
        return 'Paused: waiting for fresh HR';
    }
  }

  void _captureSummaryIfNeeded({required bool manualStop}) {
    if (_summaryCaptured) {
      return;
    }
    final config = state.activeConfig;
    final rideStart = _rideStart;
    if (config == null || rideStart == null) {
      return;
    }

    final summary = config is HrErgConfig
        ? _workoutAnalytics.summarizeHrErg(
            hrSamples: _hrSamples,
            powerSamples: _powerSamples,
            rideStart: rideStart,
            analysisEnd: _now(),
          )
        : config is Zone2AssessmentConfig
        ? _workoutAnalytics.summarizeAssessment(
            config: config,
            hrSamples: _hrSamples,
            powerSamples: _powerSamples,
            rideStart: rideStart,
            completed: !manualStop,
            hadPauseOrDisconnect: _hadPauseOrDisconnect,
          )
        : config is PowerErgConfig
        ? _workoutAnalytics.summarizePowerErg(
            hrSamples: _hrSamples,
            powerSamples: _powerSamples,
            rideStart: rideStart,
            analysisEnd: _now(),
          )
        : null;

    _summaryCaptured = true;
    if (summary != null) {
      state = state.copyWith(summary: summary);
      _trackSummary(summary);
    }
  }

  void _sampleCurrentPower(DateTime now) {
    final power = state.currentPower;
    if (power == null) {
      return;
    }
    _powerSamples.add(PowerSample(watts: power, timestamp: now));
    _trimSamples(now: now);
  }

  void _trimSamples({required DateTime now}) {
    final cutoff = now.subtract(const Duration(hours: 2));
    final liveCutoff = now.subtract(const Duration(seconds: 10));
    _hrSamples.removeWhere((sample) => sample.timestamp.isBefore(cutoff));
    _powerSamples.removeWhere((sample) => sample.timestamp.isBefore(cutoff));
    _livePowerSamples.removeWhere(
      (sample) => sample.timestamp.isBefore(liveCutoff),
    );
  }

  Future<void> _beginSession(WorkoutConfig config) async {
    final rideStart = _rideStart ?? _now();
    final sessionId = 'session_${rideStart.toUtc().microsecondsSinceEpoch}';
    _sessionId = sessionId;
    final context = SessionContext(
      sessionId: sessionId,
      workoutType: config.workoutType,
      startedAt: rideStart,
      details: _configDetailsFor(config),
    );
    _telemetry.setSessionContext(context);
    try {
      await _diagnosticsStore.startSession(context);
    } catch (error, stackTrace) {
      _recordWorkoutError(
        'diagnostics_session_start_failed',
        error,
        stackTrace,
        includeSession: false,
      );
    }
    _trackWorkoutEvent(
      'workout_started',
      telemetryProperties: <String, Object?>{
        'workout_type': config.workoutType.name,
      },
      diagnosticsData: _configDetailsFor(config),
    );
  }

  Future<void> _finishSession({required String outcome}) async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      _telemetry.clearSessionContext();
      return;
    }

    try {
      await _diagnosticsStore.closeSession(
        sessionId: sessionId,
        outcome: outcome,
        summary: _summaryDetails(state.summary),
      );
    } catch (error, stackTrace) {
      _recordWorkoutError(
        'diagnostics_session_close_failed',
        error,
        stackTrace,
        includeSession: false,
      );
    } finally {
      _telemetry.clearSessionContext();
      _sessionId = null;
    }
  }

  Future<bool> _setTargetPowerSafely(
    int watts, {
    required String reason,
  }) async {
    try {
      await _trainerRepository.setTargetPower(watts);
      _lastCommandedPower = watts;
      state = state.copyWith(clearError: true);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(error: error.toString());
      _recordWorkoutError(
        'trainer_target_power_failed',
        error,
        stackTrace,
        diagnosticsData: <String, Object?>{
          'requested_watts': watts,
          'reason': reason,
        },
      );
      return false;
    }
  }

  void _trackSummary(WorkoutSummary summary) {
    if (_summaryTelemetryCaptured) {
      return;
    }
    _summaryTelemetryCaptured = true;
    _trackWorkoutEvent(
      'workout_summary',
      telemetryProperties: _summaryDetails(summary),
      diagnosticsData: _summaryDetails(summary),
    );
  }

  Map<String, Object?> _configDetailsFor(WorkoutConfig config) {
    return switch (config) {
      HrErgConfig() => <String, Object?>{
        'workout_type': config.workoutType.name,
        'duration_minutes': config.duration.inMinutes,
        'starting_watts': config.startingWatts,
        'target_hr': config.targetHr,
        'loop_seconds': config.loopSeconds,
      },
      PowerErgConfig() => <String, Object?>{
        'workout_type': config.workoutType.name,
        'duration_minutes': config.duration.inMinutes,
        'target_power': config.targetPower,
        'max_hr': config.maxHr,
        'active_duration_minutes': config.activeDuration.inMinutes,
      },
      Zone2AssessmentConfig() => <String, Object?>{
        'workout_type': config.workoutType.name,
        'duration_minutes': config.duration.inMinutes,
        'assessment_power': config.assessmentPower,
      },
      _ => <String, Object?>{'workout_type': config.workoutType.name},
    };
  }

  Map<String, Object?> _summaryDetails(WorkoutSummary? summary) {
    if (summary == null) {
      return const <String, Object?>{};
    }
    return <String, Object?>{
      'analysis_available': summary.analysisAvailable,
      'provisional': summary.provisional,
      if (summary.powerFadePercent != null)
        'power_fade_pct': _roundToTenth(summary.powerFadePercent!),
      if (summary.aerobicDriftPercent != null)
        'aerobic_drift_pct': _roundToTenth(summary.aerobicDriftPercent!),
      if (summary.zone2Estimate != null)
        'zone2_lower_watts': summary.zone2Estimate!.lowerWatts,
      if (summary.zone2Estimate != null)
        'zone2_upper_watts': summary.zone2Estimate!.upperWatts,
      if (summary.zone2Estimate != null)
        'zone2_confidence': summary.zone2Estimate!.confidence,
      if (summary.analysisMessage != null)
        'analysis_message': summary.analysisMessage,
      if (summary.interpretation != null)
        'interpretation': summary.interpretation,
    };
  }

  double _roundToTenth(double value) {
    return (value * 10).round() / 10;
  }

  void _trackWorkoutEvent(
    String event, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
    bool includeSession = true,
  }) {
    unawaited(_telemetry.track(event, properties: telemetryProperties));
    unawaited(
      _diagnosticsStore.recordRuntimeEvent(event, data: diagnosticsData),
    );
    if (includeSession && _sessionId != null) {
      unawaited(
        _diagnosticsStore.recordSessionEvent(
          _sessionId!,
          event,
          data: diagnosticsData,
        ),
      );
    }
  }

  void _recordWorkoutError(
    String reason,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
    bool includeSession = true,
  }) {
    final runtimeData = <String, Object?>{
      'error': error.toString(),
      ...diagnosticsData,
    };
    unawaited(
      _telemetry.recordError(
        Exception(reason),
        stackTrace,
        reason: reason,
        properties: <String, Object?>{
          'error_type': error.runtimeType.toString(),
          ...telemetryProperties,
        },
      ),
    );
    unawaited(_diagnosticsStore.recordRuntimeEvent(reason, data: runtimeData));
    if (includeSession && _sessionId != null) {
      unawaited(
        _diagnosticsStore.recordSessionEvent(
          _sessionId!,
          reason,
          data: runtimeData,
        ),
      );
    }
  }

  void _resetSessionData() {
    _controlTimer?.cancel();
    _countdownTimer?.cancel();
    _adjustmentCarryNumerator = 0;
    _lastCommandedPower = null;
    _hrSamples.clear();
    _powerSamples.clear();
    _livePowerSamples.clear();
    _rideStart = null;
    _lastHrSampleAt = null;
    _hadPauseOrDisconnect = false;
    _summaryCaptured = false;
    _summaryTelemetryCaptured = false;
    _sessionId = null;
    _telemetry.clearSessionContext();
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
    _countdownTimer?.cancel();
    _hrSubscription?.cancel();
    _telemetrySubscription?.cancel();
    _hrStatusSubscription?.cancel();
    _trainerStatusSubscription?.cancel();
    _telemetry.clearSessionContext();
    super.dispose();
  }
}
