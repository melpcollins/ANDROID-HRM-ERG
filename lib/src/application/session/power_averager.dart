import '../../domain/models/power_sample.dart';

class PowerAverager {
  const PowerAverager();

  int? average(
    List<PowerSample> samples, {
    required DateTime now,
    Duration window = const Duration(seconds: 10),
  }) {
    final cutoff = now.subtract(window);
    final relevant = samples
        .where(
          (sample) =>
              !sample.timestamp.isBefore(cutoff) &&
              !sample.timestamp.isAfter(now),
        )
        .toList();

    if (relevant.isEmpty) {
      return null;
    }

    final total = relevant.fold<int>(0, (sum, sample) => sum + sample.watts);
    return (total / relevant.length).round();
  }
}
