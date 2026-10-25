import 'data_source_provenance.dart';

/// Immutable daily agro-meteorological record.
/// Distinguishes missing data (null) from affirmative zero (0.0).
class DailyAgroRecord {
  final DateTime date;
  final double? maxTemperatureC; // null = missing
  final double? minTemperatureC; // null = missing
  final double? precipitationMm; // null = missing, 0.0 = measured zero
  final double? referenceEt0Mm; // FAO-56 Penman-Monteith ET0
  final DataSourceProvenance provenance;

  const DailyAgroRecord({
    required this.date,
    this.maxTemperatureC,
    this.minTemperatureC,
    required this.precipitationMm,
    required this.referenceEt0Mm,
    required this.provenance,
  });

  /// Mean daily temperature calculated from Tmax and Tmin, or null if either is missing.
  double? get meanTemperatureC {
    if (maxTemperatureC == null || minTemperatureC == null) return null;
    return (maxTemperatureC! + minTemperatureC!) / 2.0;
  }

  /// Daily diurnal temperature range, or null if either is missing.
  double? get diurnalTemperatureRangeC {
    if (maxTemperatureC == null || minTemperatureC == null) return null;
    return maxTemperatureC! - minTemperatureC!;
  }

  @override
  String toString() =>
      'DailyAgroRecord(date: ${date.toIso8601String().substring(0, 10)}, Tmax: $maxTemperatureC°C, Tmin: $minTemperatureC°C, ET0: $referenceEt0Mm mm, P: $precipitationMm mm)';
}
