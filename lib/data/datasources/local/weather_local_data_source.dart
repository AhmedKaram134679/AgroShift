import 'package:drift/drift.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';
import 'package:agro_shift/domain/environment/models/data_source_provenance.dart';
import 'package:agro_shift/domain/validation/scientific_range_validator.dart';

import 'database/app_database.dart';
import 'cache_policy.dart';

/// Manages on-disk SQLite caching of daily agro-meteorological records via Drift.
class WeatherLocalDataSource {
  final AppDatabase _db;

  WeatherLocalDataSource(this._db);

  /// Retrieves cached daily records for a given cache key.
  /// Validates structural integrity (order, uniqueness, range boundaries, scientific ranges, and metadata consistency).
  /// Returns null if no records are found or if the cache entry fails integrity validation.
  Future<CacheLookupResult?> getCachedRecords({
    required String cacheKey,
    required bool isForecast,
    DateTime? expectedStartDate,
    DateTime? expectedEndDate,
    DateTime? now,
  }) async {
    try {
      final rows =
          await (_db.select(_db.cachedDailyRecordsTable)
                ..where((t) => t.cacheKey.equals(cacheKey))
                ..orderBy([(t) => OrderingTerm(expression: t.recordDate)]))
              .get();

      if (rows.isEmpty) {
        return null;
      }

      final cachedAt = rows.first.cachedAt;
      final isFresh = CachePolicy.isFresh(
        cachedAt: cachedAt,
        isForecast: isForecast,
        now: now,
      );

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

      if (normalizedExpectedStart != null &&
          normalizedExpectedEnd != null &&
          normalizedExpectedEnd.isBefore(normalizedExpectedStart)) {
        return null;
      }

      final expectedDays =
          (normalizedExpectedStart != null && normalizedExpectedEnd != null)
          ? normalizedExpectedEnd.difference(normalizedExpectedStart).inDays + 1
          : null;

      final List<DailyAgroRecord> records = [];
      DateTime? prevDate;

      for (final row in rows) {
        // 1. Verify shared cache metadata consistency across all rows in this entry
        if (row.cachedAt != cachedAt) {
          return null; // Inconsistent cache metadata within single entry
        }

        // 2. Validate canonical calendar date in UTC
        final recDate = DateTime.utc(
          row.recordDate.year,
          row.recordDate.month,
          row.recordDate.day,
        );

        // 3. Reject duplicate or non-ascending record dates and enforce contiguous days
        if (prevDate != null) {
          if (!recDate.isAfter(prevDate)) {
            return null; // Duplicate or out-of-order date
          }
          if (normalizedExpectedStart != null &&
              normalizedExpectedEnd != null &&
              recDate.difference(prevDate).inDays != 1) {
            return null; // Missing day / gap in expected date sequence
          }
        }
        prevDate = recDate;

        // 4. Reject records whose dates fall outside the requested range
        if (normalizedExpectedStart != null &&
            recDate.isBefore(normalizedExpectedStart)) {
          return null;
        }
        if (normalizedExpectedEnd != null &&
            recDate.isAfter(normalizedExpectedEnd)) {
          return null;
        }

        // 5. Validate range constraints on persisted records to safeguard against corrupt data
        if (row.maxTemperatureC != null && row.minTemperatureC != null) {
          final tempVal = ScientificRangeValidator.validateTemperature(
            tMax: row.maxTemperatureC!,
            tMin: row.minTemperatureC!,
          );
          if (tempVal.isFailure) {
            return null; // Corrupted cache entry should not be consumed
          }
        }

        final et0Val = ScientificRangeValidator.validateEt0(row.referenceEt0Mm);
        if (et0Val.isFailure) {
          return null;
        }

        final pVal = ScientificRangeValidator.validatePrecipitation(
          row.precipitationMm,
        );
        if (pVal.isFailure) {
          return null;
        }

        final provenance = DataSourceProvenance(
          providerName: row.providerName,
          datasetName: row.datasetName,
          requestedLatitude: row.requestedLatitude,
          requestedLongitude: row.requestedLongitude,
          gridLatitude: row.gridLatitude,
          gridLongitude: row.gridLongitude,
          gridElevationMeters: row.gridElevationMeters,
          acquisitionTimestamp: row.acquisitionTimestamp.toUtc(),
          scientificDisclaimerAr: row.scientificDisclaimerAr,
          expectedPeriodDays: expectedDays,
        );

        records.add(
          DailyAgroRecord(
            date: recDate,
            maxTemperatureC: row.maxTemperatureC,
            minTemperatureC: row.minTemperatureC,
            precipitationMm:
                row.precipitationMm, // Strictly preserves null vs 0.0
            referenceEt0Mm: row.referenceEt0Mm, // Strictly preserves null
            provenance: provenance,
          ),
        );
      }

      // 6. Verify complete range coverage when an expected interval was specified
      if (normalizedExpectedStart != null && normalizedExpectedEnd != null) {
        if (expectedDays != null && records.length != expectedDays) {
          return null; // Record count does not match expected calendar days
        }
        if (records.isEmpty) {
          return null;
        }
        final firstDate = DateTime.utc(
          records.first.date.year,
          records.first.date.month,
          records.first.date.day,
        );
        final lastDate = DateTime.utc(
          records.last.date.year,
          records.last.date.month,
          records.last.date.day,
        );
        if (firstDate != normalizedExpectedStart ||
            lastDate != normalizedExpectedEnd) {
          return null; // Boundary dates do not match requested start and end dates
        }
      }

      return CacheLookupResult(
        records: records,
        cachedAt: cachedAt,
        isFresh: isFresh,
      );
    } catch (_) {
      return null;
    }
  }

  /// Saves a list of DailyAgroRecord entities to the database under the given cacheKey.
  Future<void> saveRecords({
    required String cacheKey,
    required List<DailyAgroRecord> records,
    DateTime? cachedAt,
  }) async {
    if (records.isEmpty) return;

    final storageTime = cachedAt ?? DateTime.now();

    // Use a transaction to replace old cached rows for this key cleanly
    await _db.transaction(() async {
      await (_db.delete(
        _db.cachedDailyRecordsTable,
      )..where((t) => t.cacheKey.equals(cacheKey))).go();

      for (final r in records) {
        await _db
            .into(_db.cachedDailyRecordsTable)
            .insert(
              CachedDailyRecordsTableCompanion(
                cacheKey: Value(cacheKey),
                recordDate: Value(r.date),
                maxTemperatureC: Value(r.maxTemperatureC),
                minTemperatureC: Value(r.minTemperatureC),
                precipitationMm: Value(r.precipitationMm),
                referenceEt0Mm: Value(r.referenceEt0Mm),
                providerName: Value(r.provenance.providerName),
                datasetName: Value(r.provenance.datasetName),
                requestedLatitude: Value(r.provenance.requestedLatitude),
                requestedLongitude: Value(r.provenance.requestedLongitude),
                gridLatitude: Value(r.provenance.gridLatitude),
                gridLongitude: Value(r.provenance.gridLongitude),
                gridElevationMeters: Value(r.provenance.gridElevationMeters),
                acquisitionTimestamp: Value(r.provenance.acquisitionTimestamp),
                scientificDisclaimerAr: Value(
                  r.provenance.scientificDisclaimerAr,
                ),
                cachedAt: Value(storageTime),
              ),
            );
      }
    });
  }

  /// Clears cache entries for a given key.
  Future<void> clearCache(String cacheKey) async {
    await (_db.delete(
      _db.cachedDailyRecordsTable,
    )..where((t) => t.cacheKey.equals(cacheKey))).go();
  }
}
