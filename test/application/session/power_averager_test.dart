import 'package:android_hrm_erg/src/application/session/power_averager.dart';
import 'package:android_hrm_erg/src/domain/models/power_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('averages power over the most recent 10 seconds', () {
    final averager = const PowerAverager();
    final now = DateTime(2026, 1, 1, 9, 0, 10);

    final average = averager.average(
      <PowerSample>[
        PowerSample(watts: 100, timestamp: now.subtract(const Duration(seconds: 11))),
        PowerSample(watts: 150, timestamp: now.subtract(const Duration(seconds: 8))),
        PowerSample(watts: 200, timestamp: now.subtract(const Duration(seconds: 4))),
        PowerSample(watts: 250, timestamp: now),
      ],
      now: now,
    );

    expect(average, 200);
  });
}
