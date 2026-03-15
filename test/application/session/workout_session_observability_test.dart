import 'package:android_hrm_erg/src/application/session/workout_session_controller.dart';
import 'package:android_hrm_erg/src/domain/models/workout_config.dart';
import 'package:android_hrm_erg/src/infrastructure/diagnostics/diagnostics_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_telemetry.dart';
import '../../support/fake_repositories.dart';

void main() {
  test(
    'workout telemetry stays anonymous while diagnostics keep config detail',
    () async {
      final telemetry = FakeAppTelemetry();
      final diagnosticsStore = DiagnosticsStore.inMemory();
      final hrRepo = FakeHrMonitorRepository();
      final trainerRepo = FakeTrainerRepository();
      final controller = WorkoutSessionController(
        hrMonitorRepository: hrRepo,
        trainerRepository: trainerRepo,
        telemetry: telemetry,
        diagnosticsStore: diagnosticsStore,
      )..initialize();
      addTearDown(controller.dispose);

      await hrRepo.reconnect();
      await trainerRepo.reconnect();
      hrRepo.emitHr(120);

      await controller.startWorkout(
        const HrErgConfig(
          startingWatts: 170,
          targetHr: 122,
          loopSeconds: 20,
          duration: Duration(minutes: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final telemetryEvent = telemetry.trackedEvents.firstWhere(
        (event) => event.name == 'workout_started',
      );
      final runtimeEvents = await diagnosticsStore.recentRuntimeEvents(
        limit: 20,
      );
      final runtimeEvent = runtimeEvents.firstWhere(
        (event) => event['name'] == 'workout_started',
      );
      final runtimeData = runtimeEvent['data'] as Map<String, Object?>;

      expect(telemetry.currentSessionContext, isNotNull);
      expect(telemetryEvent.properties['workout_type'], 'hrErg');
      expect(telemetryEvent.properties.containsKey('starting_watts'), isFalse);
      expect(runtimeData['starting_watts'], 170);
      expect(runtimeData['target_hr'], 122);
    },
  );
}
