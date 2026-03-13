import 'package:equatable/equatable.dart';

import 'zone2_estimate.dart';

class WorkoutSummary extends Equatable {
  const WorkoutSummary({
    required this.analysisAvailable,
    this.powerFadePercent,
    this.aerobicDriftPercent,
    this.interpretation,
    this.analysisMessage,
    this.zone2Estimate,
    this.provisional = false,
  });

  final bool analysisAvailable;
  final double? powerFadePercent;
  final double? aerobicDriftPercent;
  final String? interpretation;
  final String? analysisMessage;
  final Zone2Estimate? zone2Estimate;
  final bool provisional;

  @override
  List<Object?> get props => [
    analysisAvailable,
    powerFadePercent,
    aerobicDriftPercent,
    interpretation,
    analysisMessage,
    zone2Estimate,
    provisional,
  ];
}
