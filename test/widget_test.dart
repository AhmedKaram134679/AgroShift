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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
}
