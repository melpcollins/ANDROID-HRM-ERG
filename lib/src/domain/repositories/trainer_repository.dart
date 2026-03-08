import '../models/ble_device_info.dart';
import '../models/connection_status.dart';

abstract class TrainerRepository {
  Stream<ConnectionStatus> get connectionStatus;

  Stream<int> get currentPower;

  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  });

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<void> reconnect();

  Future<void> setTargetPower(int watts);

  Future<String?> getSavedDeviceId();
}
