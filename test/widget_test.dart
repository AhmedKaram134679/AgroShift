import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/app/theme.dart';
import 'package:agro_shift/presentation/main_navigation_shell.dart';
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
}

class _StaticFieldNotifier extends SelectedFieldNotifier {
  final FarmField _field;
  _StaticFieldNotifier(this._field);

  @override
  FarmField build() => _field;
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
