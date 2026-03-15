import 'package:equatable/equatable.dart';

import 'workout_type.dart';

class SessionContext extends Equatable {
  const SessionContext({
    required this.sessionId,
    required this.workoutType,
    required this.startedAt,
    this.details = const <String, Object?>{},
  });

  final String sessionId;
  final WorkoutType workoutType;
  final DateTime startedAt;
  final Map<String, Object?> details;

  Map<String, Object?> toTelemetryProperties() {
    return <String, Object?>{
      'session_id': sessionId,
      'workout_type': workoutType.name,
    };
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'session_id': sessionId,
      'workout_type': workoutType.name,
      'started_at': startedAt.toUtc().toIso8601String(),
      'details': details,
    };
  }

  factory SessionContext.fromJson(Map<String, Object?> json) {
    final workoutTypeName =
        json['workout_type'] as String? ?? WorkoutType.hrErg.name;
    final workoutType = WorkoutType.values.firstWhere(
      (value) => value.name == workoutTypeName,
      orElse: () => WorkoutType.hrErg,
    );
    return SessionContext(
      sessionId: json['session_id'] as String? ?? '',
      workoutType: workoutType,
      startedAt: DateTime.parse(
        json['started_at'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
      ),
      details: Map<String, Object?>.from(
        (json['details'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }

  @override
  List<Object?> get props => [sessionId, workoutType, startedAt, details];
}
