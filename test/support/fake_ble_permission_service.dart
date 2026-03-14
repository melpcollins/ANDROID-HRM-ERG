import 'dart:async';

import 'package:android_hrm_erg/src/domain/models/ble_readiness.dart';
import 'package:android_hrm_erg/src/infrastructure/ble/ble_permission_service.dart';

class FakeBlePermissionService implements BlePermissionService {
  FakeBlePermissionService({
    BleReadiness initialReadiness = const BleReadiness(
      permissionsGranted: true,
      bluetoothEnabled: true,
    ),
  }) : _readiness = initialReadiness;

  final StreamController<bool> _bluetoothEnabledController =
      StreamController<bool>.broadcast();

  BleReadiness _readiness;
  int ensureCalls = 0;
  int checkCalls = 0;
  int openSettingsCalls = 0;

  @override
  Stream<bool> get bluetoothEnabledStream async* {
    yield _readiness.bluetoothEnabled;
    yield* _bluetoothEnabledController.stream;
  }

  @override
  Future<BleReadiness> checkStatus() async {
    checkCalls += 1;
    return _readiness;
  }

  @override
  Future<BleReadiness> ensurePermissions() async {
    ensureCalls += 1;
    return _readiness;
  }

  @override
  Future<bool> openSystemSettings() async {
    openSettingsCalls += 1;
    return true;
  }

  void setReadiness(BleReadiness readiness) {
    _readiness = readiness;
    _bluetoothEnabledController.add(readiness.bluetoothEnabled);
  }

  void dispose() {
    _bluetoothEnabledController.close();
  }
}
