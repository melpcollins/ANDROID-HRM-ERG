import 'package:android_hrm_erg/src/app.dart';
import 'package:android_hrm_erg/src/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_repositories.dart';

void main() {
  Finder findTextFieldByLabel(String label) {
    return find.ancestor(of: find.text(label), matching: find.byType(TextField));
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required FakeHrMonitorRepository hrRepo,
    required FakeTrainerRepository trainerRepo,
    Map<String, Object> mockPrefs = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(mockPrefs);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hrMonitorRepositoryProvider.overrideWithValue(hrRepo),
          trainerRepositoryProvider.overrideWithValue(trainerRepo),
        ],
        child: const HrmErgApp(),
      ),
    );
    await tester.pump();
    await hrRepo.reconnect();
    await trainerRepo.reconnect();
    await tester.pump();
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
    expect(find.byKey(const ValueKey('selected-workout-type-row')), findsOneWidget);
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
    expect(find.text('Target -5'), findsOneWidget);
    expect(find.text('Target +5'), findsOneWidget);
    expect(find.text('01:00:00'), findsOneWidget);
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
        (prefs) => Map<String, Object>.from(prefs.getKeys().fold<Map<String, Object>>(
          <String, Object>{},
          (values, key) {
            final value = prefs.get(key);
            if (value != null) {
              values[key] = value;
            }
            return values;
          },
        )),
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
}
