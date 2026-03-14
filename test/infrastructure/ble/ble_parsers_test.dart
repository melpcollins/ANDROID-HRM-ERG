import 'package:android_hrm_erg/src/infrastructure/ble/heart_rate_measurement_parser.dart';
import 'package:android_hrm_erg/src/infrastructure/ble/indoor_bike_data_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHeartRateMeasurement', () {
    test('parses 8-bit heart rate payloads', () {
      expect(parseHeartRateMeasurement(<int>[0x00, 72]), 72);
    });

    test('parses 16-bit heart rate payloads', () {
      expect(parseHeartRateMeasurement(<int>[0x01, 0x2C, 0x01]), 300);
    });

    test('returns zero for truncated payloads', () {
      expect(parseHeartRateMeasurement(<int>[0x01, 0x2C]), 0);
    });
  });

  group('parseIndoorBikeData', () {
    test('parses power and cadence when present', () {
      final telemetry = parseIndoorBikeData(
        <int>[
          0x44,
          0x00, // flags: cadence + instantaneous power, speed present
          0x2C,
          0x01, // speed
          0xB4,
          0x00, // cadence = 90 rpm (0.5 rpm units)
          0xFA,
          0x00, // power = 250 W
        ],
        timestamp: DateTime(2026, 1, 1, 9),
      );

      expect(telemetry, isNotNull);
      expect(telemetry!.powerWatts, 250);
      expect(telemetry.cadenceRpm, 90);
    });

    test('parses power when speed is omitted by the more-data flag', () {
      final telemetry = parseIndoorBikeData(
        <int>[
          0x41,
          0x00, // flags: more data + instantaneous power
          0x64,
          0x00, // power = 100 W
        ],
        timestamp: DateTime(2026, 1, 1, 9),
      );

      expect(telemetry, isNotNull);
      expect(telemetry!.powerWatts, 100);
      expect(telemetry.cadenceRpm, isNull);
    });

    test('returns null when power is missing', () {
      final telemetry = parseIndoorBikeData(
        <int>[0x04, 0x00, 0x2C, 0x01, 0xB4, 0x00],
        timestamp: DateTime(2026, 1, 1, 9),
      );

      expect(telemetry, isNull);
    });
  });
}
