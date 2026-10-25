import 'data_source_provenance.dart';

/// Immutable daily agro-meteorological record.
/// Distinguishes missing data (null) from affirmative zero (0.0).
class DailyAgroRecord {
  final DateTime date;
  final double maxTemperatureC;
  final double minTemperatureC;
  final double? precipitationMm; // null = missing, 0.0 = measured zero
  final double? referenceEt0Mm; // FAO-56 Penman-Monteith ET0
  final DataSourceProvenance provenance;

  const DailyAgroRecord({
    required this.date,
    required this.maxTemperatureC,
    required this.minTemperatureC,
    required this.precipitationMm,
    required this.referenceEt0Mm,
    required this.provenance,
  });

  /// Mean daily temperature calculated from Tmax and Tmin.
  double get meanTemperatureC => (maxTemperatureC + minTemperatureC) / 2.0;

  /// Daily diurnal temperature range.
  double get diurnalTemperatureRangeC => maxTemperatureC - minTemperatureC;

  @override
  String toString() =>
      'DailyAgroRecord(date: ${date.toIso8601String().substring(0, 10)}, Tmax: $maxTemperatureC°C, Tmin: $minTemperatureC°C, ET0: $referenceEt0Mm mm, P: $precipitationMm mm)';
}
