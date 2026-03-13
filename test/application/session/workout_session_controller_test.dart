import 'package:android_hrm_erg/src/application/session/power_adjustment_policy.dart';
import 'package:android_hrm_erg/src/application/session/workout_analytics.dart';
import 'package:android_hrm_erg/src/application/session/workout_session_controller.dart';
import 'package:android_hrm_erg/src/domain/models/hr_sample.dart';
import 'package:android_hrm_erg/src/domain/models/power_sample.dart';
import 'package:android_hrm_erg/src/domain/models/workout_config.dart';
import 'package:android_hrm_erg/src/domain/models/workout_phase.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_repositories.dart';

void main() {
  void connectDevices(
    FakeHrMonitorRepository hrRepo,
    FakeTrainerRepository trainerRepo,
  ) {
    hrRepo.reconnect();
    trainerRepo.reconnect();
  }

  List<HrSample> hrWindowSamples({
    required DateTime start,
    required DateTime end,
    required int bpm,
  }) {
    final samples = <HrSample>[];
    for (var t = start;
        t.isBefore(end);
        t = t.add(const Duration(minutes: 1))) {
      samples.add(HrSample(bpm: bpm, timestamp: t));
    }
    return samples;
  }

  List<PowerSample> powerWindowSamples({
    required DateTime start,
    required DateTime end,
    required int watts,
  }) {
    final samples = <PowerSample>[];
    for (var t = start;
        t.isBefore(end);
        t = t.add(const Duration(minutes: 1))) {
      samples.add(PowerSample(watts: watts, timestamp: t));
    }
    return samples;
  }

  group('WorkoutSessionController', () {
    test('HR-ERG pauses until HR is fresh, then resumes and adjusts power', () {
      fakeAsync((async) {
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = WorkoutSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
        )..initialize();

        connectDevices(hrRepo, trainerRepo);
        async.flushMicrotasks();

        controller.startWorkout(
          const HrErgConfig(
            startingWatts: 200,
            targetHr: 120,
            loopSeconds: 20,
            duration: Duration(minutes: 30),
          ),
        );
        async.flushMicrotasks();

        expect(controller.state.phase, WorkoutPhase.paused);

        hrRepo.emitHr(117);
        async.flushMicrotasks();
        expect(controller.state.phase, WorkoutPhase.active);

        async.elapse(const Duration(seconds: 4));
        hrRepo.emitHr(117);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        hrRepo.emitHr(117);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        hrRepo.emitHr(117);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        hrRepo.emitHr(117);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        hrRepo.emitHr(117);
        async.flushMicrotasks();

        expect(controller.state.currentPower, 203);
        expect(controller.state.lastAdjustmentWatts, 3);
      });
    });

    test('HR-ERG enters cooldown with summary at five minutes remaining', () {
      fakeAsync((async) {
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = WorkoutSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
        )..initialize();

        connectDevices(hrRepo, trainerRepo);
        async.flushMicrotasks();

        controller.startWorkout(
          const HrErgConfig(
            startingWatts: 150,
            targetHr: 130,
            loopSeconds: 20,
            duration: Duration(minutes: 6),
          ),
        );
        async.flushMicrotasks();

        hrRepo.emitHr(
          130,
          timestamp: DateTime.now().add(const Duration(minutes: 10)),
        );
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();

        expect(controller.state.phase, WorkoutPhase.cooldown);
        expect(controller.state.targetHr, 95);
        expect(controller.state.summary, isNotNull);
        expect(controller.state.summary!.analysisAvailable, isFalse);
      });
    });

    test('assessment transitions warm-up, steady block, cooldown, and complete', () {
      fakeAsync((async) {
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = WorkoutSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
        )..initialize();

        connectDevices(hrRepo, trainerRepo);
        async.flushMicrotasks();

        controller.startWorkout(
          const Zone2AssessmentConfig(assessmentPower: 180),
        );
        async.flushMicrotasks();

        hrRepo.emitHr(
          135,
          timestamp: DateTime.now().add(const Duration(hours: 2)),
        );
        async.flushMicrotasks();

        expect(controller.state.phase, WorkoutPhase.warmup);
        expect(trainerRepo.targetPowerWrites.first, 90);

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(controller.state.phase, WorkoutPhase.warmup);
        expect(trainerRepo.targetPowerWrites.contains(135), isTrue);

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(controller.state.phase, WorkoutPhase.active);
        expect(trainerRepo.targetPowerWrites.contains(180), isTrue);

        async.elapse(const Duration(minutes: 75));
        async.flushMicrotasks();
        expect(controller.state.phase, WorkoutPhase.cooldown);
        expect(trainerRepo.targetPowerWrites.contains(110), isTrue);

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(controller.state.phase, WorkoutPhase.completed);
      });
    });

    test('power ERG reduces power by 5 W/min above max HR and then holds', () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime(2026, 1, 1, 8));
        final hrRepo = FakeHrMonitorRepository();
        final trainerRepo = FakeTrainerRepository();
        final controller = WorkoutSessionController(
          hrMonitorRepository: hrRepo,
          trainerRepository: trainerRepo,
          nowProvider: () => clock.now(),
        )..initialize();

        connectDevices(hrRepo, trainerRepo);
        async.flushMicrotasks();

        controller.startWorkout(
          PowerErgConfig(
            targetPower: 200,
            maxHr: 150,
            activeDuration: const Duration(minutes: 30),
          ),
        );
        async.flushMicrotasks();

        hrRepo.emitHr(145, timestamp: clock.now());
        async.flushMicrotasks();

        expect(controller.state.phase, WorkoutPhase.warmup);
        expect(trainerRepo.targetPowerWrites.first, 100);

        async.elapse(const Duration(minutes: 10));
        async.flushMicrotasks();
        expect(controller.state.phase, WorkoutPhase.active);
        expect(controller.state.statusLabel, 'Power Block');
        expect(controller.state.currentPower, 200);
        hrRepo.emitHr(151, timestamp: clock.now());
        async.flushMicrotasks();

        for (var i = 0; i < 15; i++) {
          async.elapse(const Duration(seconds: 4));
          hrRepo.emitHr(151, timestamp: clock.now());
          async.flushMicrotasks();
        }

        expect(controller.state.currentPower, 195);

        hrRepo.emitHr(150, timestamp: clock.now());
        async.flushMicrotasks();
        for (var i = 0; i < 15; i++) {
          async.elapse(const Duration(seconds: 4));
          hrRepo.emitHr(150, timestamp: clock.now());
          async.flushMicrotasks();
        }

        expect(controller.state.currentPower, 195);
      });
    });
  });

  group('WorkoutAnalytics', () {
    test('maps assessment drift in 3-5% band to exact assessment power', () {
      final analytics = const WorkoutAnalytics();
      final start = DateTime(2026, 1, 1, 9);
      final hrSamples = [
        ...hrWindowSamples(
          start: start.add(const Duration(minutes: 20)),
          end: start.add(const Duration(minutes: 40)),
          bpm: 136,
        ),
        ...hrWindowSamples(
          start: start.add(const Duration(minutes: 65)),
          end: start.add(const Duration(minutes: 85)),
          bpm: 141,
        ),
      ];
      final powerSamples = [
        ...powerWindowSamples(
          start: start.add(const Duration(minutes: 20)),
          end: start.add(const Duration(minutes: 40)),
          watts: 188,
        ),
        ...powerWindowSamples(
          start: start.add(const Duration(minutes: 65)),
          end: start.add(const Duration(minutes: 85)),
          watts: 188,
        ),
      ];

      final summary = analytics.summarizeAssessment(
        config: const Zone2AssessmentConfig(assessmentPower: 188),
        hrSamples: hrSamples,
        powerSamples: powerSamples,
        rideStart: start,
        completed: true,
        hadPauseOrDisconnect: false,
      );

      expect(summary.analysisAvailable, isTrue);
      expect(summary.zone2Estimate, isNotNull);
      expect(summary.zone2Estimate!.lowerWatts, 188);
      expect(summary.zone2Estimate!.upperWatts, 188);
      expect(summary.zone2Estimate!.confidence, 'Good');
    });

    test('maps assessment drift above 5% to lower suggested range', () {
      final analytics = const WorkoutAnalytics();
      final start = DateTime(2026, 1, 1, 9);
      final hrSamples = [
        ...hrWindowSamples(
          start: start.add(const Duration(minutes: 20)),
          end: start.add(const Duration(minutes: 40)),
          bpm: 136,
        ),
        ...hrWindowSamples(
          start: start.add(const Duration(minutes: 65)),
          end: start.add(const Duration(minutes: 85)),
          bpm: 146,
        ),
      ];
      final powerSamples = [
        ...powerWindowSamples(
          start: start.add(const Duration(minutes: 20)),
          end: start.add(const Duration(minutes: 40)),
          watts: 190,
        ),
        ...powerWindowSamples(
          start: start.add(const Duration(minutes: 65)),
          end: start.add(const Duration(minutes: 85)),
          watts: 190,
        ),
      ];

      final summary = analytics.summarizeAssessment(
        config: const Zone2AssessmentConfig(assessmentPower: 190),
        hrSamples: hrSamples,
        powerSamples: powerSamples,
        rideStart: start,
        completed: true,
        hadPauseOrDisconnect: true,
      );

      expect(summary.zone2Estimate, isNotNull);
      expect(summary.zone2Estimate!.lowerWatts, 180);
      expect(summary.zone2Estimate!.upperWatts, 185);
      expect(summary.zone2Estimate!.confidence, 'Limited');
    });

    test('short HR-ERG rides do not produce durability classification', () {
      final analytics = const WorkoutAnalytics();
      final start = DateTime(2026, 1, 1, 9);

      final summary = analytics.summarizeHrErg(
        hrSamples: hrWindowSamples(
          start: start,
          end: start.add(const Duration(minutes: 20)),
          bpm: 130,
        ),
        powerSamples: powerWindowSamples(
          start: start,
          end: start.add(const Duration(minutes: 20)),
          watts: 180,
        ),
        rideStart: start,
        analysisEnd: start.add(const Duration(minutes: 30)),
      );

      expect(summary.analysisAvailable, isFalse);
    });
  });

  group('PowerAdjustmentPolicy', () {
    test('converts +10 W/min band into 20-second loop adjustments', () {
      final policy = const PowerAdjustmentPolicy();
      final first = policy.adjustmentForLoop(
        delta: -3,
        loopSeconds: 20,
        carryNumerator: 0,
      );
      final second = policy.adjustmentForLoop(
        delta: -3,
        loopSeconds: 20,
        carryNumerator: first.nextCarryNumerator,
      );

      expect(first.watts, 3);
      expect(second.watts, 3);
    });
  });
}
