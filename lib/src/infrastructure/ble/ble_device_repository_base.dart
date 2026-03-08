import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/ble_device_info.dart';
import '../../domain/models/connection_status.dart';
import '../storage/device_selection_store.dart';

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

  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _emitStatus(ConnectionStatus.scanning);

    final Map<String, BleDeviceInfo> allDevices = <String, BleDeviceInfo>{};
    final Map<String, BleDeviceInfo> matchingDevices =
        <String, BleDeviceInfo>{};

    final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        final name = _bestDeviceName(result);
        final deviceInfo = BleDeviceInfo(id: id, name: name);

        allDevices[id] = deviceInfo;
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

    _emitStatus(
      _device?.isConnected == true
          ? ConnectionStatus.connected
          : ConnectionStatus.disconnected,
    );

    final Iterable<BleDeviceInfo> selected = matchingDevices.isNotEmpty
        ? matchingDevices.values
        : allDevices.values;

    final devices = selected.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return devices;
  }

  Future<void> connect(String deviceId) async {
    final nextDevice = BluetoothDevice.fromId(deviceId);

    await _connectionSubscription?.cancel();
    _device = nextDevice;
    _emitStatus(ConnectionStatus.connecting);

    _connectionSubscription = nextDevice.connectionState.listen((state) {
      switch (state) {
        case BluetoothConnectionState.connected:
          _emitStatus(ConnectionStatus.connected);
          break;
        case BluetoothConnectionState.disconnected:
          _emitStatus(ConnectionStatus.disconnected);
          break;
        case _:
          _emitStatus(ConnectionStatus.connecting);
          break;
      }
    });

    try {
      await nextDevice.connect(timeout: const Duration(seconds: 20));
      await persistSelectedDeviceId(deviceId);
      _emitStatus(ConnectionStatus.connected);
    } catch (_) {
      _emitStatus(ConnectionStatus.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _emitStatus(ConnectionStatus.disconnected);
  }

  Future<void> reconnect() async {
    final savedId = await getSavedDeviceId();
    if (savedId == null || savedId.isEmpty) {
      return;
    }

    _emitStatus(ConnectionStatus.reconnecting);
    await connect(savedId);
  }

  Future<String?> getSavedDeviceId();

  Future<void> persistSelectedDeviceId(String id);

  DeviceSelectionStore get selectionStore => _store;

  void _emitStatus(ConnectionStatus status) {
    _status = status;
    if (!_connectionController.isClosed) {
      _connectionController.add(status);
    }
  }

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
