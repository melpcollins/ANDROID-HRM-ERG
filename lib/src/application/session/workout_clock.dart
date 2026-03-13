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
    if (elapsed >=
        Zone2AssessmentConfig.warmupDuration +
            Zone2AssessmentConfig.steadyDuration) {
      return WorkoutPhase.cooldown;
    }
    if (elapsed >= Zone2AssessmentConfig.warmupDuration) {
      return WorkoutPhase.active;
    }
    return WorkoutPhase.warmup;
  }

  WorkoutPhase powerErgPhase({
    required PowerErgConfig config,
    required Duration elapsed,
  }) {
    if (elapsed >= config.duration) {
      return WorkoutPhase.completed;
    }
    if (elapsed >= PowerErgConfig.warmupDuration + config.activeDuration) {
      return WorkoutPhase.cooldown;
    }
    if (elapsed >= PowerErgConfig.warmupDuration) {
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
        return 'Warm-up';
      case WorkoutPhase.active:
        if (type == WorkoutType.zone2Assessment) {
          return 'Assessment';
        }
        if (type == WorkoutType.powerErg) {
          return 'Power Block';
        }
        return 'Active';
      case WorkoutPhase.cooldown:
        return 'Cooldown';
      case WorkoutPhase.paused:
        return 'Paused';
      case WorkoutPhase.completed:
        return 'Completed';
    }
  }
}
