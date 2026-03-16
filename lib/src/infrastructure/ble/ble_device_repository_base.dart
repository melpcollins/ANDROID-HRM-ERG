import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/ble_device_info.dart';
import '../../domain/models/connection_status.dart';
import '../diagnostics/diagnostics_store.dart';
import '../observability/app_telemetry.dart';
import '../storage/device_selection_store.dart';
import 'ble_event_logger.dart';

typedef NameMatcher = bool Function(String name);

abstract class BleDeviceRepositoryBase {
  BleDeviceRepositoryBase({
    required DeviceSelectionStore store,
    required AppTelemetry telemetry,
    required DiagnosticsStore diagnosticsStore,
    required NameMatcher nameMatcher,
    required String deviceRole,
  }) : _store = store,
       _telemetry = telemetry,
       _diagnosticsStore = diagnosticsStore,
       _nameMatcher = nameMatcher,
       _deviceRole = deviceRole;

  final DeviceSelectionStore _store;
  final AppTelemetry _telemetry;
  final DiagnosticsStore _diagnosticsStore;
  final NameMatcher _nameMatcher;
  final String _deviceRole;

  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Future<void>? _connectionAttempt;

  final StreamController<ConnectionStatus> _connectionController =
      StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;

  Stream<ConnectionStatus> get connectionStatus async* {
    yield _status;
    yield* _connectionController.stream;
  }

  @protected
  ConnectionStatus get currentStatus => _status;

  @protected
  DiagnosticsStore get diagnosticsStore => _diagnosticsStore;

  @protected
  String get deviceRole => _deviceRole;

  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _stopActiveScanIfNeeded(trigger: 'scan_request');
    _trackEvent('ble_scan_started');
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
          logBleEvent(
            'device_found',
            details: <String, Object?>{'deviceId': id, 'name': name},
          );
          _recordRuntimeEvent(
            'ble_device_found',
            data: <String, Object?>{'device_id': id, 'device_name': name},
          );
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

    logBleEvent(
      'scan_completed',
      details: <String, Object?>{'count': devices.length},
    );
    _trackEvent(
      'ble_scan_completed',
      telemetryProperties: <String, Object?>{'count': devices.length},
      diagnosticsData: <String, Object?>{
        'count': devices.length,
        'devices': devices
            .map(
              (device) => <String, Object?>{
                'id': device.id,
                'name': device.name,
              },
            )
            .toList(),
      },
    );

    return devices;
  }

  Future<void> connect(String deviceId) async {
    await _runConnectionAttempt(
      deviceId: deviceId,
      requestTrigger: 'connect_request',
      attemptEvent: 'ble_connect_attempt',
      resultEvent: 'ble_connect_result',
      failureReason: 'ble_connect_failed',
      inProgressStatus: ConnectionStatus.connecting,
      successLogEvent: 'connected',
      failureLogEvent: 'connect_failed',
    );
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

    logBleEvent(
      'reconnect_started',
      details: <String, Object?>{'deviceId': savedId},
    );
    await _runConnectionAttempt(
      deviceId: savedId,
      requestTrigger: 'reconnect_request',
      attemptEvent: 'ble_reconnect_attempt',
      resultEvent: 'ble_reconnect_result',
      failureReason: 'ble_reconnect_failed',
      inProgressStatus: ConnectionStatus.reconnecting,
      successLogEvent: 'reconnect_success',
      failureLogEvent: 'reconnect_failed',
    );
  }

  Future<String?> getSavedDeviceId();

  Future<void> persistSelectedDeviceId(String id);

  DeviceSelectionStore get selectionStore => _store;

  BluetoothDevice? get connectedDevice => _device;

  @protected
  Future<void> onConnected(String deviceId) async {}

  @protected
  void emitStatus(ConnectionStatus status) {
    final previousStatus = _status;
    _status = status;
    onStatusChanged(status);
    if (previousStatus != status) {
      _trackEvent(
        'ble_status_change',
        telemetryProperties: <String, Object?>{
          'from_status': previousStatus.name,
          'to_status': status.name,
        },
        diagnosticsData: <String, Object?>{
          'from_status': previousStatus.name,
          'to_status': status.name,
        },
      );
    }
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

  @protected
  void trackRepositoryEvent(
    String event, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
  }) {
    _trackEvent(
      event,
      telemetryProperties: telemetryProperties,
      diagnosticsData: diagnosticsData,
    );
  }

  @protected
  void recordRepositoryError(
    String reason,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
  }) {
    _recordSanitizedError(
      reason,
      error,
      stackTrace,
      telemetryProperties: telemetryProperties,
      diagnosticsData: diagnosticsData,
    );
  }

  void _trackEvent(
    String event, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
  }) {
    final diagnosticsPayload = <String, Object?>{
      'device_role': _deviceRole,
      ...diagnosticsData,
    };
    unawaited(
      _diagnosticsStore.recordRuntimeEvent(event, data: diagnosticsPayload),
    );
    unawaited(
      _telemetry.track(
        event,
        properties: <String, Object?>{
          'device_role': _deviceRole,
          ...telemetryProperties,
        },
      ),
    );
  }

  void _recordRuntimeEvent(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    unawaited(
      _diagnosticsStore.recordRuntimeEvent(
        event,
        data: <String, Object?>{'device_role': _deviceRole, ...data},
      ),
    );
  }

  void _recordSanitizedError(
    String reason,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
  }) {
    _recordRuntimeEvent(
      reason,
      data: <String, Object?>{'error': error.toString(), ...diagnosticsData},
    );
    unawaited(
      _telemetry.recordError(
        Exception(reason),
        stackTrace,
        reason: reason,
        properties: <String, Object?>{
          'device_role': _deviceRole,
          'error_type': error.runtimeType.toString(),
          ...telemetryProperties,
        },
      ),
    );
  }

  Future<void> _runConnectionAttempt({
    required String deviceId,
    required String requestTrigger,
    required String attemptEvent,
    required String resultEvent,
    required String failureReason,
    required ConnectionStatus inProgressStatus,
    required String successLogEvent,
    required String failureLogEvent,
  }) async {
    if (_connectionAttempt != null) {
      _trackEvent(
        '${attemptEvent}_suppressed',
        telemetryProperties: const <String, Object?>{'result': 'suppressed'},
        diagnosticsData: <String, Object?>{
          'device_id': deviceId,
          'reason': 'in_flight',
        },
      );
      return;
    }
    if (currentStatus != ConnectionStatus.disconnected) {
      _trackEvent(
        '${attemptEvent}_suppressed',
        telemetryProperties: const <String, Object?>{'result': 'suppressed'},
        diagnosticsData: <String, Object?>{
          'device_id': deviceId,
          'reason': 'invalid_state',
          'status': currentStatus.name,
        },
      );
      return;
    }

    final guard = Completer<void>();
    _connectionAttempt = guard.future;
    try {
      await _stopActiveScanIfNeeded(trigger: requestTrigger);
      _trackEvent(
        attemptEvent,
        diagnosticsData: <String, Object?>{'device_id': deviceId},
      );
      await _connectDevice(deviceId, inProgressStatus: inProgressStatus);
      await persistSelectedDeviceId(deviceId);
      await onConnected(deviceId);
      logBleEvent(
        successLogEvent,
        details: <String, Object?>{'deviceId': deviceId},
      );
      _trackEvent(
        resultEvent,
        telemetryProperties: const <String, Object?>{'result': 'success'},
        diagnosticsData: <String, Object?>{
          'result': 'success',
          'device_id': deviceId,
        },
      );
      emitStatus(ConnectionStatus.connectedNoData);
    } catch (error, stackTrace) {
      await _resetConnectionTransport(disconnectDevice: true);
      emitStatus(ConnectionStatus.disconnected);
      logBleEvent(
        failureLogEvent,
        details: <String, Object?>{'deviceId': deviceId},
      );
      _trackEvent(
        resultEvent,
        telemetryProperties: const <String, Object?>{'result': 'failure'},
        diagnosticsData: <String, Object?>{
          'result': 'failure',
          'device_id': deviceId,
          'error': error.toString(),
        },
      );
      _recordSanitizedError(
        failureReason,
        error,
        stackTrace,
        diagnosticsData: <String, Object?>{'device_id': deviceId},
      );
      rethrow;
    } finally {
      guard.complete();
      _connectionAttempt = null;
    }
  }

  Future<void> _connectDevice(
    String deviceId, {
    required ConnectionStatus inProgressStatus,
  }) async {
    final nextDevice = BluetoothDevice.fromId(deviceId);

    await _connectionSubscription?.cancel();
    _device = nextDevice;
    emitStatus(inProgressStatus);

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
          emitStatus(inProgressStatus);
          break;
      }
    });

    await nextDevice.connect(timeout: const Duration(seconds: 20));
  }

  Future<void> _resetConnectionTransport({
    required bool disconnectDevice,
  }) async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    final device = _device;
    _device = null;
    if (disconnectDevice && device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // Best-effort only. Cleanup should not mask the original failure.
      }
    }
  }

  Future<void> _stopActiveScanIfNeeded({required String trigger}) async {
    try {
      final isScanning = await FlutterBluePlus.isScanning.first;
      if (!isScanning) {
        return;
      }

      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.isScanning.where((value) => value == false).first;
      _trackEvent(
        'ble_scan_stopped',
        telemetryProperties: <String, Object?>{'trigger': trigger},
        diagnosticsData: <String, Object?>{'trigger': trigger},
      );
    } catch (_) {
      // Best-effort only. A failed stop-scan should not block connect/scan.
    }
  }
}
