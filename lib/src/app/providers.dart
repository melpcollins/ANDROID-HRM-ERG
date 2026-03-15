import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connect/connect_setup_controller.dart';
import '../application/connect/connect_setup_state.dart';
import '../application/session/workout_session_controller.dart';
import '../application/session/workout_session_state.dart';
import '../debug/app_debug_config.dart';
import '../debug/mock_device_harness.dart';
import '../debug/mock_workout_debug_controller.dart';
import '../domain/repositories/hr_monitor_repository.dart';
import '../domain/repositories/trainer_repository.dart';
import '../infrastructure/app/app_info.dart';
import '../infrastructure/ble/android_ble_permission_service.dart';
import '../infrastructure/ble/ble_permission_service.dart';
import '../infrastructure/ble/hr_monitor_ble_repository.dart';
import '../infrastructure/ble/trainer_ble_repository.dart';
import '../infrastructure/diagnostics/diagnostics_exporter.dart';
import '../infrastructure/diagnostics/diagnostics_store.dart';
import '../infrastructure/observability/app_telemetry.dart';
import '../infrastructure/storage/device_selection_store.dart';

final appDebugConfigProvider = Provider<AppDebugConfig>((ref) {
  return AppDebugConfig.fromEnvironment();
});

final appInfoProvider = Provider<AppInfo>((ref) {
  return AppInfo.placeholder();
});

final deviceSelectionStoreProvider = Provider<DeviceSelectionStore>((ref) {
  return DeviceSelectionStore();
});

final diagnosticsStoreProvider = Provider<DiagnosticsStore>((ref) {
  return DiagnosticsStore.inMemory();
});

final appTelemetryProvider = Provider<AppTelemetry>((ref) {
  return NoopAppTelemetry(appInfo: ref.watch(appInfoProvider));
});

final diagnosticsExporterProvider = Provider<DiagnosticsExporter>((ref) {
  return DiagnosticsExporter(
    diagnosticsStore: ref.watch(diagnosticsStoreProvider),
    appInfo: ref.watch(appInfoProvider),
    deviceSelectionStore: ref.watch(deviceSelectionStoreProvider),
  );
});

final blePermissionServiceProvider = Provider<BlePermissionService>((ref) {
  final debugConfig = ref.watch(appDebugConfigProvider);
  if (debugConfig.useMockDevices) {
    return const AlwaysReadyBlePermissionService();
  }
  return const AndroidBlePermissionService();
});

final mockDeviceHarnessProvider = Provider<MockDeviceHarness>((ref) {
  final harness = MockDeviceHarness();
  ref.onDispose(harness.dispose);
  return harness;
});

final hrMonitorRepositoryProvider = Provider<HrMonitorRepository>((ref) {
  final debugConfig = ref.watch(appDebugConfigProvider);
  if (debugConfig.useMockDevices) {
    return ref.watch(mockDeviceHarnessProvider).hrMonitorRepository;
  }
  final store = ref.watch(deviceSelectionStoreProvider);
  return HrMonitorBleRepository(
    store: store,
    telemetry: ref.watch(appTelemetryProvider),
    diagnosticsStore: ref.watch(diagnosticsStoreProvider),
  );
});

final trainerRepositoryProvider = Provider<TrainerRepository>((ref) {
  final debugConfig = ref.watch(appDebugConfigProvider);
  if (debugConfig.useMockDevices) {
    return ref.watch(mockDeviceHarnessProvider).trainerRepository;
  }
  final store = ref.watch(deviceSelectionStoreProvider);
  return TrainerBleRepository(
    store: store,
    telemetry: ref.watch(appTelemetryProvider),
    diagnosticsStore: ref.watch(diagnosticsStoreProvider),
  );
});

final connectSetupControllerProvider =
    StateNotifierProvider<ConnectSetupController, ConnectSetupState>((ref) {
      final controller = ConnectSetupController(
        hrMonitorRepository: ref.watch(hrMonitorRepositoryProvider),
        trainerRepository: ref.watch(trainerRepositoryProvider),
        blePermissionService: ref.watch(blePermissionServiceProvider),
        deviceSelectionStore: ref.watch(deviceSelectionStoreProvider),
        telemetry: ref.watch(appTelemetryProvider),
        diagnosticsStore: ref.watch(diagnosticsStoreProvider),
      );

      controller.initialize();
      return controller;
    });

final workoutSessionControllerProvider =
    StateNotifierProvider<WorkoutSessionController, WorkoutSessionState>((ref) {
      final controller = WorkoutSessionController(
        hrMonitorRepository: ref.watch(hrMonitorRepositoryProvider),
        trainerRepository: ref.watch(trainerRepositoryProvider),
        telemetry: ref.watch(appTelemetryProvider),
        diagnosticsStore: ref.watch(diagnosticsStoreProvider),
      );

      controller.initialize();
      return controller;
    });

final mockWorkoutDebugControllerProvider =
    StateNotifierProvider<MockWorkoutDebugController, MockWorkoutDebugState>((
      ref,
    ) {
      return MockWorkoutDebugController(
        harness: ref.watch(mockDeviceHarnessProvider),
      );
    });
