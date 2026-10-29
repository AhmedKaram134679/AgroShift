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
    if (!referenceEt0Mm.isFinite || !cropKc.isFinite) return 0.0;
    if (referenceEt0Mm < 0.0) return 0.0;
    if (cropKc < 0.0) return 0.0;
    return cropKc * referenceEt0Mm;
  }

  /// Converts mm water depth to m³ per Feddan.
  /// 1 Feddan = 4,200.83 m².
  /// 1 mm depth = 0.001 m * 4,200.83 m² = 4.20083 m³ ≈ 4.2 m³ / feddan.
  static double convertMmToCubicMetersPerFeddan(double mmDepth) {
    if (!mmDepth.isFinite || mmDepth <= 0.0) return 0.0;
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
  /// If crop Kc parameters are non-finite or negative, returns PhysicalRangeFailure.
  /// If any finite ET0 observation is outside the operational envelope [0.0, 25.0] mm/day, returns PhysicalRangeFailure.
  /// If missing ratio exceeds 10% (or totalRequestedDays <= 0), returns InsufficientEvidenceFailure.
  static Result<({double totalEtcMm, double totalVolumeM3PerFeddan}), Failure>
  calculateCycleWaterRequirementValidated({
    required Crop crop,
    required int totalRequestedDays,
    required List<double?> dailyEt0Series,
  }) {
    final kcIniValidation = ScientificRangeValidator.validateKc(
      crop.kcIni,
      variableName: 'kcIni',
    );
    if (kcIniValidation.isFailure) {
      return FailureResult(kcIniValidation.failureOrNull!);
    }
    final kcMidValidation = ScientificRangeValidator.validateKc(
      crop.kcMid,
      variableName: 'kcMid',
    );
    if (kcMidValidation.isFailure) {
      return FailureResult(kcMidValidation.failureOrNull!);
    }
    final kcEndValidation = ScientificRangeValidator.validateKc(
      crop.kcEnd,
      variableName: 'kcEnd',
    );
    if (kcEndValidation.isFailure) {
      return FailureResult(kcEndValidation.failureOrNull!);
    }

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

  /// Calculates forecast crop evapotranspiration (ETc) for a crop with known planting date over forecast daily dates.
  ///
  /// Conforms to FAO-56 by determining Kc from the crop's actual biological age on each forecast calendar day:
  ///   cropAgeDays = forecastDate.difference(plantingDate).inDays (using normalized UTC calendar dates)
  ///   stageFraction = cropAgeDays / crop.typicalDurationDays
  ///   kc = crop.getKcForStageFraction(stageFraction)
  ///
  /// Guarantees:
  /// - A 7-day forecast does NOT progress across an entire crop cycle; each day receives Kc corresponding to its true age.
  /// - Returns [MissingCropStageFailure] if plantingDate is null, in the future relative to forecast dates, or if crop.typicalDurationDays <= 0.
  /// - Enforces operational ET0 envelope [0.0, 25.0] mm/day and rejects non-finite values with [PhysicalRangeFailure].
  /// - Enforces the 10% maximum missingness policy across totalRequestedDays with [InsufficientEvidenceFailure].
  /// - Missing days skip numeric contribution without shifting subsequent calendar dates or altering their Kc.
  /// - Extra observations beyond totalRequestedDays are ignored.
  static Result<
    ({
      double totalEtcMm,
      double totalVolumeM3PerFeddan,
      List<double?> dailyEtcMmSeries,
      List<double> dailyKcSeries,
    }),
    Failure
  >
  calculateForecastEtcValidated({
    required Crop crop,
    required DateTime? plantingDate,
    required List<DateTime> forecastDates,
    required List<double?> dailyEt0Series,
    required int totalRequestedDays,
  }) {
    if (totalRequestedDays <= 0) {
      return const FailureResult(
        InsufficientEvidenceFailure(
          userMessageAr:
              'عدد أيام التوقعات المطلوبة غير صحيح (يجب أن يكون أكبر من صفر).',
          technicalMessage: 'totalRequestedDays must be greater than zero.',
          missingRatio: 1.0,
        ),
      );
    }

    if (plantingDate == null) {
      return FailureResult(
        MissingCropStageFailure(
          userMessageAr: 'يرجى تحديد تاريخ زراعة المحصول لحساب مرحلة النمو الدقيقة والاحتياج المائي التبخري (ETc).',
          technicalMessage: 'Planting date is null for crop ${crop.id}.',
          cropId: crop.id,
        ),
      );
    }

    if (crop.typicalDurationDays <= 0) {
      return FailureResult(
        MissingCropStageFailure(
          userMessageAr: 'مدة موسم المحصول غير صالحة فسيولوجياً (يجب أن تكون أكبر من صفر).',
          technicalMessage:
              'Invalid typicalDurationDays: ${crop.typicalDurationDays} for crop ${crop.id}.',
          cropId: crop.id,
        ),
      );
    }

    // Validate crop Kc parameters
    final kcIniValidation = ScientificRangeValidator.validateKc(
      crop.kcIni,
      variableName: 'kcIni',
    );
    if (kcIniValidation.isFailure) {
      return FailureResult(kcIniValidation.failureOrNull!);
    }
    final kcMidValidation = ScientificRangeValidator.validateKc(
      crop.kcMid,
      variableName: 'kcMid',
    );
    if (kcMidValidation.isFailure) {
      return FailureResult(kcMidValidation.failureOrNull!);
    }
    final kcEndValidation = ScientificRangeValidator.validateKc(
      crop.kcEnd,
      variableName: 'kcEnd',
    );
    if (kcEndValidation.isFailure) {
      return FailureResult(kcEndValidation.failureOrNull!);
    }

    // Normalized calendar planting date in UTC (year, month, day)
    final normPlantingDate = DateTime.utc(
      plantingDate.year,
      plantingDate.month,
      plantingDate.day,
    );

    final availableRequestedDays = dailyEt0Series.length < totalRequestedDays
        ? dailyEt0Series.length
        : totalRequestedDays;

    final unionOfIncompleteDateIndices = <int>{};

    for (var dayIndex = 0; dayIndex < totalRequestedDays; dayIndex++) {
      if (dayIndex >= availableRequestedDays ||
          dayIndex >= forecastDates.length) {
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
          calculationLabel: 'Forecast Crop Water Requirement (ETc)',
          requiredVariables: ['referenceEt0Mm'],
        );

    if (validationResult.isFailure) {
      return FailureResult(validationResult.failureOrNull!);
    }

    // Calculate daily Kc based on true crop age for each forecast date
    double cumulativeEtcMm = 0.0;
    final dailyEtcSeries = <double?>[];
    final dailyKcSeries = <double>[];

    for (int dayIndex = 0; dayIndex < totalRequestedDays; dayIndex++) {
      if (dayIndex >= availableRequestedDays ||
          dayIndex >= forecastDates.length) {
        break;
      }

      final rawForecastDate = forecastDates[dayIndex];
      final normForecastDate = DateTime.utc(
        rawForecastDate.year,
        rawForecastDate.month,
        rawForecastDate.day,
      );

      final cropAgeDays = normForecastDate.difference(normPlantingDate).inDays;
      if (cropAgeDays < 0) {
        return FailureResult(
          MissingCropStageFailure(
            userMessageAr: 'تاريخ الزراعة المحدد يقع في المستقبل بالنسبة لأيام التوقعات المناخية.',
            technicalMessage:
                'Planting date ($normPlantingDate) is after forecast date ($normForecastDate).',
            cropId: crop.id,
          ),
        );
      }

      // Stage fraction based on biological age relative to typical duration
      final stageFraction = cropAgeDays / crop.typicalDurationDays;
      final kc = crop.getKcForStageFraction(stageFraction);
      dailyKcSeries.add(kc);

      final et0 = dailyEt0Series[dayIndex];
      if (et0 == null || !et0.isFinite) {
        dailyEtcSeries.add(null);
        continue; // Skip missing observation without shifting dates or subsequent Kc
      }

      final dailyEtc = calculateDailyEtc(referenceEt0Mm: et0, cropKc: kc);
      dailyEtcSeries.add(dailyEtc);
      cumulativeEtcMm += dailyEtc;
    }

    final volumeM3 = convertMmToCubicMetersPerFeddan(cumulativeEtcMm);
    return Success((
      totalEtcMm: cumulativeEtcMm,
      totalVolumeM3PerFeddan: volumeM3,
      dailyEtcMmSeries: dailyEtcSeries,
      dailyKcSeries: dailyKcSeries,
    ));
  }
}
