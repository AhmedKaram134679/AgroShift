import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../validation/scientific_range_validator.dart';
import '../models/crop.dart';

enum HeatRiskLevel {
  low, // منخفض: درجات حرارة مثالية للنمو
  moderate, // معتدل: إجهاد حراري عابر
  high, // مرتفع: تأثير سلبي على التزهير أو العقد
  severe, // حرج: خطر إجهاض الأزهار وضمور الحبوب
}

/// Evaluates critical heat stress risk for specific crop phenology.
class HeatStressEvaluator {
  HeatStressEvaluator._();

  /// Analyzes days where Tmax reaches or exceeds crop critical threshold.
  static ({
    int totalExceedanceDays,
    double peakObservedTempC,
    HeatRiskLevel riskLevel,
    String agronomicAdviceAr,
  })
  evaluateCropHeatStress({
    required Crop crop,
    required List<double> dailyTmaxSeries,
  }) {
    if (dailyTmaxSeries.isEmpty) {
      return (
        totalExceedanceDays: 0,
        peakObservedTempC: 0.0,
        riskLevel: HeatRiskLevel.low,
        agronomicAdviceAr: 'لا توجد بيانات حرارية متوفرة للتقييم.',
      );
    }

    int exceedanceDays = 0;
    double peakTemp = -100.0;

    for (final tMax in dailyTmaxSeries) {
      if (tMax > peakTemp) peakTemp = tMax;
      if (tMax >= crop.criticalHeatTemperatureC) {
        exceedanceDays++;
      }
    }

    final exceedanceRatio = exceedanceDays / dailyTmaxSeries.length;

    HeatRiskLevel riskLevel;
    String advice;

    if (exceedanceDays == 0) {
      riskLevel = HeatRiskLevel.low;
      advice =
          'درجات الحرارة ضمن النطاق الفسيولوجي الآمن لمحصول ${crop.nameAr}.';
    } else if (exceedanceRatio < 0.10) {
      riskLevel = HeatRiskLevel.moderate;
      advice =
          'تسجيل $exceedanceDays أيام تجاوزت الحد الحرج (${crop.criticalHeatTemperatureC}°C). يُنصح بتقريب فترات الري الخفيف لتبريد منطقة الجذور.';
    } else if (exceedanceRatio < 0.25) {
      riskLevel = HeatRiskLevel.high;
      advice =
          'إجهاد حراري مرتفع ($exceedanceDays يوماً). خطر على التزهير ونضج المحصول. تجنب تعطيش النباتات والرش بالمركبات المضادة للإجهاد.';
    } else {
      riskLevel = HeatRiskLevel.severe;
      advice =
          'موجات حرارية شديدة وحرجة تتجاوز قدرة تحمل ${crop.nameAr}. خطر انخفاض الإنتاجية وجودة المحصول. يوصى بمراجعة موعد الزراعة في المواسم القادمة.';
    }

    return (
      totalExceedanceDays: exceedanceDays,
      peakObservedTempC: peakTemp,
      riskLevel: riskLevel,
      agronomicAdviceAr: advice,
    );
  }

  /// Evaluates heat stress risk across an expected period, enforcing the scientific missingness policy on Tmax.
  /// If missing ratio exceeds 10% (or totalRequestedDays <= 0), returns InsufficientEvidenceFailure.
  static Result<
    ({
      int totalExceedanceDays,
      double peakObservedTempC,
      HeatRiskLevel riskLevel,
      String agronomicAdviceAr,
    }),
    InsufficientEvidenceFailure
  >
  evaluateCropHeatStressValidated({
    required Crop crop,
    required int totalRequestedDays,
    required List<double?> dailyTmaxSeries,
  }) {
    final unionOfIncompleteDateIndices = <int>{};
    final validTmaxSeries = <double>[];

    for (var i = 0; i < dailyTmaxSeries.length; i++) {
      final tMax = dailyTmaxSeries[i];
      if (tMax == null) {
        unionOfIncompleteDateIndices.add(i);
      } else {
        validTmaxSeries.add(tMax);
      }
    }

    if (dailyTmaxSeries.length < totalRequestedDays) {
      for (var i = dailyTmaxSeries.length; i < totalRequestedDays; i++) {
        unionOfIncompleteDateIndices.add(i);
      }
    }

    final validationResult =
        ScientificRangeValidator.validateCompositeMissingness(
          totalRequestedDays: totalRequestedDays,
          unionOfIncompleteDateIndices: unionOfIncompleteDateIndices,
          calculationLabel: 'Heat Stress Evaluation',
          requiredVariables: ['tMax'],
        );

    if (validationResult.isFailure) {
      return FailureResult(validationResult.failureOrNull!);
    }

    final result = evaluateCropHeatStress(
      crop: crop,
      dailyTmaxSeries: validTmaxSeries,
    );

    return Success(result);
  }
}
