import 'package:equatable/equatable.dart';

class PowerSample extends Equatable {
  const PowerSample({required this.watts, required this.timestamp});

  final int watts;
  final DateTime timestamp;

  @override
  List<Object> get props => [watts, timestamp];
}
