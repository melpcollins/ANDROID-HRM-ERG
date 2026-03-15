import 'dart:io';

import '../app/app_info.dart';
import '../storage/device_selection_store.dart';
import 'diagnostics_store.dart';

class DiagnosticsExporter {
  DiagnosticsExporter({
    required DiagnosticsStore diagnosticsStore,
    required AppInfo appInfo,
    required DeviceSelectionStore deviceSelectionStore,
  }) : _diagnosticsStore = diagnosticsStore,
       _appInfo = appInfo,
       _deviceSelectionStore = deviceSelectionStore;

  final DiagnosticsStore _diagnosticsStore;
  final AppInfo _appInfo;
  final DeviceSelectionStore _deviceSelectionStore;

  Future<Map<String, Object?>> buildExportPayload() async {
    final savedDevices = await _savedDevices();
    final runtimeEvents = await _diagnosticsStore.recentRuntimeEvents(
      limit: 500,
    );
    final sessions = await _diagnosticsStore.recentSessions(limit: 20);

    return <String, Object?>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'app_info': _appInfo.toJson(),
      'saved_devices': savedDevices,
      'runtime_events': runtimeEvents,
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'notes': const <String, Object?>{
        'purpose': 'User-requested support diagnostics export',
        'contains_richer_ble_details': true,
        'share_consent_required': true,
      },
    };
  }

  Future<File> buildExportFile() async {
    final payload = await buildExportPayload();
    final fileName =
        'cycling-hr-erg-diagnostics-${DateTime.now().millisecondsSinceEpoch}.json';
    return _diagnosticsStore.createExportFile(
      fileName: fileName,
      payload: payload,
    );
  }

  Future<Map<String, Object?>> _savedDevices() async {
    return <String, Object?>{
      'hr_monitor': <String, Object?>{
        'id': await _deviceSelectionStore.getHrMonitorId(),
        'name': await _deviceSelectionStore.getHrMonitorName(),
      },
      'trainer': <String, Object?>{
        'id': await _deviceSelectionStore.getTrainerId(),
        'name': await _deviceSelectionStore.getTrainerName(),
      },
    };
  }
}
