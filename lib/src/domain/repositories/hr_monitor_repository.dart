import '../models/ble_device_info.dart';
import '../models/connection_status.dart';
import '../models/hr_sample.dart';

abstract class HrMonitorRepository {
  Stream<ConnectionStatus> get connectionStatus;

  Stream<HrSample> get hrSamples;

  Future<List<BleDeviceInfo>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  });

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<void> reconnect();

  Future<String?> getSavedDeviceId();
}
