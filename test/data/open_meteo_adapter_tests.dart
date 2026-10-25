import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/data/datasources/remote/open_meteo_adapter.dart';
import 'package:agro_shift/data/models/open_meteo_dto.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/domain/validation/scientific_range_validator.dart';

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
      // All 10 records are preserved; Day 1 is not dropped even though its temperature was missing
      expect(records.length, equals(10));
      // First created record corresponds to Day 1: temperature is null, ET0 is 5.0, precipitation is 0.0
      expect(records.first.maxTemperatureC, isNull);
      expect(records.first.minTemperatureC, isNull);
      expect(records.first.referenceEt0Mm, equals(5.0));
      expect(records.first.precipitationMm, equals(0.0));
      // Verify that expectedPeriodDays reflects the requested 10 days
      expect(records.first.provenance.expectedPeriodDays, equals(10));
      // Day 1 had valid ET0 (5.0), Day 2 had null ET0 -> 9 out of 10 days have available ET0
      final availableEt0Days = records
          .where((r) => r.referenceEt0Mm != null)
          .length;
      expect(availableEt0Days, equals(9));
      expect(
        records
            .where(
              (r) => r.maxTemperatureC == null || r.minTemperatureC == null,
            )
            .length,
        equals(1),
      );
    });

    test('Raw sequence: Valid consecutive daily sequence succeeds', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.0,
        utcOffsetSeconds: 7200,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-05-01', '2026-05-02', '2026-05-03'],
          'temperature_2m_max': [30.0, 31.0, 32.0],
          'temperature_2m_min': [20.0, 21.0, 22.0],
          'et0_fao_evapotranspiration': [5.0, 5.2, 5.4],
          'precipitation_sum': [0.0, 0.0, 0.0],
        },
      );

      final res = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'ERA5-Land',
        expectedStartDate: DateTime.utc(2026, 5, 1),
        expectedEndDate: DateTime.utc(2026, 5, 3),
        expectedCount: 3,
      );

      expect(res.isSuccess, isTrue);
      expect(res.dataOrNull!.length, equals(3));
    });

    test('Raw sequence: Duplicate dates in raw time array fail', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.0,
        utcOffsetSeconds: 7200,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-05-01', '2026-05-02', '2026-05-02'], // duplicate
          'temperature_2m_max': [30.0, 31.0, 32.0],
          'temperature_2m_min': [20.0, 21.0, 22.0],
          'et0_fao_evapotranspiration': [5.0, 5.2, 5.4],
          'precipitation_sum': [0.0, 0.0, 0.0],
        },
      );

      final res = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'ERA5-Land',
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ParsingFailure>());
      expect(
        res.failureOrNull?.technicalMessage.contains('Duplicate date'),
        isTrue,
      );
    });

    test('Raw sequence: Descending or unordered dates fail', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.0,
        utcOffsetSeconds: 7200,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-05-02', '2026-05-01'], // descending
          'temperature_2m_max': [31.0, 30.0],
          'temperature_2m_min': [21.0, 20.0],
          'et0_fao_evapotranspiration': [5.2, 5.0],
          'precipitation_sum': [0.0, 0.0],
        },
      );

      final res = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'ERA5-Land',
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ParsingFailure>());
      expect(
        res.failureOrNull?.technicalMessage.contains('Non-ascending'),
        isTrue,
      );
    });

    test('Raw sequence: Gap in raw daily date sequence fails', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.0,
        utcOffsetSeconds: 7200,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-05-01', '2026-05-03'], // missing 2026-05-02
          'temperature_2m_max': [30.0, 32.0],
          'temperature_2m_min': [20.0, 22.0],
          'et0_fao_evapotranspiration': [5.0, 5.4],
          'precipitation_sum': [0.0, 0.0],
        },
      );

      final res = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'ERA5-Land',
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ParsingFailure>());
      expect(
        res.failureOrNull?.technicalMessage.contains(
          'Gap in raw daily date sequence',
        ),
        isTrue,
      );
    });

    test('Raw sequence: Malformed date strings fail', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.0,
        utcOffsetSeconds: 7200,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026/05/01', '2026-05-02'], // non-conforming format
          'temperature_2m_max': [30.0, 31.0],
          'temperature_2m_min': [20.0, 21.0],
          'et0_fao_evapotranspiration': [5.0, 5.2],
          'precipitation_sum': [0.0, 0.0],
        },
      );

      final res = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'ERA5-Land',
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ParsingFailure>());
      expect(
        res.failureOrNull?.technicalMessage.contains(
          'Invalid or non-conforming date string',
        ),
        isTrue,
      );
    });

    test('Raw sequence: Date outside requested interval fails', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.0,
        utcOffsetSeconds: 7200,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-05-01', '2026-05-02'],
          'temperature_2m_max': [30.0, 31.0],
          'temperature_2m_min': [20.0, 21.0],
          'et0_fao_evapotranspiration': [5.0, 5.2],
          'precipitation_sum': [0.0, 0.0],
        },
      );

      // Expected interval starts May 2
      final res = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'ERA5-Land',
        expectedStartDate: DateTime.utc(2026, 5, 2),
        expectedEndDate: DateTime.utc(2026, 5, 3),
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ParsingFailure>());
      expect(
        res.failureOrNull?.technicalMessage.contains(
          'is before requested startDate',
        ),
        isTrue,
      );
    });

    test('Raw sequence: Mismatched parallel array lengths fail safely without exception', () {
      final dto = OpenMeteoDailyResponseDto(
        latitude: 31.05,
        longitude: 31.20,
        generationTimeMs: 1.0,
        utcOffsetSeconds: 7200,
        timezone: 'Africa/Cairo',
        dailyUnits: {},
        daily: {
          'time': ['2026-05-01', '2026-05-02'],
          'temperature_2m_max': [30.0], // only 1 element
          'temperature_2m_min': [20.0, 21.0],
          'et0_fao_evapotranspiration': [5.0, 5.2],
          'precipitation_sum': [0.0, 0.0],
        },
      );

      final res = OpenMeteoAdapter.toDomainRecords(
        dto: dto,
        requestedCoordinate: coord,
        datasetLabel: 'ERA5-Land',
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ParsingFailure>());
      expect(
        res.failureOrNull?.technicalMessage.contains(
          'Mismatched parallel array lengths',
        ),
        isTrue,
      );
    });

    group('Phase 2.1.x.5: Period Completeness and Mandatory Arrays Tests', () {
      final june1 = DateTime.utc(2026, 6, 1);
      final june30 = DateTime.utc(2026, 6, 30);
      const totalJuneDays = 30;

      OpenMeteoDailyResponseDto makeRangeDto(int startDay, int endDay) {
        final days = List.generate(
          endDay - startDay + 1,
          (i) => '2026-06-${(startDay + i).toString().padLeft(2, '0')}',
        );
        final len = days.length;
        return OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': days,
            'temperature_2m_max': List.filled(len, 35.0),
            'temperature_2m_min': List.filled(len, 22.0),
            'et0_fao_evapotranspiration': List.filled(len, 5.5),
            'precipitation_sum': List.filled(len, 0.0),
          },
        );
      }

      test('June 1-30 requested; June 1-20 returned (omits end): rejected', () {
        final dto = makeRangeDto(1, 20);
        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5-Land',
          expectedStartDate: june1,
          expectedEndDate: june30,
          expectedCount: totalJuneDays,
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage,
          contains('does not equal expected endDate'),
        );
      });

      test(
        'June 1-30 requested; June 5-30 returned (omits start): rejected',
        () {
          final dto = makeRangeDto(5, 30);
          final res = OpenMeteoAdapter.toDomainRecords(
            dto: dto,
            requestedCoordinate: coord,
            datasetLabel: 'ERA5-Land',
            expectedStartDate: june1,
            expectedEndDate: june30,
            expectedCount: totalJuneDays,
          );
          expect(res.isFailure, isTrue);
          expect(res.failureOrNull, isA<ParsingFailure>());
          expect(
            res.failureOrNull!.technicalMessage,
            contains('does not equal expected startDate'),
          );
        },
      );

      test(
        'June 1-30 requested; June 1-29 returned (off by one at end): rejected',
        () {
          final dto = makeRangeDto(1, 29);
          final res = OpenMeteoAdapter.toDomainRecords(
            dto: dto,
            requestedCoordinate: coord,
            datasetLabel: 'ERA5-Land',
            expectedStartDate: june1,
            expectedEndDate: june30,
            expectedCount: totalJuneDays,
          );
          expect(res.isFailure, isTrue);
          expect(res.failureOrNull, isA<ParsingFailure>());
          expect(
            res.failureOrNull!.technicalMessage,
            contains('does not equal expected endDate'),
          );
        },
      );

      test('June 1-30 requested; all dates returned correctly: accepted', () {
        final dto = makeRangeDto(1, 30);
        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5-Land',
          expectedStartDate: june1,
          expectedEndDate: june30,
          expectedCount: totalJuneDays,
        );
        expect(res.isSuccess, isTrue);
        expect(res.dataOrNull!.length, equals(30));
        expect(res.dataOrNull!.first.date, equals(june1));
        expect(res.dataOrNull!.last.date, equals(june30));
      });

      test('Empty historical raw response fails validation', () {
        final emptyDto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': [],
            'temperature_2m_max': [],
            'temperature_2m_min': [],
            'et0_fao_evapotranspiration': [],
            'precipitation_sum': [],
          },
        );

        final res = OpenMeteoAdapter.toDomainRecords(
          dto: emptyDto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5-Land',
          expectedStartDate: june1,
          expectedEndDate: june30,
          expectedCount: 30,
        );

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(res.failureOrNull!.technicalMessage, contains('empty'));
      });

      test('Missing mandatory ET0 array is rejected', () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01'],
            'temperature_2m_max': [30.0],
            'temperature_2m_min': [20.0],
            // et0 missing entirely
            'precipitation_sum': [0.0],
          },
        );

        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5-Land',
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage,
          contains('missing required daily arrays'),
        );
      });

      test('Missing mandatory temperature_2m_max array is rejected', () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01'],
            // temperature_2m_max missing entirely
            'temperature_2m_min': [20.0],
            'et0_fao_evapotranspiration': [5.0],
            'precipitation_sum': [0.0],
          },
        );

        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5',
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage,
          contains('missing required daily arrays'),
        );
      });

      test('Missing mandatory temperature_2m_min array is rejected', () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01'],
            'temperature_2m_max': [30.0],
            // temperature_2m_min missing entirely
            'et0_fao_evapotranspiration': [5.0],
            'precipitation_sum': [0.0],
          },
        );

        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5',
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage,
          contains('missing required daily arrays'),
        );
      });

      test('Missing mandatory precipitation array is rejected', () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01'],
            'temperature_2m_max': [30.0],
            'temperature_2m_min': [20.0],
            'et0_fao_evapotranspiration': [5.0],
            // precipitation missing entirely
          },
        );

        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5',
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage,
          contains('missing required daily arrays'),
        );
      });

      test('Mismatched ET0 array length is rejected', () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01', '2026-06-02'],
            'temperature_2m_max': [30.0, 31.0],
            'temperature_2m_min': [20.0, 21.0],
            'et0_fao_evapotranspiration': [5.0], // only 1 element
            'precipitation_sum': [0.0, 0.0],
          },
        );

        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5-Land',
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage,
          contains('Mismatched parallel array lengths'),
        );
      });

      test('Mismatched precipitation array length is rejected', () {
        final dto = OpenMeteoDailyResponseDto(
          latitude: 31.05,
          longitude: 31.20,
          generationTimeMs: 1.0,
          utcOffsetSeconds: 10800,
          timezone: 'Africa/Cairo',
          dailyUnits: {},
          daily: {
            'time': ['2026-06-01', '2026-06-02'],
            'temperature_2m_max': [30.0, 31.0],
            'temperature_2m_min': [20.0, 21.0],
            'et0_fao_evapotranspiration': [5.0, 5.2],
            'precipitation_sum': [0.0], // only 1 element
          },
        );

        final res = OpenMeteoAdapter.toDomainRecords(
          dto: dto,
          requestedCoordinate: coord,
          datasetLabel: 'ERA5-Land',
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ParsingFailure>());
        expect(
          res.failureOrNull!.technicalMessage,
          contains('Mismatched parallel array lengths'),
        );
      });

      test(
        'Permits legitimate null measurements and preserves distinct 0.0 value',
        () {
          final days = List.generate(
            10,
            (i) => '2026-06-${(i + 1).toString().padLeft(2, '0')}',
          );
          final et0s = List<double?>.filled(10, 5.0);
          et0s[1] = null; // 1 out of 10 missing (10% - allowed)
          final precip = List<double?>.filled(10, 0.0);
          precip[2] = null; // 1 out of 10 missing (10% - allowed)

          final dto = OpenMeteoDailyResponseDto(
            latitude: 31.05,
            longitude: 31.20,
            generationTimeMs: 1.0,
            utcOffsetSeconds: 10800,
            timezone: 'Africa/Cairo',
            dailyUnits: {},
            daily: {
              'time': days,
              'temperature_2m_max': List.filled(10, 30.0),
              'temperature_2m_min': List.filled(10, 20.0),
              'et0_fao_evapotranspiration': et0s,
              'precipitation_sum': precip,
            },
          );

          final res = OpenMeteoAdapter.toDomainRecords(
            dto: dto,
            requestedCoordinate: coord,
            datasetLabel: 'ERA5-Land',
            expectedStartDate: DateTime.utc(2026, 6, 1),
            expectedEndDate: DateTime.utc(2026, 6, 10),
            expectedCount: 10,
          );

          expect(res.isSuccess, isTrue);
          final recs = res.dataOrNull!;
          expect(recs.length, equals(10));
          // Day 1: precipitation was 0.0 (measured zero), et0 was 5.0
          expect(recs[0].precipitationMm, equals(0.0));
          expect(recs[0].precipitationMm, isNotNull);
          expect(recs[0].referenceEt0Mm, equals(5.0));
          // Day 2: et0 was null
          expect(recs[1].referenceEt0Mm, isNull);
          // Day 3: precipitation was null
          expect(recs[2].precipitationMm, isNull);
        },
      );

      test('Phase 2.1.x.7: Composite missingness: union of incomplete dates exceeding 10% is rejected by ScientificRangeValidator', () {
        // 10 requested days
        // Day 1 missing ET0 (1/10 = 10%)
        // Day 2 missing Precipitation (1/10 = 10%)
        // Both individual missingness ratios are <= 10%, but union of incomplete dates is 2/10 = 20% (> 10%)
        final unionSet = <int>{0, 1};
        final compositeVal =
            ScientificRangeValidator.validateCompositeMissingness(
              totalRequestedDays: 10,
              unionOfIncompleteDateIndices: unionSet,
              calculationLabel: 'احتياجات الري الحقلي المركبة',
              requiredVariables: ['ET0', 'Precipitation'],
            );

        expect(compositeVal.isFailure, isTrue);
        expect(compositeVal.failureOrNull, isA<InsufficientEvidenceFailure>());
        final failure = compositeVal.failureOrNull!;
        expect(failure.missingRatio, equals(0.20));
        expect(failure.missingCount, equals(2));
        expect(failure.totalCount, equals(10));
        expect(
          failure.technicalMessage,
          contains(
            'Composite missing ratio for احتياجات الري الحقلي المركبة across union of incomplete dates (2/10 = 20.0%) exceeds 10% threshold',
          ),
        );
      });

      test('Phase 2.1.x.7: Operational screening thresholds format as operational envelope rather than physical impossibility', () {
        // Temperature above 55°C
        final tempVal = ScientificRangeValidator.validateTemperature(
          tMax: 56.0,
          tMin: 25.0,
        );
        expect(tempVal.isFailure, isTrue);
        expect(
          tempVal.failureOrNull!.technicalMessage,
          contains('is outside configured operational screening range'),
        );
        expect(
          tempVal.failureOrNull!.userMessageAr,
          contains('خارج نطاق الفحص التشغيلي المعتمد في مصر'),
        );

        // Physical consistency violation (tMax < tMin) remains a physical consistency violation
        final consistencyVal = ScientificRangeValidator.validateTemperature(
          tMax: 20.0,
          tMin: 25.0,
        );
        expect(consistencyVal.isFailure, isTrue);
        expect(
          consistencyVal.failureOrNull!.technicalMessage,
          contains(
            'Physical consistency violation: tMax cannot be strictly less than tMin',
          ),
        );
        expect(
          consistencyVal.failureOrNull!.userMessageAr,
          contains('خطأ في الاتساق الفيزيائي لدرجات الحرارة'),
        );
      });

      group('Issue A Regression Tests: Independent Variable Preservation', () {
        const coord = Coordinate(latitude: 31.10, longitude: 30.95);

        test('Test A: Missing temperature with valid ET0 and precipitation preserves date and values', () {
          final times = List.generate(
            10,
            (i) => '2024-06-${(i + 1).toString().padLeft(2, '0')}',
          );
          // Day 3 (index 2) has missing temperature: 1/10 = 10% (within tolerance)
          final tMaxList = [
            32.0,
            33.0,
            null,
            35.0,
            34.0,
            33.0,
            32.0,
            31.0,
            30.0,
            31.0,
          ];
          final tMinList = [
            20.0,
            21.0,
            null,
            23.0,
            22.0,
            21.0,
            20.0,
            19.0,
            18.0,
            19.0,
          ];
          final et0List = [5.0, 5.2, 5.5, 5.3, 5.1, 5.0, 4.9, 4.8, 4.7, 4.8];
          final pList = [0.0, 0.0, 2.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

          final dto = OpenMeteoDailyResponseDto(
            latitude: 31.10,
            longitude: 30.95,
            generationTimeMs: 1.0,
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
            datasetLabel: 'ERA5-Test',
          );

          expect(result.isSuccess, isTrue);
          final records = result.dataOrNull!;
          // All 10 dates preserved in observation sequence
          expect(records.length, equals(10));

          // Date 3 (index 2): missing temperature, valid ET0 and precipitation
          final day3 = records[2];
          expect(day3.maxTemperatureC, isNull);
          expect(day3.minTemperatureC, isNull);
          expect(day3.meanTemperatureC, isNull);
          expect(day3.diurnalTemperatureRangeC, isNull);
          expect(day3.referenceEt0Mm, equals(5.5));
          expect(day3.precipitationMm, equals(2.5));

          // Sum of ET0 includes Day 3's 5.5 mm
          final expectedTotal = et0List.fold(0.0, (acc, v) => acc + v);
          final totalEt0 = records
              .where((r) => r.referenceEt0Mm != null)
              .fold(0.0, (acc, r) => acc + r.referenceEt0Mm!);
          expect(totalEt0, closeTo(expectedTotal, 0.001));
        });

        test('Test B: Missing ET0 with valid temperature preserves temperature and marks ET0 null', () {
          final times = List.generate(
            10,
            (i) => '2024-06-${(i + 1).toString().padLeft(2, '0')}',
          );
          final tMaxList = [
            32.0,
            33.0,
            34.0,
            35.0,
            34.0,
            33.0,
            32.0,
            31.0,
            30.0,
            31.0,
          ];
          final tMinList = [
            20.0,
            21.0,
            22.0,
            23.0,
            22.0,
            21.0,
            20.0,
            19.0,
            18.0,
            19.0,
          ];
          // Day 3 (index 2) missing ET0: 1/10 = 10% (within tolerance)
          final et0List = [5.0, 5.2, null, 5.3, 5.1, 5.0, 4.9, 4.8, 4.7, 4.8];
          final pList = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

          final dto = OpenMeteoDailyResponseDto(
            latitude: 31.10,
            longitude: 30.95,
            generationTimeMs: 1.0,
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
            datasetLabel: 'ERA5-Test',
          );

          expect(result.isSuccess, isTrue);
          final records = result.dataOrNull!;
          expect(records.length, equals(10));

          // Day 3 has valid temperature but null ET0
          final day3 = records[2];
          expect(day3.maxTemperatureC, equals(34.0));
          expect(day3.minTemperatureC, equals(22.0));
          expect(day3.referenceEt0Mm, isNull);

          final availableEt0Days = records
              .where((r) => r.referenceEt0Mm != null)
              .length;
          expect(availableEt0Days, equals(9));
        });

        test('Test C: Real zero precipitation (0.0) is preserved as 0.0 and not classified as missing', () {
          final times = ['2024-06-01'];
          final dto = OpenMeteoDailyResponseDto(
            latitude: 31.10,
            longitude: 30.95,
            generationTimeMs: 1.0,
            utcOffsetSeconds: 10800,
            timezone: 'Africa/Cairo',
            dailyUnits: {},
            daily: {
              'time': times,
              'temperature_2m_max': [32.0],
              'temperature_2m_min': [20.0],
              'et0_fao_evapotranspiration': [5.0],
              'precipitation_sum': [0.0],
            },
          );

          final result = OpenMeteoAdapter.toDomainRecords(
            dto: dto,
            requestedCoordinate: coord,
            datasetLabel: 'ERA5-Test',
          );

          expect(result.isSuccess, isTrue);
          final rec = result.dataOrNull!.first;
          expect(rec.precipitationMm, equals(0.0));
        });

        test('Test D: Missing precipitation (null) remains null and is not converted to 0.0', () {
          final times = List.generate(
            10,
            (i) => '2024-06-${(i + 1).toString().padLeft(2, '0')}',
          );
          final tMaxList = [
            32.0,
            33.0,
            34.0,
            35.0,
            34.0,
            33.0,
            32.0,
            31.0,
            30.0,
            31.0,
          ];
          final tMinList = [
            20.0,
            21.0,
            22.0,
            23.0,
            22.0,
            21.0,
            20.0,
            19.0,
            18.0,
            19.0,
          ];
          final et0List = [5.0, 5.2, 5.3, 5.3, 5.1, 5.0, 4.9, 4.8, 4.7, 4.8];
          // Day 1 missing precipitation: 1/10 = 10% (within tolerance)
          final pList = [null, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

          final dto = OpenMeteoDailyResponseDto(
            latitude: 31.10,
            longitude: 30.95,
            generationTimeMs: 1.0,
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
            datasetLabel: 'ERA5-Test',
          );

          expect(result.isSuccess, isTrue);
          final rec = result.dataOrNull!.first;
          expect(rec.precipitationMm, isNull);
        });

        test('Test E: ET0 total across a date sequence with missing temperature computes correctly', () {
          final times = List.generate(
            10,
            (i) => '2024-06-${(i + 1).toString().padLeft(2, '0')}',
          );
          // Day 2 has missing temperature (1/10 = 10%)
          final tMaxList = [
            30.0,
            null,
            32.0,
            33.0,
            34.0,
            35.0,
            34.0,
            33.0,
            32.0,
            31.0,
          ];
          final tMinList = [
            18.0,
            null,
            20.0,
            21.0,
            22.0,
            23.0,
            22.0,
            21.0,
            20.0,
            19.0,
          ];
          final et0List = [4.5, 5.0, 5.5, 5.2, 5.3, 5.4, 5.1, 4.9, 4.8, 5.0];
          final pList = List.filled(10, 0.0);

          final dto = OpenMeteoDailyResponseDto(
            latitude: 31.10,
            longitude: 30.95,
            generationTimeMs: 1.0,
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
            datasetLabel: 'ERA5-Test',
          );

          expect(result.isSuccess, isTrue);
          final records = result.dataOrNull!;
          expect(records.length, equals(10));

          final expectedSum = et0List.fold(0.0, (acc, v) => acc + v);
          final totalEt0 = records
              .where((r) => r.referenceEt0Mm != null)
              .fold(0.0, (acc, r) => acc + r.referenceEt0Mm!);
          expect(totalEt0, closeTo(expectedSum, 0.001));
          // Verify that Day 2's ET0 (5.0) contributed to the sum even though its temperature was missing
          expect(records[1].maxTemperatureC, isNull);
          expect(records[1].referenceEt0Mm, equals(5.0));
        });
      });
    });
  });
}
