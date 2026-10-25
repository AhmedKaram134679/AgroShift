import 'dart:developer' as developer;
import 'dart:io';

import 'package:agro_shift/data/datasources/local/cache_policy.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';
import 'package:agro_shift/domain/environment/models/data_source_provenance.dart';
import 'package:agro_shift/domain/environment/repositories/i_weather_repository.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';
import 'package:agro_shift/data/datasources/remote/open_meteo_remote_data_source.dart';
import 'package:agro_shift/data/datasources/remote/open_meteo_adapter.dart';
import 'package:agro_shift/data/datasources/local/weather_local_data_source.dart';

/// In-memory cache entry tracking records and storage timestamp for TTL evaluation.
class _MemoryCacheEntry {
  final List<DailyAgroRecord> records;
  final DateTime storedAt;

  _MemoryCacheEntry({required this.records, required this.storedAt});

  bool isFresh({required bool isForecast, DateTime? now}) {
    return CachePolicy.isFresh(
      cachedAt: storedAt,
      isForecast: isForecast,
      now: now,
    );
  }
}

/// Concrete implementation of IWeatherRepository connecting to Open-Meteo with persistent caching.
class WeatherRepositoryImpl implements IWeatherRepository {
  final OpenMeteoRemoteDataSource _remoteDataSource;
  final WeatherLocalDataSource? _localDataSource;

  /// Official Open-Meteo ERA5 / ERA5-Land Archive publication delay is typically 5 calendar days.
  /// Source: https://open-meteo.com/en/docs/historical-weather-api
  static const int era5LandArchiveDelayDays = 5;

  // In-memory L1 cache for fast hot-lookup with TTL and integrity tracking
  final Map<String, _MemoryCacheEntry> _memoryCache = {};
  final DateTime Function()? _referenceTimeProvider;

  WeatherRepositoryImpl({
    OpenMeteoRemoteDataSource? remoteDataSource,
    this._localDataSource,
    this._referenceTimeProvider,
  }) : _remoteDataSource = remoteDataSource ?? OpenMeteoRemoteDataSource();

  /// Returns the current reference time (injectable for deterministic testing).
  DateTime _getCurrentTime() =>
      _referenceTimeProvider?.call() ?? DateTime.now();

  /// Calculates the latest eligible historical calendar date in Egypt.
  /// Based on the official Open-Meteo ERA5-Land publication delay of 5 calendar days.
  static DateTime getLatestEligibleHistoricalDate([DateTime? referenceTime]) {
    final cairoNow = getCairoDateTime(referenceTime);
    // Normalize to canonical UTC calendar date (00:00:00) before subtracting delay
    final cairoCalendarToday = DateTime.utc(
      cairoNow.year,
      cairoNow.month,
      cairoNow.day,
    );
    return cairoCalendarToday.subtract(
      const Duration(days: era5LandArchiveDelayDays),
    );
  }

  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getHistoricalDailyRecords({
    required Coordinate coordinate,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. Validate coordinate within Egypt bounds
    final coordVal = coordinate.validate();
    if (coordVal.isFailure) {
      return FailureResult(coordVal.failureOrNull!);
    }

    // Canonical UTC calendar date normalization
    final normStartDate = DateTime.utc(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normEndDate = DateTime.utc(endDate.year, endDate.month, endDate.day);

    if (normStartDate.isAfter(normEndDate)) {
      return const FailureResult(
        PhysicalRangeFailure(
          userMessageAr:
              'تاريخ بداية السجلات لا يمكن أن يكون بعد تاريخ النهاية.',
          technicalMessage: 'startDate cannot be after endDate.',
          variableName: 'startDate_after_endDate',
          actualValue: null,
        ),
      );
    }

    // 2. Clamp end date to the latest eligible historical archive calendar date (5-day delay)
    final latestEligibleDate = getLatestEligibleHistoricalDate(
      _getCurrentTime(),
    );
    final effectiveEndDate = normEndDate.isAfter(latestEligibleDate)
        ? latestEligibleDate
        : normEndDate;

    // If requested interval contains no eligible historical days, return a meaningful typed failure
    if (normStartDate.isAfter(effectiveEndDate)) {
      final latestEligibleIso = DateFormat('yyyy-MM-dd')
          .format(latestEligibleDate);
      return FailureResult(
        InsufficientEvidenceFailure(
          userMessageAr:
              'الفترة المطلوبة تقع ضمن فترة تأخير نشر أرشيف ERA5-Land (5 أيام). آخر تاريخ متاح هو $latestEligibleIso.',
          technicalMessage:
              'Requested startDate ($normStartDate) is after the latest eligible archive date ($latestEligibleDate, 5-day publication delay).',
          missingRatio: 1.0,
          variableName: 'historical_archive_unreleased',
        ),
      );
    }

    final startIso = DateFormat('yyyy-MM-dd').format(normStartDate);
    final endIso = DateFormat('yyyy-MM-dd').format(effectiveEndDate);
    const datasetTag = 'openmeteo_era5land';
    // Exact requested-coordinate identity to guarantee strict cache isolation
    final cacheKey =
        'hist_${datasetTag}_${coordinate.latitude}_${coordinate.longitude}_${startIso}_$endIso';

    // 3. Check in-memory L1 cache with TTL and range/structural validation
    if (_memoryCache.containsKey(cacheKey)) {
      final entry = _memoryCache[cacheKey]!;
      if (entry.isFresh(isForecast: false, now: _getCurrentTime()) &&
          isHistoricalValid(entry.records, normStartDate, effectiveEndDate)) {
        return Success(entry.records);
      } else if (!isHistoricalValid(
        entry.records,
        normStartDate,
        effectiveEndDate,
      )) {
        _memoryCache.remove(cacheKey); // Evict corrupted L1 entry
      }
    }

    // 4. Check durable on-disk SQLite cache
    if (_localDataSource != null) {
      final cached = await _localDataSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: false,
        expectedStartDate: normStartDate,
        expectedEndDate: effectiveEndDate,
        now: _getCurrentTime(),
      );
      if (cached != null &&
          cached.isFresh &&
          isHistoricalValid(cached.records, normStartDate, effectiveEndDate)) {
        _memoryCache[cacheKey] = _MemoryCacheEntry(
          records: cached.records,
          storedAt: cached.cachedAt,
        );
        return Success(cached.records);
      }
    }

    try {
      final dto = await _remoteDataSource.fetchHistoricalDaily(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        startDateIso: startIso,
        endDateIso: endIso,
      );

      final expectedDays =
          effectiveEndDate.difference(normStartDate).inDays + 1;
      final domainResult = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coordinate,
        datasetLabel: 'ERA5-Land Reanalysis Archive',
        expectedStartDate: normStartDate,
        expectedEndDate: effectiveEndDate,
        expectedCount: expectedDays,
      );

      if (domainResult.isSuccess) {
        final records = domainResult.dataOrNull!;
        if (records.isNotEmpty) {
          final nowUtc = _getCurrentTime().toUtc();
          _memoryCache[cacheKey] = _MemoryCacheEntry(
            records: records,
            storedAt: nowUtc,
          );
          if (_localDataSource != null) {
            try {
              await _localDataSource.saveRecords(
                cacheKey: cacheKey,
                records: records,
                cachedAt: nowUtc,
              );
            } catch (e, st) {
              // Non-fatal write error: persistence failure does not discard validated network records
              developer.log(
                'Failed to persist historical weather cache for $cacheKey: $e',
                name: 'WeatherRepositoryImpl',
                error: e,
                stackTrace: st,
              );
            }
          }
        }
      }

      return domainResult;
    } on DioException catch (dioErr) {
      // Offline fallback: only allowed for transient network errors (connection, timeout, 5xx)
      // Non-transient errors (e.g. 400 Bad Request, 422) must not mask upstream rejections with stale data
      final isTransient = _isTransientNetworkError(dioErr);

      if (isTransient) {
        if (_localDataSource != null) {
          final offlineCached = await _localDataSource.getCachedRecords(
            cacheKey: cacheKey,
            isForecast: false,
            expectedStartDate: normStartDate,
            expectedEndDate: effectiveEndDate,
          );
          if (offlineCached != null &&
              offlineCached.records.isNotEmpty &&
              isHistoricalValid(
                offlineCached.records,
                normStartDate,
                effectiveEndDate,
              )) {
            final staleRecords = _markAsStale(offlineCached.records);
            _memoryCache[cacheKey] = _MemoryCacheEntry(
              records: staleRecords,
              storedAt: offlineCached.cachedAt,
            );
            return Success(staleRecords);
          }
        }

        if (_memoryCache.containsKey(cacheKey)) {
          final entry = _memoryCache[cacheKey]!;
          if (isHistoricalValid(
            entry.records,
            normStartDate,
            effectiveEndDate,
          )) {
            return Success(_markAsStale(entry.records));
          }
        }
      }

      final responseData = dioErr.response?.data;
      String? apiReason;
      if (responseData is Map && responseData['reason'] is String) {
        apiReason = responseData['reason'] as String;
      }
      final retryAfter = dioErr.response?.headers.value('retry-after');
      final retryNote = parseRetryAfterNote(retryAfter);

      return FailureResult(
        NetworkFailure(
          userMessageAr: apiReason != null
              ? 'تنبيه الأرصاد: $apiReason$retryNote'
              : (isTransient
                    ? 'تعذر الاتصال بخادم الأرصاد الجوية. لا تتوفر نسخة مخزنة مسبقاً لهذا الموقع.'
                    : 'طلب غير صالح أو تعذر الاستجابة من خادم الأرصاد الجوية.'),
          technicalMessage:
              '${apiReason ?? dioErr.message ?? 'DioException during historical weather fetch.'}$retryNote',
          statusCode: dioErr.response?.statusCode,
        ),
      );
    } on SocketException catch (sockErr) {
      // Offline fallback
      if (_localDataSource != null) {
        final offlineCached = await _localDataSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
          expectedStartDate: normStartDate,
          expectedEndDate: effectiveEndDate,
        );
        if (offlineCached != null &&
            offlineCached.records.isNotEmpty &&
            isHistoricalValid(
              offlineCached.records,
              normStartDate,
              effectiveEndDate,
            )) {
          final staleRecords = _markAsStale(offlineCached.records);
          _memoryCache[cacheKey] = _MemoryCacheEntry(
            records: staleRecords,
            storedAt: offlineCached.cachedAt,
          );
          return Success(staleRecords);
        }
      }

      if (_memoryCache.containsKey(cacheKey)) {
        final entry = _memoryCache[cacheKey]!;
        if (isHistoricalValid(entry.records, normStartDate, effectiveEndDate)) {
          return Success(_markAsStale(entry.records));
        }
      }

      return FailureResult(
        NetworkFailure(
          userMessageAr: 'لا يوجد اتصال بالشبكة ولا تتوفر بيانات مخزنة دون اتصال لهذا الموقع.',
          technicalMessage: sockErr.message,
        ),
      );
    } catch (e) {
      return FailureResult(
        ParsingFailure(
          userMessageAr: 'حدث خطأ غير متوقع أثناء معالجة بيانات الأرصاد.',
          technicalMessage: e.toString(),
        ),
      );
    }
  }

  /// Computes the current calendar date and time in Africa/Cairo timezone.
  /// Egypt standard time is UTC+2, and during Daylight Saving Time (last Friday of April to last Thursday of October) it is UTC+3.
  /// Transitions occur at:
  /// - Start (Summer Time UTC+3): At the stroke of midnight entering the last Friday of April
  ///   (00:00 Cairo Standard Time UTC+2 = 22:00 UTC on the preceding Thursday).
  /// - End (Standard Time UTC+2): At 24:00 (midnight) at the end of the last Thursday of October
  ///   (24:00 Cairo Summer Time UTC+3 = 21:00 UTC on the last Thursday of October).
  static DateTime getCairoDateTime([DateTime? referenceUtc]) {
    final utc = (referenceUtc ?? DateTime.now()).toUtc();
    final year = utc.year;

    // Find last Friday in April
    var aprilLastFridayDay = 30;
    while (DateTime.utc(year, 4, aprilLastFridayDay).weekday !=
        DateTime.friday) {
      aprilLastFridayDay--;
    }
    // Transition starts at 00:00 Cairo Standard Time (UTC+2) = 22:00 UTC on Thursday (day before last Friday)
    final dstStartUtc = DateTime.utc(year, 4, aprilLastFridayDay - 1, 22, 0, 0);

    // Find last Thursday in October
    var octLastThursdayDay = 31;
    while (DateTime.utc(year, 10, octLastThursdayDay).weekday !=
        DateTime.thursday) {
      octLastThursdayDay--;
    }
    // Transition ends at 24:00 Cairo Summer Time (UTC+3) = 21:00 UTC on the last Thursday
    final dstEndUtc = DateTime.utc(year, 10, octLastThursdayDay, 21, 0, 0);

    final isDst =
        (utc.isAfter(dstStartUtc) || utc.isAtSameMomentAs(dstStartUtc)) &&
        utc.isBefore(dstEndUtc);
    final offsetHours = isDst ? 3 : 2;
    return utc.add(Duration(hours: offsetHours));
  }

  /// Parses and formats the RFC 7231 Retry-After header into a diagnostic string.
  /// Supports both integer delay in seconds and HTTP-date formats.
  static String parseRetryAfterNote(
    String? rawHeader, [
    DateTime? nowReference,
  ]) {
    if (rawHeader == null || rawHeader.trim().isEmpty) {
      return '';
    }
    final trimmed = rawHeader.trim();

    // 1. Try parsing non-negative integer seconds
    final seconds = int.tryParse(trimmed);
    if (seconds != null) {
      if (seconds >= 0) {
        return ' (Retry-After: ${seconds}s)';
      }
      return '';
    }

    // 2. Try parsing HTTP-date (e.g. IMF-fixdate format: "Wed, 21 Oct 2026 07:28:00 GMT")
    try {
      final parsedDate = HttpDate.parse(trimmed);
      final now = (nowReference ?? DateTime.now()).toUtc();
      final diffSeconds = parsedDate.difference(now).inSeconds;
      if (diffSeconds > 0) {
        return ' (Retry-After: ${diffSeconds}s, until $trimmed)';
      }
      return ' (Retry-After: 0s, until $trimmed)';
    } catch (_) {
      // Unparseable / malformed Retry-After header: report safely without assuming seconds unit
      return ' (Retry-After: $trimmed)';
    }
  }

  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getForecastDailyRecords({
    required Coordinate coordinate,
    required int days,
  }) async {
    final coordVal = coordinate.validate();
    if (coordVal.isFailure) {
      return FailureResult(coordVal.failureOrNull!);
    }

    const datasetTag = 'openmeteo_ecmwf_dwd';
    // Incorporate current Cairo calendar date into forecast key to prevent yesterday's forecast from masquerading as future days
    final nowCairo = getCairoDateTime(_getCurrentTime());
    final todayIso = DateFormat('yyyy-MM-dd').format(nowCairo);
    // Exact requested-coordinate identity to guarantee strict cache isolation
    final cacheKey =
        'fc_${datasetTag}_${coordinate.latitude}_${coordinate.longitude}_${todayIso}_$days';

    // 1. Check in-memory L1 cache with TTL and sequence completeness
    if (_memoryCache.containsKey(cacheKey)) {
      final entry = _memoryCache[cacheKey]!;
      if (entry.isFresh(isForecast: true, now: _getCurrentTime()) &&
          isForecastValidForToday(
            entry.records,
            nowCairo,
            expectedDays: days,
          )) {
        return Success(entry.records);
      } else if (!isForecastValidForToday(
        entry.records,
        nowCairo,
        expectedDays: days,
      )) {
        _memoryCache.remove(cacheKey);
      }
    }

    // 2. Check durable on-disk SQLite cache
    if (_localDataSource != null) {
      final cached = await _localDataSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: true,
        now: _getCurrentTime(),
      );
      if (cached != null &&
          cached.isFresh &&
          isForecastValidForToday(
            cached.records,
            nowCairo,
            expectedDays: days,
          )) {
        _memoryCache[cacheKey] = _MemoryCacheEntry(
          records: cached.records,
          storedAt: cached.cachedAt,
        );
        return Success(cached.records);
      }
    }

    try {
      final dto = await _remoteDataSource.fetchForecastDaily(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        forecastDays: days,
      );

      final domainResult = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coordinate,
        datasetLabel: 'ECMWF/DWD High-Resolution Forecast',
      );

      if (domainResult.isSuccess) {
        final records = domainResult.dataOrNull!;
        final nowUtc = _getCurrentTime().toUtc();
        _memoryCache[cacheKey] = _MemoryCacheEntry(
          records: records,
          storedAt: nowUtc,
        );
        if (_localDataSource != null) {
          try {
            await _localDataSource.saveRecords(
              cacheKey: cacheKey,
              records: records,
              cachedAt: nowUtc,
            );
          } catch (e, st) {
            // Non-fatal write error
            developer.log(
              'Failed to persist forecast weather cache for $cacheKey: $e',
              name: 'WeatherRepositoryImpl',
              error: e,
              stackTrace: st,
            );
          }
        }
      }

      return domainResult;
    } on DioException catch (dioErr) {
      final isTransient = _isTransientNetworkError(dioErr);

      if (isTransient) {
        // Offline fallback: use previously cached forecast from SQLite if available, covering the full requested interval
        if (_localDataSource != null) {
          final offlineCached = await _localDataSource.getCachedRecords(
            cacheKey: cacheKey,
            isForecast: true,
          );
          if (offlineCached != null &&
              offlineCached.records.isNotEmpty &&
              isForecastValidForToday(
                offlineCached.records,
                nowCairo,
                expectedDays: days,
              )) {
            final staleRecords = _markAsStale(offlineCached.records);
            _memoryCache[cacheKey] = _MemoryCacheEntry(
              records: staleRecords,
              storedAt: offlineCached.cachedAt,
            );
            return Success(staleRecords);
          }
        }

        if (_memoryCache.containsKey(cacheKey)) {
          final entry = _memoryCache[cacheKey]!;
          if (isForecastValidForToday(
            entry.records,
            nowCairo,
            expectedDays: days,
          )) {
            return Success(_markAsStale(entry.records));
          }
        }
      }

      final responseData = dioErr.response?.data;
      String? apiReason;
      if (responseData is Map && responseData['reason'] is String) {
        apiReason = responseData['reason'] as String;
      }
      final retryAfter = dioErr.response?.headers.value('retry-after');
      final retryNote = parseRetryAfterNote(retryAfter);

      return FailureResult(
        NetworkFailure(
          userMessageAr: apiReason != null
              ? 'تنبيه الأرصاد: $apiReason$retryNote'
              : (isTransient
                    ? 'تعذر تحميل التوقعات الجوية. لا تتوفر توقعات مخزنة سابقة بدون اتصال.'
                    : 'طلب غير صالح أو خطأ من خادم الأرصاد الجوية.'),
          technicalMessage:
              '${apiReason ?? dioErr.message ?? 'DioException during forecast weather fetch.'}$retryNote',
          statusCode: dioErr.response?.statusCode,
        ),
      );
    } catch (e) {
      return FailureResult(
        ParsingFailure(
          userMessageAr: 'حدث خطأ أثناء معالجة بيانات التوقعات.',
          technicalMessage: e.toString(),
        ),
      );
    }
  }

  /// Evaluates whether an error represents a transient network fault eligible for stale fallback.
  bool _isTransientNetworkError(DioException dioErr) {
    switch (dioErr.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.transformTimeout:
        return true;
      case DioExceptionType.badResponse:
        final status = dioErr.response?.statusCode;
        // 5xx server errors and 429 (rate limiting) are transient and eligible for stale cache fallback.
        // 400, 422, 401, 403 are fatal/non-transient client errors and must not mask failures with stale data.
        if (status == 429) return true;
        return status != null && status >= 500 && status < 600;
      case DioExceptionType.unknown:
        return dioErr.error is SocketException;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  /// Validates that historical records are non-empty, in strictly ascending chronological order,
  /// have no duplicate dates, and fall within the requested date interval.
  /// (Permits gaps between records resulting from missing-temperature filtering).
  bool isHistoricalValid(
    List<DailyAgroRecord> records,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (records.isEmpty) return false;

    final normStart = DateTime.utc(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normEnd = DateTime.utc(endDate.year, endDate.month, endDate.day);
    DateTime? prevDate;

    for (final r in records) {
      final recDate = DateTime.utc(r.date.year, r.date.month, r.date.day);
      if (recDate.isBefore(normStart) || recDate.isAfter(normEnd)) {
        return false;
      }
      if (prevDate != null) {
        if (!recDate.isAfter(prevDate)) {
          return false; // Duplicate or out-of-order date
        }
      }
      prevDate = recDate;
    }

    return true;
  }

  /// Verifies that the forecast records form a valid, continuous, ascending daily sequence
  /// starting exactly on today's calendar date and covering the requested duration.
  bool isForecastValidForToday(
    List<DailyAgroRecord> records,
    DateTime now, {
    int? expectedDays,
  }) {
    if (records.isEmpty) return false;
    if (expectedDays != null && records.length < expectedDays) {
      return false;
    }

    final today = DateTime.utc(now.year, now.month, now.day);
    DateTime? prevDate;

    for (int i = 0; i < records.length; i++) {
      final recDate = DateTime.utc(
        records[i].date.year,
        records[i].date.month,
        records[i].date.day,
      );

      // 1. The first record MUST start on today's date (not before, not after)
      if (i == 0) {
        if (!recDate.isAtSameMomentAs(today)) {
          return false;
        }
      }

      // 2. Reject duplicate dates and non-chronological ordering
      if (prevDate != null) {
        if (!recDate.isAfter(prevDate)) {
          return false; // Duplicate or out-of-order date
        }
        // Ensure consecutive days without missing gaps in the forecast sequence
        final differenceInDays = recDate.difference(prevDate).inDays;
        if (differenceInDays != 1) {
          return false;
        }
      }

      prevDate = recDate;
    }

    return true;
  }

  /// Explicitly marks cached records as offline fallback / stale data in their provenance metadata
  List<DailyAgroRecord> _markAsStale(List<DailyAgroRecord> records) {
    const offlineNote =
        '(ملاحظة: البيانات معروضة من الذاكرة المؤقتة لعدم توفر اتصال بالشبكة).';
    return records.map((r) {
      final p = r.provenance;
      final staleDisclaimer =
          p.scientificDisclaimerAr.contains('الذاكرة المؤقتة')
          ? p.scientificDisclaimerAr
          : '${p.scientificDisclaimerAr} $offlineNote';

      final staleProvenance = DataSourceProvenance(
        providerName: p.providerName,
        datasetName: p.datasetName, // Preserve pure scientific dataset identity
        requestedLatitude: p.requestedLatitude,
        requestedLongitude: p.requestedLongitude,
        gridLatitude: p.gridLatitude,
        gridLongitude: p.gridLongitude,
        gridElevationMeters: p.gridElevationMeters,
        acquisitionTimestamp: p.acquisitionTimestamp,
        scientificDisclaimerAr: staleDisclaimer,
        isStaleFallback: true, // Dedicated freshness state flag
      );

      return DailyAgroRecord(
        date: r.date,
        maxTemperatureC: r.maxTemperatureC,
        minTemperatureC: r.minTemperatureC,
        precipitationMm: r.precipitationMm,
        referenceEt0Mm: r.referenceEt0Mm,
        provenance: staleProvenance,
      );
    }).toList();
  }
}
