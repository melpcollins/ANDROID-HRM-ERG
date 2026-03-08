import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/hr_monitor_repository.dart';
import '../../domain/repositories/trainer_repository.dart';
import 'connect_setup_state.dart';

class ConnectSetupController extends StateNotifier<ConnectSetupState> {
  ConnectSetupController({
    required HrMonitorRepository hrMonitorRepository,
    required TrainerRepository trainerRepository,
  }) : _hrMonitorRepository = hrMonitorRepository,
       _trainerRepository = trainerRepository,
       super(const ConnectSetupState());

  final HrMonitorRepository _hrMonitorRepository;
  final TrainerRepository _trainerRepository;

  StreamSubscription? _hrStatusSubscription;
  StreamSubscription? _trainerStatusSubscription;

  Future<void> initialize() async {
    _hrStatusSubscription ??= _hrMonitorRepository.connectionStatus.listen((
      status,
    ) {
      state = state.copyWith(hrStatus: status);
    });

    _trainerStatusSubscription ??= _trainerRepository.connectionStatus.listen((
      status,
    ) {
      state = state.copyWith(trainerStatus: status);
    });

    final hrId = await _hrMonitorRepository.getSavedDeviceId();
    final trainerId = await _trainerRepository.getSavedDeviceId();

    state = state.copyWith(selectedHrId: hrId, selectedTrainerId: trainerId);

    await Future.wait<void>([
      _attemptReconnect(
        reconnect: reconnectHrMonitor,
        hasSavedDevice: hrId != null && hrId.isNotEmpty,
      ),
      _attemptReconnect(
        reconnect: reconnectTrainer,
        hasSavedDevice: trainerId != null && trainerId.isNotEmpty,
      ),
    ]);
  }

  Future<void> scanHrMonitors() async {
    state = state.copyWith(scanningHr: true, clearHrError: true);

    try {
      final devices = await _hrMonitorRepository.scanForDevices();
      state = state.copyWith(hrDevices: devices, scanningHr: false);
    } catch (error) {
      state = state.copyWith(scanningHr: false, hrError: error.toString());
    }
  }

  Future<void> scanTrainers() async {
    state = state.copyWith(scanningTrainer: true, clearTrainerError: true);

    try {
      final devices = await _trainerRepository.scanForDevices();
      state = state.copyWith(trainerDevices: devices, scanningTrainer: false);
    } catch (error) {
      state = state.copyWith(
        scanningTrainer: false,
        trainerError: error.toString(),
      );
    }
  }

  Future<void> connectHrMonitor(String deviceId) async {
    state = state.copyWith(clearHrError: true);
    try {
      await _hrMonitorRepository.connect(deviceId);
      state = state.copyWith(selectedHrId: deviceId);
    } catch (error) {
      state = state.copyWith(hrError: error.toString());
    }
  }

  Future<void> connectTrainer(String deviceId) async {
    state = state.copyWith(clearTrainerError: true);
    try {
      await _trainerRepository.connect(deviceId);
      state = state.copyWith(selectedTrainerId: deviceId);
    } catch (error) {
      state = state.copyWith(trainerError: error.toString());
    }
  }

  Future<void> reconnectHrMonitor() async {
    state = state.copyWith(clearHrError: true);
    try {
      await _hrMonitorRepository.reconnect();
    } catch (error) {
      state = state.copyWith(hrError: error.toString());
      rethrow;
    }
  }

  Future<void> reconnectTrainer() async {
    state = state.copyWith(clearTrainerError: true);
    try {
      await _trainerRepository.reconnect();
    } catch (error) {
      state = state.copyWith(trainerError: error.toString());
      rethrow;
    }
  }

  Future<void> _attemptReconnect({
    required Future<void> Function() reconnect,
    required bool hasSavedDevice,
  }) async {
    if (!hasSavedDevice) {
      return;
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await reconnect();
        return;
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  @override
  void dispose() {
    _hrStatusSubscription?.cancel();
    _trainerStatusSubscription?.cancel();
    super.dispose();
  }
}
