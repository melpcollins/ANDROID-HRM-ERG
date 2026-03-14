import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/ble_device_info.dart';
import '../../domain/models/connection_status.dart';
import '../storage/device_selection_store.dart';
import 'ble_event_logger.dart';

typedef NameMatcher = bool Function(String name);

abstract class BleDeviceRepositoryBase {
  BleDeviceRepositoryBase({
    required DeviceSelectionStore store,
    required NameMatcher nameMatcher,
  }) : _store = store,
       _nameMatcher = nameMatcher;

  final DeviceSelectionStore _store;
  final NameMatcher _nameMatcher;

  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final StreamController<ConnectionStatus> _connectionController =
      StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;

  Stream<ConnectionStatus> get connectionStatus async* {
    yield _status;
    yield* _connectionController.stream;
  }

  @protected
  ConnectionStatus get currentStatus => _status;

  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    logBleEvent('scan_started');
    final previousStatus = _status;
    emitStatus(ConnectionStatus.scanning);

    final Map<String, BleDeviceInfo> allDevices = <String, BleDeviceInfo>{};
    final Map<String, BleDeviceInfo> matchingDevices =
        <String, BleDeviceInfo>{};
    final Set<String> discoveredDeviceIds = <String>{};

    final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        final name = _bestDeviceName(result);
        final deviceInfo = BleDeviceInfo(id: id, name: name);

        allDevices[id] = deviceInfo;
        if (discoveredDeviceIds.add(id)) {
          logBleEvent('device_found', details: <String, Object?>{
            'deviceId': id,
            'name': name,
          });
        }
        if (_nameMatcher(name)) {
          matchingDevices[id] = deviceInfo;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      await FlutterBluePlus.isScanning.where((value) => value == false).first;
    } finally {
      await scanSubscription.cancel();
    }

    emitStatus(
      previousStatus == ConnectionStatus.connected ||
              previousStatus == ConnectionStatus.connectedNoData
          ? previousStatus
          : ConnectionStatus.disconnected,
    );

    final Iterable<BleDeviceInfo> selected = matchingDevices.isNotEmpty
        ? matchingDevices.values
        : allDevices.values;

    final devices = selected.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    logBleEvent('scan_completed', details: <String, Object?>{
      'count': devices.length,
    });

    return devices;
  }

  Future<void> connect(String deviceId) async {
    final nextDevice = BluetoothDevice.fromId(deviceId);

    await _connectionSubscription?.cancel();
    _device = nextDevice;
    emitStatus(ConnectionStatus.connecting);

    _connectionSubscription = nextDevice.connectionState.listen((state) {
      switch (state) {
        case BluetoothConnectionState.connected:
          emitStatus(ConnectionStatus.connectedNoData);
          break;
        case BluetoothConnectionState.disconnected:
          _device = null;
          emitStatus(ConnectionStatus.disconnected);
          break;
        case _:
          emitStatus(ConnectionStatus.connecting);
          break;
      }
    });

    try {
      await nextDevice.connect(timeout: const Duration(seconds: 20));
      await persistSelectedDeviceId(deviceId);
      logBleEvent('connected', details: <String, Object?>{'deviceId': deviceId});
      emitStatus(ConnectionStatus.connectedNoData);
    } catch (_) {
      emitStatus(ConnectionStatus.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _device?.disconnect();
    _device = null;
    emitStatus(ConnectionStatus.disconnected);
  }

  Future<void> reconnect() async {
    final savedId = await getSavedDeviceId();
    if (savedId == null || savedId.isEmpty) {
      return;
    }

    logBleEvent('reconnect_started', details: <String, Object?>{
      'deviceId': savedId,
    });
    emitStatus(ConnectionStatus.reconnecting);
    try {
      await connect(savedId);
      logBleEvent('reconnect_success', details: <String, Object?>{
        'deviceId': savedId,
      });
    } catch (_) {
      logBleEvent('reconnect_failed', details: <String, Object?>{
        'deviceId': savedId,
      });
      rethrow;
    }
  }

  Future<String?> getSavedDeviceId();

  Future<void> persistSelectedDeviceId(String id);

  DeviceSelectionStore get selectionStore => _store;

  BluetoothDevice? get connectedDevice => _device;

  @protected
  void emitStatus(ConnectionStatus status) {
    _status = status;
    onStatusChanged(status);
    if (!_connectionController.isClosed) {
      _connectionController.add(status);
    }
  }

  @protected
  void onStatusChanged(ConnectionStatus status) {}

  String _bestDeviceName(ScanResult result) {
    final candidates = <String>[
      result.device.platformName,
      result.advertisementData.advName,
      result.device.advName,
    ];

    for (final candidate in candidates) {
      if (candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    final id = result.device.remoteId.str;
    return 'Unknown (${id.length > 8 ? id.substring(0, 8) : id})';
  }
}
