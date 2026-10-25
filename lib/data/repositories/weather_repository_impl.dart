import 'dart:developer' as developer;
import 'dart:io';

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

/// Concrete implementation of IWeatherRepository connecting to Open-Meteo with persistent caching.
class WeatherRepositoryImpl implements IWeatherRepository {
  final OpenMeteoRemoteDataSource _remoteDataSource;
  final WeatherLocalDataSource? _localDataSource;

  // In-memory L1 cache for fast hot-lookup
  final Map<String, List<DailyAgroRecord>> _memoryCache = {};

  WeatherRepositoryImpl({
    OpenMeteoRemoteDataSource? remoteDataSource,
    this._localDataSource,
  }) : _remoteDataSource = remoteDataSource ?? OpenMeteoRemoteDataSource();

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

    final now = DateTime.now();
    // Historical archive endpoint allows dates up to current date (e.g. today).
    // Future dates beyond today are not permitted by the archive API.
    final effectiveEndDate = endDate.isAfter(now) ? now : endDate;
    if (startDate.isAfter(effectiveEndDate)) {
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

    final startIso = DateFormat('yyyy-MM-dd').format(startDate);
    final endIso = DateFormat('yyyy-MM-dd').format(effectiveEndDate);
    const datasetTag = 'openmeteo_era5land';
    // Exact requested-coordinate identity to guarantee strict cache isolation
    final cacheKey =
        'hist_${datasetTag}_${coordinate.latitude}_${coordinate.longitude}_${startIso}_$endIso';

    // 2. Check in-memory L1 cache
    if (_memoryCache.containsKey(cacheKey)) {
      return Success(_memoryCache[cacheKey]!);
    }

    // 3. Check durable on-disk SQLite cache
    if (_localDataSource != null) {
      final cached = await _localDataSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: false,
      );
      if (cached != null && cached.isFresh) {
        _memoryCache[cacheKey] = cached.records;
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

      final domainResult = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coordinate,
        datasetLabel: 'ERA5-Land Reanalysis Archive',
      );

      if (domainResult.isSuccess) {
        final records = domainResult.dataOrNull!;
        _memoryCache[cacheKey] = records;
        if (_localDataSource != null) {
          try {
            await _localDataSource.saveRecords(
              cacheKey: cacheKey,
              records: records,
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
          );
          if (offlineCached != null && offlineCached.records.isNotEmpty) {
            final staleRecords = _markAsStale(offlineCached.records);
            _memoryCache[cacheKey] = staleRecords;
            return Success(staleRecords);
          }
        }

        if (_memoryCache.containsKey(cacheKey)) {
          return Success(_markAsStale(_memoryCache[cacheKey]!));
        }
      }

      final responseData = dioErr.response?.data;
      String? apiReason;
      if (responseData is Map && responseData['reason'] is String) {
        apiReason = responseData['reason'] as String;
      }
      final retryAfter = dioErr.response?.headers.value('retry-after');
      final retryNote = retryAfter != null
          ? ' (Retry-After: ${retryAfter}s)'
          : '';

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
        );
        if (offlineCached != null && offlineCached.records.isNotEmpty) {
          final staleRecords = _markAsStale(offlineCached.records);
          _memoryCache[cacheKey] = staleRecords;
          return Success(staleRecords);
        }
      }

      if (_memoryCache.containsKey(cacheKey)) {
        return Success(_markAsStale(_memoryCache[cacheKey]!));
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
    final nowCairo = getCairoDateTime();
    final todayIso = DateFormat('yyyy-MM-dd').format(nowCairo);
    // Exact requested-coordinate identity to guarantee strict cache isolation
    final cacheKey =
        'fc_${datasetTag}_${coordinate.latitude}_${coordinate.longitude}_${todayIso}_$days';

    // 1. Check in-memory L1 cache (and ensure records match today and full interval)
    if (_memoryCache.containsKey(cacheKey)) {
      final memRecords = _memoryCache[cacheKey]!;
      if (isForecastValidForToday(memRecords, nowCairo, expectedDays: days)) {
        return Success(memRecords);
      } else {
        _memoryCache.remove(cacheKey);
      }
    }

    // 2. Check durable on-disk SQLite cache
    if (_localDataSource != null) {
      final cached = await _localDataSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: true,
      );
      if (cached != null &&
          cached.isFresh &&
          isForecastValidForToday(
            cached.records,
            nowCairo,
            expectedDays: days,
          )) {
        _memoryCache[cacheKey] = cached.records;
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
        _memoryCache[cacheKey] = records;
        if (_localDataSource != null) {
          try {
            await _localDataSource.saveRecords(
              cacheKey: cacheKey,
              records: records,
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
            _memoryCache[cacheKey] = staleRecords;
            return Success(staleRecords);
          }
        }

        if (_memoryCache.containsKey(cacheKey)) {
          final mem = _memoryCache[cacheKey]!;
          if (isForecastValidForToday(mem, nowCairo, expectedDays: days)) {
            return Success(_markAsStale(mem));
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
