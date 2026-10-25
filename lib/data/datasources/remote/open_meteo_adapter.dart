import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';
import 'package:agro_shift/data/models/open_meteo_dto.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';
import 'package:agro_shift/domain/environment/models/data_source_provenance.dart';
import 'package:agro_shift/domain/validation/scientific_range_validator.dart';

/// Adapts raw OpenMeteo DTOs into domain DailyAgroRecord entities.
/// Enforces physical boundary validation, provenance preservation, and distinct 0 vs null.
class OpenMeteoAdapter {
  OpenMeteoAdapter._();

  static Result<List<DailyAgroRecord>, Failure> toDomainRecords({
    required OpenMeteoDailyResponseDto dto,
    required Coordinate requestedCoordinate,
    required String datasetLabel,
  }) {
    final daily = dto.daily;
    final times = daily['time'] as List<dynamic>?;
    final tMaxList = daily['temperature_2m_max'] as List<dynamic>?;
    final tMinList = daily['temperature_2m_min'] as List<dynamic>?;
    final et0List = daily['et0_fao_evapotranspiration'] as List<dynamic>?;
    final pList = daily['precipitation_sum'] as List<dynamic>?;

    if (times == null || tMaxList == null || tMinList == null) {
      return const FailureResult(
        ParsingFailure(
          userMessageAr:
              'استجابة بيانات الطقس غير مكتملة أو مفقودة المتغيرات الأساسية.',
          technicalMessage: 'Response missing time or temperature arrays.',
        ),
      );
    }

    final int count = times.length;
    if (count == 0) {
      return const Success([]);
    }

    final List<DailyAgroRecord> records = [];
    int missingTempCount = 0;
    int missingEt0Count = 0;
    int missingPrecipCount = 0;

    final provenance = DataSourceProvenance(
      providerName: 'Open-Meteo Weather API',
      datasetName: datasetLabel,
      requestedLatitude: requestedCoordinate.latitude,
      requestedLongitude: requestedCoordinate.longitude,
      gridLatitude: dto.latitude,
      gridLongitude: dto.longitude,
      gridElevationMeters: dto.elevation,
      acquisitionTimestamp: DateTime.now().toUtc(),
    );

    for (int i = 0; i < count; i++) {
      final dateStr = times[i] as String;
      // Parse as canonical calendar date (YYYY-MM-DD) in UTC to prevent timezone day-shifts
      DateTime? date;
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          date = DateTime.utc(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } else {
          date = DateTime.tryParse(dateStr)?.toUtc();
        }
      } catch (_) {
        date = null;
      }

      if (date == null) {
        missingTempCount++;
        missingEt0Count++;
        missingPrecipCount++;
        continue;
      }

      final rawTmax = tMaxList[i];
      final rawTmin = tMinList[i];
      final rawEt0 = et0List != null && i < et0List.length ? et0List[i] : null;
      final rawP = pList != null && i < pList.length ? pList[i] : null;

      if (rawTmax == null || rawTmin == null) {
        missingTempCount++;
      }
      if (rawEt0 == null) {
        missingEt0Count++;
      }
      if (rawP == null) {
        missingPrecipCount++;
      }

      // If temperature is missing for the day, we cannot construct a valid DailyAgroRecord
      if (rawTmax == null || rawTmin == null) {
        continue;
      }

      final tMax = (rawTmax as num).toDouble();
      final tMin = (rawTmin as num).toDouble();
      final et0 = rawEt0 != null ? (rawEt0 as num).toDouble() : null;
      final p = rawP != null ? (rawP as num).toDouble() : null;

      // Scientific Range Validation
      final tempVal = ScientificRangeValidator.validateTemperature(
        tMax: tMax,
        tMin: tMin,
      );
      if (tempVal.isFailure) {
        return FailureResult(tempVal.failureOrNull!);
      }

      final et0Val = ScientificRangeValidator.validateEt0(et0);
      if (et0Val.isFailure) {
        return FailureResult(et0Val.failureOrNull!);
      }

      final pVal = ScientificRangeValidator.validatePrecipitation(p);
      if (pVal.isFailure) {
        return FailureResult(pVal.failureOrNull!);
      }

      records.add(
        DailyAgroRecord(
          date: date,
          maxTemperatureC: tMax,
          minTemperatureC: tMin,
          precipitationMm: p, // Preserved exact value: 0.0 is 0.0, null is null
          referenceEt0Mm: et0,
          provenance: provenance,
        ),
      );
    }

    // Variable-specific missingness threshold checks (> 10%)
    final tempMissingRatio = missingTempCount / count;
    if (tempMissingRatio > 0.10) {
      return FailureResult(
        InsufficientEvidenceFailure(
          userMessageAr:
              'نسبة درجات الحرارة المفقودة (${(tempMissingRatio * 100).toStringAsFixed(1)}%) تتجاوز الحد العلمي المقبول (10%).',
          technicalMessage:
              'Temperature missing ratio ($missingTempCount/$count) exceeds 10% threshold.',
          missingRatio: tempMissingRatio,
          variableName: 'temperature',
          missingCount: missingTempCount,
          totalCount: count,
        ),
      );
    }

    final et0MissingRatio = missingEt0Count / count;
    if (et0MissingRatio > 0.10) {
      return FailureResult(
        InsufficientEvidenceFailure(
          userMessageAr:
              'نسبة بيانات البخر نتح المرجعي (ET₀) المفقودة (${(et0MissingRatio * 100).toStringAsFixed(1)}%) تتجاوز الحد العلمي المقبول (10%).',
          technicalMessage:
              'ET0 missing ratio ($missingEt0Count/$count) exceeds 10% threshold.',
          missingRatio: et0MissingRatio,
          variableName: 'et0',
          missingCount: missingEt0Count,
          totalCount: count,
        ),
      );
    }

    final precipMissingRatio = missingPrecipCount / count;
    if (precipMissingRatio > 0.10) {
      return FailureResult(
        InsufficientEvidenceFailure(
          userMessageAr:
              'نسبة بيانات هطول الأمطار المفقودة (${(precipMissingRatio * 100).toStringAsFixed(1)}%) تتجاوز الحد العلمي المقبول (10%).',
          technicalMessage:
              'Precipitation missing ratio ($missingPrecipCount/$count) exceeds 10% threshold.',
          missingRatio: precipMissingRatio,
          variableName: 'precipitation',
          missingCount: missingPrecipCount,
          totalCount: count,
        ),
      );
    }

    return Success(records);
  }
}
