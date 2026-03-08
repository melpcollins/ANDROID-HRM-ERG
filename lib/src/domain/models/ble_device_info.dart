import 'package:equatable/equatable.dart';

class BleDeviceInfo extends Equatable {
  const BleDeviceInfo({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object> get props => [id, name];
}
