import 'package:equatable/equatable.dart';

class ErgSessionState extends Equatable {
  const ErgSessionState({
    this.isRunning = false,
    this.startingWatts,
    this.targetHr,
    this.currentPower,
    this.currentHr,
    this.averagePower,
    this.averageHr,
    this.lastAdjustmentWatts,
    this.error,
  });

  final bool isRunning;
  final int? startingWatts;
  final int? targetHr;
  final int? currentPower;
  final int? currentHr;
  final double? averagePower;
  final double? averageHr;
  final int? lastAdjustmentWatts;
  final String? error;

  ErgSessionState copyWith({
    bool? isRunning,
    int? startingWatts,
    int? targetHr,
    int? currentPower,
    int? currentHr,
    double? averagePower,
    double? averageHr,
    int? lastAdjustmentWatts,
    String? error,
    bool clearError = false,
  }) {
    return ErgSessionState(
      isRunning: isRunning ?? this.isRunning,
      startingWatts: startingWatts ?? this.startingWatts,
      targetHr: targetHr ?? this.targetHr,
      currentPower: currentPower ?? this.currentPower,
      currentHr: currentHr ?? this.currentHr,
      averagePower: averagePower ?? this.averagePower,
      averageHr: averageHr ?? this.averageHr,
      lastAdjustmentWatts: lastAdjustmentWatts ?? this.lastAdjustmentWatts,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    isRunning,
    startingWatts,
    targetHr,
    currentPower,
    currentHr,
    averagePower,
    averageHr,
    lastAdjustmentWatts,
    error,
  ];
}
