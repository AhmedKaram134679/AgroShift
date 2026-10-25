import 'dart:math' as math;

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
}
