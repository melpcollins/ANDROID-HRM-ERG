import 'dart:ui';

import 'package:android_hrm_erg/src/app.dart';
import 'package:android_hrm_erg/src/app/providers.dart';
import 'package:android_hrm_erg/src/application/session/workout_session_controller.dart';
import 'package:android_hrm_erg/src/debug/app_debug_config.dart';
import 'package:android_hrm_erg/src/debug/mock_device_harness.dart';
import 'package:android_hrm_erg/src/debug/mock_workout_debug_controller.dart';
import 'package:android_hrm_erg/src/domain/models/workout_config.dart';
import 'package:android_hrm_erg/src/domain/models/workout_phase.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'provider wiring selects mock repositories when debug mock mode is on',
    () {
      final container = ProviderContainer(
        overrides: [
          appDebugConfigProvider.overrideWithValue(
            const AppDebugConfig(useMockDevices: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(hrMonitorRepositoryProvider),
        isA<MockHrMonitorRepository>(),
      );
      expect(
        container.read(trainerRepositoryProvider),
        isA<MockTrainerRepository>(),
      );
    },
  );

  test('mock steady scenario drives HR-ERG without BLE hardware', () {
    fakeAsync((async) {
      var currentTime = DateTime(2026, 1, 1, 9);
      void advance(Duration duration) {
        for (var i = 0; i < duration.inSeconds; i++) {
          currentTime = currentTime.add(const Duration(seconds: 1));
          async.elapse(const Duration(seconds: 1));
        }
      }

      final harness = MockDeviceHarness(nowProvider: () => currentTime);
      final workoutController = WorkoutSessionController(
        hrMonitorRepository: harness.hrMonitorRepository,
        trainerRepository: harness.trainerRepository,
        nowProvider: () => currentTime,
      )..initialize();
      final debugController = MockWorkoutDebugController(harness: harness);

      debugController.connectHrMonitor();
      debugController.connectTrainer();
      async.flushMicrotasks();

      workoutController.startWorkout(
        const HrErgConfig(
          startingWatts: 200,
          targetHr: 120,
          loopSeconds: 20,
          duration: Duration(minutes: 30),
        ),
      );
      async.flushMicrotasks();

      debugController.setSteadyHr(117);
      debugController.startSteadyScenario();
      advance(const Duration(seconds: 21));
      async.flushMicrotasks();

      expect(workoutController.state.phase, WorkoutPhase.active);
      expect(workoutController.state.currentPower, greaterThan(200));

      debugController.dispose();
      workoutController.dispose();
      harness.dispose();
    });
  });

  test('dropout scenario causes stale-HR pause', () {
    fakeAsync((async) {
      var currentTime = DateTime(2026, 1, 1, 9);
      void advance(Duration duration) {
        for (var i = 0; i < duration.inSeconds; i++) {
          currentTime = currentTime.add(const Duration(seconds: 1));
          async.elapse(const Duration(seconds: 1));
        }
      }

      final harness = MockDeviceHarness(nowProvider: () => currentTime);
      final workoutController = WorkoutSessionController(
        hrMonitorRepository: harness.hrMonitorRepository,
        trainerRepository: harness.trainerRepository,
        nowProvider: () => currentTime,
      )..initialize();
      final debugController = MockWorkoutDebugController(harness: harness);

      debugController.connectHrMonitor();
      debugController.connectTrainer();
      async.flushMicrotasks();

      workoutController.startWorkout(
        const HrErgConfig(
          startingWatts: 200,
          targetHr: 120,
          loopSeconds: 20,
          duration: Duration(minutes: 30),
        ),
      );
      async.flushMicrotasks();

      debugController.startDropoutScenario();
      advance(const Duration(seconds: 16));
      async.flushMicrotasks();

      expect(workoutController.state.phase, WorkoutPhase.paused);

      debugController.dispose();
      workoutController.dispose();
      harness.dispose();
    });
  });

  testWidgets('mock controls panel is visible when mock mode is enabled', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDebugConfigProvider.overrideWithValue(
            const AppDebugConfig(useMockDevices: true),
          ),
        ],
        child: const HrmErgApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Mock Controls'), findsOneWidget);
    expect(find.text('Connect HR'), findsOneWidget);
    expect(find.text('Steady'), findsOneWidget);
  });
}
