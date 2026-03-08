import 'package:equatable/equatable.dart';

class PowerCommand extends Equatable {
  const PowerCommand({
    required this.watts,
    required this.timestamp,
    required this.reason,
  });

  final int watts;
  final DateTime timestamp;
  final String reason;

  @override
  List<Object> get props => [watts, timestamp, reason];
}
