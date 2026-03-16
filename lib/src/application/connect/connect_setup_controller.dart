import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ble_readiness.dart';
import '../../domain/models/ble_device_info.dart';
import '../../domain/models/connection_status.dart';
import '../../domain/repositories/hr_monitor_repository.dart';
import '../../domain/repositories/trainer_repository.dart';
import '../../infrastructure/app/app_info.dart';
import '../../infrastructure/ble/ble_permission_service.dart';
import '../../infrastructure/diagnostics/diagnostics_store.dart';
import '../../infrastructure/observability/app_telemetry.dart';
import '../../infrastructure/storage/device_selection_store.dart';
import 'connect_setup_state.dart';

class ConnectSetupController extends StateNotifier<ConnectSetupState> {
  static const int _hrScanAttempts = 2;
  static const Duration _hrScanRetryDelay = Duration(seconds: 1);
  static const Duration _disconnectWaitTimeout = Duration(seconds: 5);
  static const List<Duration> _defaultAutoReconnectBackoff = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
  ];

  ConnectSetupController({
    required HrMonitorRepository hrMonitorRepository,
    required TrainerRepository trainerRepository,
    required BlePermissionService blePermissionService,
    required DeviceSelectionStore deviceSelectionStore,
    AppTelemetry? telemetry,
    DiagnosticsStore? diagnosticsStore,
    Duration hrStaleThreshold = const Duration(seconds: 5),
    Duration trainerStaleThreshold = const Duration(seconds: 10),
    List<Duration> autoReconnectBackoff = _defaultAutoReconnectBackoff,
  }) : _hrMonitorRepository = hrMonitorRepository,
       _trainerRepository = trainerRepository,
       _blePermissionService = blePermissionService,
       _deviceSelectionStore = deviceSelectionStore,
       _telemetry =
           telemetry ?? NoopAppTelemetry(appInfo: AppInfo.placeholder()),
       _diagnosticsStore = diagnosticsStore ?? DiagnosticsStore.inMemory(),
       _hrStaleThreshold = hrStaleThreshold,
       _trainerStaleThreshold = trainerStaleThreshold,
       _autoReconnectBackoff = List<Duration>.unmodifiable(
         autoReconnectBackoff,
       ),
       super(const ConnectSetupState());

  final HrMonitorRepository _hrMonitorRepository;
  final TrainerRepository _trainerRepository;
  final BlePermissionService _blePermissionService;
  final DeviceSelectionStore _deviceSelectionStore;
  final AppTelemetry _telemetry;
  final DiagnosticsStore _diagnosticsStore;
  final Duration _hrStaleThreshold;
  final Duration _trainerStaleThreshold;
  final List<Duration> _autoReconnectBackoff;

  final List<_ConnectionRequest> _pendingConnectionRequests =
      <_ConnectionRequest>[];
  final Map<_BleDeviceRole, List<_StatusWaiter>> _statusWaiters =
      <_BleDeviceRole, List<_StatusWaiter>>{
        _BleDeviceRole.hrMonitor: <_StatusWaiter>[],
        _BleDeviceRole.trainer: <_StatusWaiter>[],
      };
  final Map<_BleDeviceRole, int> _autoReconnectAttempts = <_BleDeviceRole, int>{
    _BleDeviceRole.hrMonitor: 0,
    _BleDeviceRole.trainer: 0,
  };
  final Map<_BleDeviceRole, bool> _unexpectedDisconnectSuppressed =
      <_BleDeviceRole, bool>{
        _BleDeviceRole.hrMonitor: false,
        _BleDeviceRole.trainer: false,
      };

  StreamSubscription? _hrStatusSubscription;
  StreamSubscription? _trainerStatusSubscription;
  StreamSubscription? _hrSampleSubscription;
  StreamSubscription? _trainerTelemetrySubscription;
  StreamSubscription<bool>? _bluetoothEnabledSubscription;

  Timer? _hrStaleTimer;
  Timer? _trainerStaleTimer;
  Timer? _hrAutoReconnectTimer;
  Timer? _trainerAutoReconnectTimer;
  ConnectionStatus _rawHrStatus = ConnectionStatus.disconnected;
  ConnectionStatus _rawTrainerStatus = ConnectionStatus.disconnected;
  bool _hrHasFreshData = false;
  bool _hrHasReceivedDataThisConnection = false;
  bool _trainerHasFreshData = false;
  bool _connectionQueueRunning = false;
  _ConnectionRequest? _activeConnectionRequest;

  Future<void> initialize() async {
    _hrStatusSubscription ??= _hrMonitorRepository.connectionStatus.listen((
      status,
    ) {
      final previous = _rawHrStatus;
      _rawHrStatus = status;
      _resolveStatusWaiters(_BleDeviceRole.hrMonitor, status);
      _handleRawStatusChange(
        role: _BleDeviceRole.hrMonitor,
        previous: previous,
        next: status,
      );
      _applyHrStatus();
    });

    _trainerStatusSubscription ??= _trainerRepository.connectionStatus.listen((
      status,
    ) {
      final previous = _rawTrainerStatus;
      _rawTrainerStatus = status;
      _resolveStatusWaiters(_BleDeviceRole.trainer, status);
      _handleRawStatusChange(
        role: _BleDeviceRole.trainer,
        previous: previous,
        next: status,
      );
      _applyTrainerStatus();
    });
    _hrSampleSubscription ??= _hrMonitorRepository.hrSamples.listen((_) {
      _hrHasFreshData = true;
      _hrHasReceivedDataThisConnection = true;
      _scheduleHrStaleTimer();
      _markDeviceRecovered(_BleDeviceRole.hrMonitor);
      _applyHrStatus();
    });
    _trainerTelemetrySubscription ??= _trainerRepository.telemetry.listen((_) {
      _trainerHasFreshData = true;
      _scheduleTrainerStaleTimer();
      _markDeviceRecovered(_BleDeviceRole.trainer);
      _applyTrainerStatus();
    });
    _bluetoothEnabledSubscription ??= _blePermissionService
        .bluetoothEnabledStream
        .listen((enabled) {
          final wasEnabled = state.bluetoothEnabled;
          state = state.copyWith(
            bluetoothEnabled: enabled,
            readinessChecked: true,
          );
          if (wasEnabled != enabled) {
            _trackSetupEvent(
              'ble_adapter_state',
              telemetryProperties: <String, Object?>{
                'result': enabled ? 'enabled' : 'disabled',
              },
              diagnosticsData: <String, Object?>{'bluetooth_enabled': enabled},
            );
          }
          if (!enabled) {
            _clearAutoReconnectWork(
              _BleDeviceRole.hrMonitor,
              resetAttempts: true,
              cancelAllPending: true,
              cancellationReason: 'bluetooth_disabled',
            );
            _clearAutoReconnectWork(
              _BleDeviceRole.trainer,
              resetAttempts: true,
              cancelAllPending: true,
              cancellationReason: 'bluetooth_disabled',
            );
          }
          if (!wasEnabled && enabled && state.permissionsGranted) {
            unawaited(
              _enqueueSavedReconnects(
                trigger: 'bluetooth_restored',
              ).catchError((_) {}),
            );
          }
        });

    final hrId = await _hrMonitorRepository.getSavedDeviceId();
    final trainerId = await _trainerRepository.getSavedDeviceId();
    final hrName = await _deviceSelectionStore.getHrMonitorName();
    final trainerName = await _deviceSelectionStore.getTrainerName();

    state = state.copyWith(
      selectedHrId: hrId,
      selectedTrainerId: trainerId,
      selectedHrName: hrName,
      selectedTrainerName: trainerName,
    );

    await _refreshBleReadiness(
      requestPermissions: true,
      reconnectIfReady: true,
      reconnectTrigger: 'saved_reconnect',
    );
  }

  Future<void> scanHrMonitors() async {
    if (!await _ensureBleReady()) {
      return;
    }

    state = state.copyWith(scanningHr: true, clearHrError: true);

    try {
      final devices = await _scanHrDevicesWithWakeRetry();
      state = state.copyWith(hrDevices: devices, scanningHr: false);
      await _refreshSavedNameFromDevices(
        selectedId: state.selectedHrId,
        currentName: state.selectedHrName,
        devices: devices,
        persistName: _deviceSelectionStore.saveHrMonitorName,
        updateState: (name) => state = state.copyWith(selectedHrName: name),
      );
    } catch (error, stackTrace) {
      state = state.copyWith(scanningHr: false, hrError: error.toString());
      _recordSetupError(
        'ble_scan_hr_failed',
        error,
        stackTrace,
        telemetryProperties: const <String, Object?>{
          'device_role': 'hr_monitor',
        },
      );
    }
  }

  Future<void> scanTrainers() async {
    if (!await _ensureBleReady()) {
      return;
    }

    state = state.copyWith(scanningTrainer: true, clearTrainerError: true);

    try {
      final devices = await _trainerRepository.scanForDevices();
      state = state.copyWith(trainerDevices: devices, scanningTrainer: false);
      await _refreshSavedNameFromDevices(
        selectedId: state.selectedTrainerId,
        currentName: state.selectedTrainerName,
        devices: devices,
        persistName: _deviceSelectionStore.saveTrainerName,
        updateState: (name) =>
            state = state.copyWith(selectedTrainerName: name),
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        scanningTrainer: false,
        trainerError: error.toString(),
      );
      _recordSetupError(
        'ble_scan_trainer_failed',
        error,
        stackTrace,
        telemetryProperties: const <String, Object?>{'device_role': 'trainer'},
      );
    }
  }

  Future<void> connectHrMonitor(String deviceId) async {
    if (!await _ensureBleReady()) {
      return;
    }

    _clearAutoReconnectWork(
      _BleDeviceRole.hrMonitor,
      resetAttempts: true,
      cancellationReason: 'manual_connect',
    );
    state = state.copyWith(clearHrError: true);
    _trackSetupEvent(
      'ble_connect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'hr_monitor'},
      diagnosticsData: <String, Object?>{
        'device_role': 'hr_monitor',
        'device_id': deviceId,
      },
    );
    await _enqueueConnectionRequest(
      _ConnectionRequest(
        role: _BleDeviceRole.hrMonitor,
        kind: _ConnectionRequestKind.connect,
        deviceId: deviceId,
        trigger: 'manual',
      ),
    );
  }

  Future<void> connectTrainer(String deviceId) async {
    if (!await _ensureBleReady()) {
      return;
    }

    _clearAutoReconnectWork(
      _BleDeviceRole.trainer,
      resetAttempts: true,
      cancellationReason: 'manual_connect',
    );
    state = state.copyWith(clearTrainerError: true);
    _trackSetupEvent(
      'ble_connect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'trainer'},
      diagnosticsData: <String, Object?>{
        'device_role': 'trainer',
        'device_id': deviceId,
      },
    );
    await _enqueueConnectionRequest(
      _ConnectionRequest(
        role: _BleDeviceRole.trainer,
        kind: _ConnectionRequestKind.connect,
        deviceId: deviceId,
        trigger: 'manual',
      ),
    );
  }

  Future<void> disconnectHrMonitor() async {
    _clearAutoReconnectWork(
      _BleDeviceRole.hrMonitor,
      resetAttempts: true,
      cancelAllPending: true,
      cancellationReason: 'manual_disconnect',
    );
    _unexpectedDisconnectSuppressed[_BleDeviceRole.hrMonitor] = true;
    state = state.copyWith(clearHrError: true);
    _trackSetupEvent(
      'ble_disconnect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'hr_monitor'},
      diagnosticsData: const <String, Object?>{'device_role': 'hr_monitor'},
    );
    try {
      await _hrMonitorRepository.disconnect();
      if (_rawHrStatus == ConnectionStatus.disconnected) {
        _unexpectedDisconnectSuppressed[_BleDeviceRole.hrMonitor] = false;
      }
    } catch (error, stackTrace) {
      state = state.copyWith(hrError: error.toString());
      _recordSetupError(
        'ble_disconnect_hr_failed',
        error,
        stackTrace,
        telemetryProperties: const <String, Object?>{
          'device_role': 'hr_monitor',
        },
      );
    }
  }

  Future<void> disconnectTrainer() async {
    _clearAutoReconnectWork(
      _BleDeviceRole.trainer,
      resetAttempts: true,
      cancelAllPending: true,
      cancellationReason: 'manual_disconnect',
    );
    _unexpectedDisconnectSuppressed[_BleDeviceRole.trainer] = true;
    state = state.copyWith(clearTrainerError: true);
    _trackSetupEvent(
      'ble_disconnect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'trainer'},
      diagnosticsData: const <String, Object?>{'device_role': 'trainer'},
    );
    try {
      await _trainerRepository.disconnect();
      if (_rawTrainerStatus == ConnectionStatus.disconnected) {
        _unexpectedDisconnectSuppressed[_BleDeviceRole.trainer] = false;
      }
    } catch (error, stackTrace) {
      state = state.copyWith(trainerError: error.toString());
      _recordSetupError(
        'ble_disconnect_trainer_failed',
        error,
        stackTrace,
        telemetryProperties: const <String, Object?>{'device_role': 'trainer'},
      );
    }
  }

  Future<void> reconnectHrMonitor({String trigger = 'manual'}) async {
    if (!await _ensureBleReady()) {
      return;
    }

    if (trigger == 'manual') {
      _clearAutoReconnectWork(
        _BleDeviceRole.hrMonitor,
        resetAttempts: true,
        cancellationReason: 'manual_reconnect',
      );
    }
    state = state.copyWith(clearHrError: true);
    _trackSetupEvent(
      'ble_reconnect_requested',
      telemetryProperties: <String, Object?>{
        'device_role': 'hr_monitor',
        'trigger': trigger,
      },
      diagnosticsData: <String, Object?>{
        'device_role': 'hr_monitor',
        'trigger': trigger,
      },
    );
    await _enqueueConnectionRequest(
      _ConnectionRequest(
        role: _BleDeviceRole.hrMonitor,
        kind: _ConnectionRequestKind.reconnect,
        deviceId: state.selectedHrId,
        trigger: trigger,
      ),
    );
  }

  Future<void> reconnectTrainer({String trigger = 'manual'}) async {
    if (!await _ensureBleReady()) {
      return;
    }

    if (trigger == 'manual') {
      _clearAutoReconnectWork(
        _BleDeviceRole.trainer,
        resetAttempts: true,
        cancellationReason: 'manual_reconnect',
      );
    }
    state = state.copyWith(clearTrainerError: true);
    _trackSetupEvent(
      'ble_reconnect_requested',
      telemetryProperties: <String, Object?>{
        'device_role': 'trainer',
        'trigger': trigger,
      },
      diagnosticsData: <String, Object?>{
        'device_role': 'trainer',
        'trigger': trigger,
      },
    );
    await _enqueueConnectionRequest(
      _ConnectionRequest(
        role: _BleDeviceRole.trainer,
        kind: _ConnectionRequestKind.reconnect,
        deviceId: state.selectedTrainerId,
        trigger: trigger,
      ),
    );
  }

  Future<void> requestBleAccess() async {
    _trackSetupEvent('ble_permission_request');
    await _refreshBleReadiness(
      requestPermissions: true,
      reconnectIfReady: true,
      reconnectTrigger: 'saved_reconnect',
    );
  }

  Future<void> refreshBleReadiness() async {
    await _refreshBleReadiness(
      requestPermissions: false,
      reconnectIfReady: true,
      reconnectTrigger: 'saved_reconnect',
    );
  }

  Future<void> openSystemSettings() async {
    _trackSetupEvent('ble_open_settings');
    await _blePermissionService.openSystemSettings();
  }

  Future<bool> _ensureBleReady() async {
    final readiness = await _refreshBleReadiness(
      requestPermissions: true,
      reconnectTrigger: 'saved_reconnect',
    );
    return readiness.isReady;
  }

  Future<BleReadiness> _refreshBleReadiness({
    required bool requestPermissions,
    bool reconnectIfReady = false,
    required String reconnectTrigger,
  }) async {
    final readiness = requestPermissions
        ? await _blePermissionService.ensurePermissions()
        : await _blePermissionService.checkStatus();

    state = state.copyWith(
      permissionsGranted: readiness.permissionsGranted,
      bluetoothEnabled: readiness.bluetoothEnabled,
      permissionPermanentlyDenied: readiness.permissionPermanentlyDenied,
      readinessChecked: true,
    );

    if (readiness.isReady && reconnectIfReady) {
      await _enqueueSavedReconnects(trigger: reconnectTrigger);
    }

    if (requestPermissions) {
      _trackSetupEvent(
        'ble_permission_result',
        telemetryProperties: <String, Object?>{
          'result': readiness.permissionsGranted ? 'granted' : 'denied',
          'bluetooth_ready': readiness.bluetoothEnabled,
          'permission_permanently_denied':
              readiness.permissionPermanentlyDenied,
        },
        diagnosticsData: <String, Object?>{
          'permissions_granted': readiness.permissionsGranted,
          'bluetooth_enabled': readiness.bluetoothEnabled,
          'permission_permanently_denied':
              readiness.permissionPermanentlyDenied,
        },
      );
    }

    return readiness;
  }

  Future<void> _enqueueSavedReconnects({required String trigger}) async {
    if (!_isBleReadyForReconnect) {
      return;
    }

    final reconnects = <Future<void>>[];
    if (_shouldEnqueueSavedReconnect(_BleDeviceRole.hrMonitor)) {
      _clearAutoReconnectWork(
        _BleDeviceRole.hrMonitor,
        resetAttempts: true,
        cancellationReason: trigger,
      );
      reconnects.add(
        _enqueueConnectionRequest(
          _ConnectionRequest(
            role: _BleDeviceRole.hrMonitor,
            kind: _ConnectionRequestKind.reconnect,
            deviceId: state.selectedHrId,
            trigger: trigger,
          ),
        ).catchError((_) {}),
      );
    }
    if (_shouldEnqueueSavedReconnect(_BleDeviceRole.trainer)) {
      _clearAutoReconnectWork(
        _BleDeviceRole.trainer,
        resetAttempts: true,
        cancellationReason: trigger,
      );
      reconnects.add(
        _enqueueConnectionRequest(
          _ConnectionRequest(
            role: _BleDeviceRole.trainer,
            kind: _ConnectionRequestKind.reconnect,
            deviceId: state.selectedTrainerId,
            trigger: trigger,
          ),
        ).catchError((_) {}),
      );
    }

    if (reconnects.isEmpty) {
      return;
    }

    await Future.wait<void>(reconnects);
  }

  bool _shouldEnqueueSavedReconnect(_BleDeviceRole role) {
    final savedId = _selectedDeviceIdForRole(role);
    return savedId != null &&
        savedId.isNotEmpty &&
        _rawStatusForRole(role) == ConnectionStatus.disconnected;
  }

  Future<List<BleDeviceInfo>> _scanHrDevicesWithWakeRetry() async {
    List<BleDeviceInfo> devices = const <BleDeviceInfo>[];

    for (var attempt = 1; attempt <= _hrScanAttempts; attempt += 1) {
      devices = await _hrMonitorRepository.scanForDevices();
      if (devices.isNotEmpty || attempt == _hrScanAttempts) {
        return devices;
      }

      _trackSetupEvent(
        'ble_scan_retry',
        telemetryProperties: const <String, Object?>{
          'device_role': 'hr_monitor',
          'trigger': 'empty_scan',
        },
        diagnosticsData: <String, Object?>{
          'device_role': 'hr_monitor',
          'trigger': 'empty_scan',
          'attempt': attempt,
        },
      );
      await Future<void>.delayed(_hrScanRetryDelay);
    }

    return devices;
  }

  Future<void> _enqueueAndProcessQueue() async {
    if (_connectionQueueRunning) {
      return;
    }
    _connectionQueueRunning = true;
    try {
      while (_pendingConnectionRequests.isNotEmpty) {
        final request = _takeNextConnectionRequest();
        _activeConnectionRequest = request;
        try {
          await _runConnectionRequest(request);
          if (!request.completer.isCompleted) {
            request.completer.complete();
          }
        } catch (error, stackTrace) {
          if (!request.completer.isCompleted) {
            request.completer.completeError(error, stackTrace);
          }
        } finally {
          _activeConnectionRequest = null;
        }
      }
    } finally {
      _connectionQueueRunning = false;
    }
  }

  Future<void> _runConnectionRequest(_ConnectionRequest request) async {
    if (request.kind == _ConnectionRequestKind.reconnect &&
        request.trigger == 'auto_reconnect' &&
        !_isBleReadyForReconnect) {
      _trackAutoReconnectSuppressed(
        request.role,
        reason: 'ble_not_ready',
        attempt: _autoReconnectAttempts[request.role]!,
      );
      return;
    }

    try {
      switch (request.kind) {
        case _ConnectionRequestKind.connect:
          await _runConnectRequest(request);
          return;
        case _ConnectionRequestKind.reconnect:
          await _runReconnectRequest(request);
          return;
      }
    } catch (error, stackTrace) {
      _handleConnectionRequestFailure(request, error, stackTrace);
      if (request.trigger == 'auto_reconnect') {
        _scheduleAutoReconnect(request.role, reason: 'retry_after_failure');
      }
      rethrow;
    }
  }

  Future<void> _runConnectRequest(_ConnectionRequest request) async {
    final deviceId = request.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      _trackConnectionQueueSkipped(request, reason: 'missing_device_id');
      return;
    }

    if (_rawStatusForRole(request.role) != ConnectionStatus.disconnected) {
      await _disconnectForConnectionReset(
        request.role,
        trigger: 'manual_connect',
      );
    }
    if (_rawStatusForRole(request.role) != ConnectionStatus.disconnected) {
      _trackConnectionQueueSkipped(
        request,
        reason: 'state_${_rawStatusForRole(request.role).name}',
      );
      return;
    }

    await _connectRole(request.role, deviceId);
    await _handleSuccessfulConnect(request.role, deviceId);
  }

  Future<void> _runReconnectRequest(_ConnectionRequest request) async {
    final savedId = request.deviceId;
    if (savedId == null || savedId.isEmpty) {
      _trackConnectionQueueSkipped(request, reason: 'missing_saved_device');
      return;
    }

    if (_rawStatusForRole(request.role) != ConnectionStatus.disconnected) {
      if (request.trigger == 'manual') {
        await _disconnectForConnectionReset(
          request.role,
          trigger: 'manual_reconnect',
        );
      } else {
        _trackConnectionQueueSkipped(
          request,
          reason: 'state_${_rawStatusForRole(request.role).name}',
        );
        return;
      }
    }
    if (_rawStatusForRole(request.role) != ConnectionStatus.disconnected) {
      _trackConnectionQueueSkipped(
        request,
        reason: 'state_${_rawStatusForRole(request.role).name}',
      );
      return;
    }

    await _reconnectRole(request.role);
  }

  Future<void> _disconnectForConnectionReset(
    _BleDeviceRole role, {
    required String trigger,
  }) async {
    _unexpectedDisconnectSuppressed[role] = true;
    await _disconnectRole(role);
    try {
      await _waitForRawStatus(role, ConnectionStatus.disconnected);
    } finally {
      if (_rawStatusForRole(role) == ConnectionStatus.disconnected) {
        _unexpectedDisconnectSuppressed[role] = false;
      }
    }
    _trackSetupEvent(
      'ble_connection_reset',
      telemetryProperties: <String, Object?>{
        'device_role': _deviceRoleValue(role),
        'trigger': trigger,
      },
      diagnosticsData: <String, Object?>{
        'device_role': _deviceRoleValue(role),
        'trigger': trigger,
      },
    );
  }

  Future<void> _handleSuccessfulConnect(
    _BleDeviceRole role,
    String deviceId,
  ) async {
    final deviceName = _deviceNameFor(deviceId, _deviceListForRole(role));
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        state = state.copyWith(
          selectedHrId: deviceId,
          selectedHrName: deviceName,
        );
        if (_hasFriendlyDeviceName(deviceName)) {
          await _deviceSelectionStore.saveHrMonitorName(deviceName!);
        }
        return;
      case _BleDeviceRole.trainer:
        state = state.copyWith(
          selectedTrainerId: deviceId,
          selectedTrainerName: deviceName,
        );
        if (_hasFriendlyDeviceName(deviceName)) {
          await _deviceSelectionStore.saveTrainerName(deviceName!);
        }
        return;
    }
  }

  Future<void> _waitForRawStatus(
    _BleDeviceRole role,
    ConnectionStatus expected,
  ) async {
    if (_rawStatusForRole(role) == expected) {
      return;
    }

    final waiter = _StatusWaiter(expected);
    _statusWaiters[role]!.add(waiter);
    try {
      await waiter.completer.future.timeout(_disconnectWaitTimeout);
    } finally {
      _statusWaiters[role]!.remove(waiter);
    }
  }

  Future<void> _enqueueConnectionRequest(_ConnectionRequest request) async {
    final activeRequest = _activeConnectionRequest;
    if (activeRequest != null && activeRequest.isEquivalent(request)) {
      _trackConnectionQueueSkipped(request, reason: 'duplicate_active');
      return activeRequest.completer.future;
    }

    final pendingRequest = _pendingConnectionRequests
        .cast<_ConnectionRequest?>()
        .firstWhere(
          (candidate) => candidate!.isEquivalent(request),
          orElse: () => null,
        );
    if (pendingRequest != null) {
      _trackConnectionQueueSkipped(request, reason: 'duplicate_pending');
      return pendingRequest.completer.future;
    }

    _pendingConnectionRequests.add(request);
    _trackSetupEvent(
      'ble_connection_queued',
      telemetryProperties: _queueTelemetry(request),
      diagnosticsData: _queueDiagnostics(request),
    );
    unawaited(_enqueueAndProcessQueue());
    return request.completer.future;
  }

  _ConnectionRequest _takeNextConnectionRequest() {
    final hrIndex = _pendingConnectionRequests.indexWhere(
      (request) => request.role == _BleDeviceRole.hrMonitor,
    );
    final nextIndex = hrIndex == -1 ? 0 : hrIndex;
    return _pendingConnectionRequests.removeAt(nextIndex);
  }

  void _cancelPendingRequests(
    bool Function(_ConnectionRequest request) predicate, {
    required String reason,
  }) {
    for (
      var index = _pendingConnectionRequests.length - 1;
      index >= 0;
      index--
    ) {
      final request = _pendingConnectionRequests[index];
      if (!predicate(request)) {
        continue;
      }
      _pendingConnectionRequests.removeAt(index);
      _trackConnectionQueueSkipped(request, reason: reason);
      if (!request.completer.isCompleted) {
        request.completer.complete();
      }
    }
  }

  void _clearAutoReconnectWork(
    _BleDeviceRole role, {
    required bool resetAttempts,
    bool cancelAllPending = false,
    required String cancellationReason,
  }) {
    final timer = _autoReconnectTimerFor(role);
    timer?.cancel();
    _setAutoReconnectTimer(role, null);
    if (resetAttempts) {
      _autoReconnectAttempts[role] = 0;
    }
    _cancelPendingRequests(
      (request) =>
          request.role == role &&
          (cancelAllPending || request.trigger == 'auto_reconnect'),
      reason: cancellationReason,
    );
  }

  void _markDeviceRecovered(_BleDeviceRole role) {
    final hadRetryState =
        _autoReconnectAttempts[role]! > 0 ||
        _autoReconnectTimerFor(role) != null;
    if (!hadRetryState) {
      return;
    }
    _clearAutoReconnectWork(
      role,
      resetAttempts: true,
      cancellationReason: 'device_recovered',
    );
  }

  void _handleRawStatusChange({
    required _BleDeviceRole role,
    required ConnectionStatus previous,
    required ConnectionStatus next,
  }) {
    if (next != ConnectionStatus.disconnected) {
      final timer = _autoReconnectTimerFor(role);
      if (timer != null) {
        timer.cancel();
        _setAutoReconnectTimer(role, null);
      }
      return;
    }

    if (_unexpectedDisconnectSuppressed[role] == true) {
      _unexpectedDisconnectSuppressed[role] = false;
      _trackAutoReconnectSuppressed(role, reason: 'manual_disconnect');
      return;
    }

    if (_activeConnectionRequest?.role == role) {
      _trackAutoReconnectSuppressed(role, reason: 'connection_request_active');
      return;
    }

    if (!_isUnexpectedDisconnectTransition(previous)) {
      return;
    }

    _scheduleAutoReconnect(role, reason: 'unexpected_disconnect');
  }

  bool _isUnexpectedDisconnectTransition(ConnectionStatus previous) {
    switch (previous) {
      case ConnectionStatus.connected:
      case ConnectionStatus.connectedNoData:
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return true;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.scanning:
        return false;
    }
  }

  void _scheduleAutoReconnect(_BleDeviceRole role, {required String reason}) {
    if (!_isBleReadyForReconnect) {
      _trackAutoReconnectSuppressed(role, reason: 'ble_not_ready');
      return;
    }
    final savedId = _selectedDeviceIdForRole(role);
    if (savedId == null || savedId.isEmpty) {
      _trackAutoReconnectSuppressed(role, reason: 'missing_saved_device');
      return;
    }
    if (_autoReconnectTimerFor(role) != null) {
      _trackAutoReconnectSuppressed(role, reason: 'already_scheduled');
      return;
    }
    if (_hasPendingOrActiveAutoReconnect(role)) {
      _trackAutoReconnectSuppressed(role, reason: 'already_pending');
      return;
    }

    final attempts = _autoReconnectAttempts[role]!;
    if (attempts >= _autoReconnectBackoff.length) {
      _trackSetupEvent(
        'ble_auto_reconnect_exhausted',
        telemetryProperties: <String, Object?>{
          'device_role': _deviceRoleValue(role),
          'attempts': attempts,
          'reason': reason,
        },
        diagnosticsData: <String, Object?>{
          'device_role': _deviceRoleValue(role),
          'attempts': attempts,
          'reason': reason,
        },
      );
      return;
    }

    final attemptNumber = attempts + 1;
    final delay = _autoReconnectBackoff[attempts];
    _autoReconnectAttempts[role] = attemptNumber;
    _trackSetupEvent(
      'ble_auto_reconnect_scheduled',
      telemetryProperties: <String, Object?>{
        'device_role': _deviceRoleValue(role),
        'attempt': attemptNumber,
        'delay_seconds': delay.inSeconds,
        'reason': reason,
      },
      diagnosticsData: <String, Object?>{
        'device_role': _deviceRoleValue(role),
        'attempt': attemptNumber,
        'delay_ms': delay.inMilliseconds,
        'reason': reason,
      },
    );
    final timer = Timer(delay, () {
      _setAutoReconnectTimer(role, null);
      unawaited(
        _enqueueConnectionRequest(
          _ConnectionRequest(
            role: role,
            kind: _ConnectionRequestKind.reconnect,
            deviceId: _selectedDeviceIdForRole(role),
            trigger: 'auto_reconnect',
          ),
        ).catchError((_) {}),
      );
    });
    _setAutoReconnectTimer(role, timer);
  }

  bool _hasPendingOrActiveAutoReconnect(_BleDeviceRole role) {
    final activeRequest = _activeConnectionRequest;
    if (activeRequest != null &&
        activeRequest.role == role &&
        activeRequest.trigger == 'auto_reconnect') {
      return true;
    }
    return _pendingConnectionRequests.any(
      (request) => request.role == role && request.trigger == 'auto_reconnect',
    );
  }

  void _trackAutoReconnectSuppressed(
    _BleDeviceRole role, {
    required String reason,
    int? attempt,
  }) {
    _trackSetupEvent(
      'ble_auto_reconnect_suppressed',
      telemetryProperties: <String, Object?>{
        'device_role': _deviceRoleValue(role),
        'reason': reason,
        if (attempt != null) 'attempt': attempt,
      },
      diagnosticsData: <String, Object?>{
        'device_role': _deviceRoleValue(role),
        'reason': reason,
        if (attempt != null) 'attempt': attempt,
      },
    );
  }

  void _resolveStatusWaiters(_BleDeviceRole role, ConnectionStatus status) {
    final waiters = List<_StatusWaiter>.of(_statusWaiters[role]!);
    for (final waiter in waiters) {
      if (waiter.status == status && !waiter.completer.isCompleted) {
        waiter.completer.complete();
      }
    }
  }

  void _handleConnectionRequestFailure(
    _ConnectionRequest request,
    Object error,
    StackTrace stackTrace,
  ) {
    switch (request.role) {
      case _BleDeviceRole.hrMonitor:
        state = state.copyWith(hrError: error.toString());
        break;
      case _BleDeviceRole.trainer:
        state = state.copyWith(trainerError: error.toString());
        break;
    }
    _recordSetupError(
      _failureReasonFor(request),
      error,
      stackTrace,
      telemetryProperties: <String, Object?>{
        'device_role': _deviceRoleValue(request.role),
        if (request.kind == _ConnectionRequestKind.reconnect)
          'trigger': request.trigger,
      },
      diagnosticsData: <String, Object?>{
        'device_role': _deviceRoleValue(request.role),
        if (request.deviceId != null) 'device_id': request.deviceId,
        if (request.kind == _ConnectionRequestKind.reconnect)
          'trigger': request.trigger,
      },
    );
  }

  String _failureReasonFor(_ConnectionRequest request) {
    switch (request.role) {
      case _BleDeviceRole.hrMonitor:
        return request.kind == _ConnectionRequestKind.connect
            ? 'ble_connect_hr_failed'
            : 'ble_reconnect_hr_failed';
      case _BleDeviceRole.trainer:
        return request.kind == _ConnectionRequestKind.connect
            ? 'ble_connect_trainer_failed'
            : 'ble_reconnect_trainer_failed';
    }
  }

  Map<String, Object?> _queueTelemetry(
    _ConnectionRequest request, {
    String? reason,
  }) {
    return <String, Object?>{
      'device_role': _deviceRoleValue(request.role),
      'action': request.kind.name,
      'trigger': request.trigger,
      if (reason != null) 'reason': reason,
    };
  }

  Map<String, Object?> _queueDiagnostics(
    _ConnectionRequest request, {
    String? reason,
  }) {
    return <String, Object?>{
      'device_role': _deviceRoleValue(request.role),
      'action': request.kind.name,
      'trigger': request.trigger,
      if (request.deviceId != null) 'device_id': request.deviceId,
      if (reason != null) 'reason': reason,
    };
  }

  void _trackConnectionQueueSkipped(
    _ConnectionRequest request, {
    required String reason,
  }) {
    _trackSetupEvent(
      'ble_connection_queue_skipped',
      telemetryProperties: _queueTelemetry(request, reason: reason),
      diagnosticsData: _queueDiagnostics(request, reason: reason),
    );
  }

  List<BleDeviceInfo> _deviceListForRole(_BleDeviceRole role) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return state.hrDevices;
      case _BleDeviceRole.trainer:
        return state.trainerDevices;
    }
  }

  String? _selectedDeviceIdForRole(_BleDeviceRole role) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return state.selectedHrId;
      case _BleDeviceRole.trainer:
        return state.selectedTrainerId;
    }
  }

  ConnectionStatus _rawStatusForRole(_BleDeviceRole role) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return _rawHrStatus;
      case _BleDeviceRole.trainer:
        return _rawTrainerStatus;
    }
  }

  Timer? _autoReconnectTimerFor(_BleDeviceRole role) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return _hrAutoReconnectTimer;
      case _BleDeviceRole.trainer:
        return _trainerAutoReconnectTimer;
    }
  }

  void _setAutoReconnectTimer(_BleDeviceRole role, Timer? timer) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        _hrAutoReconnectTimer = timer;
        return;
      case _BleDeviceRole.trainer:
        _trainerAutoReconnectTimer = timer;
        return;
    }
  }

  String _deviceRoleValue(_BleDeviceRole role) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return 'hr_monitor';
      case _BleDeviceRole.trainer:
        return 'trainer';
    }
  }

  bool get _isBleReadyForReconnect =>
      state.permissionsGranted && state.bluetoothEnabled;

  Future<void> _connectRole(_BleDeviceRole role, String deviceId) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return _hrMonitorRepository.connect(deviceId);
      case _BleDeviceRole.trainer:
        return _trainerRepository.connect(deviceId);
    }
  }

  Future<void> _reconnectRole(_BleDeviceRole role) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return _hrMonitorRepository.reconnect();
      case _BleDeviceRole.trainer:
        return _trainerRepository.reconnect();
    }
  }

  Future<void> _disconnectRole(_BleDeviceRole role) {
    switch (role) {
      case _BleDeviceRole.hrMonitor:
        return _hrMonitorRepository.disconnect();
      case _BleDeviceRole.trainer:
        return _trainerRepository.disconnect();
    }
  }

  Future<void> _refreshSavedNameFromDevices({
    required String? selectedId,
    required String? currentName,
    required List<BleDeviceInfo> devices,
    required Future<void> Function(String name) persistName,
    required void Function(String name) updateState,
  }) async {
    if (selectedId == null || selectedId.isEmpty) {
      return;
    }

    if (_hasFriendlyDeviceName(currentName)) {
      return;
    }

    final resolvedName = _deviceNameFor(selectedId, devices);
    if (!_hasFriendlyDeviceName(resolvedName)) {
      return;
    }

    updateState(resolvedName!);
    await persistName(resolvedName);
  }

  String? _deviceNameFor(String deviceId, List<BleDeviceInfo> devices) {
    for (final device in devices) {
      if (device.id == deviceId) {
        return device.name;
      }
    }
    return null;
  }

  bool _hasFriendlyDeviceName(String? name) {
    if (name == null) {
      return false;
    }
    return name.trim().isNotEmpty;
  }

  void _applyHrStatus() {
    switch (_rawHrStatus) {
      case ConnectionStatus.connected:
      case ConnectionStatus.connectedNoData:
        state = state.copyWith(
          hrStatus: _hrHasFreshData
              ? ConnectionStatus.connected
              : (_hrHasReceivedDataThisConnection
                    ? ConnectionStatus.disconnected
                    : ConnectionStatus.connectedNoData),
        );
        return;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.scanning:
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        _hrHasFreshData = false;
        _hrHasReceivedDataThisConnection = false;
        _hrStaleTimer?.cancel();
        _hrStaleTimer = null;
        state = state.copyWith(hrStatus: _rawHrStatus);
        return;
    }
  }

  void _applyTrainerStatus() {
    switch (_rawTrainerStatus) {
      case ConnectionStatus.connected:
      case ConnectionStatus.connectedNoData:
        state = state.copyWith(
          trainerStatus: _trainerHasFreshData
              ? ConnectionStatus.connected
              : ConnectionStatus.connectedNoData,
        );
        return;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.scanning:
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        _trainerHasFreshData = false;
        _trainerStaleTimer?.cancel();
        _trainerStaleTimer = null;
        state = state.copyWith(trainerStatus: _rawTrainerStatus);
        return;
    }
  }

  void _scheduleHrStaleTimer() {
    _hrStaleTimer?.cancel();
    _hrStaleTimer = Timer(_hrStaleThreshold, () {
      _hrHasFreshData = false;
      _applyHrStatus();
    });
  }

  void _scheduleTrainerStaleTimer() {
    _trainerStaleTimer?.cancel();
    _trainerStaleTimer = Timer(_trainerStaleThreshold, () {
      _trainerHasFreshData = false;
      _applyTrainerStatus();
    });
  }

  void _trackSetupEvent(
    String event, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
  }) {
    unawaited(_telemetry.track(event, properties: telemetryProperties));
    unawaited(
      _diagnosticsStore.recordRuntimeEvent(event, data: diagnosticsData),
    );
  }

  void _recordSetupError(
    String reason,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> telemetryProperties = const <String, Object?>{},
    Map<String, Object?> diagnosticsData = const <String, Object?>{},
  }) {
    unawaited(
      _telemetry.recordError(
        Exception(reason),
        stackTrace,
        reason: reason,
        properties: <String, Object?>{
          'error_type': error.runtimeType.toString(),
          ...telemetryProperties,
        },
      ),
    );
    unawaited(
      _diagnosticsStore.recordRuntimeEvent(
        reason,
        data: <String, Object?>{'error': error.toString(), ...diagnosticsData},
      ),
    );
  }

  @override
  void dispose() {
    _cancelPendingRequests((_) => true, reason: 'dispose');
    _hrStatusSubscription?.cancel();
    _trainerStatusSubscription?.cancel();
    _hrSampleSubscription?.cancel();
    _trainerTelemetrySubscription?.cancel();
    _bluetoothEnabledSubscription?.cancel();
    _hrStaleTimer?.cancel();
    _trainerStaleTimer?.cancel();
    _hrAutoReconnectTimer?.cancel();
    _trainerAutoReconnectTimer?.cancel();
    super.dispose();
  }
}

enum _BleDeviceRole { hrMonitor, trainer }

enum _ConnectionRequestKind { connect, reconnect }

class _ConnectionRequest {
  _ConnectionRequest({
    required this.role,
    required this.kind,
    required this.deviceId,
    required this.trigger,
  });

  final _BleDeviceRole role;
  final _ConnectionRequestKind kind;
  final String? deviceId;
  final String trigger;
  final Completer<void> completer = Completer<void>();

  bool isEquivalent(_ConnectionRequest other) {
    return role == other.role &&
        kind == other.kind &&
        deviceId == other.deviceId &&
        trigger == other.trigger;
  }
}

class _StatusWaiter {
  _StatusWaiter(this.status);

  final ConnectionStatus status;
  final Completer<void> completer = Completer<void>();
}
