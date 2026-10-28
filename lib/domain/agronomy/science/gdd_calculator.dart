import 'dart:math' as math;

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../validation/scientific_range_validator.dart';

/// Scientific implementation of Growing Degree Days (GDD).
/// Standard agro-meteorological formulation with optional high-temperature cutoff.
class GddCalculator {
  GddCalculator._();

  /// Computes daily GDD contribution.
  /// Equation: GDD = max(0.0, ((Tmax_adj + Tmin_adj) / 2.0) - Tbase)
  /// If cutoff is provided, Tmax is capped at Tcutoff.
  static double calculateDailyGdd({
    required double tMax,
    required double tMin,
    required double tBase,
    double? tCutoff,
  }) {
    double effectiveTmax = tMax;
    if (tCutoff != null && effectiveTmax > tCutoff) {
      effectiveTmax = tCutoff;
    }

    double effectiveTmin = tMin;
    if (effectiveTmin < tBase) {
      effectiveTmin = tBase;
    }
    if (tCutoff != null && effectiveTmin > tCutoff) {
      effectiveTmin = tCutoff;
    }

    // In extreme anomalies or edge adjustments, effectiveTmin cannot exceed effectiveTmax
    if (effectiveTmin > effectiveTmax) {
      effectiveTmin = effectiveTmax;
    }

    final meanTemp = (effectiveTmax + effectiveTmin) / 2.0;
    final gdd = meanTemp - tBase;
    return math.max(0.0, gdd);
  }

  /// Computes cumulative GDD across a sequence of daily observations.
  static double calculateAccumulatedGdd({
    required List<({double tMax, double tMin})> dailyTemperatures,
    required double tBase,
    double? tCutoff,
  }) {
    double totalGdd = 0.0;
    for (final day in dailyTemperatures) {
      totalGdd += calculateDailyGdd(
        tMax: day.tMax,
        tMin: day.tMin,
        tBase: tBase,
        tCutoff: tCutoff,
      );
    }
    return totalGdd;
  }

  /// Computes cumulative GDD across an expected sequence of daily observations,
  /// evaluating composite missingness across required temperature inputs (Tmax and Tmin).
  /// A date is incomplete if either Tmax or Tmin is missing (null).
  /// Non-finite or out-of-range temperatures return a PhysicalRangeFailure.
  /// If missing ratio exceeds 10% (or totalRequestedDays <= 0), returns InsufficientEvidenceFailure.
  static Result<double, Failure> calculateAccumulatedGddValidated({
    required int totalRequestedDays,
    required List<({DateTime date, double? tMax, double? tMin})> observations,
    required double tBase,
    double? tCutoff,
  }) {
    final availableRequestedDays = observations.length < totalRequestedDays
        ? observations.length
        : totalRequestedDays;

    final unionOfIncompleteDateIndices = <int>{};
    final validObservations = <({double tMax, double tMin})>[];

    for (var dayIndex = 0; dayIndex < totalRequestedDays; dayIndex++) {
      if (dayIndex >= availableRequestedDays) {
        unionOfIncompleteDateIndices.add(dayIndex);
        continue;
      }

      final obs = observations[dayIndex];
      final rawTmax = obs.tMax;
      final rawTmin = obs.tMin;

      // Null is treated as missing observation
      final isTmaxNull = rawTmax == null;
      final isTminNull = rawTmin == null;

      if (isTmaxNull || isTminNull) {
        // Validate whatever is present to reject invalid numbers even on partially missing days
        if (!isTmaxNull) {
          final tMaxVal = ScientificRangeValidator.validateSingleTemperature(
            rawTmax,
            variableName: 'tMax',
          );
          if (tMaxVal.isFailure) return FailureResult(tMaxVal.failureOrNull!);
        }
        if (!isTminNull) {
          final tMinVal = ScientificRangeValidator.validateSingleTemperature(
            rawTmin,
            variableName: 'tMin',
          );
          if (tMinVal.isFailure) return FailureResult(tMinVal.failureOrNull!);
        }

        unionOfIncompleteDateIndices.add(dayIndex);
        continue;
      }

      // Both are non-null: validate pair consistency and physical ranges
      final pairVal = ScientificRangeValidator.validateTemperature(
        tMax: rawTmax,
        tMin: rawTmin,
      );
      if (pairVal.isFailure) {
        return FailureResult(pairVal.failureOrNull!);
      }

      validObservations.add((tMax: rawTmax, tMin: rawTmin));
    }

    final validationResult =
        ScientificRangeValidator.validateCompositeMissingness(
          totalRequestedDays: totalRequestedDays,
          unionOfIncompleteDateIndices: unionOfIncompleteDateIndices,
          calculationLabel: 'GDD Accumulation',
          requiredVariables: ['tMax', 'tMin'],
        );

    if (validationResult.isFailure) {
      return FailureResult(validationResult.failureOrNull!);
    }

    final gdd = calculateAccumulatedGdd(
      dailyTemperatures: validObservations,
      tBase: tBase,
      tCutoff: tCutoff,
    );

    return Success(gdd);
  }
}
