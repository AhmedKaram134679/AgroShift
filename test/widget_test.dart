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
}
