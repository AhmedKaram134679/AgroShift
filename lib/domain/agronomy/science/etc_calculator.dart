import '../../../core/constants/agro_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../validation/scientific_range_validator.dart';
import '../models/crop.dart';

/// Scientific calculation of Crop Evapotranspiration (ETc) and Volumetric Irrigation Demand.
/// Conforms to FAO Irrigation and Drainage Paper No. 56.
class EtcCalculator {
  EtcCalculator._();

  /// Computes daily crop evapotranspiration in mm/day.
  /// Equation: ETc = Kc * ET0
  static double calculateDailyEtc({
    required double referenceEt0Mm,
    required double cropKc,
  }) {
    if (referenceEt0Mm < 0.0) return 0.0;
    if (cropKc < 0.0) return 0.0;
    return cropKc * referenceEt0Mm;
  }

  /// Converts mm water depth to m³ per Feddan.
  /// 1 Feddan = 4,200.83 m².
  /// 1 mm depth = 0.001 m * 4,200.83 m² = 4.20083 m³ ≈ 4.2 m³ / feddan.
  static double convertMmToCubicMetersPerFeddan(double mmDepth) {
    if (mmDepth <= 0.0) return 0.0;
    return mmDepth * AgroConstants.cubicMetersPerFeddanPerMm;
  }

  /// Calculates cumulative water requirement over a growth cycle given daily ET0 and Crop.
  static ({double totalEtcMm, double totalVolumeM3PerFeddan})
  calculateCycleWaterRequirement({
    required Crop crop,
    required List<double> dailyEt0Series,
  }) {
    if (dailyEt0Series.isEmpty) {
      return (totalEtcMm: 0.0, totalVolumeM3PerFeddan: 0.0);
    }

    final totalDays = dailyEt0Series.length;
    double cumulativeEtcMm = 0.0;

    for (int dayIndex = 0; dayIndex < totalDays; dayIndex++) {
      final stageFraction = (dayIndex + 1) / totalDays;
      final kc = crop.getKcForStageFraction(stageFraction);
      final dailyEt0 = dailyEt0Series[dayIndex];
      cumulativeEtcMm += calculateDailyEtc(
        referenceEt0Mm: dailyEt0,
        cropKc: kc,
      );
    }

    final volumeM3 = convertMmToCubicMetersPerFeddan(cumulativeEtcMm);
    return (totalEtcMm: cumulativeEtcMm, totalVolumeM3PerFeddan: volumeM3);
  }

  /// Calculates cumulative water requirement over a growth cycle given daily ET0 observations,
  /// assessing ET0 missingness across the requested period using the scientific missingness policy.
  /// If any finite ET0 observation is outside the operational envelope [0.0, 25.0] mm/day, returns PhysicalRangeFailure.
  /// If missing ratio exceeds 10% (or totalRequestedDays <= 0), returns InsufficientEvidenceFailure.
  static Result<({double totalEtcMm, double totalVolumeM3PerFeddan}), Failure>
  calculateCycleWaterRequirementValidated({
    required Crop crop,
    required int totalRequestedDays,
    required List<double?> dailyEt0Series,
  }) {
    final availableRequestedDays = dailyEt0Series.length < totalRequestedDays
        ? dailyEt0Series.length
        : totalRequestedDays;

    final unionOfIncompleteDateIndices = <int>{};

    for (var dayIndex = 0; dayIndex < totalRequestedDays; dayIndex++) {
      if (dayIndex >= availableRequestedDays) {
        unionOfIncompleteDateIndices.add(dayIndex);
        continue;
      }

      final et0 = dailyEt0Series[dayIndex];
      if (et0 == null) {
        unionOfIncompleteDateIndices.add(dayIndex);
        continue;
      }

      final et0Validation = ScientificRangeValidator.validateEt0(et0);
      if (et0Validation.isFailure) {
        return FailureResult(et0Validation.failureOrNull!);
      }
    }

    final validationResult =
        ScientificRangeValidator.validateCompositeMissingness(
          totalRequestedDays: totalRequestedDays,
          unionOfIncompleteDateIndices: unionOfIncompleteDateIndices,
          calculationLabel: 'Crop Water Requirement (ETc)',
          requiredVariables: ['referenceEt0Mm'],
        );

    if (validationResult.isFailure) {
      return FailureResult(validationResult.failureOrNull!);
    }

    // Preserve original day alignment and growth-stage fractions:
    // stageFraction must be computed using (dayIndex + 1) / totalRequestedDays
    // so missing days do not shift subsequent days or change their assigned Kc.
    // Observations beyond totalRequestedDays are strictly ignored.
    double cumulativeEtcMm = 0.0;
    for (int dayIndex = 0; dayIndex < totalRequestedDays; dayIndex++) {
      if (dayIndex >= availableRequestedDays) {
        break;
      }
      final et0 = dailyEt0Series[dayIndex];
      if (et0 == null || !et0.isFinite) {
        continue; // Skip missing or non-finite day's numeric contribution
      }

      final stageFraction = (dayIndex + 1) / totalRequestedDays;
      final kc = crop.getKcForStageFraction(stageFraction);
      cumulativeEtcMm += calculateDailyEtc(referenceEt0Mm: et0, cropKc: kc);
    }

    final volumeM3 = convertMmToCubicMetersPerFeddan(cumulativeEtcMm);
    return Success((
      totalEtcMm: cumulativeEtcMm,
      totalVolumeM3PerFeddan: volumeM3,
    ));
  }
}
