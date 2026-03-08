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

  static const Duration _avgWindow = Duration(seconds: 60);
  static const Duration _loopInterval = Duration(seconds: 20);

  void initialize() {
    _hrSubscription ??= _hrMonitorRepository.hrSamples.listen((sample) {
      _hrSamples.add(sample);
      _trimOldSamples();

      state = state.copyWith(
        currentHr: sample.bpm,
        averageHr: _calculateHrAverage(),
      );
    });

    _powerSubscription ??= _trainerRepository.currentPower.listen((watts) {
      _powerSamples.add(_PowerSample(watts: watts, timestamp: DateTime.now()));
      _trimOldSamples();

      state = state.copyWith(
        currentPower: watts,
        averagePower: _calculatePowerAverage(),
      );
    });
  }

  Future<void> startSession({
    required int startingWatts,
    required int targetHr,
  }) async {
    state = state.copyWith(
      isRunning: true,
      startingWatts: startingWatts,
      targetHr: targetHr,
      currentPower: startingWatts,
      clearError: true,
    );

    await _trainerRepository.setTargetPower(startingWatts);

    _controlTimer?.cancel();
    _controlTimer = Timer.periodic(_loopInterval, (_) => _runControlTick());
  }

  Future<void> stopSession() async {
    _controlTimer?.cancel();
    _controlTimer = null;
    state = state.copyWith(isRunning: false);
  }

  Future<void> _runControlTick() async {
    if (!state.isRunning || state.targetHr == null) {
      return;
    }

    final avgHr = _calculateHrAverage();
    final currentPower = state.currentPower ?? state.startingWatts ?? 0;

    if (avgHr == null) {
      state = state.copyWith(
        error: 'No HR data yet. Waiting for monitor samples...',
      );
      return;
    }

    final delta = avgHr - state.targetHr!;
    final adjustPerMinute = _mapDeltaToPowerPerMinute(delta);
    final adjustPerLoop = (adjustPerMinute / 3.0).round();

    final nextPower = min(500, max(50, currentPower + adjustPerLoop));

    try {
      await _trainerRepository.setTargetPower(nextPower);
      state = state.copyWith(
        currentPower: nextPower,
        averageHr: avgHr,
        averagePower: _calculatePowerAverage(),
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

  double? _calculateHrAverage() {
    if (_hrSamples.isEmpty) {
      return null;
    }
    final total = _hrSamples.fold<int>(0, (sum, sample) => sum + sample.bpm);
    return total / _hrSamples.length;
  }

  double? _calculatePowerAverage() {
    if (_powerSamples.isEmpty) {
      return null;
    }
    final total = _powerSamples.fold<int>(
      0,
      (sum, sample) => sum + sample.watts,
    );
    return total / _powerSamples.length;
  }

  void _trimOldSamples() {
    final cutoff = DateTime.now().subtract(_avgWindow);
    _hrSamples.removeWhere((sample) => sample.timestamp.isBefore(cutoff));
    _powerSamples.removeWhere((sample) => sample.timestamp.isBefore(cutoff));
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
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
