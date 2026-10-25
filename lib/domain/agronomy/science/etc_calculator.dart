import '../../../core/constants/agro_constants.dart';
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
}
