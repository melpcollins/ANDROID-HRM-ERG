import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/connection_status.dart';
import '../../domain/models/hr_sample.dart';
import '../../domain/repositories/hr_monitor_repository.dart';
import 'ble_device_repository_base.dart';
import 'ble_event_logger.dart';
import 'heart_rate_measurement_parser.dart';

class HrMonitorBleRepository extends BleDeviceRepositoryBase
    implements HrMonitorRepository {
  HrMonitorBleRepository({
    required super.store,
    required super.telemetry,
    required super.diagnosticsStore,
  }) : _hrController = StreamController<HrSample>.broadcast(),
       super(nameMatcher: _isLikelyHrMonitor, deviceRole: 'hr_monitor');

  static const Duration _staleThreshold = Duration(seconds: 5);

  final StreamController<HrSample> _hrController;
  StreamSubscription<List<int>>? _hrNotificationSubscription;
  Timer? _staleTimer;
  bool? _lastContactDetected;

  @override
  Stream<HrSample> get hrSamples => _hrController.stream;

  @override
  Future<void> reconnect() async {
    await super.reconnect();
  }

  @override
  Future<void> disconnect() async {
    await _hrNotificationSubscription?.cancel();
    _hrNotificationSubscription = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _lastContactDetected = null;
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

  @override
  Future<void> onConnected(String deviceId) async {
    try {
      await _subscribeToHeartRate(deviceId);
      _markAwaitingFreshHr();
    } catch (_) {
      await disconnect();
      rethrow;
    }
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
      final measurement = parseHeartRateMeasurementPacket(data);
      if (measurement.contactSupported &&
          measurement.contactDetected != _lastContactDetected) {
        logBleEvent(
          measurement.contactDetected == true
              ? 'hr_contact_detected'
              : 'hr_contact_lost',
          details: <String, Object?>{
            'bpm': measurement.bpm,
            'contactSupported': measurement.contactSupported,
          },
        );
        trackRepositoryEvent(
          'ble_hr_contact_changed',
          telemetryProperties: <String, Object?>{
            'result': measurement.contactDetected == true ? 'detected' : 'lost',
          },
          diagnosticsData: <String, Object?>{
            'contact_detected': measurement.contactDetected,
            'bpm': measurement.bpm,
            'contact_supported': measurement.contactSupported,
          },
        );
        _lastContactDetected = measurement.contactDetected;
      }

      if (measurement.contactSupported &&
          measurement.contactDetected == false) {
        _staleTimer?.cancel();
        _staleTimer = null;
        emitStatus(ConnectionStatus.connectedNoData);
        return;
      }

      if (measurement.bpm <= 0) {
        return;
      }

      final sample = HrSample(bpm: measurement.bpm, timestamp: DateTime.now());
      _scheduleStaleTimer();
      emitStatus(ConnectionStatus.connected);
      _hrController.add(sample);
    });
  }

  bool _matchesUuid(Guid uuid, String shortId) {
    final normalized = shortId.toLowerCase().padLeft(4, '0');
    final shortForm = uuid.str.toLowerCase();
    final fullForm = uuid.str128.toLowerCase();
    return shortForm == normalized ||
        fullForm.contains('0000$normalized-0000-1000-8000-00805f9b34fb');
  }

  @override
  void onStatusChanged(ConnectionStatus status) {
    if (status == ConnectionStatus.disconnected) {
      _staleTimer?.cancel();
      _staleTimer = null;
      _lastContactDetected = null;
    }
  }

  void _markAwaitingFreshHr() {
    emitStatus(ConnectionStatus.connectedNoData);
  }

  void _scheduleStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer(_staleThreshold, () {
      if (currentStatus == ConnectionStatus.connected ||
          currentStatus == ConnectionStatus.connectedNoData) {
        logBleEvent(
          'stale_detected',
          details: const <String, Object?>{'device': 'hrm'},
        );
        trackRepositoryEvent(
          'ble_stale_detected',
          telemetryProperties: const <String, Object?>{'result': 'stale'},
          diagnosticsData: const <String, Object?>{
            'stale_source': 'hr_monitor',
          },
        );
        emitStatus(ConnectionStatus.connectedNoData);
      }
    });
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
