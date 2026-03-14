import 'package:android_hrm_erg/src/application/connect/connect_setup_controller.dart';
import 'package:android_hrm_erg/src/domain/models/ble_device_info.dart';
import 'package:android_hrm_erg/src/domain/models/ble_readiness.dart';
import 'package:android_hrm_erg/src/domain/models/connection_status.dart';
import 'package:android_hrm_erg/src/infrastructure/storage/device_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ble_permission_service.dart';
import '../../support/fake_repositories.dart';

void main() {
  ConnectSetupController buildController({
    required FakeHrMonitorRepository hrRepo,
    required FakeTrainerRepository trainerRepo,
    required FakeBlePermissionService permissionService,
    DeviceSelectionStore? store,
    Duration hrStaleThreshold = const Duration(seconds: 5),
    Duration trainerStaleThreshold = const Duration(seconds: 10),
  }) {
    final controller = ConnectSetupController(
      hrMonitorRepository: hrRepo,
      trainerRepository: trainerRepo,
      blePermissionService: permissionService,
      deviceSelectionStore: store ?? DeviceSelectionStore(),
      hrStaleThreshold: hrStaleThreshold,
      trainerStaleThreshold: trainerStaleThreshold,
    );
    addTearDown(() {
      controller.dispose();
      permissionService.dispose();
    });
    return controller;
  }

  test(
    'initialization loads saved IDs and names and auto reconnects when BLE is ready',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        DeviceSelectionStore.hrMonitorNameKey: 'Polar H10',
        DeviceSelectionStore.trainerNameKey: 'wattbikeAtom260160812',
      });
      final hrRepo = FakeHrMonitorRepository()..savedDeviceId = 'hr-1';
      final trainerRepo = FakeTrainerRepository()..savedDeviceId = 'trainer-1';
      final permissionService = FakeBlePermissionService();
      final controller = buildController(
        hrRepo: hrRepo,
        trainerRepo: trainerRepo,
        permissionService: permissionService,
      );

      await controller.initialize();

      expect(controller.state.selectedHrId, 'hr-1');
      expect(controller.state.selectedTrainerId, 'trainer-1');
      expect(controller.state.selectedHrName, 'Polar H10');
      expect(controller.state.selectedTrainerName, 'wattbikeAtom260160812');
      expect(controller.state.permissionsGranted, isTrue);
      expect(controller.state.bluetoothEnabled, isTrue);
      expect(hrRepo.reconnectCalls, 1);
      expect(trainerRepo.reconnectCalls, 1);
    },
  );

  test('scan stays blocked until permissions are granted', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final hrRepo = FakeHrMonitorRepository()
      ..scanResults.add(const BleDeviceInfo(id: 'hr-1', name: 'HRM'));
    final trainerRepo = FakeTrainerRepository();
    final permissionService = FakeBlePermissionService(
      initialReadiness: const BleReadiness(
        permissionsGranted: false,
        bluetoothEnabled: true,
      ),
    );
    final controller = buildController(
      hrRepo: hrRepo,
      trainerRepo: trainerRepo,
      permissionService: permissionService,
    );

    await controller.initialize();
    await controller.scanHrMonitors();

    expect(hrRepo.scanCalls, 0);
    expect(controller.state.permissionsGranted, isFalse);
    expect(controller.state.hrDevices, isEmpty);

    permissionService.setReadiness(
      const BleReadiness(permissionsGranted: true, bluetoothEnabled: true),
    );

    await controller.requestBleAccess();
    await controller.scanHrMonitors();

    expect(hrRepo.scanCalls, 1);
    expect(controller.state.hrDevices, hasLength(1));
  });

  test('bluetooth off blocks reconnect until adapter turns back on', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final hrRepo = FakeHrMonitorRepository()..savedDeviceId = 'hr-1';
    final trainerRepo = FakeTrainerRepository()..savedDeviceId = 'trainer-1';
    final permissionService = FakeBlePermissionService(
      initialReadiness: const BleReadiness(
        permissionsGranted: true,
        bluetoothEnabled: false,
      ),
    );
    final controller = buildController(
      hrRepo: hrRepo,
      trainerRepo: trainerRepo,
      permissionService: permissionService,
    );

    await controller.initialize();

    expect(controller.state.bluetoothEnabled, isFalse);
    expect(hrRepo.reconnectCalls, 0);
    expect(trainerRepo.reconnectCalls, 0);

    permissionService.setReadiness(
      const BleReadiness(permissionsGranted: true, bluetoothEnabled: true),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.bluetoothEnabled, isTrue);
    expect(hrRepo.reconnectCalls, 1);
    expect(trainerRepo.reconnectCalls, 1);
  });

  test('connected-no-data states are reflected in setup state', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    final permissionService = FakeBlePermissionService();
    final controller = buildController(
      hrRepo: hrRepo,
      trainerRepo: trainerRepo,
      permissionService: permissionService,
    );

    await controller.initialize();
    hrRepo.emitConnectionStatus(ConnectionStatus.connectedNoData);
    trainerRepo.emitConnectionStatus(ConnectionStatus.connectedNoData);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.hrStatus, ConnectionStatus.connectedNoData);
    expect(controller.state.trainerStatus, ConnectionStatus.connectedNoData);
  });

  test(
    'fresh HR data promotes connected devices and stale timers mark HR disconnected',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final hrRepo = FakeHrMonitorRepository();
      final trainerRepo = FakeTrainerRepository();
      final permissionService = FakeBlePermissionService();
      final controller = buildController(
        hrRepo: hrRepo,
        trainerRepo: trainerRepo,
        permissionService: permissionService,
        hrStaleThreshold: const Duration(milliseconds: 20),
        trainerStaleThreshold: const Duration(milliseconds: 20),
      );

      await controller.initialize();
      hrRepo.emitConnectionStatus(ConnectionStatus.connected);
      trainerRepo.emitConnectionStatus(ConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.hrStatus, ConnectionStatus.connectedNoData);
      expect(controller.state.trainerStatus, ConnectionStatus.connectedNoData);

      hrRepo.emitHr(124);
      trainerRepo.emitTelemetry(180, cadence: 90);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.hrStatus, ConnectionStatus.connected);
      expect(controller.state.trainerStatus, ConnectionStatus.connected);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.state.hrStatus, ConnectionStatus.disconnected);
      expect(controller.state.trainerStatus, ConnectionStatus.connectedNoData);
    },
  );

  test('scan upgrades saved devices from IDs to friendly names', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final store = DeviceSelectionStore();
    final hrRepo = FakeHrMonitorRepository()
      ..savedDeviceId = 'hr-1'
      ..scanResults.add(const BleDeviceInfo(id: 'hr-1', name: 'Polar H10'));
    final trainerRepo = FakeTrainerRepository()
      ..savedDeviceId = 'trainer-1'
      ..scanResults.add(
        const BleDeviceInfo(id: 'trainer-1', name: 'wattbikeAtom260160812'),
      );
    final permissionService = FakeBlePermissionService();
    final controller = buildController(
      hrRepo: hrRepo,
      trainerRepo: trainerRepo,
      permissionService: permissionService,
      store: store,
    );

    await controller.initialize();
    await controller.scanHrMonitors();
    await controller.scanTrainers();

    expect(controller.state.selectedHrName, 'Polar H10');
    expect(controller.state.selectedTrainerName, 'wattbikeAtom260160812');
    expect(await store.getHrMonitorName(), 'Polar H10');
    expect(await store.getTrainerName(), 'wattbikeAtom260160812');
  });

  test(
    'connect persists friendly names and disconnect leaves saved selections intact',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final store = DeviceSelectionStore();
      final hrRepo = FakeHrMonitorRepository()
        ..scanResults.add(const BleDeviceInfo(id: 'hr-1', name: 'Polar H10'));
      final trainerRepo = FakeTrainerRepository()
        ..scanResults.add(
          const BleDeviceInfo(id: 'trainer-1', name: 'wattbikeAtom260160812'),
        );
      final permissionService = FakeBlePermissionService();
      final controller = buildController(
        hrRepo: hrRepo,
        trainerRepo: trainerRepo,
        permissionService: permissionService,
        store: store,
      );

      await controller.initialize();
      await controller.scanHrMonitors();
      await controller.scanTrainers();
      await controller.connectHrMonitor('hr-1');
      await controller.connectTrainer('trainer-1');

      expect(controller.state.selectedHrName, 'Polar H10');
      expect(controller.state.selectedTrainerName, 'wattbikeAtom260160812');
      expect(await store.getHrMonitorName(), 'Polar H10');
      expect(await store.getTrainerName(), 'wattbikeAtom260160812');

      await controller.disconnectHrMonitor();
      await controller.disconnectTrainer();

      expect(hrRepo.disconnectCalls, 1);
      expect(trainerRepo.disconnectCalls, 1);
      expect(controller.state.selectedHrId, 'hr-1');
      expect(controller.state.selectedTrainerId, 'trainer-1');
      expect(controller.state.selectedHrName, 'Polar H10');
      expect(controller.state.selectedTrainerName, 'wattbikeAtom260160812');
    },
  );
}
