import 'package:equatable/equatable.dart';

class ErgSessionState extends Equatable {
  const ErgSessionState({
    this.isRunning = false,
    this.startingWatts,
    this.targetHr,
    this.loopSeconds,
    this.sessionDuration,
    this.remainingDuration,
    this.isCooldown = false,
    this.currentPower,
    this.currentHr,
    this.averagePower,
    this.averageHr,
    this.driftWatts,
    this.driftPercent,
    this.maxRollingPower,
    this.endingRollingPower,
    this.endSessionSummary,
    this.endSessionZone2Warning = false,
    this.lastAdjustmentWatts,
    this.error,
  });

  final bool isRunning;
  final int? startingWatts;
  final int? targetHr;
  final int? loopSeconds;
  final Duration? sessionDuration;
  final Duration? remainingDuration;
  final bool isCooldown;
  final int? currentPower;
  final int? currentHr;
  final double? averagePower;
  final double? averageHr;
  final double? driftWatts;
  final double? driftPercent;
  final double? maxRollingPower;
  final double? endingRollingPower;
  final String? endSessionSummary;
  final bool endSessionZone2Warning;
  final int? lastAdjustmentWatts;
  final String? error;

  ErgSessionState copyWith({
    bool? isRunning,
    int? startingWatts,
    int? targetHr,
    int? loopSeconds,
    Duration? sessionDuration,
    Duration? remainingDuration,
    bool? isCooldown,
    int? currentPower,
    int? currentHr,
    double? averagePower,
    double? averageHr,
    double? driftWatts,
    double? driftPercent,
    double? maxRollingPower,
    double? endingRollingPower,
    String? endSessionSummary,
    bool? endSessionZone2Warning,
    int? lastAdjustmentWatts,
    String? error,
    bool clearError = false,
    bool clearEndSessionSummary = false,
  }) {
    return ErgSessionState(
      isRunning: isRunning ?? this.isRunning,
      startingWatts: startingWatts ?? this.startingWatts,
      targetHr: targetHr ?? this.targetHr,
      loopSeconds: loopSeconds ?? this.loopSeconds,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      isCooldown: isCooldown ?? this.isCooldown,
      currentPower: currentPower ?? this.currentPower,
      currentHr: currentHr ?? this.currentHr,
      averagePower: averagePower ?? this.averagePower,
      averageHr: averageHr ?? this.averageHr,
      driftWatts: driftWatts ?? this.driftWatts,
      driftPercent: driftPercent ?? this.driftPercent,
      maxRollingPower: maxRollingPower ?? this.maxRollingPower,
      endingRollingPower: endingRollingPower ?? this.endingRollingPower,
      endSessionSummary: clearEndSessionSummary
          ? null
          : (endSessionSummary ?? this.endSessionSummary),
      endSessionZone2Warning:
          endSessionZone2Warning ?? this.endSessionZone2Warning,
      lastAdjustmentWatts: lastAdjustmentWatts ?? this.lastAdjustmentWatts,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    isRunning,
    startingWatts,
    targetHr,
    loopSeconds,
    sessionDuration,
    remainingDuration,
    isCooldown,
    currentPower,
    currentHr,
    averagePower,
    averageHr,
    driftWatts,
    driftPercent,
    maxRollingPower,
    endingRollingPower,
    endSessionSummary,
    endSessionZone2Warning,
    lastAdjustmentWatts,
    error,
  ];
}
