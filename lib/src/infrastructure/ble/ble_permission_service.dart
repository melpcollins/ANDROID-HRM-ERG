import '../../domain/models/ble_readiness.dart';

abstract class BlePermissionService {
  Stream<bool> get bluetoothEnabledStream;

  Future<BleReadiness> checkStatus();

  Future<BleReadiness> ensurePermissions();

  Future<bool> openSystemSettings();
}

class AlwaysReadyBlePermissionService implements BlePermissionService {
  const AlwaysReadyBlePermissionService();

  @override
  Stream<bool> get bluetoothEnabledStream => Stream<bool>.value(true);

  @override
  Future<BleReadiness> checkStatus() async {
    return const BleReadiness(permissionsGranted: true, bluetoothEnabled: true);
  }

  @override
  Future<BleReadiness> ensurePermissions() async {
    return const BleReadiness(permissionsGranted: true, bluetoothEnabled: true);
  }

  @override
  Future<bool> openSystemSettings() async => true;
}
