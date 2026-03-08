import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/hr_sample.dart';
import '../../domain/repositories/hr_monitor_repository.dart';
import 'ble_device_repository_base.dart';

class HrMonitorBleRepository extends BleDeviceRepositoryBase
    implements HrMonitorRepository {
  HrMonitorBleRepository({required super.store})
    : _hrController = StreamController<HrSample>.broadcast(),
      super(nameMatcher: _isLikelyHrMonitor);

  final StreamController<HrSample> _hrController;
  StreamSubscription<List<int>>? _hrNotificationSubscription;

  @override
  Stream<HrSample> get hrSamples => _hrController.stream;

  @override
  Future<void> connect(String deviceId) async {
    await super.connect(deviceId);
    await _subscribeToHeartRate(deviceId);
  }

  @override
  Future<void> reconnect() async {
    await super.reconnect();
    final savedId = await getSavedDeviceId();
    if (savedId != null && savedId.isNotEmpty) {
      await _subscribeToHeartRate(savedId);
    }
  }

  @override
  Future<void> disconnect() async {
    await _hrNotificationSubscription?.cancel();
    _hrNotificationSubscription = null;
    await super.disconnect();
  }

  @override
  Future<String?> getSavedDeviceId() {
    return selectionStore.getHrMonitorId();
  }

  @override
  Future<void> persistSelectedDeviceId(String id) {
    return selectionStore.saveHrMonitorId(id);
  }

  Future<void> _subscribeToHeartRate(String deviceId) async {
    await _hrNotificationSubscription?.cancel();
    _hrNotificationSubscription = null;

    final device = BluetoothDevice.fromId(deviceId);
    final services = await device.discoverServices();

    final hrServices = services
        .where((service) => _matchesUuid(service.uuid, '180d'))
        .toList();
    if (hrServices.isEmpty) {
      final serviceIds = services
          .map((service) => service.uuid.str128)
          .join(', ');
      throw Exception('Heart Rate service not found. Services: [$serviceIds]');
    }

    BluetoothCharacteristic? hrCharacteristic;
    for (final service in hrServices) {
      for (final characteristic in service.characteristics) {
        if (_matchesUuid(characteristic.uuid, '2a37')) {
          hrCharacteristic = characteristic;
          break;
        }
      }
      if (hrCharacteristic != null) {
        break;
      }
    }

    if (hrCharacteristic == null) {
      final characteristicIds = hrServices
          .expand((service) => service.characteristics)
          .map((characteristic) => characteristic.uuid.str128)
          .join(', ');
      throw Exception(
        'Heart Rate Measurement characteristic not found. Characteristics: [$characteristicIds]',
      );
    }

    await hrCharacteristic.setNotifyValue(true);

    _hrNotificationSubscription = hrCharacteristic.onValueReceived.listen((
      data,
    ) {
      if (data.isEmpty) {
        return;
      }

      final bpm = _parseHeartRateMeasurement(data);
      if (bpm <= 0) {
        return;
      }

      _hrController.add(HrSample(bpm: bpm, timestamp: DateTime.now()));
    });
  }

  bool _matchesUuid(Guid uuid, String shortId) {
    final normalized = shortId.toLowerCase().padLeft(4, '0');
    final shortForm = uuid.str.toLowerCase();
    final fullForm = uuid.str128.toLowerCase();
    return shortForm == normalized ||
        fullForm.contains('0000$normalized-0000-1000-8000-00805f9b34fb');
  }

  int _parseHeartRateMeasurement(List<int> data) {
    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;

    if (is16Bit) {
      if (data.length < 3) {
        return 0;
      }
      return data[1] | (data[2] << 8);
    }

    if (data.length < 2) {
      return 0;
    }

    return data[1];
  }

  static bool _isLikelyHrMonitor(String name) {
    final lower = name.toLowerCase();
    return lower.contains('hr') ||
        lower.contains('heart') ||
        lower.contains('polar') ||
        lower.contains('h10') ||
        lower.contains('dual');
  }
}
