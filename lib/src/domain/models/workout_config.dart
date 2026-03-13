import 'package:equatable/equatable.dart';

import 'workout_type.dart';

abstract class WorkoutConfig extends Equatable {
  const WorkoutConfig({
    required this.workoutType,
    required this.duration,
  });

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
    this.hrAverageWindow = const Duration(seconds: 60),
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

class Zone2AssessmentConfig extends WorkoutConfig {
  const Zone2AssessmentConfig({
    required this.assessmentPower,
  }) : super(
         workoutType: WorkoutType.zone2Assessment,
         duration: const Duration(minutes: 90),
       );

  final int assessmentPower;

  int get warmupPower => _roundToNearestFive(assessmentPower * 0.8);
  int get steadyPower => _roundToNearestFive(assessmentPower.toDouble());
  int get cooldownPower => _roundToNearestFive(assessmentPower * 0.6);

  @override
  List<Object> get props => [workoutType, duration, assessmentPower];
}

int _roundToNearestFive(double watts) {
  final rounded = ((watts / 5).round()) * 5;
  return rounded < 50 ? 50 : rounded;
}
