import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/connection_status.dart';
import '../../domain/models/trainer_telemetry.dart';
import '../../domain/repositories/trainer_repository.dart';
import 'ble_device_repository_base.dart';
import 'ble_event_logger.dart';
import 'indoor_bike_data_parser.dart';

class TrainerBleRepository extends BleDeviceRepositoryBase
    implements TrainerRepository {
  TrainerBleRepository({required super.store})
    : _telemetryController = StreamController<TrainerTelemetry>.broadcast(),
      super(nameMatcher: _isLikelyTrainer);

  static const int _requestControlOpcode = 0x00;
  static const int _setTargetPowerOpcode = 0x05;
  static const Duration _staleThreshold = Duration(seconds: 10);

  final StreamController<TrainerTelemetry> _telemetryController;
  TrainerTelemetry? _latestTelemetry;

  BluetoothCharacteristic? _controlPointCharacteristic;
  BluetoothCharacteristic? _indoorBikeDataCharacteristic;
  StreamSubscription<List<int>>? _telemetrySubscription;
  Timer? _staleTimer;
  bool _hasControl = false;

  @override
  Stream<TrainerTelemetry> get telemetry async* {
    if (_latestTelemetry != null) {
      yield _latestTelemetry!;
    }
    yield* _telemetryController.stream;
  }

  @override
  Future<void> connect(String deviceId) async {
    await super.connect(deviceId);
    try {
      await _prepareFtms();
      _markAwaitingTelemetry();
    } catch (_) {
      await super.disconnect();
      rethrow;
    }
  }

  @override
  Future<void> reconnect() async {
    await super.reconnect();
  }

  @override
  Future<void> disconnect() async {
    await _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
    _controlPointCharacteristic = null;
    _indoorBikeDataCharacteristic = null;
    _latestTelemetry = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _hasControl = false;
    await super.disconnect();
  }

  @override
  Future<void> setTargetPower(int watts) async {
    final characteristic = _controlPointCharacteristic;
    if (characteristic == null) {
      throw Exception(
        'Trainer control point not available. Connect trainer first.',
      );
    }

    final clamped = watts.clamp(50, 500);

    if (!_hasControl) {
      await _writeControlPoint(characteristic, <int>[
        _requestControlOpcode,
      ], requestOpcode: _requestControlOpcode);
      _hasControl = true;
    }

    final int lowByte = clamped & 0xFF;
    final int highByte = (clamped >> 8) & 0xFF;

    await _writeControlPoint(characteristic, <int>[
      _setTargetPowerOpcode,
      lowByte,
      highByte,
    ], requestOpcode: _setTargetPowerOpcode);
  }

  @override
  Future<String?> getSavedDeviceId() {
    return selectionStore.getTrainerId();
  }

  @override
  Future<void> persistSelectedDeviceId(String id) {
    return selectionStore.saveTrainerId(id);
  }

  Future<void> _prepareFtms() async {
    final device = connectedDevice;
    if (device == null) {
      throw Exception('Trainer device missing while preparing FTMS.');
    }

    final services = await device.discoverServices();
    final ftmsService = services.firstWhere(
      (service) => _matchesUuid(service.uuid, '1826'),
      orElse: () {
        final ids = services.map((service) => service.uuid.str128).join(', ');
        throw Exception('FTMS service not found on trainer. Services: [$ids]');
      },
    );

    _controlPointCharacteristic = ftmsService.characteristics.firstWhere(
      (characteristic) => _matchesUuid(characteristic.uuid, '2ad9'),
      orElse: () {
        final ids = ftmsService.characteristics
            .map((characteristic) => characteristic.uuid.str128)
            .join(', ');
        throw Exception(
          'FTMS Control Point not found. Characteristics: [$ids]',
        );
      },
    );
    _indoorBikeDataCharacteristic = ftmsService.characteristics.firstWhere(
      (characteristic) => _matchesUuid(characteristic.uuid, '2ad2'),
      orElse: () {
        final ids = ftmsService.characteristics
            .map((characteristic) => characteristic.uuid.str128)
            .join(', ');
        throw Exception(
          'FTMS Indoor Bike Data not found. Characteristics: [$ids]',
        );
      },
    );

    _hasControl = false;
    _latestTelemetry = null;

    final cp = _controlPointCharacteristic!;
    if (cp.properties.indicate || cp.properties.notify) {
      await cp.setNotifyValue(true);
    }

    await _telemetrySubscription?.cancel();
    _telemetrySubscription = null;

    final telemetryCharacteristic = _indoorBikeDataCharacteristic!;
    if (telemetryCharacteristic.properties.notify ||
        telemetryCharacteristic.properties.indicate) {
      await telemetryCharacteristic.setNotifyValue(true);
    }

    _telemetrySubscription = telemetryCharacteristic.onValueReceived.listen((
      data,
    ) {
      final telemetry = parseIndoorBikeData(
        data,
        timestamp: DateTime.now(),
      );
      if (telemetry == null) {
        return;
      }

      _latestTelemetry = telemetry;
      _scheduleStaleTimer();
      emitStatus(ConnectionStatus.connected);
      _telemetryController.add(telemetry);
    });
  }

  Future<void> _writeControlPoint(
    BluetoothCharacteristic characteristic,
    List<int> payload, {
    required int requestOpcode,
  }) async {
    final responseFuture = characteristic.onValueReceived
        .firstWhere((value) => _isControlPointResponseFor(value, requestOpcode))
        .timeout(const Duration(seconds: 5), onTimeout: () => <int>[]);

    await characteristic.write(payload, withoutResponse: false);

    final response = await responseFuture;
    if (response.isEmpty) {
      return;
    }

    if (response.length >= 3) {
      final resultCode = response[2];
      if (resultCode != 0x01) {
        throw Exception(
          'Trainer rejected control command (opcode 0x${requestOpcode.toRadixString(16)}, result 0x${resultCode.toRadixString(16)}).',
        );
      }
    }
  }

  bool _isControlPointResponseFor(List<int> value, int requestOpcode) {
    return value.length >= 3 && value[0] == 0x80 && value[1] == requestOpcode;
  }

  @override
  void onStatusChanged(ConnectionStatus status) {
    if (status == ConnectionStatus.disconnected) {
      _staleTimer?.cancel();
      _staleTimer = null;
      _latestTelemetry = null;
      _hasControl = false;
    }
  }

  void _markAwaitingTelemetry() {
    emitStatus(ConnectionStatus.connectedNoData);
  }

  void _scheduleStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer(_staleThreshold, () {
      if (currentStatus == ConnectionStatus.connected ||
          currentStatus == ConnectionStatus.connectedNoData) {
        logBleEvent('stale_detected', details: const <String, Object?>{
          'device': 'trainer',
        });
        emitStatus(ConnectionStatus.connectedNoData);
      }
    });
  }

  bool _matchesUuid(Guid uuid, String shortId) {
    final normalized = shortId.toLowerCase().padLeft(4, '0');
    final shortForm = uuid.str.toLowerCase();
    final fullForm = uuid.str128.toLowerCase();
    return shortForm == normalized ||
        fullForm.contains('0000$normalized-0000-1000-8000-00805f9b34fb');
  }

  static bool _isLikelyTrainer(String name) {
    final lower = name.toLowerCase();
    return lower.contains('wattbike') ||
        lower.contains('atom') ||
        lower.contains('trainer') ||
        lower.contains('bike');
  }
}
