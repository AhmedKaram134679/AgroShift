import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';
import 'package:agro_shift/data/models/open_meteo_dto.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';
import 'package:agro_shift/domain/environment/models/data_source_provenance.dart';
import 'package:agro_shift/core/constants/agro_constants.dart';
import 'package:agro_shift/domain/validation/scientific_range_validator.dart';

/// Adapts raw OpenMeteo DTOs into domain DailyAgroRecord entities.
/// Enforces physical boundary validation, provenance preservation, and distinct 0 vs null.
class OpenMeteoAdapter {
  OpenMeteoAdapter._();

  static Result<List<DailyAgroRecord>, Failure> toDomainRecords({
    required OpenMeteoDailyResponseDto dto,
    required Coordinate requestedCoordinate,
    required String datasetLabel,
    DateTime? expectedStartDate,
    DateTime? expectedEndDate,
    int? expectedCount,
  }) {
    final daily = dto.daily;
    final times = daily['time'] as List<dynamic>?;
    final tMaxList = daily['temperature_2m_max'] as List<dynamic>?;
    final tMinList = daily['temperature_2m_min'] as List<dynamic>?;
    final et0List = daily['et0_fao_evapotranspiration'] as List<dynamic>?;
    final pList = daily['precipitation_sum'] as List<dynamic>?;

    if (times == null ||
        tMaxList == null ||
        tMinList == null ||
        et0List == null ||
        pList == null) {
      return const FailureResult(
        ParsingFailure(
          userMessageAr:
              'استجابة بيانات الطقس غير مكتملة أو مفقودة المتغيرات الأساسية.',
          technicalMessage: 'Response missing required daily arrays: time, tMax, tMin, et0, or precipitation.',
        ),
      );
    }

    final int count = times.length;
    if (count == 0) {
      return const FailureResult(
        ParsingFailure(
          userMessageAr:
              'استجابة بيانات الطقس فارغة بينما يتطلب النطاق سجلات يومية.',
          technicalMessage: 'Response daily arrays are empty. An empty historical response cannot be processed as successful data.',
        ),
      );
    }

    // 1. Confirm required parallel arrays have compatible lengths (never index beyond bounds)
    if (tMaxList.length != count ||
        tMinList.length != count ||
        et0List.length != count ||
        pList.length != count) {
      return FailureResult(
        ParsingFailure(
          userMessageAr:
              'بيانات الطقس المستلمة تحتوي على مصفوفات غير متطابقة في الطول.',
          technicalMessage:
              'Mismatched parallel array lengths: time=$count, tMax=${tMaxList.length}, tMin=${tMinList.length}, et0=${et0List.length}, precip=${pList.length}.',
        ),
      );
    }

    // 2. Validate raw daily date sequence before any records are discarded
    final List<DateTime> parsedRawDates = [];
    final Set<String> seenDateStrings = {};
    DateTime? prevRawDate;

    final normalizedExpectedStart = expectedStartDate != null
        ? DateTime.utc(
            expectedStartDate.year,
            expectedStartDate.month,
            expectedStartDate.day,
          )
        : null;
    final normalizedExpectedEnd = expectedEndDate != null
        ? DateTime.utc(
            expectedEndDate.year,
            expectedEndDate.month,
            expectedEndDate.day,
          )
        : null;

    final RegExp isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    for (int i = 0; i < count; i++) {
      final rawTime = times[i];
      if (rawTime is! String || !isoDatePattern.hasMatch(rawTime)) {
        return FailureResult(
          ParsingFailure(
            userMessageAr: 'صيغة تاريخ غير صالحة في استجابة الأرصاد الجوية.',
            technicalMessage:
                'Invalid or non-conforming date string in raw response: "$rawTime".',
          ),
        );
      }

      final dateStr = rawTime;
      if (!seenDateStrings.add(dateStr)) {
        return FailureResult(
          ParsingFailure(
            userMessageAr: 'تحتوي استجابة الأرصاد الجوية على تواريخ مكررة.',
            technicalMessage: 'Duplicate date in raw response: "$dateStr".',
          ),
        );
      }

      final parts = dateStr.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final date = DateTime.utc(year, month, day);

      // Verify that calendar round-trip matches the input numbers (guards against e.g. Feb 30)
      if (date.year != year || date.month != month || date.day != day) {
        return FailureResult(
          ParsingFailure(
            userMessageAr:
                'تاريخ غير صالح من الناحية التقويمية في استجابة الأرصاد.',
            technicalMessage:
                'Malformed calendar date in raw response: "$dateStr".',
          ),
        );
      }

      // Check strictly ascending order and contiguous daily spacing
      if (prevRawDate != null) {
        if (!date.isAfter(prevRawDate)) {
          return FailureResult(
            ParsingFailure(
              userMessageAr: 'تواريخ استجابة الأرصاد غير مرتبة تصاعدياً.',
              technicalMessage:
                  'Non-ascending date order: "$dateStr" is not after "$prevRawDate".',
            ),
          );
        }
        if (date.difference(prevRawDate).inDays != 1) {
          return FailureResult(
            ParsingFailure(
              userMessageAr: 'توجد فجوة غير متوقعة في تواريخ استجابة الأرصاد.',
              technicalMessage:
                  'Gap in raw daily date sequence between "$prevRawDate" and "$date".',
            ),
          );
        }
      }

      // Validate range boundaries if expected interval was supplied
      if (normalizedExpectedStart != null &&
          date.isBefore(normalizedExpectedStart)) {
        return FailureResult(
          ParsingFailure(
            userMessageAr:
                'استجابة الأرصاد تحتوي على تواريخ تسبق الفترة المطلوبة.',
            technicalMessage:
                'Date "$dateStr" is before requested startDate "$normalizedExpectedStart".',
          ),
        );
      }
      if (normalizedExpectedEnd != null &&
          date.isAfter(normalizedExpectedEnd)) {
        return FailureResult(
          ParsingFailure(
            userMessageAr:
                'استجابة الأرصاد تحتوي على تواريخ تتجاوز الفترة المطلوبة.',
            technicalMessage:
                'Date "$dateStr" is after requested endDate "$normalizedExpectedEnd".',
          ),
        );
      }

      parsedRawDates.add(date);
      prevRawDate = date;
    }

    // 3. Confirm exact boundary coverage of the requested interval
    if (normalizedExpectedStart != null &&
        !parsedRawDates.first.isAtSameMomentAs(normalizedExpectedStart)) {
      return FailureResult(
        ParsingFailure(
          userMessageAr:
              'استجابة الأرصاد تبدأ بتاريخ لا يطابق بداية الفترة المطلوبة.',
          technicalMessage:
              'First raw response date (${parsedRawDates.first}) does not equal expected startDate ($normalizedExpectedStart).',
        ),
      );
    }

    if (normalizedExpectedEnd != null &&
        !parsedRawDates.last.isAtSameMomentAs(normalizedExpectedEnd)) {
      return FailureResult(
        ParsingFailure(
          userMessageAr:
              'استجابة الأرصاد تنتهي بتاريخ لا يطابق نهاية الفترة المطلوبة.',
          technicalMessage:
              'Last raw response date (${parsedRawDates.last}) does not equal expected endDate ($normalizedExpectedEnd).',
        ),
      );
    }

    if (expectedCount != null && parsedRawDates.length != expectedCount) {
      return FailureResult(
        ParsingFailure(
          userMessageAr:
              'عدد الأيام في استجابة الأرصاد لا يطابق الفترة المطلوبة.',
          technicalMessage:
              'Raw response date count (${parsedRawDates.length}) does not match expected ($expectedCount).',
        ),
      );
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
      expectedPeriodDays: expectedCount ?? count,
    );

    final Set<int> incompleteCompositeDateIndices = <int>{};

    for (int i = 0; i < count; i++) {
      final date = parsedRawDates[i];
      final rawTmax = tMaxList[i];
      final rawTmin = tMinList[i];
      final rawEt0 = et0List[i];
      final rawP = pList[i];

      final bool isTempMissing = rawTmax == null || rawTmin == null;
      final bool isEt0Missing = rawEt0 == null;
      final bool isPrecipMissing = rawP == null;

      if (isTempMissing) {
        missingTempCount++;
        incompleteCompositeDateIndices.add(i);
      }
      if (isEt0Missing) {
        missingEt0Count++;
        incompleteCompositeDateIndices.add(i);
      }
      if (isPrecipMissing) {
        missingPrecipCount++;
        incompleteCompositeDateIndices.add(i);
      }

      // If temperature is missing for the day, we cannot construct a valid DailyAgroRecord
      if (isTempMissing) {
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

    // 1. Variable-specific missingness threshold checks (> 10%)
    final tempMissingRatio = missingTempCount / count;
    if (tempMissingRatio > AgroConstants.maxAcceptableMissingDataRatio) {
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
    if (et0MissingRatio > AgroConstants.maxAcceptableMissingDataRatio) {
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
    if (precipMissingRatio > AgroConstants.maxAcceptableMissingDataRatio) {
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

    // 2. Variable-specific missingness threshold checks (> 10%)
    // Each individual variable has passed the 10% tolerance threshold.
    return Success(records);
  }
}
