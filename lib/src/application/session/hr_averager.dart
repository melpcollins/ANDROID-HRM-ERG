import '../../domain/models/hr_sample.dart';

class HrAverager {
  const HrAverager();

  double? average(
    List<HrSample> samples, {
    required DateTime now,
    required Duration window,
  }) {
    final cutoff = now.subtract(window);
    final relevant = samples
        .where((sample) => !sample.timestamp.isBefore(cutoff))
        .toList();
    if (relevant.isEmpty) {
      return null;
    }

    final total = relevant.fold<int>(0, (sum, sample) => sum + sample.bpm);
    return total / relevant.length;
  }
}
