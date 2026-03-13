import 'dart:async';

import '../domain/models/ble_device_info.dart';
import '../domain/models/connection_status.dart';
import '../domain/models/hr_sample.dart';
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
  final StreamController<int> _currentPowerController =
      StreamController<int>.broadcast();

  final List<int> targetPowerWrites = <int>[];
  String? _savedDeviceId;
  int _currentWatts = 0;

  @override
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  @override
  Stream<int> get currentPower async* {
    yield _currentWatts;
    yield* _currentPowerController.stream;
  }

  int get currentWatts => _currentWatts;

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
    _currentPowerController.add(watts);
  }

  void reset() {
    _savedDeviceId = null;
    _currentWatts = 0;
    targetPowerWrites.clear();
    _connectionStatusController.add(ConnectionStatus.disconnected);
    _currentPowerController.add(_currentWatts);
  }

  void dispose() {
    _connectionStatusController.close();
    _currentPowerController.close();
  }
}
