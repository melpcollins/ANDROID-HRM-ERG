import 'package:equatable/equatable.dart';

class TrainerTelemetry extends Equatable {
  const TrainerTelemetry({
    required this.powerWatts,
    required this.timestamp,
    this.cadenceRpm,
  });

  final int powerWatts;
  final int? cadenceRpm;
  final DateTime timestamp;

  @override
  List<Object?> get props => [powerWatts, cadenceRpm, timestamp];
}
