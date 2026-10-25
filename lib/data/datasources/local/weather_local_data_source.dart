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
  /// Returns null if no records are found.
  Future<CacheLookupResult?> getCachedRecords({
    required String cacheKey,
    required bool isForecast,
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
      );

      final List<DailyAgroRecord> records = [];
      for (final row in rows) {
        // Validate range constraints on persisted records to safeguard against corrupt data
        final tempVal = ScientificRangeValidator.validateTemperature(
          tMax: row.maxTemperatureC,
          tMin: row.minTemperatureC,
        );
        if (tempVal.isFailure) {
          return null; // Corrupted cache entry should not be consumed
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
        );

        records.add(
          DailyAgroRecord(
            date: row.recordDate.toUtc(),
            maxTemperatureC: row.maxTemperatureC,
            minTemperatureC: row.minTemperatureC,
            precipitationMm:
                row.precipitationMm, // Strictly preserves null vs 0.0
            referenceEt0Mm: row.referenceEt0Mm, // Strictly preserves null
            provenance: provenance,
          ),
        );
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
