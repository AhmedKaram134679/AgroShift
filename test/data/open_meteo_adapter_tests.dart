import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/data/datasources/remote/open_meteo_adapter.dart';
import 'package:agro_shift/data/models/open_meteo_dto.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/core/error/failures.dart';

void main() {
  group('OpenMeteoAdapter & Provenance Tests', () {
    const coord = Coordinate(
      latitude: 31.05,
      longitude: 31.20,
      governorateName: 'الدقهلية',
    );

    test('Successfully converts valid DTO to DailyAgroRecord list', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.5,
        utcOffsetSeconds: 10800,
        timezone: 'Africa/Cairo',
        elevation: 15.0,
        dailyUnits: {
          'temperature_2m_max': '°C',
          'temperature_2m_min': '°C',
          'et0_fao_evapotranspiration': 'mm',
          'precipitation_sum': 'mm',
        },
        daily: {
          'time': ['2026-06-01', '2026-06-02'],
          'temperature_2m_max': [34.5, 35.2],
          'temperature_2m_min': [22.0, 23.1],
          'et0_fao_evapotranspiration': [6.2, 6.5],
          'precipitation_sum': [0.0, 0.0], // Measured zero
        },
      );

      final result = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'Test ERA5',
      );

      expect(result.isSuccess, isTrue);
      final records = result.dataOrNull!;
      expect(records.length, equals(2));
      expect(records[0].maxTemperatureC, equals(34.5));
      expect(records[0].precipitationMm, equals(0.0)); // Exact 0.0 preserved
      expect(records[0].provenance.gridLatitude, equals(31.05));
    });

    test('Fails when missing temperature ratio exceeds 10%', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.2,
        utcOffsetSeconds: 10800,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-06-01', '2026-06-02', '2026-06-03', '2026-06-04'],
          'temperature_2m_max': [
            34.0,
            null,
            null,
            35.0,
          ], // 2 of 4 missing = 50%
          'temperature_2m_min': [22.0, null, null, 23.0],
          'et0_fao_evapotranspiration': [6.0, 6.1, 6.2, 6.2],
          'precipitation_sum': [0.0, 0.0, 0.0, 0.0],
        },
      );

      final result = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'Test ERA5',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<InsufficientEvidenceFailure>());
      final fail = result.failureOrNull as InsufficientEvidenceFailure;
      expect(fail.variableName, equals('temperature'));
      expect(fail.missingRatio, equals(0.5));
    });

    test(
      'Fails when ET0 is missing beyond 10% even if temperature is complete',
      () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.2,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01', '2026-06-02', '2026-06-03', '2026-06-04'],
            'temperature_2m_max': [34.0, 33.0, 35.0, 35.0],
            'temperature_2m_min': [22.0, 21.0, 23.0, 23.0],
            'et0_fao_evapotranspiration': [
              6.0,
              null,
              null,
              6.2,
            ], // 2 of 4 = 50%
            'precipitation_sum': [0.0, 0.0, 0.0, 0.0],
          },
        );

        final result = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'Test ERA5',
        );

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<InsufficientEvidenceFailure>());
        final fail = result.failureOrNull as InsufficientEvidenceFailure;
        expect(fail.variableName, equals('et0'));
        expect(fail.missingRatio, equals(0.5));
      },
    );

    test('Fails when precipitation is missing beyond 10%', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.2,
        utcOffsetSeconds: 10800,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-06-01', '2026-06-02', '2026-06-03', '2026-06-04'],
          'temperature_2m_max': [34.0, 33.0, 35.0, 35.0],
          'temperature_2m_min': [22.0, 21.0, 23.0, 23.0],
          'et0_fao_evapotranspiration': [6.0, 6.1, 6.2, 6.2],
          'precipitation_sum': [0.0, null, null, 0.0], // 2 of 4 = 50%
        },
      );

      final result = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'Test ERA5',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<InsufficientEvidenceFailure>());
      final fail = result.failureOrNull as InsufficientEvidenceFailure;
      expect(fail.variableName, equals('precipitation'));
    });

    test(
      'Accepts series with missingness within the allowed 10% tolerance',
      () {
        // 1 missing day out of 20 = 5% missingness (<= 10%)
        final times = List.generate(
          20,
          (i) => '2026-06-${(i + 1).toString().padLeft(2, '0')}',
        );
        final tMaxList = List.generate(20, (i) => 32.0);
        final tMinList = List.generate(20, (i) => 20.0);
        final et0List = List.generate(
          20,
          (i) => i == 5 ? null : 5.0,
        ); // 1 null = 5%
        final pList = List.generate(20, (i) => 0.0);

        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.2,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': times,
            'temperature_2m_max': tMaxList,
            'temperature_2m_min': tMinList,
            'et0_fao_evapotranspiration': et0List,
            'precipitation_sum': pList,
          },
        );

        final result = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'Test ERA5',
        );

        expect(result.isSuccess, isTrue);
        final records = result.dataOrNull!;
        expect(records.length, equals(20));
        // Preserved exact null for day 5, other days have non-null 5.0
        expect(records[5].referenceEt0Mm, isNull);
        expect(records[0].referenceEt0Mm, equals(5.0));
        expect(records[0].precipitationMm, equals(0.0)); // Exact measured zero
      },
    );

    test(
      'Fails when temperature data contains physical violation (tMax < tMin)',
      () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.2,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01'],
            'temperature_2m_max': [20.0],
            'temperature_2m_min': [28.0], // Invalid: min > max
            'et0_fao_evapotranspiration': [5.0],
            'precipitation_sum': [0.0],
          },
        );

        final result = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'Test ERA5',
        );

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<PhysicalRangeFailure>());
      },
    );

    test('Denominator represents total expected interval days and preserves distinct variable missingness', () {
      // 10 days total:
      // Day 1: missing temperature (skipped from DailyAgroRecord, but counted in denominator)
      // Day 2: missing ET0 only
      // Day 3: missing precipitation only
      // Days 4-10: complete
      // Temp missing: 1/10 = 10% (allowed)
      // ET0 missing: 1/10 = 10% (allowed)
      // Precip missing: 1/10 = 10% (allowed)
      final times = List.generate(
        10,
        (i) => '2026-06-${(i + 1).toString().padLeft(2, '0')}',
      );
      final tMaxList = [
        null,
        32.0,
        33.0,
        34.0,
        35.0,
        36.0,
        35.0,
        34.0,
        33.0,
        32.0,
      ];
      final tMinList = [
        null,
        20.0,
        21.0,
        22.0,
        23.0,
        24.0,
        23.0,
        22.0,
        21.0,
        20.0,
      ];
      final et0List = [5.0, null, 5.2, 5.3, 5.4, 5.5, 5.4, 5.3, 5.2, 5.1];
      final pList = [0.0, 0.0, null, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.2,
        utcOffsetSeconds: 10800,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': times,
          'temperature_2m_max': tMaxList,
          'temperature_2m_min': tMinList,
          'et0_fao_evapotranspiration': et0List,
          'precipitation_sum': pList,
        },
      );

      final result = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'Test ERA5',
      );

      // Exactly 10% missing for each variable => within tolerance threshold
      expect(result.isSuccess, isTrue);
      final records = result.dataOrNull!;
      // Total records created is 9 because Day 1 had missing temperature
      expect(records.length, equals(9));
      // First created record corresponds to Day 2: ET0 is null, precipitation is 0.0
      expect(records[0].referenceEt0Mm, isNull);
      expect(records[0].precipitationMm, equals(0.0));
      // Second created record corresponds to Day 3: ET0 is 5.2, precipitation is null
      expect(records[1].referenceEt0Mm, equals(5.2));
      expect(records[1].precipitationMm, isNull);
    });
  });
}
