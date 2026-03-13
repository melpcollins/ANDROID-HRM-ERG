import 'dart:async';

import 'package:android_hrm_erg/src/domain/models/ble_device_info.dart';
import 'package:android_hrm_erg/src/domain/models/connection_status.dart';
import 'package:android_hrm_erg/src/domain/models/hr_sample.dart';
import 'package:android_hrm_erg/src/domain/repositories/hr_monitor_repository.dart';
import 'package:android_hrm_erg/src/domain/repositories/trainer_repository.dart';

class FakeHrMonitorRepository implements HrMonitorRepository {
  FakeHrMonitorRepository() {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<HrSample> _hrSamplesController =
      StreamController<HrSample>.broadcast();

  @override
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  @override
  Stream<HrSample> get hrSamples => _hrSamplesController.stream;

  void emitHr(int bpm, {DateTime? timestamp}) {
    _hrSamplesController.add(
      HrSample(bpm: bpm, timestamp: timestamp ?? DateTime.now()),
    );
  }

  @override
  Future<void> connect(String deviceId) async {
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<String?> getSavedDeviceId() async => null;

  @override
  Future<void> reconnect() async {
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const <BleDeviceInfo>[];
  }
}

class FakeTrainerRepository implements TrainerRepository {
  FakeTrainerRepository() {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<int> _currentPowerController =
      StreamController<int>.broadcast();

  final List<int> targetPowerWrites = <int>[];
  int currentWatts = 0;

  @override
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  @override
  Stream<int> get currentPower => _currentPowerController.stream;

  void emitPower(int watts) {
    currentWatts = watts;
    _currentPowerController.add(watts);
  }

  @override
  Future<void> connect(String deviceId) async {
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<String?> getSavedDeviceId() async => null;

  @override
  Future<void> reconnect() async {
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const <BleDeviceInfo>[];
  }

  @override
  Future<void> setTargetPower(int watts) async {
    currentWatts = watts;
    targetPowerWrites.add(watts);
    _currentPowerController.add(watts);
  }
}
