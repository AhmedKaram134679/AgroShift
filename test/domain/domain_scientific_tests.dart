import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/validation/scientific_range_validator.dart';
import 'package:agro_shift/domain/agronomy/models/crop_catalog.dart';
import 'package:agro_shift/domain/agronomy/science/gdd_calculator.dart';
import 'package:agro_shift/domain/agronomy/science/etc_calculator.dart';
import 'package:agro_shift/domain/agronomy/science/heat_stress_evaluator.dart';
import 'package:agro_shift/domain/agronomy/science/rotation_evaluator.dart';
import 'package:agro_shift/domain/agronomy/science/rotation_presets.dart';

void main() {
  group('Geographic & Coordinate Validation', () {
    test('Accepts valid Nile Delta coordinates (Kafr El-Sheikh)', () {
      const coord = Coordinate(latitude: 31.11, longitude: 30.94);
      expect(coord.isWithinEgypt, isTrue);
      expect(coord.validate().isSuccess, isTrue);
    });

    test('Accepts valid Nile Valley coordinates (Aswan)', () {
      const coord = Coordinate(latitude: 24.08, longitude: 32.89);
      expect(coord.isWithinEgypt, isTrue);
      expect(coord.validate().isSuccess, isTrue);
    });

    test('Rejects coordinates outside Egypt (London, UK)', () {
      const coord = Coordinate(latitude: 51.50, longitude: -0.12);
      expect(coord.isWithinEgypt, isFalse);
      final res = coord.validate();
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull?.latitude, equals(51.50));
    });

    test('Rejects coordinates South of Egypt boundary (< 22.0)', () {
      const coord = Coordinate(latitude: 21.5, longitude: 30.0);
      expect(coord.isWithinEgypt, isFalse);
      expect(coord.validate().isFailure, isTrue);
    });
  });

  group('ScientificRangeValidator Tests', () {
    test('Validates typical Egyptian summer temperatures', () {
      final res = ScientificRangeValidator.validateTemperature(
        tMax: 38.5,
        tMin: 24.0,
      );
      expect(res.isSuccess, isTrue);
    });

    test('Rejects inverted temperature where tMax < tMin', () {
      final res = ScientificRangeValidator.validateTemperature(
        tMax: 20.0,
        tMin: 28.0,
      );
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull?.variableName, equals('tMax_less_than_tMin'));
    });

    test('Rejects impossible extreme heat (> 55°C)', () {
      final res = ScientificRangeValidator.validateTemperature(
        tMax: 65.0,
        tMin: 30.0,
      );
      expect(res.isFailure, isTrue);
    });

    test('Rejects negative or extreme ET0', () {
      expect(ScientificRangeValidator.validateEt0(-1.0).isFailure, isTrue);
      expect(ScientificRangeValidator.validateEt0(30.0).isFailure, isTrue);
      expect(ScientificRangeValidator.validateEt0(4.5).isSuccess, isTrue);
      expect(
        ScientificRangeValidator.validateEt0(null).isSuccess,
        isTrue,
      ); // Missing allowed as null
    });

    test('Rejects negative or extreme precipitation', () {
      expect(
        ScientificRangeValidator.validatePrecipitation(-5.0).isFailure,
        isTrue,
      );
      expect(
        ScientificRangeValidator.validatePrecipitation(300.0).isFailure,
        isTrue,
      );
      expect(
        ScientificRangeValidator.validatePrecipitation(0.0).isSuccess,
        isTrue,
      ); // 0.0 affirmative rain
      expect(
        ScientificRangeValidator.validatePrecipitation(null).isSuccess,
        isTrue,
      );
    });
  });

  group('GddCalculator Tests', () {
    test('Calculates simple GDD without cutoff correctly', () {
      // Mean temp = (30 + 20) / 2 = 25. Tbase = 10. GDD = 15
      final gdd = GddCalculator.calculateDailyGdd(
        tMax: 30.0,
        tMin: 20.0,
        tBase: 10.0,
      );
      expect(gdd, closeTo(15.0, 0.001));
    });

    test('Applies high-temperature cutoff for maize (Tcutoff = 30)', () {
      // Tmax = 38 (capped to 30), Tmin = 20. Mean = (30 + 20)/2 = 25. Tbase = 10. GDD = 15.
      final gdd = GddCalculator.calculateDailyGdd(
        tMax: 38.0,
        tMin: 20.0,
        tBase: 10.0,
        tCutoff: 30.0,
      );
      expect(gdd, closeTo(15.0, 0.001));
    });

    test('Returns 0.0 when temperature is below base temperature', () {
      final gdd = GddCalculator.calculateDailyGdd(
        tMax: 8.0,
        tMin: 2.0,
        tBase: 10.0,
      );
      expect(gdd, equals(0.0));
    });

    test(
      'Caps effective Tmin when Tmin exceeds Tcutoff during severe heatwave',
      () {
        // Tmax = 42 (capped to 30), Tmin = 32 (capped to 30). Mean = (30 + 30)/2 = 30. Tbase = 10. GDD = 20.
        final gdd = GddCalculator.calculateDailyGdd(
          tMax: 42.0,
          tMin: 32.0,
          tBase: 10.0,
          tCutoff: 30.0,
        );
        expect(gdd, closeTo(20.0, 0.001));
      },
    );

    test('Handles temperatures exactly at boundary thresholds', () {
      // Tmax = 30.0 (equals Tcutoff), Tmin = 10.0 (equals Tbase). Mean = 20. GDD = 10.
      final gdd = GddCalculator.calculateDailyGdd(
        tMax: 30.0,
        tMin: 10.0,
        tBase: 10.0,
        tCutoff: 30.0,
      );
      expect(gdd, closeTo(10.0, 0.001));
    });

    test(
      'Handles cold boundary where Tmin is below base and Tmax crosses base',
      () {
        // Tmax = 14, Tmin = 4 (elevated to 10). Mean = (14 + 10)/2 = 12. GDD = 12 - 10 = 2.
        final gdd = GddCalculator.calculateDailyGdd(
          tMax: 14.0,
          tMin: 4.0,
          tBase: 10.0,
        );
        expect(gdd, closeTo(2.0, 0.001));
      },
    );
  });

  group('EtcCalculator & Volumetric Conversion Tests', () {
    test('Calculates daily ETc = Kc * ET0', () {
      final etc = EtcCalculator.calculateDailyEtc(
        referenceEt0Mm: 5.0,
        cropKc: 1.15,
      );
      expect(etc, closeTo(5.75, 0.001));
    });

    test('Converts mm to m³ per Feddan accurately (1 mm = 4.2 m³/feddan)', () {
      final m3 = EtcCalculator.convertMmToCubicMetersPerFeddan(100.0);
      expect(m3, closeTo(420.0, 0.001));
    });

    test('Computes multi-stage cycle water requirement', () {
      final wheat = EgyptianCropsCatalog.wheat;
      final dailyEt0 = List.filled(150, 4.0); // 150 days at 4 mm/day
      final result = EtcCalculator.calculateCycleWaterRequirement(
        crop: wheat,
        dailyEt0Series: dailyEt0,
      );
      expect(result.totalEtcMm, greaterThan(200.0));
      expect(
        result.totalVolumeM3PerFeddan,
        closeTo(result.totalEtcMm * 4.2, 0.01),
      );
    });
  });

  group('HeatStressEvaluator Tests', () {
    test(
      'Identifies severe heat stress when threshold exceeded significantly',
      () {
        final wheat = EgyptianCropsCatalog.wheat; // Tcritical = 31°C
        final temps = [
          33.0,
          34.0,
          35.0,
          36.0,
          30.0,
        ]; // 4 out of 5 days exceed 31
        final eval = HeatStressEvaluator.evaluateCropHeatStress(
          crop: wheat,
          dailyTmaxSeries: temps,
        );
        expect(eval.totalExceedanceDays, equals(4));
        expect(eval.riskLevel, equals(HeatRiskLevel.severe));
        expect(eval.peakObservedTempC, equals(36.0));
      },
    );

    test('Evaluates low risk when temperatures remain moderate', () {
      final wheat = EgyptianCropsCatalog.wheat;
      final temps = [22.0, 24.0, 25.0, 26.0, 21.0];
      final eval = HeatStressEvaluator.evaluateCropHeatStress(
        crop: wheat,
        dailyTmaxSeries: temps,
      );
      expect(eval.totalExceedanceDays, equals(0));
      expect(eval.riskLevel, equals(HeatRiskLevel.low));
    });
  });

  group('RotationEvaluator Tests', () {
    test('Berseem to Maize results in positive soil enrichment', () {
      final res = RotationEvaluator.evaluate(
        sequence: RotationPresets.berseemToMaize,
        baselineAnnualEt0Mm: 1500.0,
      );
      expect(
        res.soilBalanceEffect,
        equals(SoilBalanceEffect.positiveEnrichment),
      );
      expect(res.hasTurnaroundConflict, isFalse);
      expect(res.estimatedAnnualWaterM3PerFeddan, greaterThan(3000.0));
    });

    test('Wheat to Maize results in cumulative soil depletion', () {
      final res = RotationEvaluator.evaluate(
        sequence: RotationPresets.wheatToMaize,
        baselineAnnualEt0Mm: 1500.0,
      );
      expect(
        res.soilBalanceEffect,
        equals(SoilBalanceEffect.cumulativeDepletion),
      );
    });

    test(
      'Wheat to Rice has significantly higher water demand than Wheat to Maize',
      () {
        final maizeRes = RotationEvaluator.evaluate(
          sequence: RotationPresets.wheatToMaize,
          baselineAnnualEt0Mm: 1500.0,
        );
        final riceRes = RotationEvaluator.evaluate(
          sequence: RotationPresets.wheatToRice,
          baselineAnnualEt0Mm: 1500.0,
        );
        expect(
          riceRes.estimatedAnnualWaterM3PerFeddan,
          greaterThan(maizeRes.estimatedAnnualWaterM3PerFeddan),
        );
      },
    );
  });

  group(
    'Issue B: Composite Missingness Validation & Calculation Integration Tests',
    () {
      test('1. totalRequestedDays == 0 fails closed with InsufficientEvidenceFailure', () {
        final res = ScientificRangeValidator.validateCompositeMissingness(
          totalRequestedDays: 0,
          unionOfIncompleteDateIndices: {},
          calculationLabel: 'Test Calc',
          requiredVariables: ['tMax', 'tMin'],
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull?.totalCount, equals(0));
        expect(res.failureOrNull?.missingRatio, equals(1.0));
        expect(
          res.failureOrNull?.technicalMessage,
          contains('requires totalRequestedDays > 0'),
        );
      });

      test('2. Negative totalRequestedDays (< 0) fails closed', () {
        final res = ScientificRangeValidator.validateCompositeMissingness(
          totalRequestedDays: -5,
          unionOfIncompleteDateIndices: {},
          calculationLabel: 'Test Calc',
          requiredVariables: ['tMax', 'tMin'],
        );
        expect(res.isFailure, isTrue);
      });

      test('3. Exactly 10% incomplete dates passes validation', () {
        final res = ScientificRangeValidator.validateCompositeMissingness(
          totalRequestedDays: 10,
          unionOfIncompleteDateIndices: {2}, // 1 out of 10 = 10.0%
          calculationLabel: 'Test Calc',
          requiredVariables: ['tMax', 'tMin'],
        );
        expect(res.isSuccess, isTrue);
      });

      test('4. More than 10% incomplete dates fails validation', () {
        final res = ScientificRangeValidator.validateCompositeMissingness(
          totalRequestedDays: 10,
          unionOfIncompleteDateIndices: {2, 5}, // 2 out of 10 = 20.0%
          calculationLabel: 'Test Calc',
          requiredVariables: ['tMax', 'tMin'],
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull?.missingCount, equals(2));
        expect(res.failureOrNull?.totalCount, equals(10));
        expect(res.failureOrNull?.missingRatio, closeTo(0.20, 0.001));
      });

      test('5 & 6. Multi-variable calculation evaluates union of incomplete dates and deduplicates overlaps', () {
        // 10 requested days
        // Date 2 missing tMax
        // Date 2 and Date 4 missing tMin
        // Union is {2, 4} = 2 dates out of 10 (20%) -> fails (> 10%)
        final observations = List.generate(
          10,
          (i) => (
            date: DateTime.utc(2024, 6, i + 1),
            tMax: (i == 2) ? null : 30.0,
            tMin: (i == 2 || i == 4) ? null : 20.0,
          ),
        );

        final res = GddCalculator.calculateAccumulatedGddValidated(
          totalRequestedDays: 10,
          observations: observations,
          tBase: 10.0,
        );

        expect(res.isFailure, isTrue);
        expect(
          res.failureOrNull?.missingCount,
          equals(2),
        ); // Union count is 2, not 3
        expect(res.failureOrNull?.technicalMessage, contains('2/10 = 20.0%'));
      });

      test('7. Missing unrelated variable does not invalidate single-variable calculation', () {
        // Heat stress requires only tMax.
        // Missing ET0 or precipitation has no effect.
        final wheat =
            EgyptianCropsCatalog.wheat; // criticalHeatTemperatureC = 31.0
        // 4 days >= 31.0 (32, 33, 32, 33) and 6 days < 31.0 (30, 29, 30, 29, 30, 29)
        final tMaxSeries = [
          30.0,
          29.0,
          32.0,
          33.0,
          30.0,
          29.0,
          32.0,
          33.0,
          30.0,
          29.0,
        ];

        final res = HeatStressEvaluator.evaluateCropHeatStressValidated(
          crop: wheat,
          totalRequestedDays: 10,
          dailyTmaxSeries: tMaxSeries,
        );

        expect(res.isSuccess, isTrue);
        expect(
          res.dataOrNull?.totalExceedanceDays,
          equals(4),
        ); // 4 exceedance days
      });

      test('8. ET0 calculation fails when ET0 own missingness exceeds 10%', () {
        final wheat = EgyptianCropsCatalog.wheat;
        // 2 out of 10 days missing ET0 (20%)
        final et0Series = [5.0, null, 5.2, null, 5.4, 5.5, 5.4, 5.3, 5.2, 5.1];

        final res = EtcCalculator.calculateCycleWaterRequirementValidated(
          crop: wheat,
          totalRequestedDays: 10,
          dailyEt0Series: et0Series,
        );

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull?.missingCount, equals(2));
        expect(res.failureOrNull?.missingRatio, closeTo(0.20, 0.001));
        expect(
          res.failureOrNull?.variableName,
          equals('composite_Crop Water Requirement (ETc)'),
        );
      });

      test('9. Temperature-only calculation is not rejected when precipitation is missing', () {
        final wheat =
            EgyptianCropsCatalog.wheat; // criticalHeatTemperatureC = 31.0
        // 10 complete tMax values all below 31.0 -> 0 exceedances -> HeatRiskLevel.low
        final tMaxSeries = [
          25.0,
          26.0,
          27.0,
          28.0,
          27.0,
          26.0,
          25.0,
          26.0,
          27.0,
          28.0,
        ];

        final res = HeatStressEvaluator.evaluateCropHeatStressValidated(
          crop: wheat,
          totalRequestedDays: 10,
          dailyTmaxSeries: tMaxSeries,
        );

        expect(res.isSuccess, isTrue);
        expect(res.dataOrNull?.riskLevel, equals(HeatRiskLevel.low));
      });

      test('10 & 11. Service integration: GddCalculator succeeds at <= 10% and fails when > 10%', () {
        // Case 1: Exactly 1 missing day out of 10 (10%) -> SUCCEEDS
        final obsPassing = List.generate(
          10,
          (i) => (
            date: DateTime.utc(2024, 6, i + 1),
            tMax: (i == 1) ? null : 30.0,
            tMin: 20.0,
          ),
        );

        final passRes = GddCalculator.calculateAccumulatedGddValidated(
          totalRequestedDays: 10,
          observations: obsPassing,
          tBase: 10.0,
        );

        expect(passRes.isSuccess, isTrue);
        // 9 days of ( (30+20)/2 - 10 ) = 15.0 each -> 9 * 15 = 135.0
        expect(passRes.dataOrNull, closeTo(135.0, 0.001));

        // Case 2: 2 missing days out of 10 (20%) -> FAILS
        final obsFailing = List.generate(
          10,
          (i) => (
            date: DateTime.utc(2024, 6, i + 1),
            tMax: (i == 1 || i == 3) ? null : 30.0,
            tMin: 20.0,
          ),
        );

        final failRes = GddCalculator.calculateAccumulatedGddValidated(
          totalRequestedDays: 10,
          observations: obsFailing,
          tBase: 10.0,
        );

        expect(failRes.isFailure, isTrue);
        expect(
          failRes.failureOrNull?.technicalMessage,
          contains('2/10 = 20.0%'),
        );
      });
    },
  );
}
