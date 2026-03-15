import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/models/ble_readiness.dart';
import 'ble_permission_service.dart';

class AndroidBlePermissionService implements BlePermissionService {
  const AndroidBlePermissionService();

  static const List<Permission> _modernPermissions = <Permission>[
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ];

  static const Permission _legacyScanPermission = Permission.locationWhenInUse;

  @override
  Stream<bool> get bluetoothEnabledStream =>
      FlutterBluePlus.adapterState.map(_isBluetoothEnabled).distinct();

  @override
  Future<BleReadiness> checkStatus() async {
    final statuses = await _currentPermissionStatuses();
    return BleReadiness(
      permissionsGranted: _permissionsGranted(statuses),
      bluetoothEnabled: await _currentBluetoothEnabled(),
      permissionPermanentlyDenied: _isPermanentlyDenied(statuses),
    );
  }

  @override
  Future<BleReadiness> ensurePermissions() async {
    var statuses = await _currentPermissionStatuses();
    if (!_permissionsGranted(statuses)) {
      statuses = await _requestPermissionStatuses();
    }

    return BleReadiness(
      permissionsGranted: _permissionsGranted(statuses),
      bluetoothEnabled: await _currentBluetoothEnabled(),
      permissionPermanentlyDenied: _isPermanentlyDenied(statuses),
    );
  }

  @override
  Future<bool> openSystemSettings() => openAppSettings();

  Future<Map<Permission, PermissionStatus>> _currentPermissionStatuses() async {
    return <Permission, PermissionStatus>{
      for (final permission in <Permission>[
        ..._modernPermissions,
        _legacyScanPermission,
      ])
        permission: await permission.status,
    };
  }

  Future<Map<Permission, PermissionStatus>> _requestPermissionStatuses() async {
    final requested = await _modernPermissions.request();
    final legacyStatus = await _legacyScanPermission.request();

    return <Permission, PermissionStatus>{
      ...requested,
      _legacyScanPermission: legacyStatus,
    };
  }

  bool _permissionsGranted(Map<Permission, PermissionStatus> statuses) {
    final modernGranted = _modernPermissions.every(
      (permission) => statuses[permission]?.isGranted ?? false,
    );
    final legacyGranted = statuses[_legacyScanPermission]?.isGranted ?? false;
    return modernGranted || legacyGranted;
  }

  bool _isPermanentlyDenied(Map<Permission, PermissionStatus> statuses) {
    return statuses.values.any((status) => status.isPermanentlyDenied);
  }

  Future<bool> _currentBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState
        .where((value) => value != BluetoothAdapterState.unknown)
        .cast<BluetoothAdapterState>()
        .first
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => BluetoothAdapterState.unknown,
        );
    return _isBluetoothEnabled(state);
  }

  bool _isBluetoothEnabled(BluetoothAdapterState state) {
    return state == BluetoothAdapterState.on;
  }
}
