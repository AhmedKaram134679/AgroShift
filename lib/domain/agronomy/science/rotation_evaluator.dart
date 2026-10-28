import '../models/crop.dart';

enum SoilBalanceEffect {
  positiveEnrichment, // تحسن في الخصوبة وتثبيت النيتروجين
  neutralOrBalanced, // استقرار نسبي
  cumulativeDepletion, // استنزاف مجهد للتربة
}

/// A planned agricultural rotation sequence (e.g. Winter crop followed by Summer crop).
class RotationSequence {
  final String id;
  final String titleAr;
  final Crop firstCrop;
  final Crop secondCrop;
  final String agronomicRationaleAr;

  const RotationSequence({
    required this.id,
    required this.titleAr,
    required this.firstCrop,
    required this.secondCrop,
    required this.agronomicRationaleAr,
  });
}

/// Scientific evaluation of a multi-season crop rotation sequence.
class RotationComparisonResult {
  final RotationSequence sequence;
  final double estimatedAnnualWaterM3PerFeddan;
  final SoilBalanceEffect soilBalanceEffect;
  final String soilImpactSummaryAr;
  final int totalGrowingDays;
  final int turnaroundDays;
  final bool hasTurnaroundConflict;
  final String turnaroundNotesAr;

  const RotationComparisonResult({
    required this.sequence,
    required this.estimatedAnnualWaterM3PerFeddan,
    required this.soilBalanceEffect,
    required this.soilImpactSummaryAr,
    required this.totalGrowingDays,
    required this.turnaroundDays,
    required this.hasTurnaroundConflict,
    required this.turnaroundNotesAr,
  });
}

/// Pure domain evaluator comparing multi-season crop rotations.
class RotationEvaluator {
  RotationEvaluator._();

  /// Evaluates multi-season crop rotation sequences using approximate agronomic heuristics.
  ///
  /// SCIENTIFIC MODEL LIMITATIONS & ASSUMPTIONS:
  /// 1. Uses a weighted Kc average ((kcIni + 2*kcMid + kcEnd) / 4.0) rather than continuous
  ///    linear interpolation across actual developmental stages.
  /// 2. Allocates baseline annual ET0 uniformly by duration ratio (duration / 365.0), whereas
  ///    real-world ET0 exhibits substantial seasonal variation between winter and summer in Egypt.
  /// 3. Rice applies an empirical standing water factor (1.30) to approximate deep percolation
  ///    and standing water evaporation; this empirical factor requires independent field lysimeter
  ///    validation across varied soil types (clay vs sandy-loam).
  /// 4. This calculation provides an approximate model estimate for comparative screening,
  ///    not measured field water consumption or actual delivery irrigation demand with conveyance losses.
  static RotationComparisonResult evaluate({
    required RotationSequence sequence,
    required double baselineAnnualEt0Mm,
  }) {
    // 1. Water requirement estimation based on weighted Kc stages and typical durations
    // First crop (Winter: ~150-180 days, lower ET0 share ~40%)
    final firstMeanKc =
        (sequence.firstCrop.kcIni +
            sequence.firstCrop.kcMid * 2 +
            sequence.firstCrop.kcEnd) /
        4.0;
    final firstCropWater =
        (firstMeanKc *
            (baselineAnnualEt0Mm *
                (sequence.firstCrop.typicalDurationDays / 365.0))) *
        4.2;

    // Second crop (Summer: higher ET0 share in Egyptian climate)
    final secondMeanKc =
        (sequence.secondCrop.kcIni +
            sequence.secondCrop.kcMid * 2 +
            sequence.secondCrop.kcEnd) /
        4.0;
    // Rice maintains standing water (percolation + saturated evaporation factor ~1.25)
    final cropWaterFactor = sequence.secondCrop.id == 'rice' ? 1.30 : 1.0;
    final secondCropWater =
        (secondMeanKc *
            cropWaterFactor *
            (baselineAnnualEt0Mm *
                (sequence.secondCrop.typicalDurationDays / 365.0))) *
        4.2;
    final totalAnnualWaterM3 = firstCropWater + secondCropWater;

    // 2. Soil impact analysis
    final bool hasEnriching =
        sequence.firstCrop.soilNutrientImpact == SoilNutrientImpact.enriching ||
        sequence.secondCrop.soilNutrientImpact == SoilNutrientImpact.enriching;
    final bool bothDepleting =
        sequence.firstCrop.soilNutrientImpact == SoilNutrientImpact.depleting &&
        sequence.secondCrop.soilNutrientImpact == SoilNutrientImpact.depleting;

    final SoilBalanceEffect effect;
    final String soilSummary;

    if (hasEnriching && !bothDepleting) {
      effect = SoilBalanceEffect.positiveEnrichment;
      soilSummary = 'دورة متوازنة حيوياً: وجود محصول بقولي يُثري محتوى النيتروجين العضوي ويقلل الحاجة للأسمدة الكيماوية في المحصول التالي.';
    } else if (bothDepleting) {
      effect = SoilBalanceEffect.cumulativeDepletion;
      soilSummary = 'دورة مجهدة للتربة: تعاقب محصولين مجهدين يستنزف خصوبة التربة ويزيد تراكم الآفات المشتركة؛ يلزم زيادة التسميد العضوي والدورات التبادلية.';
    } else {
      effect = SoilBalanceEffect.neutralOrBalanced;
      soilSummary = 'دورة متوسطة التأثير على خصوبة التربة مع استهلاك معتدل للعناصر الغذائية.';
    }

    // 3. Turnaround window: Total year has 365 days
    final totalGrowingDays =
        sequence.firstCrop.typicalDurationDays +
        sequence.secondCrop.typicalDurationDays;
    final turnaroundDays = 365 - totalGrowingDays;
    final bool conflict = turnaroundDays < 14;

    final String turnaroundNotes;
    if (conflict) {
      turnaroundNotes =
          'تنبيه فني: الفترة الفاصلة بين الحصاد والزراعة ($turnaroundDays يوماً) غير كافية لخدمة الأرض وتهوية التربة وتجهيز المهد.';
    } else {
      turnaroundNotes =
          'فترة بينية كافية ($turnaroundDays يوماً) تتيح خدمة التربة، التشميس، والتسوية بالليزر قبل الزراعة التالية.';
    }

    return RotationComparisonResult(
      sequence: sequence,
      estimatedAnnualWaterM3PerFeddan: totalAnnualWaterM3,
      soilBalanceEffect: effect,
      soilImpactSummaryAr: soilSummary,
      totalGrowingDays: totalGrowingDays,
      turnaroundDays: turnaroundDays,
      hasTurnaroundConflict: conflict,
      turnaroundNotesAr: turnaroundNotes,
    );
  }
}
