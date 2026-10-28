enum CropSeason {
  winter, // شتوي (Nov - Apr)
  summer, // صيفي (May - Sep)
  nili, // نيلي (Aug - Nov)
}

enum SoilNutrientImpact {
  enriching, // مثبت للنيتروجين ومخصب للتربة (بقوليات)
  moderate, // استهلاك معتدل
  depleting, // مستنزف للنيتروجين والمغذيات (حبوب/محاصيل مجهدة)
}

/// Agronomic profile of a cultivated crop in Egypt according to FAO-56 and ARC.
class Crop {
  final String id;
  final String nameAr;
  final String nameEn;
  final CropSeason season;
  final double baseTemperatureC;
  final double? cutoffTemperatureC;
  final double criticalHeatTemperatureC;
  final double kcIni;
  final double kcMid;
  final double kcEnd;
  final int typicalDurationDays;
  final SoilNutrientImpact soilNutrientImpact;
  final String scientificNotesAr;

  const Crop({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.season,
    required this.baseTemperatureC,
    this.cutoffTemperatureC,
    required this.criticalHeatTemperatureC,
    required this.kcIni,
    required this.kcMid,
    required this.kcEnd,
    required this.typicalDurationDays,
    required this.soilNutrientImpact,
    required this.scientificNotesAr,
  });

  /// Approximate crop coefficient Kc for a relative stage fraction (0.0 to 1.0).
  /// Based on standard FAO-56 four-stage linear interpolation with fixed developmental fractions
  /// [0.20, 0.30, 0.30, 0.20]. Note: This is a documented operational approximation for relative
  /// comparison, not a calibrated empirical biological schedule for every specific crop/cultivar.
  double getKcForStageFraction(double stageFraction) {
    if (stageFraction < 0.0) stageFraction = 0.0;
    if (stageFraction > 1.0) stageFraction = 1.0;

    // Stage durations typical breakdown:
    // Initial: 0.0 - 0.20
    // Development: 0.20 - 0.50
    // Mid-season: 0.50 - 0.80
    // Late-season: 0.80 - 1.00
    if (stageFraction <= 0.20) {
      return kcIni;
    } else if (stageFraction <= 0.50) {
      final p = (stageFraction - 0.20) / 0.30;
      return kcIni + p * (kcMid - kcIni);
    } else if (stageFraction <= 0.80) {
      return kcMid;
    } else {
      final p = (stageFraction - 0.80) / 0.20;
      return kcMid + p * (kcEnd - kcMid);
    }
  }

  @override
  String toString() => 'Crop($nameAr / $nameEn, season: $season)';
}
