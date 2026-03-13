import '../../domain/models/workout_config.dart';
import '../../domain/models/workout_phase.dart';
import '../../domain/models/workout_type.dart';

class WorkoutClock {
  const WorkoutClock();

  Duration elapsed({
    required Duration totalDuration,
    required Duration remainingDuration,
  }) {
    return totalDuration - remainingDuration;
  }

  WorkoutPhase assessmentPhase({
    required Zone2AssessmentConfig config,
    required Duration elapsed,
  }) {
    if (elapsed >= config.duration) {
      return WorkoutPhase.completed;
    }
    if (elapsed >= const Duration(minutes: 85)) {
      return WorkoutPhase.cooldown;
    }
    if (elapsed >= const Duration(minutes: 10)) {
      return WorkoutPhase.active;
    }
    return WorkoutPhase.warmup;
  }

  bool shouldEnterHrErgCooldown(Duration remaining) {
    return remaining <= const Duration(minutes: 5);
  }

  String labelForPhase(WorkoutType type, WorkoutPhase phase) {
    switch (phase) {
      case WorkoutPhase.idle:
        return 'Idle';
      case WorkoutPhase.warmup:
        return type == WorkoutType.zone2Assessment ? 'Warm-up' : 'Warm-up';
      case WorkoutPhase.active:
        return type == WorkoutType.zone2Assessment ? 'Assessment' : 'Active';
      case WorkoutPhase.cooldown:
        return 'Cooldown';
      case WorkoutPhase.paused:
        return 'Paused';
      case WorkoutPhase.completed:
        return 'Completed';
    }
  }
}
