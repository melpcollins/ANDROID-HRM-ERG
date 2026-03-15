import 'dart:math';

import '../../domain/models/hr_sample.dart';
import '../../domain/models/power_sample.dart';
import '../../domain/models/workout_config.dart';
import '../../domain/models/workout_summary.dart';
import '../../domain/models/zone2_estimate.dart';

class WorkoutAnalytics {
  const WorkoutAnalytics();

  static const Duration hrErgEarlyWindowStart = Duration(minutes: 10);
  static const Duration hrErgWindowLength = Duration(minutes: 20);
  static const Duration hrErgMinimumProvisionalDuration = Duration(minutes: 30);

  WorkoutSummary summarizeHrErg({
    required List<HrSample> hrSamples,
    required List<PowerSample> powerSamples,
    required DateTime rideStart,
    required DateTime analysisEnd,
  }) {
    final elapsed = analysisEnd.difference(rideStart);
    if (elapsed < hrErgMinimumProvisionalDuration) {
      return const WorkoutSummary(
        analysisAvailable: false,
        analysisMessage:
            'Durability analysis becomes available after 30 minutes.',
      );
    }

    final earlyStart = rideStart.add(hrErgEarlyWindowStart);
    final earlyEnd = earlyStart.add(hrErgWindowLength);
    final lateEnd = analysisEnd;
    final lateStart = lateEnd.subtract(hrErgWindowLength);
    return _buildSummary(
      hrSamples: hrSamples,
      powerSamples: powerSamples,
      earlyStart: earlyStart,
      earlyEnd: earlyEnd,
      lateStart: lateStart,
      lateEnd: lateEnd,
      fallbackMessage:
          'Durability analysis unavailable because ride data was incomplete.',
      interpretationBuilder: _durabilityInterpretation,
    );
  }

  WorkoutSummary summarizeHrErgProvisional({
    required List<HrSample> hrSamples,
    required List<PowerSample> powerSamples,
    required DateTime rideStart,
    required DateTime analysisEnd,
  }) {
    final elapsed = analysisEnd.difference(rideStart);
    if (elapsed < hrErgMinimumProvisionalDuration) {
      return const WorkoutSummary(
        analysisAvailable: false,
        analysisMessage:
            'Provisional durability becomes available after 30 minutes.',
        provisional: true,
      );
    }

    final earlyStart = rideStart.add(hrErgEarlyWindowStart);
    final earlyEnd = earlyStart.add(hrErgWindowLength);
    final lateEnd = analysisEnd;
    final lateStart = lateEnd.subtract(hrErgWindowLength);
    return _buildSummary(
      hrSamples: hrSamples,
      powerSamples: powerSamples,
      earlyStart: earlyStart,
      earlyEnd: earlyEnd,
      lateStart: lateStart,
      lateEnd: lateEnd,
      fallbackMessage:
          'Provisional durability is unavailable because ride data is incomplete.',
      interpretationBuilder: _durabilityInterpretation,
      provisional: true,
    );
  }

  WorkoutSummary summarizePowerErgProvisional({
    required List<HrSample> hrSamples,
    required List<PowerSample> powerSamples,
    required DateTime rideStart,
    required DateTime analysisEnd,
  }) {
    final elapsed = analysisEnd.difference(rideStart);
    if (elapsed < hrErgMinimumProvisionalDuration) {
      return const WorkoutSummary(
        analysisAvailable: false,
        analysisMessage:
            'Provisional aerobic drift becomes available after 30 minutes.',
        provisional: true,
      );
    }

    final earlyStart = rideStart.add(hrErgEarlyWindowStart);
    final earlyEnd = earlyStart.add(hrErgWindowLength);
    final lateEnd = analysisEnd;
    final lateStart = lateEnd.subtract(hrErgWindowLength);
    return _buildSummary(
      hrSamples: hrSamples,
      powerSamples: powerSamples,
      earlyStart: earlyStart,
      earlyEnd: earlyEnd,
      lateStart: lateStart,
      lateEnd: lateEnd,
      fallbackMessage:
          'Provisional aerobic drift is unavailable because ride data is incomplete.',
      interpretationBuilder: _durabilityInterpretation,
      provisional: true,
    );
  }

  WorkoutSummary summarizePowerErg({
    required List<HrSample> hrSamples,
    required List<PowerSample> powerSamples,
    required DateTime rideStart,
    required DateTime analysisEnd,
  }) {
    final elapsed = analysisEnd.difference(rideStart);
    if (elapsed < hrErgMinimumProvisionalDuration) {
      return const WorkoutSummary(
        analysisAvailable: false,
        analysisMessage: 'Aerobic drift becomes available after 30 minutes.',
      );
    }

    final earlyStart = rideStart.add(hrErgEarlyWindowStart);
    final earlyEnd = earlyStart.add(hrErgWindowLength);
    final lateEnd = analysisEnd;
    final lateStart = lateEnd.subtract(hrErgWindowLength);
    return _buildSummary(
      hrSamples: hrSamples,
      powerSamples: powerSamples,
      earlyStart: earlyStart,
      earlyEnd: earlyEnd,
      lateStart: lateStart,
      lateEnd: lateEnd,
      fallbackMessage:
          'Aerobic drift is unavailable because ride data was incomplete.',
      interpretationBuilder: _powerErgInterpretation,
    );
  }

  WorkoutSummary summarizeAssessment({
    required Zone2AssessmentConfig config,
    required List<HrSample> hrSamples,
    required List<PowerSample> powerSamples,
    required DateTime rideStart,
    required bool completed,
    required bool hadPauseOrDisconnect,
  }) {
    if (!completed) {
      return const WorkoutSummary(
        analysisAvailable: false,
        analysisMessage:
            'Estimate unavailable because the assessment ended early.',
      );
    }

    final earlyStart = rideStart.add(const Duration(minutes: 20));
    final earlyEnd = rideStart.add(const Duration(minutes: 40));
    final lateStart = rideStart.add(const Duration(minutes: 65));
    final lateEnd = rideStart.add(const Duration(minutes: 85));

    final summary = _buildSummary(
      hrSamples: hrSamples,
      powerSamples: powerSamples,
      earlyStart: earlyStart,
      earlyEnd: earlyEnd,
      lateStart: lateStart,
      lateEnd: lateEnd,
      fallbackMessage:
          'Estimate unavailable because the assessment data was incomplete.',
      interpretationBuilder: _assessmentInterpretation,
    );

    final drift = summary.aerobicDriftPercent;
    if (!summary.analysisAvailable || drift == null) {
      return summary;
    }

    return WorkoutSummary(
      analysisAvailable: true,
      powerFadePercent: summary.powerFadePercent,
      aerobicDriftPercent: drift,
      interpretation: summary.interpretation,
      analysisMessage: summary.analysisMessage,
      zone2Estimate: _buildZone2Estimate(
        assessmentPower: config.assessmentPower,
        driftPercent: drift,
        hadPauseOrDisconnect: hadPauseOrDisconnect,
      ),
    );
  }

  WorkoutSummary _buildSummary({
    required List<HrSample> hrSamples,
    required List<PowerSample> powerSamples,
    required DateTime earlyStart,
    required DateTime earlyEnd,
    required DateTime lateStart,
    required DateTime lateEnd,
    required String fallbackMessage,
    required String Function(double driftPercent) interpretationBuilder,
    bool provisional = false,
  }) {
    final earlyPower = _averagePower(powerSamples, earlyStart, earlyEnd);
    final latePower = _averagePower(powerSamples, lateStart, lateEnd);
    final earlyHr = _averageHr(hrSamples, earlyStart, earlyEnd);
    final lateHr = _averageHr(hrSamples, lateStart, lateEnd);

    if (earlyPower == null ||
        latePower == null ||
        earlyHr == null ||
        lateHr == null ||
        earlyPower <= 0 ||
        earlyHr <= 0 ||
        lateHr <= 0) {
      return WorkoutSummary(
        analysisAvailable: false,
        analysisMessage: fallbackMessage,
        provisional: provisional,
      );
    }

    final powerFade = ((earlyPower - latePower) / earlyPower) * 100;
    final earlyRatio = earlyPower / earlyHr;
    final lateRatio = latePower / lateHr;
    final drift = ((earlyRatio - lateRatio) / earlyRatio) * 100;

    return WorkoutSummary(
      analysisAvailable: true,
      powerFadePercent: powerFade,
      aerobicDriftPercent: drift,
      interpretation: interpretationBuilder(drift),
      provisional: provisional,
    );
  }

  double? _averagePower(
    List<PowerSample> samples,
    DateTime start,
    DateTime end,
  ) {
    final relevant = samples
        .where(
          (sample) =>
              !sample.timestamp.isBefore(start) &&
              sample.timestamp.isBefore(end),
        )
        .toList();
    if (relevant.isEmpty) {
      return null;
    }

    final total = relevant.fold<int>(0, (sum, sample) => sum + sample.watts);
    return total / relevant.length;
  }

  double? _averageHr(List<HrSample> samples, DateTime start, DateTime end) {
    final relevant = samples
        .where(
          (sample) =>
              !sample.timestamp.isBefore(start) &&
              sample.timestamp.isBefore(end),
        )
        .toList();
    if (relevant.isEmpty) {
      return null;
    }

    final total = relevant.fold<int>(0, (sum, sample) => sum + sample.bpm);
    return total / relevant.length;
  }

  String _durabilityInterpretation(double driftPercent) {
    if (driftPercent < 3) {
      return 'Aerobic drift stayed low and the ride looked very steady.';
    }
    if (driftPercent <= 5) {
      return 'Aerobic drift suggests this ride sat near upper Zone 2.';
    }
    if (driftPercent <= 7) {
      return 'Aerobic drift was borderline and likely quite hard for durable Zone 2.';
    }
    return 'Aerobic drift was high and likely above sustainable Zone 2.';
  }

  String _assessmentInterpretation(double driftPercent) {
    if (driftPercent < 3) {
      return 'This assessment looked below your current upper Zone 2 ceiling.';
    }
    if (driftPercent <= 5) {
      return 'This assessment sat inside your likely upper Zone 2 range.';
    }
    return 'This assessment was likely above your durable upper Zone 2.';
  }

  String _powerErgInterpretation(double driftPercent) {
    if (driftPercent < 3) {
      return 'This power sat in Zone 2.';
    }
    if (driftPercent <= 5) {
      return 'This power was borderline upper Zone 2.';
    }
    return 'This power was higher than Zone 2.';
  }

  Zone2Estimate _buildZone2Estimate({
    required int assessmentPower,
    required double driftPercent,
    required bool hadPauseOrDisconnect,
  }) {
    final confidence = hadPauseOrDisconnect ? 'Limited' : 'Good';
    if (driftPercent < 3) {
      return Zone2Estimate(
        lowerWatts: assessmentPower,
        upperWatts: assessmentPower + 5,
        confidence: confidence,
        interpretation: 'You can likely test slightly higher power next time.',
      );
    }
    if (driftPercent <= 5) {
      return Zone2Estimate(
        lowerWatts: assessmentPower,
        upperWatts: assessmentPower,
        confidence: confidence,
        interpretation:
            'This power looks like a practical upper Zone 2 target.',
      );
    }
    return Zone2Estimate(
      lowerWatts: max(50, assessmentPower - 10),
      upperWatts: max(50, assessmentPower - 5),
      confidence: confidence,
      interpretation:
          'A slightly lower power should be more durable for long aerobic rides.',
    );
  }
}
