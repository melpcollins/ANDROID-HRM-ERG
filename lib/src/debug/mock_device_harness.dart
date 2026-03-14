import 'dart:async';

import '../domain/models/ble_device_info.dart';
import '../domain/models/connection_status.dart';
import '../domain/models/hr_sample.dart';
import '../domain/models/trainer_telemetry.dart';
import '../domain/repositories/hr_monitor_repository.dart';
import '../domain/repositories/trainer_repository.dart';

class MockDeviceHarness {
  MockDeviceHarness({DateTime Function()? nowProvider})
    : hrMonitorRepository = MockHrMonitorRepository(nowProvider: nowProvider),
      trainerRepository = MockTrainerRepository();

  final MockHrMonitorRepository hrMonitorRepository;
  final MockTrainerRepository trainerRepository;

  Future<void> connectHrMonitor() async {
    await hrMonitorRepository.connect(MockHrMonitorRepository.deviceId);
  }

  Future<void> disconnectHrMonitor() async {
    await hrMonitorRepository.disconnect();
  }

  Future<void> connectTrainer() async {
    await trainerRepository.connect(MockTrainerRepository.deviceId);
  }

  Future<void> disconnectTrainer() async {
    await trainerRepository.disconnect();
  }

  Future<void> reconnectTrainer() async {
    await trainerRepository.reconnect();
  }

  void emitHr(int bpm) {
    hrMonitorRepository.emitHr(bpm);
  }

  void emitTrainerTelemetry(int watts, {int? cadence}) {
    trainerRepository.emitTelemetry(watts, cadence: cadence);
  }

  void stopTrainerTelemetry() {
    trainerRepository.autoEmitTelemetryOnSetTargetPower = false;
    trainerRepository.emitConnectionStatus(ConnectionStatus.connectedNoData);
  }

  void resumeTrainerTelemetry() {
    trainerRepository.autoEmitTelemetryOnSetTargetPower = true;
    trainerRepository.emitConnectionStatus(ConnectionStatus.connected);
    trainerRepository.emitTelemetry(
      trainerRepository.currentWatts,
      cadence: trainerRepository.currentCadence,
    );
  }

  void reset() {
    hrMonitorRepository.reset();
    trainerRepository.reset();
  }

  void dispose() {
    hrMonitorRepository.dispose();
    trainerRepository.dispose();
  }
}

class MockHrMonitorRepository implements HrMonitorRepository {
  MockHrMonitorRepository({DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  static const String deviceId = 'mock-hrm-1';

  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<HrSample> _hrSamplesController =
      StreamController<HrSample>.broadcast();
  final DateTime Function() _now;

  String? _savedDeviceId;

  @override
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  @override
  Stream<HrSample> get hrSamples => _hrSamplesController.stream;

  void emitHr(int bpm, {DateTime? timestamp}) {
    _hrSamplesController.add(
      HrSample(bpm: bpm, timestamp: timestamp ?? _now()),
    );
  }

  void emitConnectionStatus(ConnectionStatus status) {
    _connectionStatusController.add(status);
  }

  @override
  Future<void> connect(String deviceId) async {
    _savedDeviceId = deviceId;
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<String?> getSavedDeviceId() async => _savedDeviceId;

  @override
  Future<void> reconnect() async {
    if (_savedDeviceId == null) {
      throw Exception('No saved mock HR monitor.');
    }
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const [
      BleDeviceInfo(id: deviceId, name: 'Mock HR Monitor'),
    ];
  }

  void reset() {
    _savedDeviceId = null;
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  void dispose() {
    _connectionStatusController.close();
    _hrSamplesController.close();
  }
}

class MockTrainerRepository implements TrainerRepository {
  MockTrainerRepository() {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  static const String deviceId = 'mock-trainer-1';

  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<TrainerTelemetry> _telemetryController =
      StreamController<TrainerTelemetry>.broadcast();

  final List<int> targetPowerWrites = <int>[];
  String? _savedDeviceId;
  int _currentWatts = 0;
  int? _currentCadence;
  bool autoEmitTelemetryOnSetTargetPower = true;

  @override
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  @override
  Stream<TrainerTelemetry> get telemetry async* {
    yield TrainerTelemetry(
      powerWatts: _currentWatts,
      cadenceRpm: _currentCadence,
      timestamp: DateTime.now(),
    );
    yield* _telemetryController.stream;
  }

  int get currentWatts => _currentWatts;
  int? get currentCadence => _currentCadence;

  void emitConnectionStatus(ConnectionStatus status) {
    _connectionStatusController.add(status);
  }

  void emitTelemetry(int watts, {int? cadence, DateTime? timestamp}) {
    _currentWatts = watts;
    _currentCadence = cadence;
    _telemetryController.add(
      TrainerTelemetry(
        powerWatts: watts,
        cadenceRpm: cadence,
        timestamp: timestamp ?? DateTime.now(),
      ),
    );
  }

  @override
  Future<void> connect(String deviceId) async {
    _savedDeviceId = deviceId;
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<String?> getSavedDeviceId() async => _savedDeviceId;

  @override
  Future<void> reconnect() async {
    if (_savedDeviceId == null) {
      throw Exception('No saved mock trainer.');
    }
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const [
      BleDeviceInfo(id: deviceId, name: 'Mock Trainer'),
    ];
  }

  @override
  Future<void> setTargetPower(int watts) async {
    _currentWatts = watts;
    targetPowerWrites.add(watts);
    if (autoEmitTelemetryOnSetTargetPower) {
      emitTelemetry(watts, cadence: _currentCadence);
    }
  }

  void reset() {
    _savedDeviceId = null;
    _currentWatts = 0;
    _currentCadence = null;
    autoEmitTelemetryOnSetTargetPower = true;
    targetPowerWrites.clear();
    _connectionStatusController.add(ConnectionStatus.disconnected);
    emitTelemetry(_currentWatts);
  }

  void dispose() {
    _connectionStatusController.close();
    _telemetryController.close();
  }
}
