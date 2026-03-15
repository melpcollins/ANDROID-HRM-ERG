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
  ConnectSetupController({
    required HrMonitorRepository hrMonitorRepository,
    required TrainerRepository trainerRepository,
    required BlePermissionService blePermissionService,
    required DeviceSelectionStore deviceSelectionStore,
    AppTelemetry? telemetry,
    DiagnosticsStore? diagnosticsStore,
    Duration hrStaleThreshold = const Duration(seconds: 5),
    Duration trainerStaleThreshold = const Duration(seconds: 10),
  }) : _hrMonitorRepository = hrMonitorRepository,
       _trainerRepository = trainerRepository,
       _blePermissionService = blePermissionService,
       _deviceSelectionStore = deviceSelectionStore,
       _telemetry =
           telemetry ?? NoopAppTelemetry(appInfo: AppInfo.placeholder()),
       _diagnosticsStore = diagnosticsStore ?? DiagnosticsStore.inMemory(),
       _hrStaleThreshold = hrStaleThreshold,
       _trainerStaleThreshold = trainerStaleThreshold,
       super(const ConnectSetupState());

  final HrMonitorRepository _hrMonitorRepository;
  final TrainerRepository _trainerRepository;
  final BlePermissionService _blePermissionService;
  final DeviceSelectionStore _deviceSelectionStore;
  final AppTelemetry _telemetry;
  final DiagnosticsStore _diagnosticsStore;
  final Duration _hrStaleThreshold;
  final Duration _trainerStaleThreshold;

  StreamSubscription? _hrStatusSubscription;
  StreamSubscription? _trainerStatusSubscription;
  StreamSubscription? _hrSampleSubscription;
  StreamSubscription? _trainerTelemetrySubscription;
  StreamSubscription<bool>? _bluetoothEnabledSubscription;

  Timer? _hrStaleTimer;
  Timer? _trainerStaleTimer;
  ConnectionStatus _rawHrStatus = ConnectionStatus.disconnected;
  ConnectionStatus _rawTrainerStatus = ConnectionStatus.disconnected;
  bool _hrHasFreshData = false;
  bool _hrHasReceivedDataThisConnection = false;
  bool _trainerHasFreshData = false;

  bool _autoReconnectInProgress = false;

  Future<void> initialize() async {
    _hrStatusSubscription ??= _hrMonitorRepository.connectionStatus.listen((
      status,
    ) {
      _rawHrStatus = status;
      _applyHrStatus();
    });

    _trainerStatusSubscription ??= _trainerRepository.connectionStatus.listen((
      status,
    ) {
      _rawTrainerStatus = status;
      _applyTrainerStatus();
    });
    _hrSampleSubscription ??= _hrMonitorRepository.hrSamples.listen((_) {
      _hrHasFreshData = true;
      _hrHasReceivedDataThisConnection = true;
      _scheduleHrStaleTimer();
      _applyHrStatus();
    });
    _trainerTelemetrySubscription ??= _trainerRepository.telemetry.listen((_) {
      _trainerHasFreshData = true;
      _scheduleTrainerStaleTimer();
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
          if (!wasEnabled && enabled && state.permissionsGranted) {
            unawaited(_attemptSavedReconnects());
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
    );
  }

  Future<void> scanHrMonitors() async {
    if (!await _ensureBleReady()) {
      return;
    }

    state = state.copyWith(scanningHr: true, clearHrError: true);

    try {
      final devices = await _hrMonitorRepository.scanForDevices();
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

    state = state.copyWith(clearHrError: true);
    _trackSetupEvent(
      'ble_connect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'hr_monitor'},
      diagnosticsData: <String, Object?>{
        'device_role': 'hr_monitor',
        'device_id': deviceId,
      },
    );
    try {
      await _hrMonitorRepository.connect(deviceId);
      final deviceName = _deviceNameFor(deviceId, state.hrDevices);
      state = state.copyWith(
        selectedHrId: deviceId,
        selectedHrName: deviceName,
      );
      if (_hasFriendlyDeviceName(deviceName)) {
        await _deviceSelectionStore.saveHrMonitorName(deviceName!);
      }
    } catch (error, stackTrace) {
      state = state.copyWith(hrError: error.toString());
      _recordSetupError(
        'ble_connect_hr_failed',
        error,
        stackTrace,
        telemetryProperties: const <String, Object?>{
          'device_role': 'hr_monitor',
        },
        diagnosticsData: <String, Object?>{'device_id': deviceId},
      );
    }
  }

  Future<void> connectTrainer(String deviceId) async {
    if (!await _ensureBleReady()) {
      return;
    }

    state = state.copyWith(clearTrainerError: true);
    _trackSetupEvent(
      'ble_connect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'trainer'},
      diagnosticsData: <String, Object?>{
        'device_role': 'trainer',
        'device_id': deviceId,
      },
    );
    try {
      await _trainerRepository.connect(deviceId);
      final deviceName = _deviceNameFor(deviceId, state.trainerDevices);
      state = state.copyWith(
        selectedTrainerId: deviceId,
        selectedTrainerName: deviceName,
      );
      if (_hasFriendlyDeviceName(deviceName)) {
        await _deviceSelectionStore.saveTrainerName(deviceName!);
      }
    } catch (error, stackTrace) {
      state = state.copyWith(trainerError: error.toString());
      _recordSetupError(
        'ble_connect_trainer_failed',
        error,
        stackTrace,
        telemetryProperties: const <String, Object?>{'device_role': 'trainer'},
        diagnosticsData: <String, Object?>{'device_id': deviceId},
      );
    }
  }

  Future<void> disconnectHrMonitor() async {
    state = state.copyWith(clearHrError: true);
    _trackSetupEvent(
      'ble_disconnect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'hr_monitor'},
      diagnosticsData: const <String, Object?>{'device_role': 'hr_monitor'},
    );
    try {
      await _hrMonitorRepository.disconnect();
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
    state = state.copyWith(clearTrainerError: true);
    _trackSetupEvent(
      'ble_disconnect_requested',
      telemetryProperties: const <String, Object?>{'device_role': 'trainer'},
      diagnosticsData: const <String, Object?>{'device_role': 'trainer'},
    );
    try {
      await _trainerRepository.disconnect();
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
    try {
      await _hrMonitorRepository.reconnect();
    } catch (error, stackTrace) {
      state = state.copyWith(hrError: error.toString());
      _recordSetupError(
        'ble_reconnect_hr_failed',
        error,
        stackTrace,
        telemetryProperties: <String, Object?>{
          'device_role': 'hr_monitor',
          'trigger': trigger,
        },
      );
      rethrow;
    }
  }

  Future<void> reconnectTrainer({String trigger = 'manual'}) async {
    if (!await _ensureBleReady()) {
      return;
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
    try {
      await _trainerRepository.reconnect();
    } catch (error, stackTrace) {
      state = state.copyWith(trainerError: error.toString());
      _recordSetupError(
        'ble_reconnect_trainer_failed',
        error,
        stackTrace,
        telemetryProperties: <String, Object?>{
          'device_role': 'trainer',
          'trigger': trigger,
        },
      );
      rethrow;
    }
  }

  Future<void> requestBleAccess() async {
    _trackSetupEvent('ble_permission_request');
    await _refreshBleReadiness(
      requestPermissions: true,
      reconnectIfReady: true,
    );
  }

  Future<void> refreshBleReadiness() async {
    await _refreshBleReadiness(
      requestPermissions: false,
      reconnectIfReady: true,
    );
  }

  Future<void> openSystemSettings() async {
    _trackSetupEvent('ble_open_settings');
    await _blePermissionService.openSystemSettings();
  }

  Future<bool> _ensureBleReady() async {
    final readiness = await _refreshBleReadiness(requestPermissions: true);
    return readiness.isReady;
  }

  Future<BleReadiness> _refreshBleReadiness({
    required bool requestPermissions,
    bool reconnectIfReady = false,
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
      await _attemptSavedReconnects();
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

  Future<void> _attemptSavedReconnects() async {
    if (_autoReconnectInProgress ||
        !state.permissionsGranted ||
        !state.bluetoothEnabled) {
      return;
    }

    _autoReconnectInProgress = true;
    try {
      await Future.wait<void>([
        _attemptReconnect(
          reconnect: () => reconnectHrMonitor(trigger: 'auto_reconnect'),
          hasSavedDevice:
              state.selectedHrId != null &&
              state.selectedHrId!.isNotEmpty &&
              state.hrStatus == ConnectionStatus.disconnected,
        ),
        _attemptReconnect(
          reconnect: () => reconnectTrainer(trigger: 'auto_reconnect'),
          hasSavedDevice:
              state.selectedTrainerId != null &&
              state.selectedTrainerId!.isNotEmpty &&
              state.trainerStatus == ConnectionStatus.disconnected,
        ),
      ]);
    } finally {
      _autoReconnectInProgress = false;
    }
  }

  Future<void> _attemptReconnect({
    required Future<void> Function() reconnect,
    required bool hasSavedDevice,
  }) async {
    if (!hasSavedDevice) {
      return;
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await reconnect();
        return;
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
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
    _hrStatusSubscription?.cancel();
    _trainerStatusSubscription?.cancel();
    _hrSampleSubscription?.cancel();
    _trainerTelemetrySubscription?.cancel();
    _bluetoothEnabledSubscription?.cancel();
    _hrStaleTimer?.cancel();
    _trainerStaleTimer?.cancel();
    super.dispose();
  }
}
