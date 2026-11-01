import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:agro_shift/app/theme.dart';
import 'package:agro_shift/presentation/main_navigation_shell.dart';
import 'package:agro_shift/presentation/screens/field_management_screen.dart';
import 'package:agro_shift/presentation/screens/environmental_analysis_screen.dart';
import 'package:agro_shift/presentation/providers/agro_providers.dart';
import 'package:agro_shift/domain/environment/repositories/i_weather_repository.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/environment/models/daily_agro_record.dart';
import 'package:agro_shift/domain/environment/models/data_source_provenance.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
import 'package:agro_shift/data/datasources/local/database/connection.dart';
import 'package:agro_shift/presentation/widgets/provenance_card.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/core/error/result.dart';

class MockWeatherRepository implements IWeatherRepository {
  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getForecastDailyRecords({
    required Coordinate coordinate,
    required int days,
  }) async {
    final prov = DataSourceProvenance(
      providerName: 'Test Mock Provider',
      datasetName: 'Mock Forecast',
      requestedLatitude: coordinate.latitude,
      requestedLongitude: coordinate.longitude,
      gridLatitude: coordinate.latitude,
      gridLongitude: coordinate.longitude,
      acquisitionTimestamp: DateTime.now().toUtc(),
    );
    return Success([
      DailyAgroRecord(
        date: DateTime.now(),
        maxTemperatureC: 32.0,
        minTemperatureC: 20.0,
        precipitationMm: 0.0,
        referenceEt0Mm: 4.5,
        provenance: prov,
      ),
    ]);
  }

  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getHistoricalDailyRecords({
    required Coordinate coordinate,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return const Success([]);
  }
}

void main() {
  testWidgets('AgroShiftApp bootstrap smoke test', (WidgetTester tester) async {
    final testDb = constructTestDb();
    addTearDown(() => testDb.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          weatherRepositoryProvider.overrideWithValue(MockWeatherRepository()),
        ],
        child: MaterialApp(
          theme: AgroTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MainNavigationShell(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main navigation shell renders
    expect(find.byType(MainNavigationShell), findsOneWidget);

    // Verify Arabic navigation items render
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المناخ'), findsOneWidget);
    expect(find.text('الدورات'), findsOneWidget);
    expect(find.text('الحقول'), findsOneWidget);
    expect(find.text('المنهجية'), findsOneWidget);
  });

  testWidgets(
    'ProvenanceCard displays requested and grid coordinates distinctly',
    (WidgetTester tester) async {
      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.1000,
        requestedLongitude: 30.9500,
        gridLatitude: 31.1250,
        gridLongitude: 31.0000,
        gridElevationMeters: 7.5,
        acquisitionTimestamp: DateTime.utc(2026, 10, 25, 12, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ProvenanceCard(provenance: prov)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('المصدر وبيانات التتبع العلمي (Provenance)'),
        findsOneWidget,
      );
      expect(find.text('الإحداثيات المطلوبة للحقل:'), findsOneWidget);
      expect(find.text('31.1000°N, 30.9500°E'), findsOneWidget);
      expect(find.text('إحداثيات خلية الشبكة (Grid):'), findsOneWidget);
      expect(find.text('31.1250°N, 31.0000°E'), findsOneWidget);
      expect(find.text('7.5 متر'), findsOneWidget);
    },
  );

  testWidgets(
    'Dashboard displays heat stress alert card when missingness exceeds validation threshold',
    (WidgetTester tester) async {
      // 7-day forecast with 2 missing maxTemperature days (2/7 = ~28.5% > 10% threshold)
      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'Mock Forecast',
        requestedLatitude: 31.1000,
        requestedLongitude: 30.9500,
        gridLatitude: 31.0,
        gridLongitude: 31.0,
        acquisitionTimestamp: DateTime.now().toUtc(),
        expectedPeriodDays: 7,
      );

      final records = List.generate(7, (i) {
        return DailyAgroRecord(
          date: DateTime(2024, 6, 1 + i),
          maxTemperatureC: i < 2 ? null : 36.0,
          minTemperatureC: 20.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 6.0,
          provenance: prov,
        );
      });

      final customRepo = _StaticWeatherRepository(records);
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(customRepo),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: MainNavigationShell(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that heat stress evaluation failed validation gracefully with the Arabic alert
      expect(
        find.text('تعذر تقييم الإجهاد الحراري — بيانات غير مكتملة'),
        findsOneWidget,
      );
      // Verify ETc water requirement section renders successfully because ET0 is complete
      expect(
        find.textContaining('الاستهلاك المائي التبخري للمحصول (ETc)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Dashboard displays ETc failure alert card when missingness exceeds validation threshold',
    (WidgetTester tester) async {
      // 7-day forecast with 2 missing referenceEt0Mm days (2/7 = ~28.5% > 10% threshold)
      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'Mock Forecast',
        requestedLatitude: 31.1000,
        requestedLongitude: 30.9500,
        gridLatitude: 31.0,
        gridLongitude: 31.0,
        acquisitionTimestamp: DateTime.now().toUtc(),
        expectedPeriodDays: 7,
      );

      final records = List.generate(7, (i) {
        return DailyAgroRecord(
          date: DateTime(2024, 6, 1 + i),
          maxTemperatureC: 36.0,
          minTemperatureC: 20.0,
          precipitationMm: 0.0,
          referenceEt0Mm: i < 2 ? null : 6.0,
          provenance: prov,
        );
      });

      final customRepo = _StaticWeatherRepository(records);
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(customRepo),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: MainNavigationShell(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that ETc calculation failed validation gracefully with the Arabic alert
      expect(
        find.text('تعذر حساب الاحتياج المائي (ETc) — بيانات غير مكتملة'),
        findsOneWidget,
      );
      // Heat stress succeeds because temperatures are 100% complete
      expect(find.text('مؤشر الإجهاد الحراري للمحصول:'), findsOneWidget);
    },
  );

  testWidgets(
    'Dashboard displays prompt to select crop when activeField has no selected crop',
    (WidgetTester tester) async {
      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'Mock Forecast',
        requestedLatitude: 31.1000,
        requestedLongitude: 30.9500,
        gridLatitude: 31.0,
        gridLongitude: 31.0,
        acquisitionTimestamp: DateTime.now().toUtc(),
        expectedPeriodDays: 7,
      );

      final records = List.generate(7, (i) {
        return DailyAgroRecord(
          date: DateTime(2024, 6, 1 + i),
          maxTemperatureC: 32.0,
          minTemperatureC: 20.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.5,
          provenance: prov,
        );
      });

      final customRepo = _StaticWeatherRepository(records);
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      // Create a field without an active crop
      const noCropField = FarmField(
        id: 'field_no_crop',
        nameAr: 'حقل بدون محصول',
        governorateAr: 'الغربية',
        coordinate: Coordinate(latitude: 31.1000, longitude: 30.9500),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
        activeCropId: null, // No crop selected
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(customRepo),
            fieldListProvider.overrideWith(
              () => _StaticFieldListNotifier([noCropField]),
            ),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(noCropField),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: MainNavigationShell(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify prompt to select crop is displayed
      expect(
        find.text(
          'يرجى تحديد المحصول القائم للحقل لحساب الاحتياج المائي الفعلي للمحصول (ETc).',
        ),
        findsOneWidget,
      );
      // Verify no volumetric crop demand is shown
      expect(
        find.textContaining('حجم البخر نتح التقديري للمحصول'),
        findsNothing,
      );
      // ET0 total is still displayed
      expect(
        find.textContaining('مجموع البخر نتح المرجعي (ET₀)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Dashboard displays unavailable data state when zero valid ET0 observations exist',
    (WidgetTester tester) async {
      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'Mock Forecast',
        requestedLatitude: 31.1000,
        requestedLongitude: 30.9500,
        gridLatitude: 31.0,
        gridLongitude: 31.0,
        acquisitionTimestamp: DateTime.now().toUtc(),
        expectedPeriodDays: 7,
      );

      // All 7 days have null referenceEt0Mm
      final records = List.generate(7, (i) {
        return DailyAgroRecord(
          date: DateTime(2024, 6, 1 + i),
          maxTemperatureC: 32.0,
          minTemperatureC: 20.0,
          precipitationMm: 0.0,
          referenceEt0Mm: null,
          provenance: prov,
        );
      });

      final customRepo = _StaticWeatherRepository(records);
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(customRepo),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: MainNavigationShell(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify unavailable ET0 message is displayed
      expect(
        find.text(
          'لا توجد قراءات صالحة للبخر نتح المرجعي (ET₀) خلال الفترة المطلوبة.',
        ),
        findsOneWidget,
      );
      // Verify ETc calculation failure is displayed
      expect(
        find.text('تعذر حساب الاحتياج المائي (ETc) — بيانات غير مكتملة'),
        findsOneWidget,
      );
      // Verify no volumetric demand is shown
      expect(find.textContaining('م³ / فدان'), findsNothing);
    },
  );

  testWidgets(
    'Dashboard displays successful ETc calculation and volumetric demand when ET0 series is complete',
    (WidgetTester tester) async {
      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'Mock Forecast',
        requestedLatitude: 31.1000,
        requestedLongitude: 30.9500,
        gridLatitude: 31.0,
        gridLongitude: 31.0,
        acquisitionTimestamp: DateTime.now().toUtc(),
        expectedPeriodDays: 7,
      );

      // 7 complete days with 5.0 mm/day ET0
      final records = List.generate(7, (i) {
        return DailyAgroRecord(
          date: DateTime(2024, 6, 1 + i),
          maxTemperatureC: 32.0,
          minTemperatureC: 20.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.0,
          provenance: prov,
        );
      });

      final customRepo = _StaticWeatherRepository(records);
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(customRepo),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: MainNavigationShell(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify complete ET0 period label is displayed
      expect(
        find.text('البخر نتح المرجعي (ET₀) — فترة 7 أيام'),
        findsOneWidget,
      );
      // Total ET0 is 35.0 mm
      expect(
        find.text('مجموع البخر نتح المرجعي (ET₀): 35.0 مم'),
        findsOneWidget,
      );
      // Verify ETc title and volumetric card render
      expect(
        find.textContaining('الاستهلاك المائي التبخري للمحصول (ETc)'),
        findsOneWidget,
      );
      expect(find.textContaining('م³ / فدان'), findsOneWidget);
    },
  );

  test(
    'fieldForecastProvider contract: invokes weather repository with exact selected field coordinates and days=7, preserving records and null semantics',
    () async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      const distinctiveCoordinate = Coordinate(
        latitude: 31.1234,
        longitude: 30.5678,
        governorateName: 'كفر الشيخ',
      );

      final distinctiveField = FarmField(
        id: 'field_contract_test',
        nameAr: 'حقل اختبار تعاقدي',
        governorateAr: 'كفر الشيخ',
        coordinate: distinctiveCoordinate,
        areaInFeddan: 7.5,
        soilType: SoilType.clay,
        activeCropId: 'wheat',
        plantingDate: DateTime.utc(2024, 1, 1),
      );

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'Contract Verification Dataset',
        requestedLatitude: distinctiveCoordinate.latitude,
        requestedLongitude: distinctiveCoordinate.longitude,
        gridLatitude: 31.1250,
        gridLongitude: 30.5750,
        acquisitionTimestamp: DateTime.utc(2026, 11, 1, 12, 0),
        expectedPeriodDays: 7,
      );

      final deterministicRecords = [
        DailyAgroRecord(
          date: DateTime.utc(2024, 6, 1),
          maxTemperatureC: 30.0,
          minTemperatureC: 18.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 0.0, // Affirmative zero
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(2024, 6, 2),
          maxTemperatureC: 31.0,
          minTemperatureC: 19.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.5,
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(2024, 6, 3),
          maxTemperatureC: 32.0,
          minTemperatureC: 20.0,
          precipitationMm: 1.2,
          referenceEt0Mm: null, // Missing observation
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(2024, 6, 4),
          maxTemperatureC: 33.0,
          minTemperatureC: 21.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 4.8,
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(2024, 6, 5),
          maxTemperatureC: 34.0,
          minTemperatureC: 22.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 5.2,
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(2024, 6, 6),
          maxTemperatureC: 35.0,
          minTemperatureC: 23.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 6.1,
          provenance: prov,
        ),
        DailyAgroRecord(
          date: DateTime.utc(2024, 6, 7),
          maxTemperatureC: 36.0,
          minTemperatureC: 24.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 7.0,
          provenance: prov,
        ),
      ];

      final capturingRepo = _CapturingWeatherRepository(deterministicRecords);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          weatherRepositoryProvider.overrideWithValue(capturingRepo),
          fieldListProvider.overrideWith(
            () => _StaticFieldListNotifier([distinctiveField]),
          ),
          selectedFieldProvider.overrideWith(
            () => _StaticFieldNotifier(distinctiveField),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Read fieldForecastProvider
      final result = await container.read(fieldForecastProvider.future);

      // 1. Verify getForecastDailyRecords was called exactly once
      expect(capturingRepo.getForecastCallCount, equals(1));

      // 2. Verify exact selected field coordinates were passed
      expect(capturingRepo.capturedCoordinate, equals(distinctiveCoordinate));

      // 3. Verify days equals 7
      expect(capturingRepo.capturedDays, equals(7));

      // 4. Verify provider returns success with same logical records
      expect(result.isSuccess, isTrue);
      final returnedRecords = result.dataOrNull!;

      // 5. Verify record count
      expect(returnedRecords.length, equals(7));

      // 6. Verify dates, ordering, and referenceEt0Mm values
      for (var i = 0; i < deterministicRecords.length; i++) {
        expect(returnedRecords[i].date, equals(deterministicRecords[i].date));
        expect(
          returnedRecords[i].referenceEt0Mm,
          equals(deterministicRecords[i].referenceEt0Mm),
        );
      }

      // 7. Verify null versus 0.0 distinction and no silent zero replacement
      expect(returnedRecords[0].referenceEt0Mm, equals(0.0));
      expect(returnedRecords[2].referenceEt0Mm, isNull);
      expect(returnedRecords[2].referenceEt0Mm, isNot(equals(0.0)));
    },
  );

  testWidgets(
    'Dashboard-to-ETc data handoff: preserves dates, order, ET0 values, null-vs-zero semantics, and requested period in calculation and UI',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      // Planting date: 2024-01-15 for wheat (duration 150 days)
      // Development stage: ages 31 to 75 days, Kc(age) = 0.40 + (age - 30) / 60
      final plantingDate = DateTime(2024, 1, 15);
      final field = FarmField(
        id: 'field_handoff_kafr_sheikh',
        nameAr: 'حقل اختبار تسليم البيانات',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
        activeCropId: 'wheat',
        plantingDate: plantingDate,
      );

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'Mock Forecast',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2026, 11, 1, 12, 0),
        expectedPeriodDays: 10,
      );

      // 10 consecutive forecast dates: 2024-02-24 (age 40) to 2024-03-04 (age 49)
      // Distinct ET0 values on each day with Day 0 = 0.0 and Day 7 = null
      final et0Values = <double?>[
        0.0, // Day 0 (age 40, Kc = 17/30): 0.0 * Kc = 0.0 mm
        3.0, // Day 1 (age 41, Kc = 35/60): 3.0 * (35/60) = 1.750 mm
        4.0, // Day 2 (age 42, Kc = 36/60): 4.0 * 0.60 = 2.400 mm
        5.0, // Day 3 (age 43, Kc = 37/60): 5.0 * (37/60) = 3.083333 mm
        6.0, // Day 4 (age 44, Kc = 38/60): 6.0 * (38/60) = 3.800 mm
        7.0, // Day 5 (age 45, Kc = 39/60): 7.0 * 0.65 = 4.550 mm
        8.0, // Day 6 (age 46, Kc = 40/60): 8.0 * (40/60) = 5.333333 mm
        null, // Day 7 (age 47, Kc = 41/60): null observation -> skipped
        4.5, // Day 8 (age 48, Kc = 42/60): 4.5 * 0.70 = 3.150 mm
        5.5, // Day 9 (age 49, Kc = 43/60): 5.5 * (43/60) = 3.941667 mm
      ];

      // Sum of ET0 = 0.0 + 3.0 + 4.0 + 5.0 + 6.0 + 7.0 + 8.0 + 4.5 + 5.5 = 43.0 mm
      // Sum of daily ETc = 28.008333 mm -> formatted as "28.0 مم"
      // Volume = 28.008333 * 4.2 = 117.635 m³/feddan -> formatted as "118 م³ / فدان"
      final records = List.generate(10, (i) {
        return DailyAgroRecord(
          date: plantingDate.add(Duration(days: 40 + i)),
          maxTemperatureC: 28.0,
          minTemperatureC: 16.0,
          precipitationMm: 0.0,
          referenceEt0Mm: et0Values[i],
          provenance: prov,
        );
      });

      final customRepo = _StaticWeatherRepository(records);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(customRepo),
            fieldListProvider.overrideWith(
              () => _StaticFieldListNotifier([field]),
            ),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(field),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: MainNavigationShell(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify requested forecast period (10 days) and available count (9 days)
      // Confirms expectedPeriodDays from provenance was preserved and 0.0 is counted while null is not
      expect(
        find.text('البخر نتح المرجعي (ET₀) — مجموع جزئي (9 من 10 أيام مطلوبة)'),
        findsOneWidget,
      );

      // 2. Verify partial reference ET0 total reflects exactly the 9 available days (43.0 mm)
      expect(
        find.text(
          'مجموع جزئي للبخر نتح المرجعي (9 من أصل 10 يوماً مطلوبة): 43.0 مم',
        ),
        findsOneWidget,
      );

      // 3. Verify missing observation warning identifies exactly 1 missing day
      expect(
        find.text(
          'تنبيه: التوقعات غير مكتملة لكامل الفترة (1 أيام بدون قراءة ET₀ صالحة من أصل 10 يوماً). المجموع المعروض يمثل الأيام المتوفرة فقط.',
        ),
        findsOneWidget,
      );

      // 4. Verify crop title identifies wheat correctly
      expect(
        find.text('الاستهلاك المائي التبخري للمحصول (ETc) — القمح'),
        findsOneWidget,
      );

      // 5. Verify partial ETc total: 28.0 mm
      // Proves chronological order and exact pairing of each ET0 value with that day's Kc
      expect(
        find.text('استهلاك مائي جزئي للمحصول (9 من 10 أيام): 28.0 مم'),
        findsOneWidget,
      );

      // 6. Verify volumetric demand reflects conversion: 118 m³/feddan
      expect(
        find.text(
          'حجم البخر نتح التقديري الجزئي للمحصول (القمح - للأيام المتوفرة): 118 م³ / فدان',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Dashboard add field button navigates to fields management tab and does not show manual snackbar',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(
              MockWeatherRepository(),
            ),
            fieldListProvider.overrideWith(() => _StaticFieldListNotifier([])),
            selectedFieldProvider.overrideWith(
              () => _NullSelectedFieldNotifier(),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: MainNavigationShell(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify add-field button is visible on dashboard empty state
      final addBtnFinder = find.widgetWithText(
        ElevatedButton,
        'إضافة حقل زراعي',
      );
      expect(addBtnFinder, findsOneWidget);

      // Verify initial selected navigation destination is index 0 (الرئيسية)
      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);
      final navBarInitial = tester.widget<NavigationBar>(navBarFinder);
      expect(navBarInitial.selectedIndex, equals(0));

      // 2. Tap the add-field button
      await tester.tap(addBtnFinder);
      await tester.pumpAndSettle();

      // 3. Verify destination tab switched to index 3 (الحقول / FieldManagementScreen)
      final navBarUpdated = tester.widget<NavigationBar>(navBarFinder);
      expect(navBarUpdated.selectedIndex, equals(3));

      // 4. Verify that old SnackBar message is NOT displayed
      expect(
        find.text('انتقل إلى قسم "الحقول" من الشريط السفلي لإضافة حقل جديد'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'FieldManagementScreen displays structured field cards and opens add field dialog',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      const activeField = FarmField(
        id: 'f_active',
        nameAr: 'حقل سيدي سالم (كفر الشيخ)',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(
          latitude: 31.10,
          longitude: 30.95,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
        activeCropId: 'wheat',
      );

      const inactiveField = FarmField(
        id: 'f_inactive',
        nameAr: 'مزرعة طنطا الإرشادية',
        governorateAr: 'الغربية',
        coordinate: Coordinate(
          latitude: 30.79,
          longitude: 31.00,
          governorateName: 'الغربية',
        ),
        areaInFeddan: 3.5,
        soilType: SoilType.clayLoam,
        activeCropId: 'berseem',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            weatherRepositoryProvider.overrideWithValue(
              MockWeatherRepository(),
            ),
            fieldListProvider.overrideWith(
              () => _StaticFieldListNotifier([activeField, inactiveField]),
            ),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: FieldManagementScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and registered fields count
      expect(find.text('الحقول المسجلة في مصر (2):'), findsOneWidget);

      // Verify both fields are rendered
      expect(find.text('حقل سيدي سالم (كفر الشيخ)'), findsOneWidget);
      expect(find.text('مزرعة طنطا الإرشادية'), findsOneWidget);

      // Verify active badge on active field and activate button on inactive field
      expect(find.text('الحقل النشط'), findsOneWidget);
      expect(find.text('تفعيل'), findsOneWidget);

      // Verify metadata is displayed without character squishing
      expect(find.text('5.0 فدان'), findsOneWidget);
      expect(find.text('3.5 فدان'), findsOneWidget);
      expect(find.text('تعديل المحصول والزراعة'), findsNWidgets(2));

      // Tap the FAB to open the Add Field Dialog
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Verify Dialog opens with title and inputs
      expect(find.text('إضافة حقل زراعي جديد في مصر'), findsOneWidget);
      expect(find.text('اسم الحقل / المزرعة'), findsOneWidget);
      expect(find.text('حفظ الحقل'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة حقل زراعي جديد في مصر'), findsNothing);
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen preserves ET0 completeness while disclosing missing temperature data',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 5,
      );

      // 5-day series: every day has valid ET0 (3.0 mm/day).
      // Day 3 (index 2) is missing Tmax (null).
      final records = List.generate(5, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: i == 2 ? null : 22.0,
          minTemperatureC: 12.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.0,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_analysis',
        nameAr: 'حقل التحليل الاختباري',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assertion A — ET₀ completeness is preserved:
      // The ET₀ summary must report complete ET₀ for all 5 days without claiming partial or missing ET₀.
      expect(
        find.textContaining('إجمالي الفاقد البخري خلال 5 يوماً: 15.0 مم'),
        findsOneWidget,
      );
      expect(
        find.textContaining('مجموع جزئي للفاقد البخري'),
        findsNothing,
      );
      expect(
        find.textContaining('بدون قراءة ET₀'),
        findsNothing,
      );

      // Assertion B — Missing temperature data is disclosed:
      // The UI must clearly disclose that temperature data is incomplete.
      expect(
        find.textContaining('بيانات درجات الحرارة غير مكتملة'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen displays no warnings when both ET0 and temperature data are complete',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 5,
      );

      // 5 complete days with all temperature and ET0 values present
      final records = List.generate(5, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: 22.0,
          minTemperatureC: 12.0,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.0,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_analysis_complete',
        nameAr: 'حقل التحليل المكتمل',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete ET0 displayed
      expect(
        find.textContaining('إجمالي الفاقد البخري خلال 5 يوماً: 15.0 مم'),
        findsOneWidget,
      );
      // No warnings displayed
      expect(find.textContaining('تنبيه:'), findsNothing);
      expect(find.textContaining('بيانات درجات الحرارة غير مكتملة'), findsNothing);
      expect(find.textContaining('بيانات البخر نتح المرجعي (ET₀) غير مكتملة'), findsNothing);
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen temperature chart: missing Tmax breaks Tmax line with nullSpot and keeps Tmin valid',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 5,
      );

      // 5-day series: Tmax is missing on Day 2 (index 2); Tmin is valid on all days.
      final records = List.generate(5, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: i == 2 ? null : 20.0 + i,
          minTemperatureC: 10.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.0,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_tmax_gap',
        nameAr: 'حقل اختبار فجوة العظمى',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tMaxBar = lineChart.data.lineBarsData[0];
      final tMinBar = lineChart.data.lineBarsData[1];

      // Tmax series must contain 5 chronological slots, with index 2 as nullSpot
      expect(tMaxBar.spots.length, 5);
      expect(tMaxBar.spots[0].x, 0.0);
      expect(tMaxBar.spots[0].y, 20.0);
      expect(tMaxBar.spots[0].isNotNull(), isTrue);
      expect(tMaxBar.spots[1].x, 1.0);
      expect(tMaxBar.spots[1].y, 21.0);
      expect(tMaxBar.spots[1].isNotNull(), isTrue);
      expect(tMaxBar.spots[2].isNull(), isTrue);
      expect(tMaxBar.spots[3].x, 3.0);
      expect(tMaxBar.spots[3].y, 23.0);
      expect(tMaxBar.spots[3].isNotNull(), isTrue);
      expect(tMaxBar.spots[4].x, 4.0);
      expect(tMaxBar.spots[4].y, 24.0);
      expect(tMaxBar.spots[4].isNotNull(), isTrue);

      // Tmin series must remain fully populated with no null spots
      expect(tMinBar.spots.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(tMinBar.spots[i].isNotNull(), isTrue);
        expect(tMinBar.spots[i].x, i.toDouble());
        expect(tMinBar.spots[i].y, 10.0 + i);
      }
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen temperature chart: missing Tmin breaks Tmin line with nullSpot and keeps Tmax valid',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 5,
      );

      // 5-day series: Tmin is missing on Day 1 (index 1); Tmax is valid on all days.
      final records = List.generate(5, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: 25.0 + i,
          minTemperatureC: i == 1 ? null : 15.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.0,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_tmin_gap',
        nameAr: 'حقل اختبار فجوة الصغرى',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tMaxBar = lineChart.data.lineBarsData[0];
      final tMinBar = lineChart.data.lineBarsData[1];

      // Tmax series must remain fully populated with no null spots
      expect(tMaxBar.spots.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(tMaxBar.spots[i].isNotNull(), isTrue);
        expect(tMaxBar.spots[i].x, i.toDouble());
        expect(tMaxBar.spots[i].y, 25.0 + i);
      }

      // Tmin series must contain 5 slots, with index 1 as nullSpot
      expect(tMinBar.spots.length, 5);
      expect(tMinBar.spots[0].x, 0.0);
      expect(tMinBar.spots[0].y, 15.0);
      expect(tMinBar.spots[0].isNotNull(), isTrue);
      expect(tMinBar.spots[1].isNull(), isTrue);
      expect(tMinBar.spots[2].x, 2.0);
      expect(tMinBar.spots[2].y, 17.0);
      expect(tMinBar.spots[2].isNotNull(), isTrue);
      expect(tMinBar.spots[3].x, 3.0);
      expect(tMinBar.spots[3].y, 18.0);
      expect(tMinBar.spots[3].isNotNull(), isTrue);
      expect(tMinBar.spots[4].x, 4.0);
      expect(tMinBar.spots[4].y, 19.0);
      expect(tMinBar.spots[4].isNotNull(), isTrue);
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen temperature chart: consecutive missing days remain as gaps and preserve original x indices',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 6,
      );

      // 6-day series:
      // Tmax missing on index 2, 3 (consecutive)
      // Tmin missing on index 3, 4 (consecutive)
      // On index 3, both are missing
      final records = List.generate(6, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: (i == 2 || i == 3) ? null : 20.0 + i,
          minTemperatureC: (i == 3 || i == 4) ? null : 10.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 2.5,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_consecutive_gaps',
        nameAr: 'حقل اختبار الفجوات المتتالية',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tMaxBar = lineChart.data.lineBarsData[0];
      final tMinBar = lineChart.data.lineBarsData[1];

      expect(tMaxBar.spots.length, 6);
      expect(tMaxBar.spots[0].x, 0.0);
      expect(tMaxBar.spots[1].x, 1.0);
      expect(tMaxBar.spots[2].isNull(), isTrue);
      expect(tMaxBar.spots[3].isNull(), isTrue);
      expect(tMaxBar.spots[4].isNotNull(), isTrue);
      expect(tMaxBar.spots[4].x, 4.0);
      expect(tMaxBar.spots[4].y, 24.0);
      expect(tMaxBar.spots[5].isNotNull(), isTrue);
      expect(tMaxBar.spots[5].x, 5.0);
      expect(tMaxBar.spots[5].y, 25.0);

      expect(tMinBar.spots.length, 6);
      expect(tMinBar.spots[0].x, 0.0);
      expect(tMinBar.spots[1].x, 1.0);
      expect(tMinBar.spots[2].isNotNull(), isTrue);
      expect(tMinBar.spots[2].x, 2.0);
      expect(tMinBar.spots[2].y, 12.0);
      expect(tMinBar.spots[3].isNull(), isTrue);
      expect(tMinBar.spots[4].isNull(), isTrue);
      expect(tMinBar.spots[5].isNotNull(), isTrue);
      expect(tMinBar.spots[5].x, 5.0);
      expect(tMinBar.spots[5].y, 15.0);
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen temperature chart: complete series preserves all day positions without null spots',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 5,
      );

      final records = List.generate(5, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: 22.0 + i,
          minTemperatureC: 12.0 + i,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.0,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_complete_chart',
        nameAr: 'حقل اختبار الرسم البياني المكتمل',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tMaxBar = lineChart.data.lineBarsData[0];
      final tMinBar = lineChart.data.lineBarsData[1];

      expect(tMaxBar.spots.length, 5);
      expect(tMinBar.spots.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(tMaxBar.spots[i].isNotNull(), isTrue);
        expect(tMaxBar.spots[i].x, i.toDouble());
        expect(tMaxBar.spots[i].y, 22.0 + i);

        expect(tMinBar.spots[i].isNotNull(), isTrue);
        expect(tMinBar.spots[i].x, i.toDouble());
        expect(tMinBar.spots[i].y, 12.0 + i);
      }
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen temperature chart: all Tmax readings missing renders safely with null spots and valid Tmin',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 5,
      );

      final distinctTminValues = [11.0, 13.5, 12.0, 15.0, 14.5];

      // 5-day series where every record has maxTemperatureC == null,
      // and each record has a distinct valid minTemperatureC.
      final records = List.generate(5, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: null,
          minTemperatureC: distinctTminValues[i],
          precipitationMm: 0.0,
          referenceEt0Mm: 3.5,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_all_tmax_null',
        nameAr: 'حقل اختبار غياب العظمى بالكامل',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      // Verify the screen builds and renders without throwing an exception
      await tester.pumpAndSettle();

      // Verify the LineChart widget is present
      expect(find.byType(LineChart), findsOneWidget);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tMaxBar = lineChart.data.lineBarsData[0];
      final tMinBar = lineChart.data.lineBarsData[1];

      // Verify Tmax series has exactly 5 spots and every single spot is a null spot (no fabricated values)
      expect(tMaxBar.spots.length, 5);
      expect(tMaxBar.spots.every((s) => s.isNull()), isTrue);
      expect(tMaxBar.spots.any((s) => s.isNotNull()), isFalse);

      // Verify Tmin series retains all original distinct values at correct chronological indices
      expect(tMinBar.spots.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(tMinBar.spots[i].isNotNull(), isTrue);
        expect(tMinBar.spots[i].x, i.toDouble());
        expect(tMinBar.spots[i].y, distinctTminValues[i]);
      }

      // Verify disclosure that temperature data is incomplete
      expect(
        find.textContaining('بيانات درجات الحرارة غير مكتملة'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'EnvironmentalAnalysisScreen temperature chart: all Tmin readings missing renders safely with null spots and valid Tmax',
    (WidgetTester tester) async {
      final testDb = constructTestDb();
      addTearDown(() => testDb.close());

      final prov = DataSourceProvenance(
        providerName: 'Open-Meteo Weather API',
        datasetName: 'ERA5 Reanalysis Archive',
        requestedLatitude: 31.27,
        requestedLongitude: 30.79,
        gridLatitude: 31.25,
        gridLongitude: 30.75,
        acquisitionTimestamp: DateTime.utc(2025, 1, 1),
        expectedPeriodDays: 5,
      );

      final distinctTmaxValues = [21.0, 24.5, 22.0, 26.5, 25.0];

      // 5-day series where every record has minTemperatureC == null,
      // and each record has a distinct valid maxTemperatureC.
      final records = List.generate(5, (i) {
        return DailyAgroRecord(
          date: DateTime.utc(2025, 1, 1 + i),
          maxTemperatureC: distinctTmaxValues[i],
          minTemperatureC: null,
          precipitationMm: 0.0,
          referenceEt0Mm: 3.5,
          provenance: prov,
        );
      });

      final activeField = FarmField(
        id: 'field_test_all_tmin_null',
        nameAr: 'حقل اختبار غياب الصغرى بالكامل',
        governorateAr: 'كفر الشيخ',
        coordinate: const Coordinate(
          latitude: 31.27,
          longitude: 30.79,
          governorateName: 'كفر الشيخ',
        ),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            selectedFieldProvider.overrideWith(
              () => _StaticFieldNotifier(activeField),
            ),
            fieldHistorical30DaysProvider.overrideWith(
              (ref) async => Success(records),
            ),
          ],
          child: MaterialApp(
            theme: AgroTheme.lightTheme,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: EnvironmentalAnalysisScreen(),
            ),
          ),
        ),
      );

      // Verify the screen builds and renders without throwing an exception
      await tester.pumpAndSettle();

      // Verify the LineChart widget is present
      expect(find.byType(LineChart), findsOneWidget);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tMaxBar = lineChart.data.lineBarsData[0];
      final tMinBar = lineChart.data.lineBarsData[1];

      // Verify Tmin series has exactly 5 spots and every single spot is a null spot (no fabricated values)
      expect(tMinBar.spots.length, 5);
      expect(tMinBar.spots.every((s) => s.isNull()), isTrue);
      expect(tMinBar.spots.any((s) => s.isNotNull()), isFalse);

      // Verify Tmax series retains all original distinct values at correct chronological indices
      expect(tMaxBar.spots.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(tMaxBar.spots[i].isNotNull(), isTrue);
        expect(tMaxBar.spots[i].x, i.toDouble());
        expect(tMaxBar.spots[i].y, distinctTmaxValues[i]);
      }

      // Verify disclosure that temperature data is incomplete
      expect(
        find.textContaining('بيانات درجات الحرارة غير مكتملة'),
        findsOneWidget,
      );
    },
  );
}

class _NullSelectedFieldNotifier extends SelectedFieldNotifier {
  @override
  FarmField? build() => null;
}

class _StaticFieldNotifier extends SelectedFieldNotifier {
  final FarmField _field;
  _StaticFieldNotifier(this._field);

  @override
  FarmField? build() => _field;
}

class _StaticFieldListNotifier extends FieldListNotifier {
  final List<FarmField> _fields;
  _StaticFieldListNotifier(this._fields);

  @override
  List<FarmField> build() => _fields;
}

class _StaticWeatherRepository implements IWeatherRepository {
  final List<DailyAgroRecord> records;
  _StaticWeatherRepository(this.records);

  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getForecastDailyRecords({
    required Coordinate coordinate,
    required int days,
  }) async {
    return Success(records);
  }

  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getHistoricalDailyRecords({
    required Coordinate coordinate,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return Success(records);
  }
}

class _CapturingWeatherRepository implements IWeatherRepository {
  final List<DailyAgroRecord> records;
  int getForecastCallCount = 0;
  Coordinate? capturedCoordinate;
  int? capturedDays;

  _CapturingWeatherRepository(this.records);

  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getForecastDailyRecords({
    required Coordinate coordinate,
    required int days,
  }) async {
    getForecastCallCount++;
    capturedCoordinate = coordinate;
    capturedDays = days;
    return Success(records);
  }

  @override
  Future<Result<List<DailyAgroRecord>, Failure>> getHistoricalDailyRecords({
    required Coordinate coordinate,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return Success(records);
  }
}
