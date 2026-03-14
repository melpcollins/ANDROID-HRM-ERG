import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_device_harness.dart';

enum MockHrScenario { idle, steady, slowRise, dropout }

class MockWorkoutDebugState {
  const MockWorkoutDebugState({
    this.steadyHr = 135,
    this.scenario = MockHrScenario.idle,
    this.statusMessage = 'Idle',
  });

  final int steadyHr;
  final MockHrScenario scenario;
  final String statusMessage;

  MockWorkoutDebugState copyWith({
    int? steadyHr,
    MockHrScenario? scenario,
    String? statusMessage,
  }) {
    return MockWorkoutDebugState(
      steadyHr: steadyHr ?? this.steadyHr,
      scenario: scenario ?? this.scenario,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class MockWorkoutDebugController extends StateNotifier<MockWorkoutDebugState> {
  MockWorkoutDebugController({required MockDeviceHarness harness})
    : _harness = harness,
      super(const MockWorkoutDebugState());

  final MockDeviceHarness _harness;
  Timer? _scenarioTimer;

  Future<void> connectHrMonitor() async {
    await _harness.connectHrMonitor();
    state = state.copyWith(statusMessage: 'Mock HR connected');
  }

  Future<void> disconnectHrMonitor() async {
    _stopScenario();
    await _harness.disconnectHrMonitor();
    state = state.copyWith(statusMessage: 'Mock HR disconnected');
  }

  Future<void> connectTrainer() async {
    await _harness.connectTrainer();
    state = state.copyWith(statusMessage: 'Mock trainer connected');
  }

  Future<void> disconnectTrainer() async {
    await _harness.disconnectTrainer();
    state = state.copyWith(statusMessage: 'Mock trainer disconnected');
  }

  Future<void> reconnectTrainer() async {
    await _harness.reconnectTrainer();
    state = state.copyWith(statusMessage: 'Mock trainer reconnected');
  }

  void pauseTrainerTelemetry() {
    _harness.stopTrainerTelemetry();
    state = state.copyWith(statusMessage: 'Mock trainer telemetry stalled');
  }

  void resumeTrainerTelemetry() {
    _harness.resumeTrainerTelemetry();
    state = state.copyWith(statusMessage: 'Mock trainer telemetry resumed');
  }

  void setSteadyHr(int bpm) {
    state = state.copyWith(steadyHr: bpm, statusMessage: 'Steady HR set to $bpm bpm');
  }

  void emitSteadyHrNow() {
    _harness.emitHr(state.steadyHr);
    state = state.copyWith(statusMessage: 'Emitted ${state.steadyHr} bpm');
  }

  void startSteadyScenario() {
    _startScenario(MockHrScenario.steady, (tick) {
      _harness.emitHr(state.steadyHr);
    }, 'Steady HR scenario running');
  }

  void startSlowRiseScenario() {
    final baseHr = state.steadyHr;
    _startScenario(MockHrScenario.slowRise, (tick) {
      final nextHr = baseHr + (tick ~/ 3);
      _harness.emitHr(nextHr);
    }, 'Slow rise scenario running');
  }

  void startDropoutScenario() {
    _startScenario(MockHrScenario.dropout, (tick) {
      if (tick < 4) {
        _harness.emitHr(state.steadyHr);
        return;
      }
      _stopScenario();
      state = state.copyWith(
        scenario: MockHrScenario.dropout,
        statusMessage: 'Dropout scenario stopped sending HR',
      );
    }, 'Dropout scenario running');
  }

  void reset() {
    _stopScenario();
    _harness.reset();
    state = const MockWorkoutDebugState(
      statusMessage: 'Mock devices reset',
    );
  }

  void _startScenario(
    MockHrScenario scenario,
    void Function(int tick) onTick,
    String statusMessage,
  ) {
    _stopScenario();
    var tick = 0;
    state = state.copyWith(scenario: scenario, statusMessage: statusMessage);
    _scenarioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      onTick(tick);
      tick += 1;
    });
  }

  void _stopScenario() {
    _scenarioTimer?.cancel();
    _scenarioTimer = null;
  }

  @override
  void dispose() {
    _stopScenario();
    super.dispose();
  }
}
