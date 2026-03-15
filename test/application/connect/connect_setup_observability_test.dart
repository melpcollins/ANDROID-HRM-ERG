import 'package:android_hrm_erg/src/application/connect/connect_setup_controller.dart';
import 'package:android_hrm_erg/src/infrastructure/diagnostics/diagnostics_store.dart';
import 'package:android_hrm_erg/src/infrastructure/storage/device_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_telemetry.dart';
import '../../support/fake_ble_permission_service.dart';
import '../../support/fake_repositories.dart';

void main() {
  test(
    'connect requests keep device id in diagnostics but not backend telemetry',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final telemetry = FakeAppTelemetry();
      final diagnosticsStore = DiagnosticsStore.inMemory();
      final controller = ConnectSetupController(
        hrMonitorRepository: FakeHrMonitorRepository(),
        trainerRepository: FakeTrainerRepository(),
        blePermissionService: FakeBlePermissionService(),
        deviceSelectionStore: DeviceSelectionStore(),
        telemetry: telemetry,
        diagnosticsStore: diagnosticsStore,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.connectHrMonitor('device-123');
      await Future<void>.delayed(Duration.zero);

      final telemetryEvent = telemetry.trackedEvents.firstWhere(
        (event) => event.name == 'ble_connect_requested',
      );
      final runtimeEvents = await diagnosticsStore.recentRuntimeEvents(
        limit: 20,
      );
      final runtimeEvent = runtimeEvents.firstWhere(
        (event) => event['name'] == 'ble_connect_requested',
      );
      final runtimeData = runtimeEvent['data'] as Map<String, Object?>;

      expect(telemetryEvent.properties.containsKey('device_id'), isFalse);
      expect(runtimeData['device_id'], 'device-123');
    },
  );
}
