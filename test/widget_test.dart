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
  }

  Future<void> startSession(
    WidgetTester tester, {
    required int hours,
    required int minutes,
  }) async {
    await tester.enterText(find.byType(TextField).at(3), '$hours');
    await tester.enterText(find.byType(TextField).at(4), '$minutes');
    await tester.tap(find.text('Start'));
    await tester.pump();
  }

  testWidgets('shows duration fields in ERG control form', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: FakeTrainerRepository(),
    );

    expect(find.text('Starting Watts'), findsOneWidget);
    expect(find.text('Target Heart Rate'), findsOneWidget);
    expect(find.text('Loop Interval (seconds)'), findsOneWidget);
    expect(find.text('Duration Hours'), findsOneWidget);
    expect(find.text('Duration Minutes'), findsOneWidget);
  });

  testWidgets(
    'enters cooldown at 5 minutes remaining and updates target HR to 95',
    (WidgetTester tester) async {
      await pumpApp(
        tester,
        hrRepo: FakeHrMonitorRepository(),
        trainerRepo: FakeTrainerRepository(),
      );

      await startSession(tester, hours: 0, minutes: 6);
      await tester.pump(const Duration(seconds: 60));

      expect(find.text('Cooldown'), findsOneWidget);
      expect(find.text('95 bpm'), findsOneWidget);
      expect(find.text('00:05:00'), findsOneWidget);
    },
  );

  testWidgets('shows drift as -- when drift is zero', (
    WidgetTester tester,
  ) async {
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: trainerRepo,
    );

    await startSession(tester, hours: 0, minutes: 30);
    trainerRepo.emitPower(100);
    await tester.pump();

    expect(find.text('Drift'), findsOneWidget);
    expect(find.text('--'), findsWidgets);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('colors drift green when drift percent is <= 5', (
    WidgetTester tester,
  ) async {
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: trainerRepo,
    );

    await startSession(tester, hours: 0, minutes: 30);
    trainerRepo.emitPower(100);
    trainerRepo.emitPower(95);
    await tester.pump();

    final text = tester.widget<Text>(find.text('2.6%'));
    expect(text.style?.color, equals(Colors.green.shade700));
  });

  testWidgets('colors drift yellow when drift percent is > 5 and <= 10', (
    WidgetTester tester,
  ) async {
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: trainerRepo,
    );

    await startSession(tester, hours: 0, minutes: 30);
    trainerRepo.emitPower(100);
    trainerRepo.emitPower(88);
    await tester.pump();

    final text = tester.widget<Text>(find.text('6.8%'));
    expect(text.style?.color, equals(Colors.amber.shade800));
  });

  testWidgets('colors drift red when drift percent is > 10', (
    WidgetTester tester,
  ) async {
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: trainerRepo,
    );

    await startSession(tester, hours: 0, minutes: 30);
    trainerRepo.emitPower(100);
    trainerRepo.emitPower(70);
    await tester.pump();

    final text = tester.widget<Text>(find.text('21.4%'));
    final context = tester.element(find.text('21.4%'));
    expect(text.style?.color, equals(Theme.of(context).colorScheme.error));
  });

  testWidgets('shows end-of-session summary and zone 2 warning', (
    WidgetTester tester,
  ) async {
    final trainerRepo = FakeTrainerRepository();
    await pumpApp(
      tester,
      hrRepo: FakeHrMonitorRepository(),
      trainerRepo: trainerRepo,
    );

    await startSession(tester, hours: 0, minutes: 6);
    trainerRepo.emitPower(100);
    trainerRepo.emitPower(88);
    await tester.pump();

    await tester.pump(const Duration(minutes: 6));

    expect(find.textContaining('Your max 20 min power was'), findsOneWidget);
    expect(
      find.textContaining('Your ending rolling power was'),
      findsOneWidget,
    );
    expect(find.textContaining('Your drift was'), findsOneWidget);
    expect(
      find.text('Warning: this was likely above zone 2 effort.'),
      findsOneWidget,
    );
  });
}
