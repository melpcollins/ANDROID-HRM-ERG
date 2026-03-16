import 'dart:async';

import 'package:android_hrm_erg/src/domain/models/ble_device_info.dart';
import 'package:android_hrm_erg/src/domain/models/connection_status.dart';
import 'package:android_hrm_erg/src/domain/models/hr_sample.dart';
import 'package:android_hrm_erg/src/domain/models/trainer_telemetry.dart';
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
  final List<BleDeviceInfo> scanResults = <BleDeviceInfo>[];
  final List<List<BleDeviceInfo>> queuedScanResults = <List<BleDeviceInfo>>[];
  final List<String> callLog = <String>[];

  String? savedDeviceId;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int reconnectCalls = 0;
  int scanCalls = 0;
  Future<void> Function(String deviceId)? connectHandler;
  Future<void> Function()? disconnectHandler;
  Future<void> Function()? reconnectHandler;

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

  void emitConnectionStatus(ConnectionStatus status) {
    _connectionStatusController.add(status);
  }

  @override
  Future<void> connect(String deviceId) async {
    savedDeviceId = deviceId;
    connectCalls += 1;
    callLog.add('hr_connect:$deviceId');
    if (connectHandler != null) {
      await connectHandler!(deviceId);
      return;
    }
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    callLog.add('hr_disconnect');
    if (disconnectHandler != null) {
      await disconnectHandler!();
      return;
    }
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<String?> getSavedDeviceId() async => savedDeviceId;

  @override
  Future<void> reconnect() async {
    reconnectCalls += 1;
    callLog.add('hr_reconnect');
    if (reconnectHandler != null) {
      await reconnectHandler!();
      return;
    }
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    scanCalls += 1;
    if (queuedScanResults.isNotEmpty) {
      return List<BleDeviceInfo>.of(queuedScanResults.removeAt(0));
    }
    return List<BleDeviceInfo>.of(scanResults);
  }
}

class FakeTrainerRepository implements TrainerRepository {
  FakeTrainerRepository() {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<TrainerTelemetry> _telemetryController =
      StreamController<TrainerTelemetry>.broadcast();

  final List<int> targetPowerWrites = <int>[];
  final List<BleDeviceInfo> scanResults = <BleDeviceInfo>[];
  final List<String> callLog = <String>[];
  bool autoEmitTelemetryOnSetTargetPower = true;
  int currentWatts = 0;
  int? currentCadence;
  String? savedDeviceId;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int reconnectCalls = 0;
  int scanCalls = 0;
  Future<void> Function(String deviceId)? connectHandler;
  Future<void> Function()? disconnectHandler;
  Future<void> Function()? reconnectHandler;

  @override
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  @override
  Stream<TrainerTelemetry> get telemetry => _telemetryController.stream;

  void emitTelemetry(int watts, {int? cadence, DateTime? timestamp}) {
    currentWatts = watts;
    currentCadence = cadence;
    _telemetryController.add(
      TrainerTelemetry(
        powerWatts: watts,
        cadenceRpm: cadence,
        timestamp: timestamp ?? DateTime.now(),
      ),
    );
  }

  void emitConnectionStatus(ConnectionStatus status) {
    _connectionStatusController.add(status);
  }

  @override
  Future<void> connect(String deviceId) async {
    savedDeviceId = deviceId;
    connectCalls += 1;
    callLog.add('trainer_connect:$deviceId');
    if (connectHandler != null) {
      await connectHandler!(deviceId);
      return;
    }
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    callLog.add('trainer_disconnect');
    if (disconnectHandler != null) {
      await disconnectHandler!();
      return;
    }
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  @override
  Future<String?> getSavedDeviceId() async => savedDeviceId;

  @override
  Future<void> reconnect() async {
    reconnectCalls += 1;
    callLog.add('trainer_reconnect');
    if (reconnectHandler != null) {
      await reconnectHandler!();
      return;
    }
    _connectionStatusController.add(ConnectionStatus.connected);
  }

  @override
  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    scanCalls += 1;
    return List<BleDeviceInfo>.of(scanResults);
  }

  @override
  Future<void> setTargetPower(int watts) async {
    currentWatts = watts;
    targetPowerWrites.add(watts);
    if (autoEmitTelemetryOnSetTargetPower) {
      emitTelemetry(watts, cadence: currentCadence);
    }
  }
}
