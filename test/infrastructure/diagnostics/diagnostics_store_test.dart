import 'dart:io';

import 'package:android_hrm_erg/src/domain/models/session_context.dart';
import 'package:android_hrm_erg/src/domain/models/workout_type.dart';
import 'package:android_hrm_erg/src/infrastructure/app/app_info.dart';
import 'package:android_hrm_erg/src/infrastructure/diagnostics/diagnostics_exporter.dart';
import 'package:android_hrm_erg/src/infrastructure/diagnostics/diagnostics_store.dart';
import 'package:android_hrm_erg/src/infrastructure/storage/device_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('diagnostics-store');
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('prunes persistent sessions down to the newest 20', () async {
    final store = DiagnosticsStore.forDirectory(tempDirectory, maxSessions: 20);
    await store.ensureReady();

    final start = DateTime.utc(2026, 1, 1, 9);
    for (var index = 0; index < 22; index += 1) {
      final sessionId = 'session_$index';
      await store.startSession(
        SessionContext(
          sessionId: sessionId,
          workoutType: WorkoutType.hrErg,
          startedAt: start.add(Duration(minutes: index)),
          details: <String, Object?>{'sequence': index},
        ),
      );
      await store.closeSession(
        sessionId: sessionId,
        outcome: 'completed',
        summary: <String, Object?>{'sequence': index},
      );
    }

    final sessions = await store.recentSessions(limit: 25);
    final sessionIds = sessions
        .map((session) => session.context.sessionId)
        .toSet();

    expect(sessions, hasLength(20));
    expect(sessionIds.contains('session_0'), isFalse);
    expect(sessionIds.contains('session_1'), isFalse);
    expect(sessionIds.contains('session_21'), isTrue);
    expect(sessionIds.contains('session_20'), isTrue);
  });

  test(
    'builds export payload with runtime events, sessions, and saved devices',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        DeviceSelectionStore.hrMonitorKey: 'hr-1',
        DeviceSelectionStore.hrMonitorNameKey: 'Polar H10',
        DeviceSelectionStore.trainerKey: 'trainer-1',
        DeviceSelectionStore.trainerNameKey: 'Wattbike Atom',
      });

      final store = DiagnosticsStore.forDirectory(tempDirectory);
      await store.ensureReady();
      await store.recordRuntimeEvent(
        'ble_device_found',
        data: const <String, Object?>{
          'device_id': 'hr-1',
          'device_name': 'Polar H10',
        },
      );
      await store.startSession(
        SessionContext(
          sessionId: 'session_export',
          workoutType: WorkoutType.powerErg,
          startedAt: DateTime.utc(2026, 1, 1, 9),
          details: const <String, Object?>{'target_power': 180},
        ),
      );
      await store.recordSessionEvent(
        'session_export',
        'workout_started',
        data: const <String, Object?>{'target_power': 180},
      );
      await store.closeSession(
        sessionId: 'session_export',
        outcome: 'completed',
        summary: const <String, Object?>{'analysis_available': true},
      );

      final exporter = DiagnosticsExporter(
        diagnosticsStore: store,
        appInfo: const AppInfo(
          appName: 'Zone 2 Cycling by Heart',
          packageName: 'com.example.placeholder',
          version: '1.0.0',
          buildNumber: '1',
          platform: 'android',
          operatingSystemVersion: 'Android 14',
          phoneModel: 'Pixel Test',
          androidApiLevel: 34,
        ),
        deviceSelectionStore: DeviceSelectionStore(),
      );

      final payload = await exporter.buildExportPayload();
      final savedDevices = payload['saved_devices'] as Map<String, Object?>;
      final hrMonitor = savedDevices['hr_monitor'] as Map<String, Object?>;
      final trainer = savedDevices['trainer'] as Map<String, Object?>;
      final runtimeEvents = payload['runtime_events'] as List<Object?>;
      final sessions = payload['sessions'] as List<Object?>;

      expect(hrMonitor['id'], 'hr-1');
      expect(hrMonitor['name'], 'Polar H10');
      expect(trainer['id'], 'trainer-1');
      expect(trainer['name'], 'Wattbike Atom');
      expect(runtimeEvents, hasLength(1));
      expect(sessions, hasLength(1));
    },
  );
}
