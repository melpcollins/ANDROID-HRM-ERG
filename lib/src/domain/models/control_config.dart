import 'package:equatable/equatable.dart';

class ControlConfig extends Equatable {
  const ControlConfig({
    required this.targetHr,
    this.minPower = 50,
    this.maxPower = 500,
    this.loopSeconds = 20,
    this.avgWindowSeconds = 60,
  }) : assert(minPower < maxPower),
       assert(loopSeconds > 0),
       assert(avgWindowSeconds > 0);

  final int targetHr;
  final int minPower;
  final int maxPower;
  final int loopSeconds;
  final int avgWindowSeconds;

  @override
  List<Object> get props => [
    targetHr,
    minPower,
    maxPower,
    loopSeconds,
    avgWindowSeconds,
  ];
}
