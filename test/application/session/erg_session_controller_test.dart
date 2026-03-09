import 'package:android_hrm_erg/src/application/session/erg_session_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_repositories.dart';

void main() {
  group('ErgSessionController countdown and cooldown', () {
    test(
      'starts with configured duration and enters cooldown at 5 minutes',
      () {
        fakeAsync((async) {
          final hrRepo = FakeHrMonitorRepository();
          final trainerRepo = FakeTrainerRepository();
          final controller = ErgSessionController(
            hrMonitorRepository: hrRepo,
            trainerRepository: trainerRepo,
          )..initialize();

          controller.startSession(
            startingWatts: 120,
            targetHr: 130,
            loopSeconds: 10,
            sessionDuration: const Duration(minutes: 6),
          );
          async.flushMicrotasks();

          expect(
            controller.state.remainingDuration,
            const Duration(minutes: 6),
          );
          expect(controller.state.isCooldown, isFalse);
          expect(controller.state.targetHr, 130);

          async.elapse(const Duration(seconds: 60));
          async.flushMicrotasks();

          expect(
            controller.state.remainingDuration,
            const Duration(minutes: 5),
          );
          expect(controller.state.isCooldown, isTrue);
          expect(controller.state.targetHr, 95);
        });
      },
    );

    test('stops automatically when countdown reaches zero', () {
      fakeAsync((async) {
        final controller = ErgSessionController(
          hrMonitorRepository: FakeHrMonitorRepository(),
          trainerRepository: FakeTrainerRepository(),
        )..initialize();

        controller.startSession(
          startingWatts: 120,
          targetHr: 130,
          loopSeconds: 10,
          sessionDuration: const Duration(seconds: 2),
        );
        async.flushMicrotasks();

        expect(controller.state.isRunning, isTrue);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(controller.state.remainingDuration, Duration.zero);
        expect(controller.state.isRunning, isFalse);
      });
    });
  });

  group('ErgSessionController drift percentage', () {
    test('sets driftPercent to null when drift is zero', () {
      fakeAsync((async) {
        final trainerRepo = FakeTrainerRepository();
        final controller = ErgSessionController(
          hrMonitorRepository: FakeHrMonitorRepository(),
          trainerRepository: trainerRepo,
        )..initialize();

        controller.startSession(
          startingWatts: 100,
          targetHr: 120,
          loopSeconds: 10,
          sessionDuration: const Duration(minutes: 30),
        );
        async.flushMicrotasks();

        trainerRepo.emitPower(100);
        async.flushMicrotasks();

        expect(controller.state.driftWatts, 0);
        expect(controller.state.driftPercent, isNull);
      });
    });

    test(
      'calculates drift percentage as drift watts divided by current power',
      () {
        fakeAsync((async) {
          final trainerRepo = FakeTrainerRepository();
          final controller = ErgSessionController(
            hrMonitorRepository: FakeHrMonitorRepository(),
            trainerRepository: trainerRepo,
          )..initialize();

          controller.startSession(
            startingWatts: 100,
            targetHr: 120,
            loopSeconds: 10,
            sessionDuration: const Duration(minutes: 30),
          );
          async.flushMicrotasks();

          trainerRepo.emitPower(100);
          trainerRepo.emitPower(88);
          async.flushMicrotasks();

          expect(controller.state.driftWatts, closeTo(6.0, 0.001));
          expect(controller.state.driftPercent, closeTo(6.818, 0.01));
        });
      },
    );
  });
}
