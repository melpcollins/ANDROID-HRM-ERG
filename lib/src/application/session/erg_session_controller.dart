import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/hr_sample.dart';
import '../../domain/repositories/hr_monitor_repository.dart';
import '../../domain/repositories/trainer_repository.dart';
import 'erg_session_state.dart';

class ErgSessionController extends StateNotifier<ErgSessionState> {
  ErgSessionController({
    required HrMonitorRepository hrMonitorRepository,
    required TrainerRepository trainerRepository,
  }) : _hrMonitorRepository = hrMonitorRepository,
       _trainerRepository = trainerRepository,
       super(const ErgSessionState());

  final HrMonitorRepository _hrMonitorRepository;
  final TrainerRepository _trainerRepository;

  final List<HrSample> _hrSamples = <HrSample>[];
  final List<_PowerSample> _powerSamples = <_PowerSample>[];

  StreamSubscription<HrSample>? _hrSubscription;
  StreamSubscription<int>? _powerSubscription;
  Timer? _controlTimer;
  Timer? _countdownTimer;
  Duration _loopInterval = const Duration(seconds: 10);
  double _maxRollingAveragePower = 0;

  static const Duration _hrAvgWindow = Duration(seconds: 10);
  static const Duration _powerAvgWindow = Duration(minutes: 20);
  static const Duration _cooldownLeadTime = Duration(minutes: 5);
  static const int _cooldownTargetHr = 95;

  void initialize() {
    _hrSubscription ??= _hrMonitorRepository.hrSamples.listen((sample) {
      _hrSamples.add(sample);
      _trimOldSamples();

      state = state.copyWith(
        currentHr: sample.bpm,
        averageHr: _calculateHrAverage(window: _hrAvgWindow),
      );
    });

    _powerSubscription ??= _trainerRepository.currentPower.listen((watts) {
      _powerSamples.add(_PowerSample(watts: watts, timestamp: DateTime.now()));
      _trimOldSamples();
      _updatePowerDriftStats(currentPower: watts);
    });
  }

  Future<void> startSession({
    required int startingWatts,
    required int targetHr,
    required int loopSeconds,
    required Duration sessionDuration,
  }) async {
    _loopInterval = Duration(seconds: loopSeconds);
    _maxRollingAveragePower = 0;
    _hrSamples.clear();
    _powerSamples.clear();

    state = state.copyWith(
      isRunning: true,
      startingWatts: startingWatts,
      targetHr: targetHr,
      loopSeconds: loopSeconds,
      sessionDuration: sessionDuration,
      remainingDuration: sessionDuration,
      isCooldown: false,
      currentPower: startingWatts,
      driftWatts: 0,
      driftPercent: null,
      averagePower: null,
      averageHr: null,
      clearError: true,
    );

    await _trainerRepository.setTargetPower(startingWatts);

    _controlTimer?.cancel();
    _controlTimer = Timer.periodic(_loopInterval, (_) => _runControlTick());
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _runCountdownTick(),
    );
  }

  Future<void> stopSession() async {
    _controlTimer?.cancel();
    _controlTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = state.copyWith(isRunning: false, isCooldown: false);
  }

  Future<void> _runCountdownTick() async {
    if (!state.isRunning) {
      return;
    }

    final remaining = state.remainingDuration;
    if (remaining == null) {
      return;
    }

    final nextRemaining = remaining - const Duration(seconds: 1);
    final clampedRemaining = nextRemaining.isNegative
        ? Duration.zero
        : nextRemaining;

    var nextTargetHr = state.targetHr;
    var nextIsCooldown = state.isCooldown;

    if (!state.isCooldown && clampedRemaining <= _cooldownLeadTime) {
      nextTargetHr = _cooldownTargetHr;
      nextIsCooldown = true;
    }

    state = state.copyWith(
      remainingDuration: clampedRemaining,
      targetHr: nextTargetHr,
      isCooldown: nextIsCooldown,
    );

    if (clampedRemaining == Duration.zero) {
      await stopSession();
    }
  }

  Future<void> _runControlTick() async {
    if (!state.isRunning || state.targetHr == null) {
      return;
    }

    final avgHr = _calculateHrAverage(window: _hrAvgWindow);
    final currentPower = state.currentPower ?? state.startingWatts ?? 0;

    if (avgHr == null) {
      state = state.copyWith(
        error: 'No HR data yet. Waiting for monitor samples...',
      );
      return;
    }

    final delta = avgHr - state.targetHr!;
    final adjustPerMinute = _mapDeltaToPowerPerMinute(delta);
    final adjustPerLoop = (adjustPerMinute * (_loopInterval.inSeconds / 60.0))
        .round();

    final nextPower = min(500, max(50, currentPower + adjustPerLoop));

    try {
      await _trainerRepository.setTargetPower(nextPower);
      state = state.copyWith(
        currentPower: nextPower,
        averageHr: avgHr,
        averagePower: _calculatePowerAverage(window: _powerAvgWindow),
        lastAdjustmentWatts: adjustPerLoop,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  int _mapDeltaToPowerPerMinute(double delta) {
    if (delta >= 3) {
      return -10;
    }
    if (delta >= 2) {
      return -6;
    }
    if (delta >= 1) {
      return -3;
    }
    if (delta <= -3) {
      return 10;
    }
    if (delta <= -2) {
      return 6;
    }
    if (delta <= -1) {
      return 3;
    }
    return 0;
  }

  double? _calculateHrAverage({required Duration window}) {
    final relevantSamples = _samplesWithinWindow(window);
    if (relevantSamples.isEmpty) {
      return null;
    }

    final total = relevantSamples.fold<int>(
      0,
      (sum, sample) => sum + sample.bpm,
    );
    return total / relevantSamples.length;
  }

  double? _calculatePowerAverage({required Duration window}) {
    final relevantSamples = _powerSamplesWithinWindow(window);
    if (relevantSamples.isEmpty) {
      return null;
    }

    final total = relevantSamples.fold<int>(
      0,
      (sum, sample) => sum + sample.watts,
    );
    return total / relevantSamples.length;
  }

  List<HrSample> _samplesWithinWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return _hrSamples
        .where((sample) => sample.timestamp.isAfter(cutoff))
        .toList();
  }

  List<_PowerSample> _powerSamplesWithinWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return _powerSamples
        .where((sample) => sample.timestamp.isAfter(cutoff))
        .toList();
  }

  void _updatePowerDriftStats({required int currentPower}) {
    final currentRollingAvg = _calculatePowerAverage(window: _powerAvgWindow);
    if (currentRollingAvg == null) {
      return;
    }

    if (currentRollingAvg > _maxRollingAveragePower) {
      _maxRollingAveragePower = currentRollingAvg;
    }

    final driftWatts = _maxRollingAveragePower - currentRollingAvg;
    final driftPercent = (driftWatts <= 0 || currentPower <= 0)
        ? null
        : (driftWatts / currentPower) * 100;

    state = state.copyWith(
      currentPower: currentPower,
      averagePower: currentRollingAvg,
      driftWatts: driftWatts,
      driftPercent: driftPercent,
    );
  }

  void _trimOldSamples() {
    final now = DateTime.now();
    final hrCutoff = now.subtract(_hrAvgWindow);
    final powerCutoff = now.subtract(_powerAvgWindow);

    _hrSamples.removeWhere((sample) => sample.timestamp.isBefore(hrCutoff));
    _powerSamples.removeWhere(
      (sample) => sample.timestamp.isBefore(powerCutoff),
    );
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
    _countdownTimer?.cancel();
    _hrSubscription?.cancel();
    _powerSubscription?.cancel();
    super.dispose();
  }
}

class _PowerSample {
  const _PowerSample({required this.watts, required this.timestamp});

  final int watts;
  final DateTime timestamp;
}
