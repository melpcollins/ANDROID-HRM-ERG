import '../models/ble_device_info.dart';
import '../models/connection_status.dart';
import '../models/trainer_telemetry.dart';

abstract class TrainerRepository {
  Stream<ConnectionStatus> get connectionStatus;

  Stream<TrainerTelemetry> get telemetry;

  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  });

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<void> reconnect();

  Future<void> setTargetPower(int watts);

  Future<String?> getSavedDeviceId();
}
