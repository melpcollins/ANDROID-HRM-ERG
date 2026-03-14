import 'package:equatable/equatable.dart';

import '../../domain/models/ble_device_info.dart';
import '../../domain/models/connection_status.dart';

class ConnectSetupState extends Equatable {
  const ConnectSetupState({
    this.hrStatus = ConnectionStatus.disconnected,
    this.trainerStatus = ConnectionStatus.disconnected,
    this.hrDevices = const <BleDeviceInfo>[],
    this.trainerDevices = const <BleDeviceInfo>[],
    this.selectedHrId,
    this.selectedTrainerId,
    this.selectedHrName,
    this.selectedTrainerName,
    this.hrError,
    this.trainerError,
    this.scanningHr = false,
    this.scanningTrainer = false,
    this.permissionsGranted = false,
    this.bluetoothEnabled = false,
    this.permissionPermanentlyDenied = false,
    this.readinessChecked = false,
  });

  final ConnectionStatus hrStatus;
  final ConnectionStatus trainerStatus;
  final List<BleDeviceInfo> hrDevices;
  final List<BleDeviceInfo> trainerDevices;
  final String? selectedHrId;
  final String? selectedTrainerId;
  final String? selectedHrName;
  final String? selectedTrainerName;
  final String? hrError;
  final String? trainerError;
  final bool scanningHr;
  final bool scanningTrainer;
  final bool permissionsGranted;
  final bool bluetoothEnabled;
  final bool permissionPermanentlyDenied;
  final bool readinessChecked;

  ConnectSetupState copyWith({
    ConnectionStatus? hrStatus,
    ConnectionStatus? trainerStatus,
    List<BleDeviceInfo>? hrDevices,
    List<BleDeviceInfo>? trainerDevices,
    String? selectedHrId,
    String? selectedTrainerId,
    String? selectedHrName,
    String? selectedTrainerName,
    String? hrError,
    String? trainerError,
    bool? scanningHr,
    bool? scanningTrainer,
    bool? permissionsGranted,
    bool? bluetoothEnabled,
    bool? permissionPermanentlyDenied,
    bool? readinessChecked,
    bool clearHrError = false,
    bool clearTrainerError = false,
  }) {
    return ConnectSetupState(
      hrStatus: hrStatus ?? this.hrStatus,
      trainerStatus: trainerStatus ?? this.trainerStatus,
      hrDevices: hrDevices ?? this.hrDevices,
      trainerDevices: trainerDevices ?? this.trainerDevices,
      selectedHrId: selectedHrId ?? this.selectedHrId,
      selectedTrainerId: selectedTrainerId ?? this.selectedTrainerId,
      selectedHrName: selectedHrName ?? this.selectedHrName,
      selectedTrainerName: selectedTrainerName ?? this.selectedTrainerName,
      hrError: clearHrError ? null : (hrError ?? this.hrError),
      trainerError: clearTrainerError
          ? null
          : (trainerError ?? this.trainerError),
      scanningHr: scanningHr ?? this.scanningHr,
      scanningTrainer: scanningTrainer ?? this.scanningTrainer,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
      permissionPermanentlyDenied:
          permissionPermanentlyDenied ?? this.permissionPermanentlyDenied,
      readinessChecked: readinessChecked ?? this.readinessChecked,
    );
  }

  @override
  List<Object?> get props => [
    hrStatus,
    trainerStatus,
    hrDevices,
    trainerDevices,
    selectedHrId,
    selectedTrainerId,
    selectedHrName,
    selectedTrainerName,
    hrError,
    trainerError,
    scanningHr,
    scanningTrainer,
    permissionsGranted,
    bluetoothEnabled,
    permissionPermanentlyDenied,
    readinessChecked,
  ];
}
