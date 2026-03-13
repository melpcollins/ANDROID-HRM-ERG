import 'dart:math';

import '../../domain/models/hr_sample.dart';
import '../../domain/models/power_sample.dart';
import '../../domain/models/workout_config.dart';
import '../../domain/models/workout_summary.dart';
import '../../domain/models/zone2_estimate.dart';

class WorkoutAnalytics {
  const WorkoutAnalytics();

  WorkoutSummary summarizeHrErg({
    required List<HrSample> hrSamples,
    required List<PowerSample> powerSamples,
    required DateTime rideStart,
    required DateTime analysisEnd,
  }) {
    final trimmedStart = rideStart.add(const Duration(minutes: 10));
    final trimmedDuration = analysisEnd.difference(trimmedStart);
    if (trimmedDuration < const Duration(minutes: 40)) {
      return const WorkoutSummary(
        analysisAvailable: false,
        analysisMessage:
            'Durability analysis unavailable for rides under 55 minutes.',
      );
    }

    final earlyStart = trimmedStart;
    final earlyEnd = earlyStart.add(const Duration(minutes: 20));
    final lateEnd = analysisEnd;
    final lateStart = lateEnd.subtract(const Duration(minutes: 20));
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
              !sample.timestamp.isBefore(start) && sample.timestamp.isBefore(end),
        )
        .toList();
    if (relevant.isEmpty) {
      return null;
    }

    final total = relevant.fold<int>(0, (sum, sample) => sum + sample.watts);
    return total / relevant.length;
  }

  double? _averageHr(
    List<HrSample> samples,
    DateTime start,
    DateTime end,
  ) {
    final relevant = samples
        .where(
          (sample) =>
              !sample.timestamp.isBefore(start) && sample.timestamp.isBefore(end),
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
