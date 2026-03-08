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
    this.hrError,
    this.trainerError,
    this.scanningHr = false,
    this.scanningTrainer = false,
  });

  final ConnectionStatus hrStatus;
  final ConnectionStatus trainerStatus;
  final List<BleDeviceInfo> hrDevices;
  final List<BleDeviceInfo> trainerDevices;
  final String? selectedHrId;
  final String? selectedTrainerId;
  final String? hrError;
  final String? trainerError;
  final bool scanningHr;
  final bool scanningTrainer;

  ConnectSetupState copyWith({
    ConnectionStatus? hrStatus,
    ConnectionStatus? trainerStatus,
    List<BleDeviceInfo>? hrDevices,
    List<BleDeviceInfo>? trainerDevices,
    String? selectedHrId,
    String? selectedTrainerId,
    String? hrError,
    String? trainerError,
    bool? scanningHr,
    bool? scanningTrainer,
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
      hrError: clearHrError ? null : (hrError ?? this.hrError),
      trainerError: clearTrainerError
          ? null
          : (trainerError ?? this.trainerError),
      scanningHr: scanningHr ?? this.scanningHr,
      scanningTrainer: scanningTrainer ?? this.scanningTrainer,
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
    hrError,
    trainerError,
    scanningHr,
    scanningTrainer,
  ];
}
