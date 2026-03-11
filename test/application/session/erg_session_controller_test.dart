import 'package:android_hrm_erg/src/application/session/erg_session_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_repositories.dart';

void main() {
  void runControlTickWithFreshHr({
    required FakeAsync async,
    required FakeHrMonitorRepository hrRepo,
    required int bpm,
  }) {
    async.elapse(const Duration(seconds: 9));
    hrRepo.emitHr(bpm);
    async.flushMicrotasks();
    async.elapse(const Duration(seconds: 1));
    async.flushMicrotasks();
  }

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

    test('freezes drift and rolling power tracking once cooldown starts', () {
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
          sessionDuration: const Duration(minutes: 6),
        );
        async.flushMicrotasks();

        trainerRepo.emitPower(100);
        trainerRepo.emitPower(88);
        async.flushMicrotasks();

        final driftBeforeCooldown = controller.state.driftPercent;
        final rollingBeforeCooldown = controller.state.averagePower;
        final maxBeforeCooldown = controller.state.maxRollingPower;

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(controller.state.isCooldown, isTrue);

        trainerRepo.emitPower(70);
        async.flushMicrotasks();

        expect(controller.state.currentPower, 70);
        expect(
          controller.state.driftPercent,
          closeTo(driftBeforeCooldown!, 0.01),
        );
        expect(
          controller.state.averagePower,
          closeTo(rollingBeforeCooldown!, 0.01),
        );
        expect(
          controller.state.maxRollingPower,
          closeTo(maxBeforeCooldown!, 0.01),
        );
      });
    });

    test(
      'builds end-of-session summary and zone 2 warning when drift > 5%',
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
            sessionDuration: const Duration(seconds: 2),
          );
          async.flushMicrotasks();

          trainerRepo.emitPower(100);
          trainerRepo.emitPower(88);
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          expect(controller.state.isRunning, isFalse);
          expect(
            controller.state.endSessionSummary,
            contains('Your max 20 min power was'),
          );
          expect(
            controller.state.endSessionSummary,
            contains('Your ending rolling power was'),
          );
          expect(
            controller.state.endSessionSummary,
            contains('Your drift was'),
          );
          expect(controller.state.endSessionZone2Warning, isTrue);
        });
      },
    );
  });

  group('ErgSessionController UC-04 automatic power adjustment', () {
    test('sends power commands at loop interval and increases when HR is low', () {
      fakeAsync((async) {
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = ErgSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
        )..initialize();

        controller.startSession(
          startingWatts: 200,
          targetHr: 120,
          loopSeconds: 10,
          sessionDuration: const Duration(minutes: 30),
        );
        async.flushMicrotasks();

        for (var i = 0; i < 6; i++) {
          runControlTickWithFreshHr(async: async, hrRepo: hrRepo, bpm: 117);
        }

        expect(trainerRepo.targetPowerWrites.length, 7);
        expect(controller.state.currentPower, 210);
        expect(controller.state.lastAdjustmentWatts, 2);
      });
    });

    test('reduces power when HR is above target', () {
      fakeAsync((async) {
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = ErgSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
        )..initialize();

        controller.startSession(
          startingWatts: 200,
          targetHr: 120,
          loopSeconds: 10,
          sessionDuration: const Duration(minutes: 30),
        );
        async.flushMicrotasks();

        for (var i = 0; i < 6; i++) {
          runControlTickWithFreshHr(async: async, hrRepo: hrRepo, bpm: 123);
        }

        expect(controller.state.currentPower, 190);
        expect(controller.state.lastAdjustmentWatts, -2);
      });
    });

    test('matches +3 W/min band over time for a 10-second loop', () {
      fakeAsync((async) {
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = ErgSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
        )..initialize();

        controller.startSession(
          startingWatts: 200,
          targetHr: 120,
          loopSeconds: 10,
          sessionDuration: const Duration(minutes: 30),
        );
        async.flushMicrotasks();

        for (var i = 0; i < 6; i++) {
          runControlTickWithFreshHr(async: async, hrRepo: hrRepo, bpm: 119);
        }

        expect(controller.state.currentPower, 203);
      });
    });

    test('clamps next power to safe range 50..500 W', () {
      fakeAsync((async) {
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = ErgSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
        )..initialize();

        controller.startSession(
          startingWatts: 499,
          targetHr: 120,
          loopSeconds: 10,
          sessionDuration: const Duration(minutes: 30),
        );
        async.flushMicrotasks();
        runControlTickWithFreshHr(async: async, hrRepo: hrRepo, bpm: 117);
        expect(controller.state.currentPower, 500);

        controller.startSession(
          startingWatts: 51,
          targetHr: 120,
          loopSeconds: 10,
          sessionDuration: const Duration(minutes: 30),
        );
        async.flushMicrotasks();
        runControlTickWithFreshHr(async: async, hrRepo: hrRepo, bpm: 123);
        expect(controller.state.currentPower, 50);
      });
    });

    test('sets error and skips adjustment when no HR data is available', () {
      fakeAsync((async) {
        final trainerRepo = FakeTrainerRepository();
        final controller = ErgSessionController(
          hrMonitorRepository: FakeHrMonitorRepository(),
          trainerRepository: trainerRepo,
        )..initialize();

        controller.startSession(
          startingWatts: 200,
          targetHr: 120,
          loopSeconds: 10,
          sessionDuration: const Duration(minutes: 30),
        );
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(
          controller.state.error,
          'No HR data yet. Waiting for monitor samples...',
        );
        expect(trainerRepo.targetPowerWrites, [200]);
      });
    });
  });
}
