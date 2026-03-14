import 'package:equatable/equatable.dart';

class BleReadiness extends Equatable {
  const BleReadiness({
    required this.permissionsGranted,
    required this.bluetoothEnabled,
    this.permissionPermanentlyDenied = false,
  });

  final bool permissionsGranted;
  final bool bluetoothEnabled;
  final bool permissionPermanentlyDenied;

  bool get isReady => permissionsGranted && bluetoothEnabled;

  @override
  List<Object?> get props => [
    permissionsGranted,
    bluetoothEnabled,
    permissionPermanentlyDenied,
  ];
}
