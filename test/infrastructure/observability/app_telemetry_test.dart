import 'package:android_hrm_erg/src/infrastructure/observability/app_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

enum _TestState { ready }

class _CustomValue {
  @override
  String toString() => 'custom';
}

void main() {
  group('normalizeTelemetryProperties', () {
    test('keeps booleans for non-analytics telemetry consumers', () {
      final normalized = normalizeTelemetryProperties(<String, Object?>{
        'flag_true': true,
        'flag_false': false,
      });

      expect(normalized, <String, Object>{
        'flag_true': true,
        'flag_false': false,
      });
    });
  });

  group('normalizeAnalyticsParameters', () {
    test('converts booleans to numeric flags and preserves supported values', () {
      final timestamp = DateTime.utc(2026, 3, 16, 8, 30);
      final normalized = normalizeAnalyticsParameters(<String, Object?>{
        'bluetooth_ready': true,
        'analysis_available': false,
        'count': 3,
        'ratio': 1.5,
        'result': 'granted',
        'state': _TestState.ready,
        'captured_at': timestamp,
        'elapsed': const Duration(seconds: 42),
        'custom': _CustomValue(),
        'ignored': null,
      });

      expect(normalized, <String, Object>{
        'bluetooth_ready': 1,
        'analysis_available': 0,
        'count': 3,
        'ratio': 1.5,
        'result': 'granted',
        'state': 'ready',
        'captured_at': timestamp.toIso8601String(),
        'elapsed': 42000,
        'custom': 'custom',
      });
    });
  });
}
