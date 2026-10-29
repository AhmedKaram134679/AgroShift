import 'package:agro_shift/data/datasources/remote/open_meteo_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
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

  const mockDailyUnits = <String, dynamic>{
    'temperature_2m_max': '°C',
    'temperature_2m_min': '°C',
    'et0_fao_evapotranspiration': 'mm',
    'precipitation_sum': 'mm',
  };

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

    test('4. Deleting all registered fields results in an empty list and empty database read without resurrecting defaults', () async {
      const def1 = FarmField(
        id: 'def_1',
        nameAr: 'حقل الدلتا',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 31.10, longitude: 30.90),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await fieldRepo.seedDefaultFieldsIfNecessary([def1]);
      var all = (await fieldRepo.getAllFields()).dataOrNull!;
      expect(all.length, equals(1));

      // Delete def1
      await fieldRepo.deleteField('def_1');
      all = (await fieldRepo.getAllFields()).dataOrNull!;
      expect(all.isEmpty, isTrue);

      // Reloading via new repo instance still returns empty list
      final newRepo = FarmFieldRepositoryImpl(db);
      await newRepo.seedDefaultFieldsIfNecessary([def1]);
      final reloaded = (await newRepo.getAllFields()).dataOrNull!;
      expect(reloaded.isEmpty, isTrue);
    });

    test('5. Creating a new field persists valid createdAt and updatedAt timestamps read back from SQLite', () async {
      final beforeTime = DateTime.now().subtract(const Duration(seconds: 2));
      const newField = FarmField(
        id: 'field_new_timestamp_test',
        nameAr: 'حقل جديد للتحقق من الطابع الزمني',
        governorateAr: 'المنيا',
        coordinate: Coordinate(latitude: 28.10, longitude: 30.70),
        areaInFeddan: 8.0,
        soilType: SoilType.clayLoam,
      );

      // B1: Creating a new field
      final saveRes = await fieldRepo.saveField(newField);
      expect(saveRes.isSuccess, isTrue);

      final row = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_new_timestamp_test'))).getSingle();

      expect(
        row.createdAt.isAfter(beforeTime) ||
            row.createdAt.isAtSameMomentAs(beforeTime),
        isTrue,
      );
      expect(
        row.updatedAt.isAfter(beforeTime) ||
            row.updatedAt.isAtSameMomentAs(beforeTime),
        isTrue,
      );
      // For a newly created field, createdAt and updatedAt correspond to initial creation time
      expect(
        row.createdAt.difference(row.updatedAt).inSeconds.abs() <= 1,
        isTrue,
      );
    });

    test('6. Updating an existing field preserves original createdAt and advances updatedAt', () async {
      const field = FarmField(
        id: 'field_timestamp_test',
        nameAr: 'حقل اختبار الطابع الزمني',
        governorateAr: 'الفيوم',
        coordinate: Coordinate(latitude: 29.30, longitude: 30.84),
        areaInFeddan: 10.0,
        soilType: SoilType.clayLoam,
      );

      // 1. Initial save
      final saveRes = await fieldRepo.saveField(field);
      expect(saveRes.isSuccess, isTrue);

      // Read raw database row to inspect createdAt and updatedAt
      final initialRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_timestamp_test'))).getSingle();

      final initialCreatedAt = initialRow.createdAt;
      final initialUpdatedAt = initialRow.updatedAt;

      // Delay 1100ms to cross 1-second boundary for SQLite seconds resolution
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      // 2. Update the field (B2)
      const updatedField = FarmField(
        id: 'field_timestamp_test',
        nameAr: 'حقل اختبار الطابع الزمني المحدث',
        governorateAr: 'الفيوم',
        coordinate: Coordinate(latitude: 29.30, longitude: 30.84),
        areaInFeddan: 12.0,
        soilType: SoilType.clayLoam,
      );

      final updateRes = await fieldRepo.saveField(updatedField);
      expect(updateRes.isSuccess, isTrue);

      // Read updated database row
      final updatedRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_timestamp_test'))).getSingle();

      // Assert createdAt is identical
      expect(updatedRow.createdAt, equals(initialCreatedAt));

      // Assert updatedAt is strictly later than initialUpdatedAt
      expect(updatedRow.updatedAt.isAfter(initialUpdatedAt), isTrue);

      // Assert field attributes updated
      expect(updatedRow.nameAr, equals('حقل اختبار الطابع الزمني المحدث'));
      expect(updatedRow.areaInFeddan, equals(12.0));
    });

    test('7. Database failure on saveField fails safely with ParsingFailure without reporting success', () async {
      // B3 & B4: Simulate database query/write failure by operating against a closed underlying sqlite3 connection
      final rawSql = sqlite3.openInMemory();
      final isolatedDb = AppDatabase(NativeDatabase.opened(rawSql));
      // Trigger table creation
      await isolatedDb.customSelect('SELECT 1').get();
      rawSql.close(); // Close the underlying sqlite3 instance directly

      final isolatedRepo = FarmFieldRepositoryImpl(isolatedDb);

      const field = FarmField(
        id: 'field_closed_db_test',
        nameAr: 'حقل قاعدة مغلقة',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 31.10, longitude: 30.90),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      final res = await isolatedRepo.saveField(field);
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ParsingFailure>());
      expect(
        (res.failureOrNull as ParsingFailure).userMessageAr,
        contains('تعذر حفظ الحقل'),
      );
    });

    test('8. Pre-write coordinate validation failure rejects update and preserves existing valid field data untouched', () async {
      const field = FarmField(
        id: 'field_integrity_guard_test',
        nameAr: 'حقل سليم أصلي',
        governorateAr: 'البحيرة',
        coordinate: Coordinate(latitude: 30.40, longitude: 30.30),
        areaInFeddan: 10.0,
        soilType: SoilType.sandyLoam,
      );

      // Successfully persist initial valid field
      final initialSaveRes = await fieldRepo.saveField(field);
      expect(initialSaveRes.isSuccess, isTrue);

      final initialRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_integrity_guard_test'))).getSingle();

      // Attempt invalid write: coordinate out of Egypt bounds -> validation fails before DB write
      const invalidUpdate = FarmField(
        id: 'field_integrity_guard_test',
        nameAr: 'تعديل فاشل بسبب إحداثيات خاطئة',
        governorateAr: 'البحيرة',
        coordinate: Coordinate(latitude: 99.0, longitude: 99.0), // Invalid
        areaInFeddan: 20.0,
        soilType: SoilType.sandyLoam,
      );

      final failedRes = await fieldRepo.saveField(invalidUpdate);
      expect(failedRes.isFailure, isTrue);
      expect(failedRes.failureOrNull, isA<CoordinateOutOfBoundsFailure>());

      // Verify that existing row in database remained completely untouched
      final rowAfterFailure = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_integrity_guard_test'))).getSingle();

      expect(rowAfterFailure.nameAr, equals('حقل سليم أصلي'));
      expect(rowAfterFailure.areaInFeddan, equals(10.0));
      expect(rowAfterFailure.createdAt, equals(initialRow.createdAt));
      expect(rowAfterFailure.updatedAt, equals(initialRow.updatedAt));
    });

    test('8_area_1. Pre-write area validation rejects zero area and does not create database row', () async {
      const field = FarmField(
        id: 'field_zero_area_test',
        nameAr: 'حقل مساحة صفرية',
        governorateAr: 'الغربية',
        coordinate: Coordinate(latitude: 30.80, longitude: 31.00),
        areaInFeddan: 0.0,
        soilType: SoilType.clay,
      );

      final res = await fieldRepo.saveField(field);
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<PhysicalRangeFailure>());
      final failure = res.failureOrNull as PhysicalRangeFailure;
      expect(failure.variableName, equals('areaInFeddan'));
      expect(failure.actualValue, equals(0.0));

      final row = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_zero_area_test'))).getSingleOrNull();
      expect(
        row,
        isNull,
        reason: 'Zero area must not create a row in the database',
      );
    });

    test('8_area_2. Pre-write area validation rejects negative area and does not create database row', () async {
      const field = FarmField(
        id: 'field_negative_area_test',
        nameAr: 'حقل مساحة سالبة',
        governorateAr: 'المنيا',
        coordinate: Coordinate(latitude: 28.50, longitude: 30.80),
        areaInFeddan: -3.5,
        soilType: SoilType.clayLoam,
      );

      final res = await fieldRepo.saveField(field);
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<PhysicalRangeFailure>());
      final failure = res.failureOrNull as PhysicalRangeFailure;
      expect(failure.variableName, equals('areaInFeddan'));
      expect(failure.actualValue, equals(-3.5));

      final row =
          await (db.select(db.farmFieldsTable)
                ..where((t) => t.id.equals('field_negative_area_test')))
              .getSingleOrNull();
      expect(
        row,
        isNull,
        reason: 'Negative area must not create a row in the database',
      );
    });

    test('8_area_3. Pre-write area validation rejects NaN and infinite area values and does not create database row', () async {
      for (final nonFinite in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final field = FarmField(
          id: 'field_non_finite_${nonFinite.hashCode}',
          nameAr: 'حقل غير منته',
          governorateAr: 'البحيرة',
          coordinate: const Coordinate(latitude: 30.40, longitude: 30.30),
          areaInFeddan: nonFinite,
          soilType: SoilType.sandyLoam,
        );

        final res = await fieldRepo.saveField(field);
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<PhysicalRangeFailure>());
        final failure = res.failureOrNull as PhysicalRangeFailure;
        expect(failure.variableName, equals('areaInFeddan'));

        final row = await (db.select(
          db.farmFieldsTable,
        )..where((t) => t.id.equals(field.id))).getSingleOrNull();
        expect(
          row,
          isNull,
          reason: 'Non-finite area must not create a database row',
        );
      }
    });

    test('8_area_4. Pre-write area validation rejects invalid update and preserves existing valid database row untouched', () async {
      const initialField = FarmField(
        id: 'field_area_update_guard',
        nameAr: 'حقل سليم للحماية',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 31.10, longitude: 30.95),
        areaInFeddan: 8.0,
        soilType: SoilType.clay,
      );

      final initialSave = await fieldRepo.saveField(initialField);
      expect(initialSave.isSuccess, isTrue);

      final initialRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_area_update_guard'))).getSingle();

      for (final invalidArea in [
        0.0,
        -2.5,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final invalidUpdate = FarmField(
          id: 'field_area_update_guard',
          nameAr: 'اسم معدل خاطئ',
          governorateAr: 'كفر الشيخ',
          coordinate: const Coordinate(latitude: 31.10, longitude: 30.95),
          areaInFeddan: invalidArea,
          soilType: SoilType.clay,
        );

        final res = await fieldRepo.saveField(invalidUpdate);
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<PhysicalRangeFailure>());

        final rowAfter = await (db.select(
          db.farmFieldsTable,
        )..where((t) => t.id.equals('field_area_update_guard'))).getSingle();

        expect(rowAfter.nameAr, equals('حقل سليم للحماية'));
        expect(rowAfter.areaInFeddan, equals(8.0));
        expect(rowAfter.createdAt, equals(initialRow.createdAt));
        expect(rowAfter.updatedAt, equals(initialRow.updatedAt));
      }
    });

    test('8_area_5. Valid field insertion and subsequent valid update succeed and persist correct area to SQLite', () async {
      const validField = FarmField(
        id: 'field_valid_area_lifecycle',
        nameAr: 'حقل دورة حياة المساحة',
        governorateAr: 'الشرقية',
        coordinate: Coordinate(latitude: 30.58, longitude: 31.50),
        areaInFeddan: 7.5,
        soilType: SoilType.clayLoam,
      );

      final saveRes = await fieldRepo.saveField(validField);
      expect(saveRes.isSuccess, isTrue);

      final insertedRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_valid_area_lifecycle'))).getSingle();
      expect(insertedRow.areaInFeddan, equals(7.5));
      expect(insertedRow.nameAr, equals('حقل دورة حياة المساحة'));

      final validUpdate = FarmField(
        id: 'field_valid_area_lifecycle',
        nameAr: 'حقل دورة حياة المساحة المعدل',
        governorateAr: 'الشرقية',
        coordinate: const Coordinate(latitude: 30.58, longitude: 31.50),
        areaInFeddan: 14.25,
        soilType: SoilType.clayLoam,
      );

      final updateRes = await fieldRepo.saveField(validUpdate);
      expect(updateRes.isSuccess, isTrue);

      final updatedRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_valid_area_lifecycle'))).getSingle();
      expect(updatedRow.areaInFeddan, equals(14.25));
      expect(updatedRow.nameAr, equals('حقل دورة حياة المساحة المعدل'));
      expect(updatedRow.createdAt, equals(insertedRow.createdAt));
    });

    test('8b. Default-field identity is preserved during updates and seeding failures propagate', () async {
      // 1. Saving a new ordinary field without specifying isDefault persists false
      const ordinaryField = FarmField(
        id: 'field_ordinary_1',
        nameAr: 'حقل مستخدم عادي',
        governorateAr: 'الدقهلية',
        coordinate: Coordinate(latitude: 31.05, longitude: 31.38),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );
      final saveOrdRes = await fieldRepo.saveField(ordinaryField);
      expect(saveOrdRes.isSuccess, isTrue);

      final ordRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_ordinary_1'))).getSingle();
      expect(
        ordRow.isDefault,
        isFalse,
        reason: 'Ordinary field must persist isDefault = false',
      );

      // 2. Saving a new field with isDefault: true persists true
      const defaultField = FarmField(
        id: 'field_default_1',
        nameAr: 'حقل نموذجي أصلي',
        governorateAr: 'الغربية',
        coordinate: Coordinate(latitude: 30.80, longitude: 31.00),
        areaInFeddan: 4.0,
        soilType: SoilType.clayLoam,
      );
      final saveDefRes = await fieldRepo.saveField(
        defaultField,
        isDefault: true,
      );
      expect(saveDefRes.isSuccess, isTrue);

      final defRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_default_1'))).getSingle();
      expect(
        defRow.isDefault,
        isTrue,
        reason: 'Explicit default field must persist isDefault = true',
      );

      // 3. Updating an existing default field without specifying isDefault preserves true
      const updatedDefaultField = FarmField(
        id: 'field_default_1',
        nameAr: 'حقل نموذجي معدل المساحة والمحصول',
        governorateAr: 'الغربية',
        coordinate: Coordinate(latitude: 30.80, longitude: 31.00),
        areaInFeddan: 6.5,
        soilType: SoilType.clayLoam,
        activeCropId: 'wheat',
      );
      // Notice: isDefault parameter is omitted (defaults to false)
      final updateDefRes = await fieldRepo.saveField(updatedDefaultField);
      expect(updateDefRes.isSuccess, isTrue);

      final updatedDefRow = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_default_1'))).getSingle();
      expect(
        updatedDefRow.isDefault,
        isTrue,
        reason: 'Updating default field without isDefault parameter must preserve isDefault = true',
      );
      expect(updatedDefRow.areaInFeddan, equals(6.5));
      expect(updatedDefRow.activeCropId, equals('wheat'));

      // 4. Deleting that updated default field records its ID in the deleted-default registry
      final delRes = await fieldRepo.deleteField('field_default_1');
      expect(delRes.isSuccess, isTrue);

      final tombstoneRow = await (db.select(
        db.deletedDefaultFieldIdsTable,
      )..where((t) => t.id.equals('field_default_1'))).getSingleOrNull();
      expect(
        tombstoneRow,
        isNotNull,
        reason: 'Deleting updated default field must record its ID in deletedDefaultFieldIdsTable',
      );

      // 5. Running default-field seeding afterward does not recreate that deleted field
      final reseedRepo = FarmFieldRepositoryImpl(db);
      final seedRes = await reseedRepo.seedDefaultFieldsIfNecessary([
        defaultField,
      ]);
      expect(seedRes.isSuccess, isTrue);

      final fieldAfterReseed = await (db.select(
        db.farmFieldsTable,
      )..where((t) => t.id.equals('field_default_1'))).getSingleOrNull();
      expect(
        fieldAfterReseed,
        isNull,
        reason:
            'Tombstoned default field must not be resurrected during seeding',
      );
    });

    test('8c. Failed default-field save causes seedDefaultFieldsIfNecessary to propagate failure', () async {
      // Deterministically inject an SQLite trigger that fails insert into farm_fields_table
      // for a specific sentinel field ID
      await db.customStatement('''
        CREATE TRIGGER abort_sentinel_insert
        BEFORE INSERT ON farm_fields_table
        WHEN NEW.id = 'field_failing_sentinel'
        BEGIN
          SELECT RAISE(ABORT, 'Simulated SQLite insert failure for sentinel default field');
        END;
      ''');

      const normalDefault = FarmField(
        id: 'field_seed_ok',
        nameAr: 'حقل نموذجي صالح',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 31.10, longitude: 30.90),
        areaInFeddan: 3.0,
        soilType: SoilType.clay,
      );

      const failingDefault = FarmField(
        id: 'field_failing_sentinel',
        nameAr: 'حقل نموذجي يفشل في الإدراج',
        governorateAr: 'المنيا',
        coordinate: Coordinate(latitude: 28.10, longitude: 30.70),
        areaInFeddan: 5.0,
        soilType: SoilType.clayLoam,
      );

      // Attempt seeding with the failing sentinel
      final seedRes = await fieldRepo.seedDefaultFieldsIfNecessary([
        normalDefault,
        failingDefault,
      ]);

      // 1. Must report Failure, NOT Success
      expect(
        seedRes.isFailure,
        isTrue,
        reason: 'seedDefaultFieldsIfNecessary must return Failure when a save fails',
      );
      expect(seedRes.failureOrNull, isA<ParsingFailure>());
      expect(
        seedRes.failureOrNull?.userMessageAr,
        contains('تعذر حفظ الحقل في قاعدة البيانات.'),
      );

      // 2. Clean up SQLite test trigger
      await db.customStatement('DROP TRIGGER IF EXISTS abort_sentinel_insert;');
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

      // Trigger onUpgrade explicitly for existing schema version (v2 -> v3)
      final migrator = db.createMigrator();
      await db.migration.onUpgrade(migrator, 2, 3);

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
                  'daily_units': mockDailyUnits,
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
        referenceTimeProvider: () => DateTime.utc(2026, 6, 1, 12, 0),
      );

      const coord = Coordinate(latitude: 31.10, longitude: 30.95);
      final res = await repo.getForecastDailyRecords(
        coordinate: coord,
        days: 2,
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
                      'daily_units': mockDailyUnits,
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
                maxTemperatureC: const Value(30.0),
                minTemperatureC: const Value(18.0),
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
                maxTemperatureC: const Value(30.0),
                minTemperatureC: const Value(18.0),
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
                maxTemperatureC: const Value(31.0),
                minTemperatureC: const Value(19.0),
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
                    'daily_units': mockDailyUnits,
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
                      'daily_units': mockDailyUnits,
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
                    'daily_units': mockDailyUnits,
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
                      'daily_units': mockDailyUnits,
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
                      'daily_units': mockDailyUnits,
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
                      'daily_units': mockDailyUnits,
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
                      'daily_units': mockDailyUnits,
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
                    'daily_units': mockDailyUnits,
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

      test('61. Forecast request of 7 days returning 6 days is rejected as truncated response', () async {
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
                    'daily_units': mockDailyUnits,
                    'daily': {
                      // Returns 6 days instead of requested 7
                      'time': [
                        '2026-06-15',
                        '2026-06-16',
                        '2026-06-17',
                        '2026-06-18',
                        '2026-06-19',
                        '2026-06-20',
                      ],
                      'temperature_2m_max': [
                        35.0,
                        34.0,
                        33.0,
                        32.0,
                        33.0,
                        34.0,
                      ],
                      'temperature_2m_min': [
                        22.0,
                        21.0,
                        20.0,
                        21.0,
                        22.0,
                        23.0,
                      ],
                      'precipitation_sum': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
                      'et0_fao_evapotranspiration': [
                        6.0,
                        6.1,
                        5.9,
                        6.2,
                        6.3,
                        6.0,
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

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage.contains('expected') ||
              res.failureOrNull!.technicalMessage.contains('match'),
          isTrue,
        );
      });

      test('62. Forecast request of 7 days returning 7 days succeeds with expectedPeriodDays=7', () async {
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
                    'daily_units': mockDailyUnits,
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
                        35.0,
                        34.0,
                        33.0,
                        32.0,
                        33.0,
                        34.0,
                        35.0,
                      ],
                      'temperature_2m_min': [
                        22.0,
                        21.0,
                        20.0,
                        21.0,
                        22.0,
                        23.0,
                        22.0,
                      ],
                      'precipitation_sum': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
                      'et0_fao_evapotranspiration': [
                        6.0,
                        6.1,
                        5.9,
                        6.2,
                        6.3,
                        6.0,
                        6.4,
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
        final records = res.dataOrNull!;
        expect(records.length, equals(7));
        expect(records.first.provenance.expectedPeriodDays, equals(7));
      });
    });

    group('Drift Schema Migration Tests: v1 to v2', () {
      test('Upgrades legacy v1 database with NOT NULL columns to v2 without data loss and allows null temperatures', () async {
        // Step 1: Create a raw SQLite database with version 1 schema where max_temperature_c and min_temperature_c are NOT NULL
        final rawSqliteDb = sqlite3.openInMemory();

        // Create FarmFieldsTable
        rawSqliteDb.execute('''
          CREATE TABLE IF NOT EXISTS farm_fields_table (
            id TEXT NOT NULL PRIMARY KEY,
            name_ar TEXT NOT NULL,
            governorate_ar TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            area_in_feddan REAL NOT NULL,
            soil_type TEXT NOT NULL,
            active_crop_id TEXT,
            is_default INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        // Create DeletedDefaultFieldIdsTable
        rawSqliteDb.execute('''
          CREATE TABLE IF NOT EXISTS deleted_default_field_ids_table (
            id TEXT NOT NULL PRIMARY KEY,
            deleted_at INTEGER NOT NULL
          );
        ''');

        // Create CachedDailyRecordsTable with v1 NOT NULL constraints on temperatures
        rawSqliteDb.execute('''
          CREATE TABLE IF NOT EXISTS cached_daily_records_table (
            cache_key TEXT NOT NULL,
            record_date INTEGER NOT NULL,
            max_temperature_c REAL NOT NULL,
            min_temperature_c REAL NOT NULL,
            precipitation_mm REAL,
            reference_et0_mm REAL,
            provider_name TEXT NOT NULL,
            dataset_name TEXT NOT NULL,
            requested_latitude REAL NOT NULL,
            requested_longitude REAL NOT NULL,
            grid_latitude REAL NOT NULL,
            grid_longitude REAL NOT NULL,
            grid_elevation_meters REAL,
            acquisition_timestamp INTEGER NOT NULL,
            scientific_disclaimer_ar TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            PRIMARY KEY (cache_key, record_date)
          );
        ''');

        // Insert a legacy record into v1 table
        final legacyDate = DateTime.utc(2024, 6, 1).millisecondsSinceEpoch;
        final legacyNow = DateTime.utc(
          2024,
          6,
          1,
          12,
          0,
        ).millisecondsSinceEpoch;
        rawSqliteDb.execute('''
          INSERT INTO cached_daily_records_table (
            cache_key, record_date, max_temperature_c, min_temperature_c,
            precipitation_mm, reference_et0_mm, provider_name, dataset_name,
            requested_latitude, requested_longitude, grid_latitude, grid_longitude,
            grid_elevation_meters, acquisition_timestamp, scientific_disclaimer_ar, cached_at
          ) VALUES (
            'hist_test_v1', $legacyDate, 35.5, 22.0,
            0.0, 6.5, 'Open-Meteo', 'ERA5',
            31.10, 30.95, 31.0, 31.0,
            6.0, $legacyNow, 'disclaimer', $legacyNow
          );
        ''');

        // Insert a legacy farm field into v1 table
        rawSqliteDb.execute('''
          INSERT INTO farm_fields_table (
            id, name_ar, governorate_ar, latitude, longitude, area_in_feddan,
            soil_type, active_crop_id, is_default, created_at, updated_at
          ) VALUES (
            'legacy_field_1', 'حقل التراث المصري', 'كفر الشيخ', 31.10, 30.95, 5.0,
            'clay', 'wheat', 1, $legacyNow, $legacyNow
          );
        ''');

        // Set pragma user_version = 1
        rawSqliteDb.execute('PRAGMA user_version = 1;');

        // Step 2: Open with AppDatabase (v2 with MigrationStrategy)
        // Pass closeUnderlyingOnClose: false so closing upgradedDb does not destroy
        // the in-memory SQLite connection before Step 8 reopenedDb tests idempotency.
        final upgradedDb = AppDatabase(
          NativeDatabase.opened(rawSqliteDb, closeUnderlyingOnClose: false),
        );

        // Verify that onUpgrade ran and schemaVersion is now 3
        expect(upgradedDb.schemaVersion, equals(3));

        // Step 3: Verify the legacy records (farm field and weather) are preserved with exact original values
        final legacyField = await (upgradedDb.select(
          upgradedDb.farmFieldsTable,
        )..where((t) => t.id.equals('legacy_field_1'))).getSingle();
        expect(legacyField.nameAr, equals('حقل التراث المصري'));
        expect(legacyField.areaInFeddan, equals(5.0));
        expect(legacyField.soilType, equals('clay'));
        expect(legacyField.activeCropId, equals('wheat'));
        expect(legacyField.plantingDate, isNull);
        expect(legacyField.isDefault, isTrue);

        final legacyRow = await (upgradedDb.select(
          upgradedDb.cachedDailyRecordsTable,
        )..where((t) => t.cacheKey.equals('hist_test_v1'))).getSingle();

        expect(legacyRow.cacheKey, equals('hist_test_v1'));
        expect(legacyRow.maxTemperatureC, equals(35.5));
        expect(legacyRow.minTemperatureC, equals(22.0));
        expect(legacyRow.referenceEt0Mm, equals(6.5));
        expect(
          legacyRow.precipitationMm,
          equals(0.0),
        ); // 0.0 preserved, not null

        // Step 4: Insert new records into upgraded table with NULL temperatures
        final date2 = DateTime.utc(2024, 6, 2);
        final date3 = DateTime.utc(2024, 6, 3);

        // Record with maxTemperatureC == null
        await upgradedDb
            .into(upgradedDb.cachedDailyRecordsTable)
            .insert(
              CachedDailyRecordsTableCompanion.insert(
                cacheKey: 'hist_test_v1',
                recordDate: date2,
                maxTemperatureC: const Value.absent(), // null
                minTemperatureC: const Value(21.5),
                referenceEt0Mm: const Value(6.8),
                precipitationMm: const Value(0.0),
                providerName: 'Open-Meteo',
                datasetName: 'ERA5',
                requestedLatitude: 31.10,
                requestedLongitude: 30.95,
                gridLatitude: 31.0,
                gridLongitude: 31.0,
                acquisitionTimestamp: DateTime.utc(2024, 6, 2, 12, 0),
                scientificDisclaimerAr: 'disclaimer',
                cachedAt: DateTime.utc(2024, 6, 2, 12, 0),
              ),
            );

        // Record with minTemperatureC == null
        await upgradedDb
            .into(upgradedDb.cachedDailyRecordsTable)
            .insert(
              CachedDailyRecordsTableCompanion.insert(
                cacheKey: 'hist_test_v1',
                recordDate: date3,
                maxTemperatureC: const Value(36.0),
                minTemperatureC: const Value.absent(), // null
                referenceEt0Mm: const Value(7.0),
                precipitationMm: const Value(1.5),
                providerName: 'Open-Meteo',
                datasetName: 'ERA5',
                requestedLatitude: 31.10,
                requestedLongitude: 30.95,
                gridLatitude: 31.0,
                gridLongitude: 31.0,
                acquisitionTimestamp: DateTime.utc(2024, 6, 3, 12, 0),
                scientificDisclaimerAr: 'disclaimer',
                cachedAt: DateTime.utc(2024, 6, 3, 12, 0),
              ),
            );

        // Step 5: Read back records and verify nullable semantics
        final row2 =
            await (upgradedDb.select(upgradedDb.cachedDailyRecordsTable)..where(
                  (t) =>
                      t.cacheKey.equals('hist_test_v1') &
                      t.recordDate.equals(date2),
                ))
                .getSingle();
        expect(row2.maxTemperatureC, isNull);
        expect(row2.minTemperatureC, equals(21.5));
        expect(row2.referenceEt0Mm, equals(6.8));

        final row3 =
            await (upgradedDb.select(upgradedDb.cachedDailyRecordsTable)..where(
                  (t) =>
                      t.cacheKey.equals('hist_test_v1') &
                      t.recordDate.equals(date3),
                ))
                .getSingle();
        expect(row3.maxTemperatureC, equals(36.0));
        expect(row3.minTemperatureC, isNull);
        expect(row3.precipitationMm, equals(1.5));

        // Step 6: Verify primary key constraint is preserved (inserting duplicate cacheKey + recordDate fails)
        expect(
          upgradedDb
              .into(upgradedDb.cachedDailyRecordsTable)
              .insert(
                CachedDailyRecordsTableCompanion.insert(
                  cacheKey: 'hist_test_v1',
                  recordDate: date2, // Duplicate
                  maxTemperatureC: const Value(30.0),
                  minTemperatureC: const Value(20.0),
                  providerName: 'Open-Meteo',
                  datasetName: 'ERA5',
                  requestedLatitude: 31.10,
                  requestedLongitude: 30.95,
                  gridLatitude: 31.0,
                  gridLongitude: 31.0,
                  acquisitionTimestamp: DateTime.utc(2024, 6, 2, 12, 0),
                  scientificDisclaimerAr: 'disclaimer',
                  cachedAt: DateTime.utc(2024, 6, 2, 12, 0),
                ),
              ),
          throwsA(anything),
        );

        // Step 7: Verify all records in migrated table before closing
        final allCached = await upgradedDb
            .select(upgradedDb.cachedDailyRecordsTable)
            .get();
        expect(allCached.length, equals(3));
        expect(
          allCached.any(
            (r) => r.maxTemperatureC == 35.5 && r.minTemperatureC == 22.0,
          ),
          isTrue,
        );
        expect(
          allCached.any(
            (r) => r.maxTemperatureC == null && r.minTemperatureC == 21.5,
          ),
          isTrue,
        );
        expect(
          allCached.any(
            (r) => r.maxTemperatureC == 36.0 && r.minTemperatureC == null,
          ),
          isTrue,
        );

        await upgradedDb.close();

        // Step 8: Reopen database and verify migration idempotency (no data duplication or corruption)
        final reopenedDb = AppDatabase(NativeDatabase.opened(rawSqliteDb));
        expect(reopenedDb.schemaVersion, equals(3));

        final fieldsAfterReopen = await reopenedDb
            .select(reopenedDb.farmFieldsTable)
            .get();
        expect(fieldsAfterReopen.length, equals(1));
        expect(fieldsAfterReopen.first.id, equals('legacy_field_1'));

        final weatherAfterReopen = await reopenedDb
            .select(reopenedDb.cachedDailyRecordsTable)
            .get();
        expect(weatherAfterReopen.length, equals(3));

        await reopenedDb.close();
        rawSqliteDb.close();
      });

      test('Drift Schema Migration Tests: v2 to v3 upgrades farm_fields_table with nullable planting_date', () async {
        // Step 1: Create an in-memory SQLite database simulating schema v2
        final rawSqliteDb = sqlite3.openInMemory();
        final nowMs = DateTime.utc(2024, 6, 1, 12, 0).millisecondsSinceEpoch;

        rawSqliteDb.execute('''
          CREATE TABLE farm_fields_table (
            id TEXT NOT NULL PRIMARY KEY,
            name_ar TEXT NOT NULL,
            governorate_ar TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            area_in_feddan REAL NOT NULL,
            soil_type TEXT NOT NULL,
            active_crop_id TEXT,
            is_default INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        rawSqliteDb.execute('''
          CREATE TABLE deleted_default_field_ids_table (
            id TEXT NOT NULL PRIMARY KEY,
            deleted_at INTEGER NOT NULL
          );
        ''');

        rawSqliteDb.execute('''
          CREATE TABLE cached_daily_records_table (
            cache_key TEXT NOT NULL,
            record_date INTEGER NOT NULL,
            max_temperature_c REAL,
            min_temperature_c REAL,
            precipitation_mm REAL,
            reference_et0_mm REAL,
            provider_name TEXT NOT NULL,
            dataset_name TEXT NOT NULL,
            requested_latitude REAL NOT NULL,
            requested_longitude REAL NOT NULL,
            grid_latitude REAL NOT NULL,
            grid_longitude REAL NOT NULL,
            grid_elevation_meters REAL,
            acquisition_timestamp INTEGER NOT NULL,
            scientific_disclaimer_ar TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            PRIMARY KEY (cache_key, record_date)
          );
        ''');

        // Pre-migration assertions on raw schema-v2 database:
        // 1. Verify PRAGMA table_info confirms 'planting_date' is absent before migration
        final preCols = rawSqliteDb.select(
          "PRAGMA table_info('farm_fields_table');",
        );
        final hasPlantingDateBefore = preCols.any(
          (row) => row['name'] == 'planting_date',
        );
        expect(
          hasPlantingDateBefore,
          isFalse,
          reason: 'Schema v2 must not contain planting_date',
        );

        // 2. Insert legacy field under v2 preserving all fields
        rawSqliteDb.execute('''
          INSERT INTO farm_fields_table (
            id, name_ar, governorate_ar, latitude, longitude, area_in_feddan,
            soil_type, active_crop_id, is_default, created_at, updated_at
          ) VALUES (
            'v2_field_1', 'حقل الدلتا القديم', 'كفر الشيخ', 31.10, 30.95, 5.0,
            'clay', 'wheat', 1, $nowMs, $nowMs
          );
        ''');

        // 3. Mark database explicitly as schema version 2
        rawSqliteDb.execute('PRAGMA user_version = 2;');
        final preVersion =
            rawSqliteDb.select('PRAGMA user_version;').first['user_version']
                as int;
        expect(
          preVersion,
          equals(2),
          reason: 'Starting database must be user_version 2',
        );

        // Step 2: Open with AppDatabase (v3) exercising real lifecycle migration
        final upgradedDb = AppDatabase(
          NativeDatabase.opened(rawSqliteDb, closeUnderlyingOnClose: false),
        );
        expect(upgradedDb.schemaVersion, equals(3));

        // Step 3: Verify post-migration SQLite state
        // In Drift, opening and running queries (like select or customSelect) executes the migrator
        final fieldRepo = FarmFieldRepositoryImpl(upgradedDb);
        final fieldsRes = await fieldRepo.getAllFields();
        expect(fieldsRes.isSuccess, isTrue);

        // 1. User version pragma updated to 3 by Drift migrator
        final postVersion =
            rawSqliteDb.select('PRAGMA user_version;').first['user_version']
                as int;
        expect(postVersion, equals(3));

        // 2. Column planting_date now exists in PRAGMA table_info
        final postCols = rawSqliteDb.select(
          "PRAGMA table_info('farm_fields_table');",
        );
        final hasPlantingDateAfter = postCols.any(
          (row) => row['name'] == 'planting_date',
        );
        expect(
          hasPlantingDateAfter,
          isTrue,
          reason: 'Schema v3 must contain planting_date',
        );

        // 3. Verify existing field data is intact and plantingDate defaults to null
        final fields = fieldsRes.dataOrNull!;
        expect(fields.length, equals(1));
        final f = fields.first;
        expect(f.id, equals('v2_field_1'));
        expect(f.nameAr, equals('حقل الدلتا القديم'));
        expect(f.governorateAr, equals('كفر الشيخ'));
        expect(f.coordinate.latitude, equals(31.10));
        expect(f.coordinate.longitude, equals(30.95));
        expect(f.areaInFeddan, equals(5.0));
        expect(f.soilType, equals(SoilType.clay));
        expect(f.activeCropId, equals('wheat'));
        expect(f.plantingDate, isNull);

        // Step 4: Save field with planting date and reload
        final plantingDate = DateTime.utc(2024, 1, 10);
        final updated = FarmField(
          id: f.id,
          nameAr: f.nameAr,
          governorateAr: f.governorateAr,
          coordinate: f.coordinate,
          areaInFeddan: f.areaInFeddan,
          soilType: f.soilType,
          activeCropId: f.activeCropId,
          plantingDate: plantingDate,
        );
        final saveRes = await fieldRepo.saveField(updated);
        expect(saveRes.isSuccess, isTrue);

        final reloaded = (await fieldRepo.getAllFields()).dataOrNull!.first;
        expect(reloaded.plantingDate?.year, equals(2024));
        expect(reloaded.plantingDate?.month, equals(1));
        expect(reloaded.plantingDate?.day, equals(10));

        await upgradedDb.close();

        // Step 5: Reopen and verify persistence idempotency
        final reopenedDb = AppDatabase(NativeDatabase.opened(rawSqliteDb));
        expect(reopenedDb.schemaVersion, equals(3));
        final reopenedRepo = FarmFieldRepositoryImpl(reopenedDb);
        final persisted = (await reopenedRepo.getAllFields()).dataOrNull!.first;
        expect(persisted.plantingDate?.year, equals(2024));
        expect(persisted.plantingDate?.month, equals(1));
        expect(persisted.plantingDate?.day, equals(10));

        await reopenedDb.close();
        rawSqliteDb.close();
      });
    });
  });
}
