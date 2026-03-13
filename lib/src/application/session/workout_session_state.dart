import 'package:equatable/equatable.dart';

import '../../domain/models/pause_reason.dart';
import '../../domain/models/workout_config.dart';
import '../../domain/models/workout_phase.dart';
import '../../domain/models/workout_summary.dart';
import '../../domain/models/workout_type.dart';

class WorkoutSessionState extends Equatable {
  const WorkoutSessionState({
    this.selectedWorkoutType = WorkoutType.hrErg,
    this.activeConfig,
    this.phase = WorkoutPhase.idle,
    this.pauseReason,
    this.phaseBeforePause,
    this.hrConnected = false,
    this.trainerConnected = false,
    this.currentHr,
    this.averageHr,
    this.currentPower,
    this.targetHr,
    this.lastAdjustmentWatts,
    this.totalDuration,
    this.remainingDuration,
    this.statusLabel = 'Idle',
    this.provisionalSummary,
    this.summary,
    this.error,
  });

  final WorkoutType selectedWorkoutType;
  final WorkoutConfig? activeConfig;
  final WorkoutPhase phase;
  final PauseReason? pauseReason;
  final WorkoutPhase? phaseBeforePause;
  final bool hrConnected;
  final bool trainerConnected;
  final int? currentHr;
  final double? averageHr;
  final int? currentPower;
  final int? targetHr;
  final int? lastAdjustmentWatts;
  final Duration? totalDuration;
  final Duration? remainingDuration;
  final String statusLabel;
  final WorkoutSummary? provisionalSummary;
  final WorkoutSummary? summary;
  final String? error;

  bool get isRunning =>
      phase != WorkoutPhase.idle && phase != WorkoutPhase.completed;
  bool get isPaused => phase == WorkoutPhase.paused;
  bool get isCompleted => phase == WorkoutPhase.completed;

  WorkoutSessionState copyWith({
    WorkoutType? selectedWorkoutType,
    WorkoutConfig? activeConfig,
    WorkoutPhase? phase,
    PauseReason? pauseReason,
    WorkoutPhase? phaseBeforePause,
    bool? hrConnected,
    bool? trainerConnected,
    int? currentHr,
    double? averageHr,
    int? currentPower,
    int? targetHr,
    int? lastAdjustmentWatts,
    Duration? totalDuration,
    Duration? remainingDuration,
    String? statusLabel,
    WorkoutSummary? provisionalSummary,
    WorkoutSummary? summary,
    String? error,
    bool clearProvisionalSummary = false,
    bool clearSummary = false,
    bool clearError = false,
    bool clearPauseReason = false,
    bool clearPhaseBeforePause = false,
  }) {
    return WorkoutSessionState(
      selectedWorkoutType: selectedWorkoutType ?? this.selectedWorkoutType,
      activeConfig: activeConfig ?? this.activeConfig,
      phase: phase ?? this.phase,
      pauseReason: clearPauseReason ? null : (pauseReason ?? this.pauseReason),
      phaseBeforePause: clearPhaseBeforePause
          ? null
          : (phaseBeforePause ?? this.phaseBeforePause),
      hrConnected: hrConnected ?? this.hrConnected,
      trainerConnected: trainerConnected ?? this.trainerConnected,
      currentHr: currentHr ?? this.currentHr,
      averageHr: averageHr ?? this.averageHr,
      currentPower: currentPower ?? this.currentPower,
      targetHr: targetHr ?? this.targetHr,
      lastAdjustmentWatts: lastAdjustmentWatts ?? this.lastAdjustmentWatts,
      totalDuration: totalDuration ?? this.totalDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      statusLabel: statusLabel ?? this.statusLabel,
      provisionalSummary: clearProvisionalSummary
          ? null
          : (provisionalSummary ?? this.provisionalSummary),
      summary: clearSummary ? null : (summary ?? this.summary),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    selectedWorkoutType,
    activeConfig,
    phase,
    pauseReason,
    phaseBeforePause,
    hrConnected,
    trainerConnected,
    currentHr,
    averageHr,
    currentPower,
    targetHr,
    lastAdjustmentWatts,
    totalDuration,
    remainingDuration,
    statusLabel,
    provisionalSummary,
    summary,
    error,
  ];
}
