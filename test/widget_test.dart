import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/app/theme.dart';
import 'package:agro_shift/presentation/main_navigation_shell.dart';
import 'package:agro_shift/presentation/screens/field_management_screen.dart';
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
