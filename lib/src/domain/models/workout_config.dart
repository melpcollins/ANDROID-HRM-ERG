import 'package:equatable/equatable.dart';

import 'workout_type.dart';

abstract class WorkoutConfig extends Equatable {
  const WorkoutConfig({required this.workoutType, required this.duration});

  final WorkoutType workoutType;
  final Duration duration;
}

class HrErgConfig extends WorkoutConfig {
  const HrErgConfig({
    required this.startingWatts,
    required this.targetHr,
    required this.loopSeconds,
    required super.duration,
    this.minPower = 50,
    this.maxPower = 500,
    this.hrAverageWindow = const Duration(seconds: 10),
  }) : super(workoutType: WorkoutType.hrErg);

  final int startingWatts;
  final int targetHr;
  final int loopSeconds;
  final int minPower;
  final int maxPower;
  final Duration hrAverageWindow;

  @override
  List<Object> get props => [
    workoutType,
    duration,
    startingWatts,
    targetHr,
    loopSeconds,
    minPower,
    maxPower,
    hrAverageWindow,
  ];
}

class PowerErgConfig extends WorkoutConfig {
  // ignore: prefer_const_constructors_in_immutables
  PowerErgConfig({
    required this.targetPower,
    required this.maxHr,
    required this.activeDuration,
    this.loopSeconds = 5,
    this.hrAverageWindow = const Duration(seconds: 10),
    this.minPower = 50,
  }) : super(
         workoutType: WorkoutType.powerErg,
         duration: activeDuration + warmupDuration + cooldownDuration,
       );

  final int targetPower;
  final int maxHr;
  final Duration activeDuration;
  final int loopSeconds;
  final Duration hrAverageWindow;
  final int minPower;

  static const Duration warmupDuration = Duration(minutes: 10);
  static const Duration cooldownDuration = Duration(minutes: 5);

  int get warmupStartPower => _roundToNearestFive(targetPower * 0.5);
  int get steadyPower => _roundToNearestFive(targetPower.toDouble());
  int get cooldownPower => _roundToNearestFive(targetPower * 0.6);

  int warmupPowerAt(Duration elapsed) {
    if (elapsed <= Duration.zero) {
      return warmupStartPower;
    }
    if (elapsed >= warmupDuration) {
      return steadyPower;
    }

    final progress = elapsed.inMilliseconds / warmupDuration.inMilliseconds;
    final watts =
        warmupStartPower + ((steadyPower - warmupStartPower) * progress);
    return _roundToNearestFive(watts);
  }

  @override
  List<Object> get props => [
    workoutType,
    duration,
    targetPower,
    maxHr,
    activeDuration,
    loopSeconds,
    hrAverageWindow,
    minPower,
  ];
}

class Zone2AssessmentConfig extends WorkoutConfig {
  const Zone2AssessmentConfig({required this.assessmentPower})
    : super(
        workoutType: WorkoutType.zone2Assessment,
        duration: const Duration(minutes: 90),
      );

  final int assessmentPower;

  static const Duration warmupDuration = Duration(minutes: 10);
  static const Duration steadyDuration = Duration(minutes: 75);
  static const Duration cooldownDuration = Duration(minutes: 5);

  int get warmupStartPower => _roundToNearestFive(assessmentPower * 0.5);
  int get steadyPower => _roundToNearestFive(assessmentPower.toDouble());
  int get cooldownPower => _roundToNearestFive(assessmentPower * 0.6);

  int warmupPowerAt(Duration elapsed) {
    if (elapsed <= Duration.zero) {
      return warmupStartPower;
    }
    if (elapsed >= warmupDuration) {
      return steadyPower;
    }

    final progress = elapsed.inMilliseconds / warmupDuration.inMilliseconds;
    final watts =
        warmupStartPower + ((steadyPower - warmupStartPower) * progress);
    return _roundToNearestFive(watts);
  }

  @override
  List<Object> get props => [workoutType, duration, assessmentPower];
}

int _roundToNearestFive(double watts) {
  final rounded = ((watts / 5).round()) * 5;
  return rounded < 50 ? 50 : rounded;
}
