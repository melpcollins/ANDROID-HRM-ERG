class PowerAdjustmentPolicy {
  const PowerAdjustmentPolicy();

  static const int fixedOverMaxHrRatePerMinute = -5;

  int ratePerMinuteForDelta(double delta) {
    if (delta >= 3) {
      return -10;
    }
    if (delta >= 2) {
      return -6;
    }
    if (delta >= 1) {
      return -3;
    }
    if (delta <= -3) {
      return 10;
    }
    if (delta <= -2) {
      return 6;
    }
    if (delta <= -1) {
      return 3;
    }
    return 0;
  }

  PowerAdjustmentResult adjustmentForLoop({
    required double delta,
    required int loopSeconds,
    required int carryNumerator,
  }) {
    final perMinute = ratePerMinuteForDelta(delta);
    return adjustmentForRate(
      perMinute: perMinute,
      loopSeconds: loopSeconds,
      carryNumerator: carryNumerator,
    );
  }

  PowerAdjustmentResult adjustmentForRate({
    required int perMinute,
    required int loopSeconds,
    required int carryNumerator,
  }) {
    final nextNumerator = carryNumerator + (perMinute * loopSeconds);
    final watts = nextNumerator ~/ 60;
    final remainder = nextNumerator - (watts * 60);
    return PowerAdjustmentResult(watts: watts, nextCarryNumerator: remainder);
  }
}

class PowerAdjustmentResult {
  const PowerAdjustmentResult({
    required this.watts,
    required this.nextCarryNumerator,
  });

  final int watts;
  final int nextCarryNumerator;
}
