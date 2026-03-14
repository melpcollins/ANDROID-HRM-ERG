import 'package:equatable/equatable.dart';

import '../../domain/models/connection_status.dart';
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
    this.hrStatus = ConnectionStatus.disconnected,
    this.trainerStatus = ConnectionStatus.disconnected,
    this.currentHr,
    this.averageHr,
    this.currentPower,
    this.displayPower,
    this.currentCadence,
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
  final ConnectionStatus hrStatus;
  final ConnectionStatus trainerStatus;
  final int? currentHr;
  final double? averageHr;
  final int? currentPower;
  final int? displayPower;
  final int? currentCadence;
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
  bool get hrConnected =>
      hrStatus == ConnectionStatus.connected ||
      hrStatus == ConnectionStatus.connectedNoData;
  bool get trainerConnected =>
      trainerStatus == ConnectionStatus.connected ||
      trainerStatus == ConnectionStatus.connectedNoData;
  bool get hrFresh => hrStatus == ConnectionStatus.connected;
  bool get trainerFresh => trainerStatus == ConnectionStatus.connected;

  WorkoutSessionState copyWith({
    WorkoutType? selectedWorkoutType,
    WorkoutConfig? activeConfig,
    WorkoutPhase? phase,
    PauseReason? pauseReason,
    WorkoutPhase? phaseBeforePause,
    ConnectionStatus? hrStatus,
    ConnectionStatus? trainerStatus,
    int? currentHr,
    double? averageHr,
    int? currentPower,
    int? displayPower,
    int? currentCadence,
    int? targetHr,
    int? lastAdjustmentWatts,
    Duration? totalDuration,
    Duration? remainingDuration,
    String? statusLabel,
    WorkoutSummary? provisionalSummary,
    WorkoutSummary? summary,
    String? error,
    bool clearCurrentCadence = false,
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
      hrStatus: hrStatus ?? this.hrStatus,
      trainerStatus: trainerStatus ?? this.trainerStatus,
      currentHr: currentHr ?? this.currentHr,
      averageHr: averageHr ?? this.averageHr,
      currentPower: currentPower ?? this.currentPower,
      displayPower: displayPower ?? this.displayPower,
      currentCadence: clearCurrentCadence
          ? null
          : (currentCadence ?? this.currentCadence),
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
    hrStatus,
    trainerStatus,
    currentHr,
    averageHr,
    currentPower,
    displayPower,
    currentCadence,
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
