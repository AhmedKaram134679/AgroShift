import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/data/datasources/remote/open_meteo_remote_data_source.dart';
import 'package:agro_shift/data/datasources/remote/open_meteo_adapter.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';

void main() {
  group('OpenMeteoRemoteDataSource HTTP Request & Deserialization Tests', () {
    const testLatitude = 31.05;
    const testLongitude = 31.20;

    final mockResponsePayload = <String, dynamic>{
      'latitude': testLatitude,
      'longitude': testLongitude,
      'generationtime_ms': 0.15,
      'utc_offset_seconds': 10800,
      'timezone': 'Africa/Cairo',
      'elevation': 12.0,
      'daily_units': {
        'time': 'iso8601',
        'temperature_2m_max': '°C',
        'temperature_2m_min': '°C',
        'et0_fao_evapotranspiration': 'mm',
        'precipitation_sum': 'mm',
      },
      'daily': {
        'time': ['2024-06-01', '2024-06-02', '2024-06-03'],
        'temperature_2m_max': [35.0, 36.0, 35.5],
        'temperature_2m_min': [21.0, 22.0, 21.5],
        'et0_fao_evapotranspiration': [6.5, 6.8, 6.7],
        'precipitation_sum': [0.0, 0.0, 0.0],
      },
    };

    test('fetchHistoricalDaily: verifies exact archive URL, models=era5, and parameters', () async {
      RequestOptions? capturedOptions;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: mockResponsePayload,
              ),
            );
          },
        ),
      );

      final dataSource = OpenMeteoRemoteDataSource(dio: dio);
      final dto = await dataSource.fetchHistoricalDaily(
        latitude: testLatitude,
        longitude: testLongitude,
        startDateIso: '2024-06-01',
        endDateIso: '2024-06-03',
      );

      // Verify URL and query parameters
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, equals('https://archive-api.open-meteo.com/v1/archive'));
      final qp = capturedOptions!.queryParameters;
      expect(qp['latitude'], equals(testLatitude));
      expect(qp['longitude'], equals(testLongitude));
      expect(qp['start_date'], equals('2024-06-01'));
      expect(qp['end_date'], equals('2024-06-03'));
      expect(qp['models'], equals('era5'), reason: 'Historical request must explicitly select models=era5');
      expect(qp['timezone'], equals('Africa/Cairo'));
      expect(
        qp['daily'],
        equals('temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum'),
      );

      // Verify deserialized DTO
      expect(dto.latitude, equals(testLatitude));
      expect(dto.longitude, equals(testLongitude));
      expect(dto.timezone, equals('Africa/Cairo'));
      expect(dto.daily['time'], equals(['2024-06-01', '2024-06-02', '2024-06-03']));
      expect(dto.daily['et0_fao_evapotranspiration'], equals([6.5, 6.8, 6.7]));
    });

    test('fetchForecastDaily: verifies forecast URL, forecast_days, and absence of models override', () async {
      RequestOptions? capturedOptions;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: mockResponsePayload,
              ),
            );
          },
        ),
      );

      final dataSource = OpenMeteoRemoteDataSource(dio: dio);
      final dto = await dataSource.fetchForecastDaily(
        latitude: testLatitude,
        longitude: testLongitude,
        forecastDays: 7,
      );

      // Verify URL and query parameters
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, equals('https://api.open-meteo.com/v1/forecast'));
      final qp = capturedOptions!.queryParameters;
      expect(qp['latitude'], equals(testLatitude));
      expect(qp['longitude'], equals(testLongitude));
      expect(qp['forecast_days'], equals(7));
      expect(qp.containsKey('models'), isFalse, reason: 'Forecast request must NOT override models parameter');
      expect(qp['timezone'], equals('Africa/Cairo'));
      expect(
        qp['daily'],
        equals('temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum'),
      );

      // Verify deserialized DTO
      expect(dto.latitude, equals(testLatitude));
      expect(dto.longitude, equals(testLongitude));
      expect(dto.timezone, equals('Africa/Cairo'));
    });

    test(
      'Live Open-Meteo ERA5 historical archive smoke test (opt-in)',
      () async {
        final dataSource = OpenMeteoRemoteDataSource();
        const coord = Coordinate(
          latitude: 31.0,
          longitude: 31.0,
          governorateName: 'كفر الشيخ',
        );

        final dto = await dataSource.fetchHistoricalDaily(
          latitude: coord.latitude,
          longitude: coord.longitude,
          startDateIso: '2024-06-01',
          endDateIso: '2024-06-03',
        );

        // Verify returned DTO structure and units
        expect(dto.dailyUnits['temperature_2m_max'], equals('°C'));
        expect(dto.dailyUnits['temperature_2m_min'], equals('°C'));
        expect(dto.dailyUnits['et0_fao_evapotranspiration'], equals('mm'));
        expect(dto.dailyUnits['precipitation_sum'], equals('mm'));

        final times = dto.daily['time'] as List;
        expect(times.length, equals(3));
        expect(times, equals(['2024-06-01', '2024-06-02', '2024-06-03']));

        // Pass response through the production DTO/adapter path
        final result = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5 Reanalysis Archive',
        );

        expect(result.isSuccess, isTrue);
        final records = result.dataOrNull!;
        expect(records.length, equals(3));

        for (final r in records) {
          expect(r.provenance.datasetName, equals('ERA5 Reanalysis Archive'));
          expect(r.referenceEt0Mm, isNotNull);
          expect(r.referenceEt0Mm!, greaterThanOrEqualTo(0.0));
          expect(r.referenceEt0Mm!, lessThanOrEqualTo(25.0));
          if (r.maxTemperatureC != null && r.minTemperatureC != null) {
            expect(r.maxTemperatureC!, greaterThanOrEqualTo(r.minTemperatureC!));
          }
        }
      },
      skip: Platform.environment['RUN_LIVE_API_TESTS'] != 'true'
          ? 'Opt-in live network smoke test skipped by default to keep test suite hermetic. Set RUN_LIVE_API_TESTS=true to enable.'
          : null,
    );
  });
}
