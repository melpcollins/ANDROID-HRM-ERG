import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connect/connect_setup_controller.dart';
import '../application/connect/connect_setup_state.dart';
import '../application/session/erg_session_controller.dart';
import '../application/session/erg_session_state.dart';
import '../domain/repositories/hr_monitor_repository.dart';
import '../domain/repositories/trainer_repository.dart';
import '../infrastructure/ble/hr_monitor_ble_repository.dart';
import '../infrastructure/ble/trainer_ble_repository.dart';
import '../infrastructure/storage/device_selection_store.dart';

final deviceSelectionStoreProvider = Provider<DeviceSelectionStore>((ref) {
  return DeviceSelectionStore();
});

final hrMonitorRepositoryProvider = Provider<HrMonitorRepository>((ref) {
  final store = ref.watch(deviceSelectionStoreProvider);
  return HrMonitorBleRepository(store: store);
});

final trainerRepositoryProvider = Provider<TrainerRepository>((ref) {
  final store = ref.watch(deviceSelectionStoreProvider);
  return TrainerBleRepository(store: store);
});

final connectSetupControllerProvider =
    StateNotifierProvider<ConnectSetupController, ConnectSetupState>((ref) {
      final controller = ConnectSetupController(
        hrMonitorRepository: ref.watch(hrMonitorRepositoryProvider),
        trainerRepository: ref.watch(trainerRepositoryProvider),
      );

      controller.initialize();
      return controller;
    });

final ergSessionControllerProvider =
    StateNotifierProvider<ErgSessionController, ErgSessionState>((ref) {
      final controller = ErgSessionController(
        hrMonitorRepository: ref.watch(hrMonitorRepositoryProvider),
        trainerRepository: ref.watch(trainerRepositoryProvider),
      );

      controller.initialize();
      return controller;
    });
