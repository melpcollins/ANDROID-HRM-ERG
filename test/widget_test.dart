import 'package:android_hrm_erg/src/app.dart';
import 'package:android_hrm_erg/src/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required FakeHrMonitorRepository hrRepo,
    required FakeTrainerRepository trainerRepo,
  }) async {
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
    expect(find.text('Zone 2 Assessment'), findsOneWidget);
    expect(find.text('Starting Watts'), findsOneWidget);
    expect(find.text('Target Heart Rate'), findsOneWidget);
    expect(find.text('Duration Hours'), findsOneWidget);
    expect(find.text('Duration Minutes'), findsOneWidget);
    expect(find.textContaining('60s HR average'), findsOneWidget);
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

    expect(find.text('Assessment Power'), findsOneWidget);
    expect(find.textContaining('Fixed protocol'), findsOneWidget);
    expect(find.text('Starting Watts'), findsNothing);
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
}
