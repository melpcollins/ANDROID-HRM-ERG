import 'package:android_hrm_erg/src/app.dart';
import 'package:android_hrm_erg/src/app/providers.dart';
import 'package:android_hrm_erg/src/domain/models/ble_readiness.dart';
import 'package:android_hrm_erg/src/domain/models/connection_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_ble_permission_service.dart';
import 'support/fake_repositories.dart';

void main() {
  Finder findTextFieldByLabel(String label) {
    return find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required FakeHrMonitorRepository hrRepo,
    required FakeTrainerRepository trainerRepo,
    FakeBlePermissionService? permissionService,
    Map<String, Object> mockPrefs = const <String, Object>{},
    Size physicalSize = const Size(1200, 2200),
    bool autoConnectDevices = true,
  }) async {
    final blePermissionService =
        permissionService ?? FakeBlePermissionService();
    addTearDown(blePermissionService.dispose);
    SharedPreferences.setMockInitialValues(mockPrefs);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = physicalSize;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hrMonitorRepositoryProvider.overrideWithValue(hrRepo),
          trainerRepositoryProvider.overrideWithValue(trainerRepo),
          blePermissionServiceProvider.overrideWithValue(blePermissionService),
        ],
        child: const HrmErgApp(),
      ),
    );
    await tester.pump();
    if (autoConnectDevices) {
      await hrRepo.reconnect();
      await trainerRepo.reconnect();
      hrRepo.emitHr(124);
      trainerRepo.emitTelemetry(180, cadence: trainerRepo.currentCadence ?? 88);
      await tester.pump();
    }
  }

  testWidgets('shows HR-ERG setup fields by default', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
    );

    expect(find.text('HR-ERG'), findsOneWidget);
    expect(find.text('Power-ERG'), findsOneWidget);
    expect(find.text('Zone 2 Assessment'), findsOneWidget);
    expect(find.text('Starting Watts'), findsOneWidget);
    expect(find.text('Target Heart Rate'), findsOneWidget);
    expect(find.text('Duration Hours'), findsOneWidget);
    expect(find.text('Duration Minutes'), findsOneWidget);
    expect(find.textContaining('10s HR average'), findsOneWidget);
    expect(find.text('70'), findsWidgets);
    expect(find.text('112'), findsWidgets);
  });

  testWidgets('switches to Zone 2 assessment setup', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
    );

    await tester.tap(find.text('Zone 2 Assessment'));
    await tester.pump();

    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Assessment Power'), findsOneWidget);
    expect(find.textContaining('Fixed protocol'), findsOneWidget);
    expect(find.text('Starting Watts'), findsNothing);
    expect(
      find.byKey(const ValueKey('selected-workout-type-row')),
      findsOneWidget,
    );
  });

  testWidgets('switches to Power-ERG and shows its setup fields', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
    );

    await tester.tap(find.text('Power-ERG'));
    await tester.pump();

    expect(find.text('Target Power'), findsOneWidget);
    expect(find.text('Max Heart Rate'), findsOneWidget);
    expect(find.text('140'), findsWidgets);
    expect(find.text('125'), findsWidgets);
    expect(find.textContaining('10 min ramp from 50% to 100%'), findsOneWidget);
    expect(find.text('Target Heart Rate'), findsNothing);

    await tester.tap(find.text('Change'));
    await tester.pump();

    expect(find.byKey(const ValueKey('workout-type-options')), findsOneWidget);
    expect(find.text('HR-ERG'), findsOneWidget);
    expect(find.text('Power-ERG'), findsOneWidget);
    expect(find.text('Zone 2 Assessment'), findsOneWidget);
  });

  testWidgets('starts HR-ERG and shows target adjustment buttons', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(tester, hrRepo: hrRepo, trainerRepo: trainerRepo);

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Live Session'), findsOneWidget);
    expect(find.text('HR Avg (10s)'), findsNothing);
    expect(find.text('Target -5'), findsOneWidget);
    expect(find.text('Target +5'), findsOneWidget);
    expect(find.text('01:00:00'), findsOneWidget);
  });

  testWidgets('stale HR shows disconnected in setup after fresh data stops', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(tester, hrRepo: hrRepo, trainerRepo: trainerRepo);

    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Trainer'), findsOneWidget);
    expect(find.text('Reconnect saved'), findsOneWidget);
  });

  testWidgets('live HR-ERG metrics show target HR above power and cadence', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository()..currentCadence = 88;
    await pumpApp(tester, hrRepo: hrRepo, trainerRepo: trainerRepo);

    await tester.tap(find.text('Start'));
    await tester.pump();

    final hrTop = tester.getTopLeft(find.text('HR')).dy;
    final targetHrTop = tester.getTopLeft(find.text('Target HR')).dy;
    final powerTop = tester.getTopLeft(find.text('Power (10s avg)')).dy;
    final cadenceTop = tester.getTopLeft(find.text('Cadence')).dy;

    expect(targetHrTop, greaterThan(hrTop));
    expect(powerTop, greaterThan(targetHrTop));
    expect(cadenceTop, greaterThan(powerTop));
  });

  testWidgets('live session blanks stale HR instead of holding last bpm', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(tester, hrRepo: hrRepo, trainerRepo: trainerRepo);

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('124 bpm'), findsOneWidget);

    hrRepo.emitConnectionStatus(ConnectionStatus.connectedNoData);
    await tester.pumpAndSettle();

    expect(find.text('124 bpm'), findsNothing);
    expect(find.text('--'), findsWidgets);
  });

  testWidgets('workout setup collapses on start and reopens on stop', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(tester, hrRepo: hrRepo, trainerRepo: trainerRepo);

    expect(find.text('Starting Watts'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Starting Watts'), findsNothing);
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(find.text('Starting Watts'), findsOneWidget);
  });

  testWidgets('starts Zone 2 assessment and shows fixed countdown', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(tester, hrRepo: hrRepo, trainerRepo: trainerRepo);

    await tester.tap(find.text('Zone 2 Assessment'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Live Session'), findsOneWidget);
    expect(find.text('01:30:00'), findsOneWidget);
  });

  testWidgets('starts Power-ERG and shows total countdown', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(tester, hrRepo: hrRepo, trainerRepo: trainerRepo);

    await tester.tap(find.text('Power-ERG'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Live Session'), findsOneWidget);
    expect(find.text('Max HR'), findsOneWidget);
    expect(find.text('Target Power'), findsOneWidget);
    expect(find.text('Power -5'), findsOneWidget);
    expect(find.text('Power +5'), findsOneWidget);
    expect(find.text('01:15:00'), findsOneWidget);
  });

  testWidgets('connected device cards collapse and expand when tapped', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
    );

    expect(find.byKey(const ValueKey('compact-device-row')), findsOneWidget);
    expect(find.text('HR Monitor'), findsNothing);
    expect(find.text('Trainer'), findsNothing);
    expect(find.text('HR-Connected'), findsOneWidget);
    expect(find.text('TR-Connected'), findsOneWidget);
    expect(find.text('No devices yet. Tap Scan.'), findsNothing);

    await tester.tap(find.text('HR-Connected'));
    await tester.pump();

    expect(find.byKey(const ValueKey('compact-device-row')), findsNothing);
    expect(find.text('HR Monitor'), findsOneWidget);
    expect(find.text('Trainer'), findsOneWidget);
    expect(find.text('No devices yet. Tap Scan.'), findsOneWidget);

    await tester.tap(find.text('Connected').last);
    await tester.pump();

    expect(find.text('No devices yet. Tap Scan.'), findsNWidgets(2));
  });

  testWidgets('compact connected device pills do not overflow on phone width', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
      physicalSize: const Size(390, 844),
    );

    expect(find.byKey(const ValueKey('compact-device-row')), findsOneWidget);
    expect(find.text('HR-Connected'), findsOneWidget);
    expect(find.text('TR-Connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads saved HR-ERG defaults from shared preferences', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
      mockPrefs: const <String, Object>{
        'hr_erg_starting_watts': 88,
        'hr_erg_target_hr': 123,
      },
    );

    await tester.pumpAndSettle();

    expect(find.text('88'), findsWidgets);
    expect(find.text('123'), findsWidgets);
  });

  testWidgets('persists edited HR-ERG defaults across app restart', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
    );

    await tester.enterText(findTextFieldByLabel('Starting Watts'), '84');
    await tester.pump();
    await tester.enterText(findTextFieldByLabel('Target Heart Rate'), '118');
    await tester.pumpAndSettle();

    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
      mockPrefs: await SharedPreferences.getInstance().then(
        (prefs) => Map<String, Object>.from(
          prefs.getKeys().fold<Map<String, Object>>(<String, Object>{}, (
            values,
            key,
          ) {
            final value = prefs.get(key);
            if (value != null) {
              values[key] = value;
            }
            return values;
          }),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final startingWattsField = tester.widget<TextField>(
      findTextFieldByLabel('Starting Watts'),
    );
    final targetHrField = tester.widget<TextField>(
      findTextFieldByLabel('Target Heart Rate'),
    );

    expect(startingWattsField.controller?.text, '84');
    expect(targetHrField.controller?.text, '118');
  });

  testWidgets('shows permission guidance when Bluetooth access is denied', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
      permissionService: FakeBlePermissionService(
        initialReadiness: const BleReadiness(
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      ),
      autoConnectDevices: false,
    );

    expect(find.text('Bluetooth Access Needed'), findsOneWidget);
    expect(find.text('Grant access'), findsOneWidget);
  });

  testWidgets('shows Bluetooth-off guidance when adapter is disabled', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
      permissionService: FakeBlePermissionService(
        initialReadiness: const BleReadiness(
          permissionsGranted: true,
          bluetoothEnabled: false,
        ),
      ),
      autoConnectDevices: false,
    );

    expect(find.text('Bluetooth Is Off'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('shows connected-without-data labels for device sections', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository();
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(
      tester,
      hrRepo: hrRepo,
      trainerRepo: trainerRepo,
      autoConnectDevices: false,
    );

    hrRepo.emitConnectionStatus(ConnectionStatus.connectedNoData);
    trainerRepo.emitConnectionStatus(ConnectionStatus.connectedNoData);
    await tester.pumpAndSettle();

    expect(find.text('Connected (no HR data)'), findsOneWidget);
    expect(find.text('Connected (no response)'), findsOneWidget);
  });

  testWidgets(
    'connected-without-data devices expand to show reconnection actions',
    (WidgetTester tester) async {
      final hrRepo = FakeHrMonitorRepository()..savedDeviceId = 'hr-1';
      final trainerRepo = FakeTrainerRepository()..savedDeviceId = 'trainer-1';
      await pumpApp(
        tester,
        hrRepo: hrRepo,
        trainerRepo: trainerRepo,
        autoConnectDevices: false,
      );

      hrRepo.emitConnectionStatus(ConnectionStatus.connectedNoData);
      trainerRepo.emitConnectionStatus(ConnectionStatus.connectedNoData);
      await tester.pumpAndSettle();

      expect(find.text('Connected (no HR data)'), findsOneWidget);
      expect(find.text('Connected (no response)'), findsOneWidget);
      expect(find.text('Reconnect saved'), findsNWidgets(2));
      expect(find.text('Disconnect'), findsNWidgets(2));
    },
  );

  testWidgets('shows friendly saved device names instead of IDs', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository()..savedDeviceId = 'C3:E7:00:11';
    final trainerRepo = FakeTrainerRepository()..savedDeviceId = 'C3:E7:22:33';
    await pumpApp(
      tester,
      hrRepo: hrRepo,
      trainerRepo: trainerRepo,
      autoConnectDevices: false,
      permissionService: FakeBlePermissionService(
        initialReadiness: const BleReadiness(
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      ),
      mockPrefs: const <String, Object>{
        'selected_hr_monitor_name': 'Polar H10',
        'selected_trainer_name': 'wattbikeAtom260160812',
      },
    );

    expect(find.text('Saved device: Polar H10'), findsOneWidget);
    expect(find.text('Saved device: wattbikeAtom260160812'), findsOneWidget);
    expect(find.text('Saved device: C3:E7:00:11'), findsNothing);
    expect(find.text('Saved device: C3:E7:22:33'), findsNothing);
  });

  testWidgets('shows disconnect buttons for saved devices', (
    WidgetTester tester,
  ) async {
    final hrRepo = FakeHrMonitorRepository()..savedDeviceId = 'hr-1';
    final trainerRepo = FakeTrainerRepository()..savedDeviceId = 'trainer-1';
    await pumpApp(
      tester,
      hrRepo: hrRepo,
      trainerRepo: trainerRepo,
      autoConnectDevices: false,
      permissionService: FakeBlePermissionService(
        initialReadiness: const BleReadiness(
          permissionsGranted: false,
          bluetoothEnabled: true,
        ),
      ),
      mockPrefs: const <String, Object>{
        'selected_hr_monitor_name': 'Polar H10',
        'selected_trainer_name': 'wattbikeAtom260160812',
      },
    );

    expect(find.text('Disconnect'), findsNWidgets(2));
  });
}
