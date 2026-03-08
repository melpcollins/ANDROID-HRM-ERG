import 'package:equatable/equatable.dart';

class HrSample extends Equatable {
  const HrSample({required this.bpm, required this.timestamp});

  final int bpm;
  final DateTime timestamp;

  @override
  List<Object> get props => [bpm, timestamp];
}
