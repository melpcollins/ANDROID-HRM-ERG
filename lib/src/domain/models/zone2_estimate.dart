import 'package:equatable/equatable.dart';

class Zone2Estimate extends Equatable {
  const Zone2Estimate({
    required this.lowerWatts,
    required this.upperWatts,
    required this.confidence,
    required this.interpretation,
  });

  final int lowerWatts;
  final int upperWatts;
  final String confidence;
  final String interpretation;

  bool get isRange => lowerWatts != upperWatts;

  @override
  List<Object> get props => [
    lowerWatts,
    upperWatts,
    confidence,
    interpretation,
  ];
}
