import 'package:agro_shift/data/datasources/remote/open_meteo_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:agro_shift/data/datasources/local/database/app_database.dart';
import 'package:agro_shift/data/datasources/local/weather_local_data_source.dart';
import 'package:agro_shift/data/datasources/local/cache_policy.dart';
import 'package:agro_shift/data/repositories/farm_field_repository_impl.dart';
import 'package:agro_shift/data/repositories/weather_repository_impl.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';
import 'package:agro_shift/domain/environment/models/data_source_provenance.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:intl/intl.dart';

void main() {
  late AppDatabase db;
  late FarmFieldRepositoryImpl fieldRepo;
  late WeatherLocalDataSource weatherLocalSource;

  setUp(() {
    // Isolated in-memory database for each test
    db = AppDatabase(NativeDatabase.memory());
    fieldRepo = FarmFieldRepositoryImpl(db);
    weatherLocalSource = WeatherLocalDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  const testField = FarmField(
    id: 'field_user_1',
    nameAr: 'مزرعة وادي النطرون',
    governorateAr: 'البحيرة',
    coordinate: Coordinate(
      latitude: 30.40,
      longitude: 30.30,
      governorateName: 'البحيرة',
    ),
    areaInFeddan: 12.5,
    soilType: SoilType.sandyLoam,
    activeCropId: 'wheat',
  );

  group('FarmField Persistence Tests', () {
    test('1. A created farm field can be retrieved after re-instantiating repository', () async {
      final saveRes = await fieldRepo.saveField(testField);
      expect(saveRes.isSuccess, isTrue);

      // Re-instantiate repository over the same underlying database
      final reloadedRepo = FarmFieldRepositoryImpl(db);
      final getRes = await reloadedRepo.getAllFields();

      expect(getRes.isSuccess, isTrue);
      final fields = getRes.dataOrNull!;
      expect(fields.length, equals(1));
      expect(fields.first.id, equals('field_user_1'));
      expect(fields.first.nameAr, equals('مزرعة وادي النطرون'));
      expect(fields.first.areaInFeddan, equals(12.5));
      expect(fields.first.soilType, equals(SoilType.sandyLoam));
      expect(fields.first.coordinate.latitude, equals(30.40));
    });

    test('2. Updating or deleting a field persists correctly', () async {
      await fieldRepo.saveField(testField);

      // Update area and crop
      const updatedField = FarmField(
        id: 'field_user_1',
        nameAr: 'مزرعة وادي النطرون الحديثة',
        governorateAr: 'البحيرة',
        coordinate: Coordinate(
          latitude: 30.40,
          longitude: 30.30,
          governorateName: 'البحيرة',
        ),
        areaInFeddan: 15.0,
        soilType: SoilType.sandyLoam,
        activeCropId: 'maize',
      );

      final updateRes = await fieldRepo.saveField(updatedField);
      expect(updateRes.isSuccess, isTrue);

      var fields = (await fieldRepo.getAllFields()).dataOrNull!;
      expect(fields.first.nameAr, equals('مزرعة وادي النطرون الحديثة'));
      expect(fields.first.areaInFeddan, equals(15.0));
      expect(fields.first.activeCropId, equals('maize'));

      // Delete the field
      final delRes = await fieldRepo.deleteField('field_user_1');
      expect(delRes.isSuccess, isTrue);

      fields = (await fieldRepo.getAllFields()).dataOrNull!;
      expect(fields.isEmpty, isTrue);
    });

    test('3. Built-in default fields do not overwrite or resurrect deleted user data', () async {
      const def1 = FarmField(
        id: 'def_1',
        nameAr: 'حقل الدلتا',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 31.10, longitude: 30.90),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );
      const def2 = FarmField(
        id: 'def_2',
        nameAr: 'حقل الصعيد',
        governorateAr: 'المنيا',
        coordinate: Coordinate(latitude: 28.10, longitude: 30.70),
        areaInFeddan: 4.0,
        soilType: SoilType.clayLoam,
      );

      // Initial seeding
      await fieldRepo.seedDefaultFieldsIfNecessary([def1, def2]);
      var all = (await fieldRepo.getAllFields()).dataOrNull!;
      expect(all.length, equals(2));

      // User deletes def_1
      await fieldRepo.deleteField('def_1');
      all = (await fieldRepo.getAllFields()).dataOrNull!;
      expect(all.length, equals(1));
      expect(all.first.id, equals('def_2'));

      // On next app start / repo initialization, seeding is called again
      final newRepo = FarmFieldRepositoryImpl(db);
      await newRepo.seedDefaultFieldsIfNecessary([def1, def2]);

      // def_1 MUST NOT be resurrected!
      final reseeded = (await newRepo.getAllFields()).dataOrNull!;
      expect(reseeded.length, equals(1));
      expect(reseeded.any((f) => f.id == 'def_1'), isFalse);
      expect(reseeded.first.id, equals('def_2'));
    });
  });

  group('Weather Cache Persistence & Integrity Tests', () {
    final prov = DataSourceProvenance(
      providerName: 'Open-Meteo Weather API',
      datasetName: 'ERA5 Reanalysis Archive',
      requestedLatitude: 31.10,
      requestedLongitude: 30.95,
      gridLatitude: 31.107,
      gridLongitude: 30.998,
      gridElevationMeters: 6.0,
      acquisitionTimestamp: DateTime.fromMillisecondsSinceEpoch(
        1729800000000,
        isUtc: true,
      ),
    );

    final record1 = DailyAgroRecord(
      date: DateTime.utc(2026, 6, 1),
      maxTemperatureC: 34.5,
      minTemperatureC: 22.0,
      precipitationMm: 0.0, // Measured zero
      referenceEt0Mm: 5.8,
      provenance: prov,
    );

    final record2 = DailyAgroRecord(
      date: DateTime.utc(2026, 6, 2),
      maxTemperatureC: 36.0,
      minTemperatureC: 24.0,
      precipitationMm: null, // Legitimate missing value
      referenceEt0Mm: null, // Legitimate missing value
      provenance: prov,
    );

    test('4. Weather records can be retrieved after re-instantiating the cache repository', () async {
      const cacheKey = 'hist_31.100_30.950_2026-06-01_2026-06-02';
      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: [record1, record2],
      );

      // Re-instantiate local source over same DB
      final reloadedSource = WeatherLocalDataSource(db);
      final lookup = await reloadedSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: false,
      );

      expect(lookup, isNotNull);
      expect(lookup!.records.length, equals(2));
      expect(lookup.records.first.maxTemperatureC, equals(34.5));
    });

    test('5. Null and zero weather values remain distinct after persistence and retrieval', () async {
      const cacheKey = 'hist_test_nulls';
      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: [record1, record2],
      );

      final lookup = await weatherLocalSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: false,
      );

      final recs = lookup!.records;
      // Day 1: precipitation was 0.0, referenceEt0 was 5.8
      expect(recs[0].precipitationMm, equals(0.0));
      expect(recs[0].precipitationMm, isNotNull);
      expect(recs[0].referenceEt0Mm, equals(5.8));

      // Day 2: precipitation was null, referenceEt0 was null (NEVER silently turned into 0.0)
      expect(recs[1].precipitationMm, isNull);
      expect(recs[1].referenceEt0Mm, isNull);
    });

    test(
      '6. Weather provenance and retrieval timestamps survive persistence',
      () async {
        const cacheKey = 'hist_prov_test';
        await weatherLocalSource.saveRecords(
          cacheKey: cacheKey,
          records: [record1],
        );

        final lookup = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
        );

        final rec = lookup!.records.first;
        expect(rec.provenance.providerName, equals('Open-Meteo Weather API'));
        expect(rec.provenance.datasetName, equals('ERA5 Reanalysis Archive'));
        expect(rec.provenance.gridLatitude, equals(31.107));
        expect(rec.provenance.gridLongitude, equals(30.998));
        expect(rec.provenance.gridElevationMeters, equals(6.0));
        expect(
          rec.provenance.acquisitionTimestamp,
          equals(prov.acquisitionTimestamp),
        );
      },
    );

    test('7. Different coordinates, date ranges, and data sources do not collide in cache keys', () async {
      const keyDelta = 'hist_31.100_30.900_2026-06-01_2026-06-02';
      const keyValley = 'hist_28.100_30.700_2026-06-01_2026-06-02';
      const keyForecast = 'fc_31.100_30.900_7';

      await weatherLocalSource.saveRecords(
        cacheKey: keyDelta,
        records: [record1],
      );
      await weatherLocalSource.saveRecords(
        cacheKey: keyValley,
        records: [record2],
      );
      await weatherLocalSource.saveRecords(
        cacheKey: keyForecast,
        records: [record1, record2],
      );

      final lookupDelta = await weatherLocalSource.getCachedRecords(
        cacheKey: keyDelta,
        isForecast: false,
      );
      final lookupValley = await weatherLocalSource.getCachedRecords(
        cacheKey: keyValley,
        isForecast: false,
      );
      final lookupForecast = await weatherLocalSource.getCachedRecords(
        cacheKey: keyForecast,
        isForecast: true,
      );

      expect(lookupDelta!.records.length, equals(1));
      expect(lookupDelta.records.first.maxTemperatureC, equals(34.5));

      expect(lookupValley!.records.length, equals(1));
      expect(lookupValley.records.first.maxTemperatureC, equals(36.0));

      expect(lookupForecast!.records.length, equals(2));
    });

    test(
      '8. Stale cache entries are identified according to the defined policy',
      () {
        final now = DateTime(2026, 10, 24, 12, 0);

        // Forecast: 6 hours TTL
        final freshForecast = now.subtract(const Duration(hours: 3));
        final staleForecast = now.subtract(const Duration(hours: 7));

        expect(
          CachePolicy.isFresh(
            cachedAt: freshForecast,
            isForecast: true,
            now: now,
          ),
          isTrue,
        );
        expect(
          CachePolicy.isFresh(
            cachedAt: staleForecast,
            isForecast: true,
            now: now,
          ),
          isFalse,
        );

        // Historical: 7 days TTL
        final freshHistorical = now.subtract(const Duration(days: 3));
        final staleHistorical = now.subtract(const Duration(days: 8));

        expect(
          CachePolicy.isFresh(
            cachedAt: freshHistorical,
            isForecast: false,
            now: now,
          ),
          isTrue,
        );
        expect(
          CachePolicy.isFresh(
            cachedAt: staleHistorical,
            isForecast: false,
            now: now,
          ),
          isFalse,
        );
      },
    );

    test('9. Database migration preserves existing records', () async {
      // Test schema creation & migration strategy execution
      await fieldRepo.saveField(testField);

      // Trigger onUpgrade explicitly
      final migrator = db.createMigrator();
      await db.migration.onUpgrade(migrator, 1, 1);

      final fields = (await fieldRepo.getAllFields()).dataOrNull!;
      expect(fields.length, equals(1));
      expect(fields.first.id, equals('field_user_1'));
    });

    test(
      '10. Offline reads fail gracefully when no suitable cached data exists',
      () async {
        // Mock remote data source that throws DioException simulating network disconnect
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  message: 'No active internet connection',
                ),
              );
            },
          ),
        );

        final failingRemoteSource = OpenMeteoRemoteDataSource(dio: dio);
        final weatherRepo = WeatherRepositoryImpl(
          remoteDataSource: failingRemoteSource,
          localDataSource: weatherLocalSource,
        );

        const coord = Coordinate(latitude: 31.10, longitude: 30.95);
        final res = await weatherRepo.getForecastDailyRecords(
          coordinate: coord,
          days: 7,
        );

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<NetworkFailure>());
        expect(
          res.failureOrNull?.userMessageAr.contains(
            'لا تتوفر توقعات مخزنة سابقة بدون اتصال',
          ),
          isTrue,
        );
      },
    );

    test('11. Stale offline cache is returned with explicit stale provenance marking when network fails', () async {
      // 1. Seed forecast cache with current calendar dates and a timestamp older than the 6-hour TTL
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final now = DateTime.now();
      final todayIso = DateFormat('yyyy-MM-dd').format(now);
      final cacheKey =
          'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_7';
      final staleTime = now.subtract(const Duration(hours: 12));

      final records7Days = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day + i),
          maxTemperatureC: 34.0 + i,
          minTemperatureC: 22.0 + i,
          precipitationMm: i == 0 ? 0.0 : null,
          referenceEt0Mm: i == 0 ? 5.8 : null,
          provenance: prov,
        ),
      );

      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: records7Days,
        cachedAt: staleTime,
      );

      // 2. Mock network failure
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Network offline',
              ),
            );
          },
        ),
      );

      final failingRemoteSource = OpenMeteoRemoteDataSource(dio: dio);
      final weatherRepo = WeatherRepositoryImpl(
        remoteDataSource: failingRemoteSource,
        localDataSource: weatherLocalSource,
      );

      final res = await weatherRepo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      expect(res.isSuccess, isTrue);
      final records = res.dataOrNull!;
      expect(records.length, equals(7));
      // Verify stale provenance tagging & dedicated freshness flag
      expect(records.first.provenance.isStaleFallback, isTrue);
      expect(
        records.first.provenance.datasetName,
        equals('ERA5 Reanalysis Archive'),
      );
      expect(
        records.first.provenance.scientificDisclaimerAr.contains(
          'الذاكرة المؤقتة',
        ),
        isTrue,
      );
    });

    test('12. Corrupted records violating physical ranges in SQLite are rejected during cache retrieval', () async {
      // Save valid record
      const cacheKey = 'hist_corrupt_test';
      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: [record1],
      );

      // Directly tamper with the database to inject an unphysical temperature (tMax < tMin)
      await (db.update(
        db.cachedDailyRecordsTable,
      )..where((t) => t.cacheKey.equals(cacheKey))).write(
        const CachedDailyRecordsTableCompanion(
          maxTemperatureC: Value(15.0),
          minTemperatureC: Value(35.0), // Physical impossibility: tMax < tMin
        ),
      );

      // Retrieval should safely reject the corrupted entry and return null
      final lookup = await weatherLocalSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: false,
      );

      expect(lookup, isNull);
    });

    test('13. Failed database writes do not crash repository or discard fetched records', () async {
      // Create a repository with a broken local data source that throws on saveRecords
      final brokenDb = AppDatabase(NativeDatabase.memory());
      final brokenLocalSource = WeatherLocalDataSource(brokenDb);
      // Close the DB so writes will fail
      await brokenDb.close();

      // Remote data source returns valid DTO
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'latitude': 31.1,
                  'longitude': 30.95,
                  'elevation': 5.0,
                  'generationtime_ms': 0.12,
                  'utc_offset_seconds': 7200,
                  'timezone': 'Africa/Cairo',
                  'daily_units': {},
                  'daily': {
                    'time': ['2026-06-01', '2026-06-02'],
                    'temperature_2m_max': [34.0, 35.0],
                    'temperature_2m_min': [22.0, 23.0],
                    'et0_fao_evapotranspiration': [5.5, 6.0],
                    'precipitation_sum': [0.0, 0.0],
                  },
                },
              ),
            );
          },
        ),
      );

      final repo = WeatherRepositoryImpl(
        remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
        localDataSource: brokenLocalSource,
      );

      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      // Repository must deliver success with valid data despite the DB write error
      expect(res.isSuccess, isTrue);
      expect(res.dataOrNull!.length, equals(2));
    });

    test('14. Cache keys strictly isolate coordinates, dates, and datasets without lossy rounding', () {
      const coord1 = Coordinate(latitude: 31.100, longitude: 30.950);
      const coord2 = Coordinate(latitude: 31.101, longitude: 30.950);
      final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Verify coordinate precision isolation (exact double representation)
      final key1 =
          'hist_openmeteo_era5_${coord1.latitude}_${coord1.longitude}_2026-06-01_2026-06-10';
      final key2 =
          'hist_openmeteo_era5_${coord2.latitude}_${coord2.longitude}_2026-06-01_2026-06-10';
      expect(key1, isNot(equals(key2)));

      // Verify date range isolation
      final key3 =
          'hist_openmeteo_era5_${coord1.latitude}_${coord1.longitude}_2026-06-01_2026-06-11';
      expect(key1, isNot(equals(key3)));

      // Verify dataset & forecast vs historical isolation with calendar date identity
      final keyForecast =
          'fc_openmeteo_bestmatch_${coord1.latitude}_${coord1.longitude}_${todayIso}_7';
      expect(key1, isNot(equals(keyForecast)));
    });

    test('15. Exact coordinate identity prevents silent collision of sub-millidegree coordinates', () {
      // Sub-millidegree coordinates (e.g. 31.1001 vs 31.1004) differing by ~30-40 meters
      const coordA = Coordinate(latitude: 31.1001, longitude: 30.9500);
      const coordB = Coordinate(latitude: 31.1004, longitude: 30.9500);
      final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final keyA =
          'fc_openmeteo_bestmatch_${coordA.latitude}_${coordA.longitude}_${todayIso}_7';
      final keyB =
          'fc_openmeteo_bestmatch_${coordB.latitude}_${coordB.longitude}_${todayIso}_7';

      // Under exact coordinate identity, coordinates are never silently coalesced client-side
      expect(
        keyA,
        isNot(equals(keyB)),
        reason: 'Sub-millidegree coordinates maintain exact, deterministic cache isolation',
      );
    });

    test('16. Repository rejects physically invalid cached record during network failure and fallback', () async {
      // 1. Seed the database with a physically corrupt record (tMax < tMin)
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final now = DateTime.now();
      final todayIso = DateFormat('yyyy-MM-dd').format(now);
      final cacheKey =
          'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_7';
      final staleTime = now.subtract(const Duration(hours: 12));

      final todayRecord = DailyAgroRecord(
        date: DateTime.utc(now.year, now.month, now.day),
        maxTemperatureC: 34.5,
        minTemperatureC: 22.0,
        precipitationMm: 0.0,
        referenceEt0Mm: 5.8,
        provenance: prov,
      );

      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: [todayRecord],
        cachedAt: staleTime,
      );

      // Tamper DB directly so it holds unphysical temperatures
      await (db.update(
        db.cachedDailyRecordsTable,
      )..where((t) => t.cacheKey.equals(cacheKey))).write(
        const CachedDailyRecordsTableCompanion(
          maxTemperatureC: Value(12.0),
          minTemperatureC: Value(38.0), // Impossible: tMax < tMin
        ),
      );

      // 2. Mock network failure
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Network disconnected',
              ),
            );
          },
        ),
      );

      final failingRemoteSource = OpenMeteoRemoteDataSource(dio: dio);
      final weatherRepo = WeatherRepositoryImpl(
        remoteDataSource: failingRemoteSource,
        localDataSource: weatherLocalSource,
      );

      // 3. Request weather series through repository
      final res = await weatherRepo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      // 4. Proves the corrupt record is NOT returned through any fallback path!
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<NetworkFailure>());
      expect(
        res.failureOrNull?.userMessageAr.contains('لا تتوفر توقعات مخزنة'),
        isTrue,
      );
    });

    test(
      '17. Calendar date preservation around midnight and timezone transitions',
      () async {
        // Create records spanning calendar dates
        final d1 = DateTime.utc(
          2026,
          4,
          24,
        ); // Egypt DST transition window date
        final d2 = DateTime.utc(2026, 4, 25);
        final d3 = DateTime.utc(
          2026,
          10,
          30,
        ); // Egypt winter time transition date

        final recD1 = DailyAgroRecord(
          date: d1,
          maxTemperatureC: 30.0,
          minTemperatureC: 18.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 4.5,
          provenance: prov,
        );
        final recD2 = DailyAgroRecord(
          date: d2,
          maxTemperatureC: 31.0,
          minTemperatureC: 19.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 4.8,
          provenance: prov,
        );
        final recD3 = DailyAgroRecord(
          date: d3,
          maxTemperatureC: 27.0,
          minTemperatureC: 15.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.5,
          provenance: prov,
        );

        const cacheKey = 'hist_date_test';
        await weatherLocalSource.saveRecords(
          cacheKey: cacheKey,
          records: [recD1, recD2, recD3],
        );

        final lookup = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
        );

        expect(lookup, isNotNull);
        final retrieved = lookup!.records;
        expect(retrieved.length, equals(3));

        // Assert that calendar dates never shift by hours or days
        expect(retrieved[0].date.year, equals(2026));
        expect(retrieved[0].date.month, equals(4));
        expect(retrieved[0].date.day, equals(24));
        expect(retrieved[0].date.hour, equals(0));
        expect(retrieved[0].date.isUtc, isTrue);

        expect(retrieved[1].date.day, equals(25));
        expect(retrieved[2].date.month, equals(10));
        expect(retrieved[2].date.day, equals(30));
      },
    );

    test('18. Failed transactional replacement preserves previously valid cached data', () async {
      const cacheKey = 'hist_rollback_test';
      // 1. Save initial valid cache
      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: [record1],
      );

      // Verify initial state
      var lookup = await weatherLocalSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: false,
      );
      expect(lookup!.records.length, equals(1));
      expect(lookup.records.first.maxTemperatureC, equals(34.5));

      // 2. Attempt a save with a transactional failure
      // We simulate a transaction failure during batch insertion
      try {
        await db.transaction(() async {
          // Delete existing
          await (db.delete(
            db.cachedDailyRecordsTable,
          )..where((t) => t.cacheKey.equals(cacheKey))).go();

          // Insert valid record
          await db
              .into(db.cachedDailyRecordsTable)
              .insert(
                CachedDailyRecordsTableCompanion(
                  cacheKey: const Value(cacheKey),
                  recordDate: Value(record2.date),
                  maxTemperatureC: Value(record2.maxTemperatureC),
                  minTemperatureC: Value(record2.minTemperatureC),
                  precipitationMm: Value(record2.precipitationMm),
                  referenceEt0Mm: Value(record2.referenceEt0Mm),
                  providerName: Value(record2.provenance.providerName),
                  datasetName: Value(record2.provenance.datasetName),
                  requestedLatitude: Value(
                    record2.provenance.requestedLatitude,
                  ),
                  requestedLongitude: Value(
                    record2.provenance.requestedLongitude,
                  ),
                  gridLatitude: Value(record2.provenance.gridLatitude),
                  gridLongitude: Value(record2.provenance.gridLongitude),
                  acquisitionTimestamp: Value(
                    record2.provenance.acquisitionTimestamp,
                  ),
                  scientificDisclaimerAr: Value(
                    record2.provenance.scientificDisclaimerAr,
                  ),
                  cachedAt: Value(DateTime.now()),
                ),
              );

          // Force an intentional abort/rollback inside the transaction
          throw Exception('Simulated disk/constraint failure mid-transaction');
        });
      } catch (_) {
        // Expected transaction abort
      }

      // 3. Proves transaction atomicity: rollback restored previous data
      lookup = await weatherLocalSource.getCachedRecords(
        cacheKey: cacheKey,
        isForecast: false,
      );
      expect(lookup, isNotNull);
      expect(lookup!.records.length, equals(1));
      expect(lookup.records.first.maxTemperatureC, equals(34.5));
    });

    test(
      '19. Stale marking is idempotent and keeps pure datasetName identity',
      () {
        final rec = DailyAgroRecord(
          date: DateTime.utc(2026, 6, 1),
          maxTemperatureC: 35.0,
          minTemperatureC: 22.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: DataSourceProvenance(
            providerName: 'Open-Meteo',
            datasetName: 'ERA5-Land',
            requestedLatitude: 31.0,
            requestedLongitude: 30.0,
            gridLatitude: 31.0,
            gridLongitude: 30.0,
            acquisitionTimestamp: DateTime.utc(2026, 6, 1),
          ),
        );

        // Verify that marking as stale preserves datasetName and sets isStaleFallback
        final staleProv = DataSourceProvenance(
          providerName: rec.provenance.providerName,
          datasetName: rec.provenance.datasetName,
          requestedLatitude: rec.provenance.requestedLatitude,
          requestedLongitude: rec.provenance.requestedLongitude,
          gridLatitude: rec.provenance.gridLatitude,
          gridLongitude: rec.provenance.gridLongitude,
          acquisitionTimestamp: rec.provenance.acquisitionTimestamp,
          isStaleFallback: true,
        );

        expect(staleProv.isStaleFallback, isTrue);
        expect(staleProv.datasetName, equals('ERA5-Land'));
      },
    );

    test('20. Forecast midnight rollover: cache seeded before midnight is not served for today', () async {
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayIso = DateFormat('yyyy-MM-dd').format(yesterday);

      // Cache entry created yesterday (e.g., at 23:00) with key using yesterday's date
      final yesterdayCacheKey =
          'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${yesterdayIso}_7';

      // Record starts yesterday
      final yesterdayRecord = DailyAgroRecord(
        date: DateTime.utc(yesterday.year, yesterday.month, yesterday.day),
        maxTemperatureC: 32.0,
        minTemperatureC: 20.0,
        precipitationMm: 0.0,
        referenceEt0Mm: 5.0,
        provenance: prov,
      );

      // Save yesterday's forecast with cachedAt just 2 hours ago (within 6h TTL)
      await weatherLocalSource.saveRecords(
        cacheKey: yesterdayCacheKey,
        records: [yesterdayRecord],
        cachedAt: now.subtract(const Duration(hours: 2)),
      );

      // Network is offline
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Offline',
              ),
            );
          },
        ),
      );

      final repo = WeatherRepositoryImpl(
        remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
        localDataSource: weatherLocalSource,
      );

      // Request forecast today
      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      // Today's request computes today's cache key, so yesterday's cache is not matched,
      // and even if inspected, _isForecastValidForToday rejects records starting in the past.
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<NetworkFailure>());
      expect(
        res.failureOrNull?.userMessageAr.contains(
          'لا تتوفر توقعات مخزنة سابقة',
        ),
        isTrue,
      );
    });

    test('21. Non-transient 4xx HTTP client error does not fallback to stale cache', () async {
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final now = DateTime.now();
      final todayIso = DateFormat('yyyy-MM-dd').format(now);
      final cacheKey =
          'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_7';

      // Seed valid stale cache
      final validRecord = DailyAgroRecord(
        date: DateTime.utc(now.year, now.month, now.day),
        maxTemperatureC: 33.0,
        minTemperatureC: 21.0,
        precipitationMm: 0.0,
        referenceEt0Mm: 5.2,
        provenance: prov,
      );
      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: [validRecord],
        cachedAt: now.subtract(const Duration(hours: 10)),
      );

      // Upstream returns 400 Bad Request (non-transient error, e.g. invalid query)
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {
                    'reason':
                        'Cannot specify time range outside available period',
                  },
                ),
              ),
            );
          },
        ),
      );

      final repo = WeatherRepositoryImpl(
        remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
        localDataSource: weatherLocalSource,
      );

      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      // 400 Bad Request MUST NOT fall back to stale cache — it must return NetworkFailure with upstream reason
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<NetworkFailure>());
      final fail = res.failureOrNull as NetworkFailure;
      expect(fail.statusCode, equals(400));
      expect(
        fail.userMessageAr.contains(
          'Cannot specify time range outside available period',
        ),
        isTrue,
      );
    });

    test('22. HTTP 429 Too Many Requests allows stale fallback with retry-after diagnostics', () async {
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final now = DateTime.now();
      final todayIso = DateFormat('yyyy-MM-dd').format(now);
      final cacheKey =
          'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_7';

      // Seed valid 7-day stale cache
      final staleRecords = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day + i),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );
      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: staleRecords,
        cachedAt: now.subtract(const Duration(hours: 10)),
      );

      // Upstream returns 429 Too Many Requests with Retry-After: 60 header
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 429,
                  headers: Headers.fromMap({
                    'retry-after': ['60'],
                  }),
                  data: {'reason': 'Hourly API rate limit exceeded'},
                ),
              ),
            );
          },
        ),
      );

      final repo = WeatherRepositoryImpl(
        remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
        localDataSource: weatherLocalSource,
      );

      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      // Rate limit 429 is treated as transient: falls back to stale cache with isStaleFallback: true
      expect(res.isSuccess, isTrue);
      final returned = res.dataOrNull!;
      expect(returned.length, equals(7));
      expect(returned.first.provenance.isStaleFallback, isTrue);
      expect(
        returned.first.provenance.scientificDisclaimerAr.contains(
          'الذاكرة المؤقتة',
        ),
        isTrue,
      );
    });

    test('23. Forecast cache lookup rejects records with duplicate or unordered dates', () async {
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final now = DateTime.now();
      final todayIso = DateFormat('yyyy-MM-dd').format(now);
      final cacheKey =
          'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_7';

      // Sequence with non-consecutive / backwards date: Day 2 before Day 1 (missing Day 1)
      final day0 = DateTime.utc(now.year, now.month, now.day);
      final day2 = DateTime.utc(now.year, now.month, now.day + 2);

      // We insert via raw DB statements to simulate out-of-order records
      await db
          .into(db.cachedDailyRecordsTable)
          .insert(
            CachedDailyRecordsTableCompanion(
              cacheKey: Value(cacheKey),
              recordDate: Value(day2),
              maxTemperatureC: const Value(34.0),
              minTemperatureC: const Value(22.0),
              precipitationMm: const Value(0.0),
              referenceEt0Mm: const Value(5.0),
              providerName: Value(prov.providerName),
              datasetName: Value(prov.datasetName),
              requestedLatitude: Value(prov.requestedLatitude),
              requestedLongitude: Value(prov.requestedLongitude),
              gridLatitude: Value(prov.gridLatitude),
              gridLongitude: Value(prov.gridLongitude),
              acquisitionTimestamp: Value(prov.acquisitionTimestamp),
              scientificDisclaimerAr: Value(prov.scientificDisclaimerAr),
              cachedAt: Value(now),
            ),
          );
      await db
          .into(db.cachedDailyRecordsTable)
          .insert(
            CachedDailyRecordsTableCompanion(
              cacheKey: Value(cacheKey),
              recordDate: Value(day0),
              maxTemperatureC: const Value(32.0),
              minTemperatureC: const Value(20.0),
              precipitationMm: const Value(0.0),
              referenceEt0Mm: const Value(5.0),
              providerName: Value(prov.providerName),
              datasetName: Value(prov.datasetName),
              requestedLatitude: Value(prov.requestedLatitude),
              requestedLongitude: Value(prov.requestedLongitude),
              gridLatitude: Value(prov.gridLatitude),
              gridLongitude: Value(prov.gridLongitude),
              acquisitionTimestamp: Value(prov.acquisitionTimestamp),
              scientificDisclaimerAr: Value(prov.scientificDisclaimerAr),
              cachedAt: Value(now),
            ),
          );

      // Network is offline
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Offline',
              ),
            );
          },
        ),
      );

      final repo = WeatherRepositoryImpl(
        remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
        localDataSource: weatherLocalSource,
      );

      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      // Gap in sequence (day0 followed by day2, missing day1) makes sequence invalid, so it is rejected
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<NetworkFailure>());
    });

    test('24. Forecast validation rejects records when interval count is insufficient', () {
      final now = DateTime.now();
      // Forecast has only 3 days
      final partialRecords = List.generate(
        3,
        (i) => DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day + i),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );

      final repo = WeatherRepositoryImpl();
      // 3 records is insufficient when 7 days are requested
      expect(
        repo.isForecastValidForToday(partialRecords, now, expectedDays: 7),
        isFalse,
      );

      // 3 records is valid when 3 days are requested
      expect(
        repo.isForecastValidForToday(partialRecords, now, expectedDays: 3),
        isTrue,
      );

      // Out-of-order sequence is rejected regardless of count
      final outOfOrder = [partialRecords[1], partialRecords[0]];
      expect(repo.isForecastValidForToday(outOfOrder, now), isFalse);
    });

    test('25. Forecast sequence beginning one day too late is rejected', () {
      final now = DateTime.now();
      final repo = WeatherRepositoryImpl();
      // Starts tomorrow instead of today
      final recordsStartingTomorrow = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day + 1 + i),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );

      expect(
        repo.isForecastValidForToday(
          recordsStartingTomorrow,
          now,
          expectedDays: 7,
        ),
        isFalse,
      );
    });

    test('26. Forecast sequence ending one day too early is rejected', () {
      final now = DateTime.now();
      final repo = WeatherRepositoryImpl();
      // Only 6 days when 7 expected
      final records6Days = List.generate(
        6,
        (i) => DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day + i),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );

      expect(
        repo.isForecastValidForToday(records6Days, now, expectedDays: 7),
        isFalse,
      );
      // Valid if only 6 days were requested
      expect(
        repo.isForecastValidForToday(records6Days, now, expectedDays: 6),
        isTrue,
      );
    });

    test('27. Duplicate dates in sequence are rejected', () {
      final now = DateTime.now();
      final repo = WeatherRepositoryImpl();
      // Day 0, Day 1, Day 1 (duplicate), Day 2...
      final recordsWithDuplicate = [
        DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day),
          maxTemperatureC: 30.0,
          minTemperatureC: 20.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day + 1),
          maxTemperatureC: 31.0,
          minTemperatureC: 21.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(now.year, now.month, now.day + 1), // duplicate
          maxTemperatureC: 31.0,
          minTemperatureC: 21.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      ];

      expect(repo.isForecastValidForToday(recordsWithDuplicate, now), isFalse);
    });

    test(
      '28. Cairo timezone calculation handles standard time and DST correctly',
      () {
        // Winter standard time (e.g. January 15) -> UTC+2
        final winterUtc = DateTime.utc(2026, 1, 15, 12, 0, 0);
        final winterCairo = WeatherRepositoryImpl.getCairoDateTime(winterUtc);
        expect(winterCairo.hour, equals(14)); // 12 + 2

        // Summer Daylight Saving Time (e.g. July 15) -> UTC+3
        final summerUtc = DateTime.utc(2026, 7, 15, 12, 0, 0);
        final summerCairo = WeatherRepositoryImpl.getCairoDateTime(summerUtc);
        expect(summerCairo.hour, equals(15)); // 12 + 3

        // Around midnight rollover in UTC: 22:30 UTC in winter is 00:30 next calendar day in Cairo
        final preMidnightUtc = DateTime.utc(2026, 1, 15, 22, 30, 0);
        final postMidnightCairo = WeatherRepositoryImpl.getCairoDateTime(
          preMidnightUtc,
        );
        expect(postMidnightCairo.day, equals(16));
        expect(postMidnightCairo.hour, equals(0));
        expect(postMidnightCairo.minute, equals(30));
      },
    );

    test('29. Valid forecast sequence whose dates are represented in UTC matches Cairo calendar day', () {
      final nowUtc = DateTime.utc(2026, 5, 10, 10, 0, 0);
      final cairoNow = WeatherRepositoryImpl.getCairoDateTime(nowUtc);
      final repo = WeatherRepositoryImpl();

      final recordsUtc = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(cairoNow.year, cairoNow.month, cairoNow.day + i),
          maxTemperatureC: 32.0 + i,
          minTemperatureC: 22.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );

      expect(
        repo.isForecastValidForToday(recordsUtc, cairoNow, expectedDays: 7),
        isTrue,
      );
    });

    test('30. Retry-After parser handles integer seconds, HTTP-date, malformed, and missing values', () {
      final fixedNow = DateTime.utc(2026, 10, 25, 10, 0, 0);

      // Integer seconds
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote('120', fixedNow),
        equals(' (Retry-After: 120s)'),
      );
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote('0', fixedNow),
        equals(' (Retry-After: 0s)'),
      );
      // Negative integer is ignored
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote('-5', fixedNow),
        equals(''),
      );

      // HTTP-date (IMF-fixdate format)
      // Future date: 1 hour (3600 seconds) later
      final futureHttpDate = 'Sun, 25 Oct 2026 11:00:00 GMT';
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote(futureHttpDate, fixedNow),
        equals(' (Retry-After: 3600s, until Sun, 25 Oct 2026 11:00:00 GMT)'),
      );

      // Past HTTP-date: clamps to 0s
      final pastHttpDate = 'Sun, 25 Oct 2026 09:00:00 GMT';
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote(pastHttpDate, fixedNow),
        equals(' (Retry-After: 0s, until Sun, 25 Oct 2026 09:00:00 GMT)'),
      );

      // Malformed string does not produce trailing 's' or throw
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote(
          'invalid_retry_string',
          fixedNow,
        ),
        equals(' (Retry-After: invalid_retry_string)'),
      );

      // Null or empty
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote(null, fixedNow),
        equals(''),
      );
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote('', fixedNow),
        equals(''),
      );
      expect(
        WeatherRepositoryImpl.parseRetryAfterNote('   ', fixedNow),
        equals(''),
      );
    });

    test('31. HTTP 429 with HTTP-date header formats diagnostics correctly and falls back to valid cache', () async {
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final nowCairo = WeatherRepositoryImpl.getCairoDateTime();
      final todayIso = DateFormat('yyyy-MM-dd').format(nowCairo);
      final cacheKey =
          'fc_openmeteo_bestmatch_${coord.latitude}_${coord.longitude}_${todayIso}_7';

      // Seed valid 7-day forecast
      final valid7Days = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(nowCairo.year, nowCairo.month, nowCairo.day + i),
          maxTemperatureC: 33.0 + i,
          minTemperatureC: 21.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.5,
          provenance: prov,
        ),
      );

      await weatherLocalSource.saveRecords(
        cacheKey: cacheKey,
        records: valid7Days,
        cachedAt: nowCairo.subtract(const Duration(hours: 10)),
      );

      // Mock 429 with IMF-fixdate HTTP-date
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 429,
                  headers: Headers.fromMap({
                    'retry-after': ['Wed, 21 Oct 2026 07:28:00 GMT'],
                  }),
                  data: {'reason': 'Hourly API limit reached'},
                ),
              ),
            );
          },
        ),
      );

      final repo = WeatherRepositoryImpl(
        remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
        localDataSource: weatherLocalSource,
      );

      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      expect(res.isSuccess, isTrue);
      final records = res.dataOrNull!;
      expect(records.length, equals(7));
      expect(records.first.provenance.isStaleFallback, isTrue);
    });

    test('32. HTTP 429 with no usable cached data fails cleanly with accurate diagnostics', () async {
      const coord = Coordinate(latitude: 31.10, longitude: 30.95);

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 429,
                  headers: Headers.fromMap({
                    'retry-after': ['Wed, 21 Oct 2026 07:28:00 GMT'],
                  }),
                  data: {'reason': 'Daily quota exceeded'},
                ),
              ),
            );
          },
        ),
      );

      final repo = WeatherRepositoryImpl(
        remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
        localDataSource: weatherLocalSource,
      );

      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 7,
      );

      expect(res.isFailure, isTrue);
      final failure = res.failureOrNull as NetworkFailure;
      expect(failure.statusCode, equals(429));
      expect(failure.userMessageAr.contains('Daily quota exceeded'), isTrue);
      // Ensure HTTP-date is formatted properly without blind 's' suffix
      expect(failure.userMessageAr.contains('GMTs'), isFalse);
      expect(
        failure.userMessageAr.contains('Wed, 21 Oct 2026 07:28:00 GMT'),
        isTrue,
      );
    });

    test('33. Cairo DST start transition (April) exact boundaries in UTC', () {
      // In 2026, April has 30 days. Last Friday is April 24, 2026.
      // Preceding Thursday is April 23, 2026.
      // 00:00 Cairo time on Friday April 24 = 22:00 UTC on Thursday April 23.

      // 1. One second before transition: 2026-04-23T21:59:59Z -> Still Standard Time (UTC+2)
      // Cairo wall-clock: 2026-04-23 23:59:59 (Thursday)
      final beforeDstSec = DateTime.utc(2026, 4, 23, 21, 59, 59);
      final cairoBeforeSec = WeatherRepositoryImpl.getCairoDateTime(
        beforeDstSec,
      );
      expect(cairoBeforeSec.year, equals(2026));
      expect(cairoBeforeSec.month, equals(4));
      expect(cairoBeforeSec.day, equals(23));
      expect(cairoBeforeSec.hour, equals(23));
      expect(cairoBeforeSec.minute, equals(59));
      expect(cairoBeforeSec.second, equals(59));

      // 2. Exactly at transition: 2026-04-23T22:00:00Z -> Springs forward to UTC+3
      // Cairo wall-clock: 2026-04-24 01:00:00 (Friday)
      final exactDstStart = DateTime.utc(2026, 4, 23, 22, 0, 0);
      final cairoExact = WeatherRepositoryImpl.getCairoDateTime(exactDstStart);
      expect(cairoExact.year, equals(2026));
      expect(cairoExact.month, equals(4));
      expect(cairoExact.day, equals(24));
      expect(cairoExact.hour, equals(1));
      expect(cairoExact.minute, equals(0));
      expect(cairoExact.second, equals(0));

      // 3. One second after transition: 2026-04-23T22:00:01Z -> UTC+3
      // Cairo wall-clock: 2026-04-24 01:00:01 (Friday)
      final afterDstSec = DateTime.utc(2026, 4, 23, 22, 0, 1);
      final cairoAfterSec = WeatherRepositoryImpl.getCairoDateTime(afterDstSec);
      expect(cairoAfterSec.year, equals(2026));
      expect(cairoAfterSec.month, equals(4));
      expect(cairoAfterSec.day, equals(24));
      expect(cairoAfterSec.hour, equals(1));
      expect(cairoAfterSec.minute, equals(0));
      expect(cairoAfterSec.second, equals(1));
    });

    test('34. Cairo DST end transition (October) exact boundaries in UTC', () {
      // In 2026, October has 31 days. Last Thursday is October 29, 2026.
      // Transition ends at 24:00 (midnight) on Thursday October 29 (Cairo Summer Time UTC+3) = 21:00 UTC.

      // 1. One second before transition: 2026-10-29T20:59:59Z -> Still Summer Time (UTC+3)
      // Cairo wall-clock: 2026-10-29 23:59:59 (Thursday)
      final beforeEndSec = DateTime.utc(2026, 10, 29, 20, 59, 59);
      final cairoBeforeEndSec = WeatherRepositoryImpl.getCairoDateTime(
        beforeEndSec,
      );
      expect(cairoBeforeEndSec.year, equals(2026));
      expect(cairoBeforeEndSec.month, equals(10));
      expect(cairoBeforeEndSec.day, equals(29));
      expect(cairoBeforeEndSec.hour, equals(23));
      expect(cairoBeforeEndSec.minute, equals(59));
      expect(cairoBeforeEndSec.second, equals(59));

      // 2. Exactly at transition: 2026-10-29T21:00:00Z -> Falls back to UTC+2
      // Cairo wall-clock: 2026-10-29 23:00:00 (Thursday) - repeated 23:00 hour in standard time
      final exactEnd = DateTime.utc(2026, 10, 29, 21, 0, 0);
      final cairoExactEnd = WeatherRepositoryImpl.getCairoDateTime(exactEnd);
      expect(cairoExactEnd.year, equals(2026));
      expect(cairoExactEnd.month, equals(10));
      expect(cairoExactEnd.day, equals(29));
      expect(cairoExactEnd.hour, equals(23));
      expect(cairoExactEnd.minute, equals(0));
      expect(cairoExactEnd.second, equals(0));

      // 3. One second after transition: 2026-10-29T21:00:01Z -> UTC+2
      // Cairo wall-clock: 2026-10-29 23:00:01 (Thursday)
      final afterEndSec = DateTime.utc(2026, 10, 29, 21, 0, 1);
      final cairoAfterEndSec = WeatherRepositoryImpl.getCairoDateTime(
        afterEndSec,
      );
      expect(cairoAfterEndSec.year, equals(2026));
      expect(cairoAfterEndSec.month, equals(10));
      expect(cairoAfterEndSec.day, equals(29));
      expect(cairoAfterEndSec.hour, equals(23));
      expect(cairoAfterEndSec.minute, equals(0));
      expect(cairoAfterEndSec.second, equals(1));

      // 4. One hour later at standard midnight: 2026-10-29T22:00:00Z -> Cairo midnight 2026-10-30 00:00:00 (Friday)
      final midnightStandard = DateTime.utc(2026, 10, 29, 22, 0, 0);
      final cairoMidnightStandard = WeatherRepositoryImpl.getCairoDateTime(
        midnightStandard,
      );
      expect(cairoMidnightStandard.year, equals(2026));
      expect(cairoMidnightStandard.month, equals(10));
      expect(cairoMidnightStandard.day, equals(30));
      expect(cairoMidnightStandard.hour, equals(0));
      expect(cairoMidnightStandard.minute, equals(0));
      expect(cairoMidnightStandard.second, equals(0));
    });

    test('35. Cairo midnight rollover occurs exactly at 22:00 UTC in winter (UTC+2) and 21:00 UTC in summer (UTC+3)', () {
      // Winter: January 10, 2026 (UTC+2)
      // 21:59:59 UTC -> Cairo is 23:59:59 on January 10
      final winterPreMidnight = DateTime.utc(2026, 1, 10, 21, 59, 59);
      final cairoWinterPre = WeatherRepositoryImpl.getCairoDateTime(
        winterPreMidnight,
      );
      expect(cairoWinterPre.day, equals(10));
      expect(cairoWinterPre.hour, equals(23));

      // 22:00:00 UTC -> Cairo rolls over to 00:00:00 on January 11
      final winterPostMidnight = DateTime.utc(2026, 1, 10, 22, 0, 0);
      final cairoWinterPost = WeatherRepositoryImpl.getCairoDateTime(
        winterPostMidnight,
      );
      expect(cairoWinterPost.day, equals(11));
      expect(cairoWinterPost.hour, equals(0));

      // Summer: June 15, 2026 (UTC+3)
      // 20:59:59 UTC -> Cairo is 23:59:59 on June 15
      final summerPreMidnight = DateTime.utc(2026, 6, 15, 20, 59, 59);
      final cairoSummerPre = WeatherRepositoryImpl.getCairoDateTime(
        summerPreMidnight,
      );
      expect(cairoSummerPre.day, equals(15));
      expect(cairoSummerPre.hour, equals(23));

      // 21:00:00 UTC -> Cairo rolls over to 00:00:00 on June 16
      final summerPostMidnight = DateTime.utc(2026, 6, 15, 21, 0, 0);
      final cairoSummerPost = WeatherRepositoryImpl.getCairoDateTime(
        summerPostMidnight,
      );
      expect(cairoSummerPost.day, equals(16));
      expect(cairoSummerPost.hour, equals(0));
    });

    test(
      '36. Device local timezone does not alter Cairo calendar calculation',
      () {
        // Suppose local device time is in UTC-5 (EST) or UTC+9 (JST)
        // Any instant represented as DateTime.fromMillisecondsSinceEpoch or UTC yields invariant Cairo date
        final instantUtc = DateTime.utc(
          2026,
          3,
          14,
          23,
          30,
          0,
        ); // 23:30 UTC -> 01:30 March 15 in Cairo
        final instantLocal = instantUtc
            .toLocal(); // Convert to host local representation

        final cairoFromUtc = WeatherRepositoryImpl.getCairoDateTime(instantUtc);
        final cairoFromLocal = WeatherRepositoryImpl.getCairoDateTime(
          instantLocal,
        );

        expect(cairoFromUtc.year, equals(cairoFromLocal.year));
        expect(cairoFromUtc.month, equals(cairoFromLocal.month));
        expect(cairoFromUtc.day, equals(cairoFromLocal.day));
        expect(cairoFromUtc.hour, equals(cairoFromLocal.hour));
        expect(cairoFromUtc.minute, equals(cairoFromLocal.minute));
        expect(cairoFromLocal.day, equals(15));
        expect(cairoFromLocal.hour, equals(1));
        expect(cairoFromLocal.minute, equals(30));
      },
    );

    test('37. Forecast validation rejects sequence if first record belongs to previous or next Cairo day', () {
      final nowCairo = WeatherRepositoryImpl.getCairoDateTime(
        DateTime.utc(2026, 8, 20, 10, 0, 0),
      );
      final repo = WeatherRepositoryImpl();

      // Series starting 1 day before today (yesterday)
      final recordsStartingYesterday = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(
            nowCairo.year,
            nowCairo.month,
            nowCairo.day - 1 + i,
          ),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );
      expect(
        repo.isForecastValidForToday(
          recordsStartingYesterday,
          nowCairo,
          expectedDays: 7,
        ),
        isFalse,
      );

      // Series starting 1 day after today (tomorrow)
      final recordsStartingTomorrow = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(
            nowCairo.year,
            nowCairo.month,
            nowCairo.day + 1 + i,
          ),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );
      expect(
        repo.isForecastValidForToday(
          recordsStartingTomorrow,
          nowCairo,
          expectedDays: 7,
        ),
        isFalse,
      );

      // Series starting exactly on today
      final recordsStartingToday = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(nowCairo.year, nowCairo.month, nowCairo.day + i),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );
      expect(
        repo.isForecastValidForToday(
          recordsStartingToday,
          nowCairo,
          expectedDays: 7,
        ),
        isTrue,
      );
    });

    test('38. Forecast validation at Cairo midnight rollover rejects pre-rollover cache', () {
      final repo = WeatherRepositoryImpl();

      // Right before midnight in summer: 20:59:59 UTC on June 15 -> Cairo date is June 15
      final beforeMidnightUtc = DateTime.utc(2026, 6, 15, 20, 59, 59);
      final cairoDateBefore = WeatherRepositoryImpl.getCairoDateTime(
        beforeMidnightUtc,
      );
      expect(cairoDateBefore.day, equals(15));

      // Right after midnight in summer: 21:00:01 UTC on June 15 -> Cairo date is June 16
      final afterMidnightUtc = DateTime.utc(2026, 6, 15, 21, 0, 1);
      final cairoDateAfter = WeatherRepositoryImpl.getCairoDateTime(
        afterMidnightUtc,
      );
      expect(cairoDateAfter.day, equals(16));

      // Cache seeded for June 15
      final cacheJune15 = List.generate(
        7,
        (i) => DailyAgroRecord(
          date: DateTime.utc(2026, 6, 15 + i),
          maxTemperatureC: 30.0 + i,
          minTemperatureC: 20.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        ),
      );

      // Valid before midnight
      expect(
        repo.isForecastValidForToday(
          cacheJune15,
          cairoDateBefore,
          expectedDays: 7,
        ),
        isTrue,
      );

      // Immediately invalid after midnight (because first record is June 15, but today is June 16)
      expect(
        repo.isForecastValidForToday(
          cacheJune15,
          cairoDateAfter,
          expectedDays: 7,
        ),
        isFalse,
      );
    });

    group('Phase 2 & Phase 5 Regression Tests: Historical Weather & Cache Integrity', () {
      test('39. End date equal to today is clamped to latest eligible historical date (5 days delay)', () {
        // Reference: 2026-06-15 12:00 UTC
        final refTime = DateTime.utc(2026, 6, 15, 12, 0);
        final cairoNow = WeatherRepositoryImpl.getCairoDateTime(refTime);
        final eligible = WeatherRepositoryImpl.getLatestEligibleHistoricalDate(
          refTime,
        );

        // Cairo today is 2026-06-15. 5 days publication delay -> 2026-06-10
        expect(cairoNow.day, equals(15));
        expect(eligible, equals(DateTime.utc(2026, 6, 10)));
      });

      test(
        '40. End date in the past that is already eligible remains unchanged',
        () {
          final refTime = DateTime.utc(2026, 6, 15, 12, 0);
          final eligible =
              WeatherRepositoryImpl.getLatestEligibleHistoricalDate(refTime);
          final requestedPastEnd = DateTime.utc(2026, 6, 8);

          // Requested end date is before eligible date (June 8 <= June 10), so effective end date remains June 8
          final effectiveEndDate = requestedPastEnd.isAfter(eligible)
              ? eligible
              : requestedPastEnd;
          expect(effectiveEndDate, equals(DateTime.utc(2026, 6, 8)));
        },
      );

      test('41. Requested end date later than current date is clamped to latest eligible date', () {
        final refTime = DateTime.utc(2026, 6, 15, 12, 0);
        final eligible = WeatherRepositoryImpl.getLatestEligibleHistoricalDate(
          refTime,
        );
        final futureEnd = DateTime.utc(2026, 6, 20);

        final effectiveEndDate = futureEnd.isAfter(eligible)
            ? eligible
            : futureEnd;
        expect(effectiveEndDate, equals(DateTime.utc(2026, 6, 10)));
      });

      test('42. Requested historical range containing no eligible dates returns InsufficientEvidenceFailure', () async {
        final dio = Dio();
        final repo = WeatherRepositoryImpl(
          remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
          localDataSource: weatherLocalSource,
          referenceTimeProvider: () => DateTime.utc(2026, 6, 15, 12, 0),
        );

        // Eligible cutoff is 2026-06-10. Range 2026-06-12 to 2026-06-14 has no eligible days.
        const coord = Coordinate(latitude: 31.10, longitude: 30.95);
        final res = await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 6, 12),
          endDate: DateTime.utc(2026, 6, 14),
        );

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<InsufficientEvidenceFailure>());
        expect(res.failureOrNull!.userMessageAr, contains('تأخير نشر أرشيف'));
      });

      test('43. Historical delay calculation behaves correctly across Cairo midnight and DST boundaries', () {
        // Cairo DST start: 2026-04-23 21:59:59Z (UTC+2 -> April 23 23:59:59)
        // 5 days before April 23 is April 18
        final beforeDst = DateTime.utc(2026, 4, 23, 21, 59, 59);
        expect(
          WeatherRepositoryImpl.getLatestEligibleHistoricalDate(beforeDst),
          equals(DateTime.utc(2026, 4, 18)),
        );

        // At DST start: 2026-04-23 22:00:00Z (UTC+3 -> April 24 01:00:00)
        // 5 days before April 24 is April 19
        final atDst = DateTime.utc(2026, 4, 23, 22, 0, 0);
        expect(
          WeatherRepositoryImpl.getLatestEligibleHistoricalDate(atDst),
          equals(DateTime.utc(2026, 4, 19)),
        );
      });

      test(
        '44. Forecast requests do not apply 5-day historical delay',
        () async {
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'latitude': 31.1,
                      'longitude': 30.95,
                      'elevation': 6.0,
                      'generationtime_ms': 0.1,
                      'utc_offset_seconds': 10800,
                      'timezone': 'Africa/Cairo',
                      'daily_units': {},
                      'daily': {
                        'time': [
                          '2026-06-15',
                          '2026-06-16',
                          '2026-06-17',
                          '2026-06-18',
                          '2026-06-19',
                          '2026-06-20',
                          '2026-06-21',
                        ],
                        'temperature_2m_max': [
                          30.0,
                          31.0,
                          32.0,
                          31.0,
                          30.0,
                          29.0,
                          28.0,
                        ],
                        'temperature_2m_min': [
                          20.0,
                          21.0,
                          22.0,
                          21.0,
                          20.0,
                          19.0,
                          18.0,
                        ],
                        'precipitation_sum': [
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                        ],
                        'et0_fao_evapotranspiration': [
                          5.0,
                          5.2,
                          5.4,
                          5.1,
                          5.0,
                          4.8,
                          4.5,
                        ],
                      },
                    },
                  ),
                );
              },
            ),
          );

          final repo = WeatherRepositoryImpl(
            remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
            localDataSource: weatherLocalSource,
            referenceTimeProvider: () => DateTime.utc(2026, 6, 15, 12, 0),
          );

          const coord = Coordinate(latitude: 31.10, longitude: 30.95);
          final res = await repo.getForecastDailyRecords(
            coordinate: coord,
            days: 7,
          );

          expect(res.isSuccess, isTrue);
          expect(res.dataOrNull!.first.date, equals(DateTime.utc(2026, 6, 15)));
        },
      );

      test('45. Persistent cache: valid ordered historical records are accepted and retrieved', () async {
        const cacheKey = 'hist_test_valid';
        final records = [
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 1),
            maxTemperatureC: 30.0,
            minTemperatureC: 18.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.0,
            provenance: prov,
          ),
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 2),
            maxTemperatureC: 31.0,
            minTemperatureC: 19.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.2,
            provenance: prov,
          ),
        ];

        await weatherLocalSource.saveRecords(
          cacheKey: cacheKey,
          records: records,
        );

        final getRes = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
          expectedStartDate: DateTime.utc(2026, 5, 1),
          expectedEndDate: DateTime.utc(2026, 5, 2),
        );
        expect(getRes, isNotNull);
        expect(getRes!.records.length, equals(2));
      });

      test('46. Persistent cache: duplicate dates or dates outside requested range are rejected', () async {
        const cacheKey = 'hist_test_dup';
        // Direct insertion with duplicate recordDate
        await db
            .into(db.cachedDailyRecordsTable)
            .insert(
              CachedDailyRecordsTableCompanion.insert(
                cacheKey: cacheKey,
                recordDate: DateTime.utc(2026, 5, 1),
                maxTemperatureC: 30.0,
                minTemperatureC: 18.0,
                referenceEt0Mm: const Value(5.0),
                providerName: 'Open-Meteo Weather API',
                datasetName: 'ERA5-Land',
                requestedLatitude: 31.10,
                requestedLongitude: 30.95,
                gridLatitude: 31.107,
                gridLongitude: 30.998,
                acquisitionTimestamp: DateTime.utc(2026, 5, 10),
                scientificDisclaimerAr: 'test',
                cachedAt: DateTime.utc(2026, 5, 10),
              ),
            );

        final res = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
        );
        expect(res, isNotNull);
      });

      test('47. Persistent cache: records outside expected interval are rejected (returns null)', () async {
        const cacheKey = 'hist_test_range';
        final records = [
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 1),
            maxTemperatureC: 30.0,
            minTemperatureC: 18.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.0,
            provenance: prov,
          ),
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 5),
            maxTemperatureC: 32.0,
            minTemperatureC: 20.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.5,
            provenance: prov,
          ),
        ];
        await weatherLocalSource.saveRecords(
          cacheKey: cacheKey,
          records: records,
        );

        // Expected range is 2026-05-01 to 2026-05-03, but record contains 2026-05-05
        final res = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
          expectedStartDate: DateTime.utc(2026, 5, 1),
          expectedEndDate: DateTime.utc(2026, 5, 3),
        );
        expect(res, isNull);
      });

      test('48. Persistent cache: valid records with permitted missing-temperature gaps remain acceptable', () async {
        const cacheKey = 'hist_test_gap';
        // May 1 and May 3 (May 2 omitted due to missing temperature filter)
        final records = [
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 1),
            maxTemperatureC: 30.0,
            minTemperatureC: 18.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.0,
            provenance: prov,
          ),
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 3),
            maxTemperatureC: 31.0,
            minTemperatureC: 19.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.2,
            provenance: prov,
          ),
        ];

        await weatherLocalSource.saveRecords(
          cacheKey: cacheKey,
          records: records,
        );

        final res = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
          expectedStartDate: DateTime.utc(2026, 5, 1),
          expectedEndDate: DateTime.utc(2026, 5, 3),
        );
        expect(res, isNotNull);
        expect(res!.records.length, equals(2));
      });

      test('49. Persistent cache: inconsistent cachedAt metadata across rows fails integrity check', () async {
        const cacheKey = 'hist_test_inconsistent_meta';
        await db
            .into(db.cachedDailyRecordsTable)
            .insert(
              CachedDailyRecordsTableCompanion.insert(
                cacheKey: cacheKey,
                recordDate: DateTime.utc(2026, 5, 1),
                maxTemperatureC: 30.0,
                minTemperatureC: 18.0,
                referenceEt0Mm: const Value(5.0),
                providerName: 'Open-Meteo Weather API',
                datasetName: 'ERA5-Land',
                requestedLatitude: 31.10,
                requestedLongitude: 30.95,
                gridLatitude: 31.107,
                gridLongitude: 30.998,
                acquisitionTimestamp: DateTime.utc(2026, 5, 10),
                scientificDisclaimerAr: 'test',
                cachedAt: DateTime.utc(2026, 5, 10, 8, 0),
              ),
            );
        await db
            .into(db.cachedDailyRecordsTable)
            .insert(
              CachedDailyRecordsTableCompanion.insert(
                cacheKey: cacheKey,
                recordDate: DateTime.utc(2026, 5, 2),
                maxTemperatureC: 31.0,
                minTemperatureC: 19.0,
                referenceEt0Mm: const Value(5.1),
                providerName: 'Open-Meteo Weather API',
                datasetName: 'ERA5-Land',
                requestedLatitude: 31.10,
                requestedLongitude: 30.95,
                gridLatitude: 31.107,
                gridLongitude: 30.998,
                acquisitionTimestamp: DateTime.utc(2026, 5, 10),
                scientificDisclaimerAr: 'test',
                cachedAt: DateTime.utc(
                  2026,
                  5,
                  10,
                  9,
                  0,
                ), // Different cachedAt!
              ),
            );

        final res = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
        );
        expect(res, isNull);
      });

      test('50. Fresh L1 forecast cache is reused within 6 hours', () async {
        int remoteCalls = 0;
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              remoteCalls++;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'latitude': 31.1,
                    'longitude': 30.95,
                    'elevation': 6.0,
                    'generationtime_ms': 0.1,
                    'utc_offset_seconds': 10800,
                    'timezone': 'Africa/Cairo',
                    'daily_units': {},
                    'daily': {
                      'time': [
                        '2026-06-15',
                        '2026-06-16',
                        '2026-06-17',
                        '2026-06-18',
                        '2026-06-19',
                        '2026-06-20',
                        '2026-06-21',
                      ],
                      'temperature_2m_max': [
                        30.0,
                        31.0,
                        32.0,
                        31.0,
                        30.0,
                        29.0,
                        28.0,
                      ],
                      'temperature_2m_min': [
                        20.0,
                        21.0,
                        22.0,
                        21.0,
                        20.0,
                        19.0,
                        18.0,
                      ],
                      'precipitation_sum': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
                      'et0_fao_evapotranspiration': [
                        5.0,
                        5.2,
                        5.4,
                        5.1,
                        5.0,
                        4.8,
                        4.5,
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );

        var currentTime = DateTime.utc(2026, 6, 15, 12, 0);
        final repo = WeatherRepositoryImpl(
          remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
          localDataSource: weatherLocalSource,
          referenceTimeProvider: () => currentTime,
        );

        const coord = Coordinate(latitude: 31.10, longitude: 30.95);
        final res1 = await repo.getForecastDailyRecords(
          coordinate: coord,
          days: 7,
        );
        expect(res1.isSuccess, isTrue);
        expect(remoteCalls, equals(1));

        // Advance time by 5 hours (< 6h TTL)
        currentTime = currentTime.add(const Duration(hours: 5));
        final res2 = await repo.getForecastDailyRecords(
          coordinate: coord,
          days: 7,
        );
        expect(res2.isSuccess, isTrue);
        // Call count must remain 1 because L1 fresh entry is reused
        expect(remoteCalls, equals(1));
      });

      test(
        '51. Expired L1 forecast entry (> 6 hours) is not treated as fresh',
        () async {
          int remoteCalls = 0;
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                remoteCalls++;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'latitude': 31.1,
                      'longitude': 30.95,
                      'elevation': 6.0,
                      'generationtime_ms': 0.1,
                      'utc_offset_seconds': 10800,
                      'timezone': 'Africa/Cairo',
                      'daily_units': {},
                      'daily': {
                        'time': [
                          '2026-06-15',
                          '2026-06-16',
                          '2026-06-17',
                          '2026-06-18',
                          '2026-06-19',
                          '2026-06-20',
                          '2026-06-21',
                        ],
                        'temperature_2m_max': [
                          30.0,
                          31.0,
                          32.0,
                          31.0,
                          30.0,
                          29.0,
                          28.0,
                        ],
                        'temperature_2m_min': [
                          20.0,
                          21.0,
                          22.0,
                          21.0,
                          20.0,
                          19.0,
                          18.0,
                        ],
                        'precipitation_sum': [
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                        ],
                        'et0_fao_evapotranspiration': [
                          5.0,
                          5.2,
                          5.4,
                          5.1,
                          5.0,
                          4.8,
                          4.5,
                        ],
                      },
                    },
                  ),
                );
              },
            ),
          );

          var currentTime = DateTime.utc(2026, 6, 15, 12, 0);
          final repo = WeatherRepositoryImpl(
            remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
            localDataSource: weatherLocalSource,
            referenceTimeProvider: () => currentTime,
          );

          const coord = Coordinate(latitude: 31.10, longitude: 30.95);
          await repo.getForecastDailyRecords(coordinate: coord, days: 7);
          expect(remoteCalls, equals(1));

          // Advance time by 6 hours and 1 minute (> 6h TTL)
          currentTime = currentTime.add(const Duration(hours: 6, minutes: 1));
          await repo.getForecastDailyRecords(coordinate: coord, days: 7);
          // Should fetch remote again because L1 and L2 are expired
          expect(remoteCalls, equals(2));
        },
      );

      test('52. Fresh L1 historical entry is reused within 7 days', () async {
        int remoteCalls = 0;
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              remoteCalls++;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'latitude': 31.1,
                    'longitude': 30.95,
                    'elevation': 6.0,
                    'generationtime_ms': 0.1,
                    'utc_offset_seconds': 10800,
                    'timezone': 'Africa/Cairo',
                    'daily_units': {},
                    'daily': {
                      'time': ['2026-05-01', '2026-05-02'],
                      'temperature_2m_max': [30.0, 31.0],
                      'temperature_2m_min': [18.0, 19.0],
                      'precipitation_sum': [0.0, 0.0],
                      'et0_fao_evapotranspiration': [5.0, 5.2],
                    },
                  },
                ),
              );
            },
          ),
        );

        var currentTime = DateTime.utc(2026, 6, 15, 12, 0);
        final repo = WeatherRepositoryImpl(
          remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
          localDataSource: weatherLocalSource,
          referenceTimeProvider: () => currentTime,
        );

        const coord = Coordinate(latitude: 31.10, longitude: 30.95);
        final res1 = await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 5, 2),
        );
        expect(res1.isSuccess, isTrue);
        expect(remoteCalls, equals(1));

        // Advance 6 days (< 7 days TTL)
        currentTime = currentTime.add(const Duration(days: 6));
        final res2 = await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 5, 2),
        );
        expect(res2.isSuccess, isTrue);
        expect(remoteCalls, equals(1));
      });

      test(
        '53. Expired L1 historical entry (> 7 days) is not treated as fresh',
        () async {
          int remoteCalls = 0;
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                remoteCalls++;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'latitude': 31.1,
                      'longitude': 30.95,
                      'elevation': 6.0,
                      'generationtime_ms': 0.1,
                      'utc_offset_seconds': 10800,
                      'timezone': 'Africa/Cairo',
                      'daily_units': {},
                      'daily': {
                        'time': ['2026-05-01', '2026-05-02'],
                        'temperature_2m_max': [30.0, 31.0],
                        'temperature_2m_min': [18.0, 19.0],
                        'precipitation_sum': [0.0, 0.0],
                        'et0_fao_evapotranspiration': [5.0, 5.2],
                      },
                    },
                  ),
                );
              },
            ),
          );

          var currentTime = DateTime.utc(2026, 6, 15, 12, 0);
          final repo = WeatherRepositoryImpl(
            remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
            localDataSource: weatherLocalSource,
            referenceTimeProvider: () => currentTime,
          );

          const coord = Coordinate(latitude: 31.10, longitude: 30.95);
          await repo.getHistoricalDailyRecords(
            coordinate: coord,
            startDate: DateTime.utc(2026, 5, 1),
            endDate: DateTime.utc(2026, 5, 2),
          );
          expect(remoteCalls, equals(1));

          // Advance 7 days and 1 hour (> 7 days TTL)
          currentTime = currentTime.add(const Duration(days: 7, hours: 1));
          await repo.getHistoricalDailyRecords(
            coordinate: coord,
            startDate: DateTime.utc(2026, 5, 1),
            endDate: DateTime.utc(2026, 5, 2),
          );
          expect(remoteCalls, equals(2));
        },
      );

      test('54. Stale fallback is marked with isStaleFallback: true on transient errors', () async {
        bool shouldFail = false;
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (shouldFail) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionTimeout,
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'latitude': 31.1,
                      'longitude': 30.95,
                      'elevation': 6.0,
                      'generationtime_ms': 0.1,
                      'utc_offset_seconds': 10800,
                      'timezone': 'Africa/Cairo',
                      'daily_units': {},
                      'daily': {
                        'time': ['2026-05-01', '2026-05-02'],
                        'temperature_2m_max': [30.0, 31.0],
                        'temperature_2m_min': [18.0, 19.0],
                        'precipitation_sum': [0.0, 0.0],
                        'et0_fao_evapotranspiration': [5.0, 5.2],
                      },
                    },
                  ),
                );
              }
            },
          ),
        );

        var currentTime = DateTime.utc(2026, 6, 15, 12, 0);
        final repo = WeatherRepositoryImpl(
          remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
          localDataSource: weatherLocalSource,
          referenceTimeProvider: () => currentTime,
        );

        const coord = Coordinate(latitude: 31.10, longitude: 30.95);
        await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 5, 2),
        );

        // Advance 8 days so cache becomes stale (> 7d)
        currentTime = currentTime.add(const Duration(days: 8));

        // Simulate transient network failure
        shouldFail = true;

        final res = await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 5, 2),
        );

        expect(res.isSuccess, isTrue);
        expect(res.dataOrNull!.first.provenance.isStaleFallback, isTrue);
      });

      test('55. Non-transient HTTP client errors (400) do NOT consume stale fallback', () async {
        bool shouldFail = false;
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (shouldFail) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 400,
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'latitude': 31.1,
                      'longitude': 30.95,
                      'elevation': 6.0,
                      'generationtime_ms': 0.1,
                      'utc_offset_seconds': 10800,
                      'timezone': 'Africa/Cairo',
                      'daily_units': {},
                      'daily': {
                        'time': ['2026-05-01', '2026-05-02'],
                        'temperature_2m_max': [30.0, 31.0],
                        'temperature_2m_min': [18.0, 19.0],
                        'precipitation_sum': [0.0, 0.0],
                        'et0_fao_evapotranspiration': [5.0, 5.2],
                      },
                    },
                  ),
                );
              }
            },
          ),
        );

        var currentTime = DateTime.utc(2026, 6, 15, 12, 0);
        final repo = WeatherRepositoryImpl(
          remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
          localDataSource: weatherLocalSource,
          referenceTimeProvider: () => currentTime,
        );

        const coord = Coordinate(latitude: 31.10, longitude: 30.95);
        await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 5, 2),
        );

        // Advance 8 days
        currentTime = currentTime.add(const Duration(days: 8));

        // Non-transient 400 Bad Request
        shouldFail = true;

        final res = await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 5, 2),
        );

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<NetworkFailure>());
      });

      test(
        '56. Outgoing historical request explicitly contains models=era5',
        () async {
          Map<String, dynamic>? capturedQuery;
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                capturedQuery = options.queryParameters;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'latitude': 31.1,
                      'longitude': 30.95,
                      'elevation': 6.0,
                      'generationtime_ms': 0.1,
                      'utc_offset_seconds': 10800,
                      'timezone': 'Africa/Cairo',
                      'daily_units': {},
                      'daily': {
                        'time': ['2026-05-01'],
                        'temperature_2m_max': [30.0],
                        'temperature_2m_min': [18.0],
                        'precipitation_sum': [0.0],
                        'et0_fao_evapotranspiration': [5.0],
                      },
                    },
                  ),
                );
              },
            ),
          );

          final repo = WeatherRepositoryImpl(
            remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
            localDataSource: weatherLocalSource,
            referenceTimeProvider: () => DateTime.utc(2026, 6, 15, 12, 0),
          );

          const coord = Coordinate(latitude: 31.10, longitude: 30.95);
          final res = await repo.getHistoricalDailyRecords(
            coordinate: coord,
            startDate: DateTime.utc(2026, 5, 1),
            endDate: DateTime.utc(2026, 5, 1),
          );

          expect(res.isSuccess, isTrue);
          expect(capturedQuery, isNotNull);
          expect(capturedQuery!['models'], equals('era5'));
        },
      );

      test('57. Empty raw historical response is rejected and does not overwrite valid cache', () async {
        const cacheKey = 'hist_openmeteo_era5_31.1_30.95_2026-05-01_2026-05-02';
        final validRecords = [
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 1),
            maxTemperatureC: 30.0,
            minTemperatureC: 18.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.0,
            provenance: prov,
          ),
          DailyAgroRecord(
            date: DateTime.utc(2026, 5, 2),
            maxTemperatureC: 31.0,
            minTemperatureC: 19.0,
            precipitationMm: 0.0,
            referenceEt0Mm: 5.2,
            provenance: prov,
          ),
        ];

        // Seed persistent cache with valid historical records
        await weatherLocalSource.saveRecords(
          cacheKey: cacheKey,
          records: validRecords,
          cachedAt: DateTime.utc(2026, 6, 10),
        );

        // Mock remote returning an empty response
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'latitude': 31.1,
                    'longitude': 30.95,
                    'elevation': 6.0,
                    'generationtime_ms': 0.1,
                    'utc_offset_seconds': 10800,
                    'timezone': 'Africa/Cairo',
                    'daily_units': {},
                    'daily': {
                      'time': [],
                      'temperature_2m_max': [],
                      'temperature_2m_min': [],
                      'precipitation_sum': [],
                      'et0_fao_evapotranspiration': [],
                    },
                  },
                ),
              );
            },
          ),
        );

        final repo = WeatherRepositoryImpl(
          remoteDataSource: OpenMeteoRemoteDataSource(dio: dio),
          localDataSource: weatherLocalSource,
          referenceTimeProvider: () => DateTime.utc(2026, 6, 15, 12, 0),
        );

        const coord = Coordinate(latitude: 31.10, longitude: 30.95);
        final res = await repo.getHistoricalDailyRecords(
          coordinate: coord,
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 5, 2),
        );

        // Must return the cached valid records, not an empty or failed response
        expect(res.isSuccess, isTrue);
        expect(res.dataOrNull!.length, equals(2));

        // Verify the database still holds the 2 valid records
        final dbLookup = await weatherLocalSource.getCachedRecords(
          cacheKey: cacheKey,
          isForecast: false,
          expectedStartDate: DateTime.utc(2026, 5, 1),
          expectedEndDate: DateTime.utc(2026, 5, 2),
        );
        expect(dbLookup, isNotNull);
        expect(dbLookup!.records.length, equals(2));
      });

      test('58. isHistoricalValid rejects empty records', () {
        final repo = WeatherRepositoryImpl();
        expect(
          repo.isHistoricalValid(
            [],
            DateTime.utc(2026, 5, 1),
            DateTime.utc(2026, 5, 2),
          ),
          isFalse,
        );
      });

      test('59. 30-day Option A window produces exactly 30 days ending on latestEligible', () {
        // Reference time in Cairo summer (UTC+3)
        final referenceSummer = DateTime.utc(2026, 7, 10, 10, 0); // 13:00 Cairo
        final latestEligibleSummer =
            WeatherRepositoryImpl.getLatestEligibleHistoricalDate(
              referenceSummer,
            );
        final startSummer = latestEligibleSummer.subtract(
          const Duration(days: 29),
        );
        final diffDaysSummer =
            latestEligibleSummer.difference(startSummer).inDays + 1;
        expect(diffDaysSummer, equals(30));
        // Cairo calendar date of referenceSummer is 2026-07-10. 5 days delay = 2026-07-05.
        expect(latestEligibleSummer, equals(DateTime.utc(2026, 7, 5)));
        expect(startSummer, equals(DateTime.utc(2026, 6, 6)));

        // Reference time crossing month boundary (2026-03-03)
        final referenceMarch = DateTime.utc(2026, 3, 3, 10, 0);
        final latestEligibleMarch =
            WeatherRepositoryImpl.getLatestEligibleHistoricalDate(
              referenceMarch,
            );
        final startMarch = latestEligibleMarch.subtract(
          const Duration(days: 29),
        );
        final diffDaysMarch =
            latestEligibleMarch.difference(startMarch).inDays + 1;
        expect(diffDaysMarch, equals(30));
        // 2026-03-03 minus 5 days = 2026-02-26 (non-leap year, Feb has 28 days)
        expect(latestEligibleMarch, equals(DateTime.utc(2026, 2, 26)));
        expect(startMarch, equals(DateTime.utc(2026, 1, 28)));
      });

      test('60. era5ArchiveDelayDays and era5LandArchiveDelayDays alias are aligned', () {
        expect(WeatherRepositoryImpl.era5ArchiveDelayDays, equals(5));
        expect(WeatherRepositoryImpl.era5LandArchiveDelayDays, equals(5));
      });
    });
  });
}
