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
      expect(ScientificRangeValidator.validateEt0(null).isSuccess, isTrue);
      expect(ScientificRangeValidator.validateEt0(0.0).isSuccess, isTrue);
      expect(ScientificRangeValidator.validateEt0(7.5).isSuccess, isTrue);
      expect(ScientificRangeValidator.validateEt0(25.0).isSuccess, isTrue);
      expect(ScientificRangeValidator.validateEt0(-0.01).isFailure, isTrue);
      expect(ScientificRangeValidator.validateEt0(25.01).isFailure, isTrue);
      expect(
        ScientificRangeValidator.validateEt0(double.nan).isFailure,
        isTrue,
      );
      expect(
        ScientificRangeValidator.validateEt0(double.infinity).isFailure,
        isTrue,
      );
      expect(
        ScientificRangeValidator.validateEt0(double.negativeInfinity).isFailure,
        isTrue,
      );
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

    test('Preserves growth-stage fraction alignment when ET0 observations are missing', () {
      final wheat = EgyptianCropsCatalog.wheat;
      // 10 requested days
      // Complete series: 10 days of ET0 = 5.0 mm/day
      final completeEt0 = List.filled(10, 5.0);
      final completeRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyEt0Series: completeEt0,
      );
      expect(completeRes.isSuccess, isTrue);

      // Now create series where Day 2 (index 1) is missing (null)
      // If day alignment is preserved, days 3-10 still receive the exact same Kc as in complete series.
      // Expected totalEtcMm is completeRes.totalEtcMm - (Day 2 contribution)
      final day2Kc = wheat.getKcForStageFraction((1 + 1) / 10);
      final day2EtcContribution = 5.0 * day2Kc;

      final withMissingDay = List<double?>.generate(
        10,
        (i) => (i == 1) ? null : 5.0,
      );
      final partialRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyEt0Series: withMissingDay,
      );
      expect(partialRes.isSuccess, isTrue);

      final expectedPartialEtc =
          completeRes.dataOrNull!.totalEtcMm - day2EtcContribution;
      expect(
        partialRes.dataOrNull!.totalEtcMm,
        closeTo(expectedPartialEtc, 0.0001),
      );

      // Contrast: if observations were compacted to a 9-day list, Kc calculation would use /9 instead of /10
      // which would assign different Kc values to remaining days. Our test proves original day positions are strictly preserved.
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

  group('Temporal Boundary & Requested Period Invariance Tests (P0/P1)', () {
    final wheat = EgyptianCropsCatalog.wheat;

    test('1. ETc: Shorter series than totalRequestedDays accounts for omitted days in missingness', () {
      // 5 observations provided, 7 requested -> 2 missing days out of 7 = 28.6% > 10%
      final shortEt0Series = [5.0, 5.2, 5.4, 5.1, 5.3];

      final res = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 7,
        dailyEt0Series: shortEt0Series,
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull?.missingCount, equals(2));
      expect(res.failureOrNull?.missingRatio, closeTo(2 / 7, 0.001));
    });

    test('2. ETc: Longer series ignores extra observations and extra nulls beyond requested period', () {
      // Requested period: 7 days.
      // Observations: 10 days, where days 7, 8, 9 contain nulls and non-finite values.
      final valid7Days = [5.0, 5.2, 5.4, 5.1, 5.3, 5.0, 5.2];
      final long10Days = [...valid7Days, null, double.nan, null];

      final res7 = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 7,
        dailyEt0Series: valid7Days,
      );

      final res10 = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 7,
        dailyEt0Series: long10Days,
      );

      expect(res7.isSuccess, isTrue);
      expect(res10.isSuccess, isTrue);
      // Results must be strictly identical
      expect(res10.dataOrNull?.totalEtcMm, equals(res7.dataOrNull?.totalEtcMm));
      expect(
        res10.dataOrNull?.totalVolumeM3PerFeddan,
        equals(res7.dataOrNull?.totalVolumeM3PerFeddan),
      );
    });

    test('3. ETc: Non-finite values (NaN / Infinity) within requested period are treated as incomplete', () {
      // 10 requested days, day 1 is NaN, day 3 is Infinity -> 2 incomplete days (20%) -> FAILS
      final nanSeries = [
        5.0,
        double.nan,
        5.4,
        double.infinity,
        5.3,
        5.0,
        5.2,
        5.1,
        5.3,
        5.0,
      ];

      final res = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyEt0Series: nanSeries,
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull?.missingCount, equals(2));
    });

    test('4. GDD: Longer series ignores extra observations and extra nulls beyond requested period', () {
      final validObs7 = List.generate(
        7,
        (i) => (date: DateTime.utc(2024, 6, i + 1), tMax: 30.0, tMin: 20.0),
      );

      final extraObs = [
        (date: DateTime.utc(2024, 6, 8), tMax: null, tMin: null),
        (date: DateTime.utc(2024, 6, 9), tMax: double.nan, tMin: 20.0),
        (date: DateTime.utc(2024, 6, 10), tMax: 35.0, tMin: null),
      ];

      final res7 = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 7,
        observations: validObs7,
        tBase: 10.0,
      );

      final resWithExtra = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 7,
        observations: [...validObs7, ...extraObs],
        tBase: 10.0,
      );

      expect(res7.isSuccess, isTrue);
      expect(resWithExtra.isSuccess, isTrue);
      expect(resWithExtra.dataOrNull, equals(res7.dataOrNull));
    });

    test('5. Heat Stress: Longer series ignores extra observations and extra nulls beyond requested period', () {
      final valid7 = [32.0, 33.0, 30.0, 29.0, 34.0, 35.0, 28.0];
      final long10 = [
        ...valid7,
        null,
        double.nan,
        45.0,
      ]; // Day 10 is 45.0, should be ignored

      final res7 = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 7,
        dailyTmaxSeries: valid7,
      );

      final res10 = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 7,
        dailyTmaxSeries: long10,
      );

      expect(res7.isSuccess, isTrue);
      expect(res10.isSuccess, isTrue);
      expect(
        res10.dataOrNull?.totalExceedanceDays,
        equals(res7.dataOrNull?.totalExceedanceDays),
      );
      expect(
        res10.dataOrNull?.peakObservedTempC,
        equals(res7.dataOrNull?.peakObservedTempC),
      );
      expect(res10.dataOrNull?.riskLevel, equals(res7.dataOrNull?.riskLevel));
    });

    test('6. Calculators return InsufficientEvidenceFailure on zero or negative requested days', () {
      final validEt0 = [5.0, 5.2, 5.1];
      final resEt0Zero = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 0,
        dailyEt0Series: validEt0,
      );
      expect(resEt0Zero.isFailure, isTrue);

      final resEt0Neg = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: -5,
        dailyEt0Series: validEt0,
      );
      expect(resEt0Neg.isFailure, isTrue);

      final obs = [(date: DateTime.utc(2024, 6, 1), tMax: 30.0, tMin: 20.0)];
      final resGddZero = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 0,
        observations: obs,
        tBase: 10.0,
      );
      expect(resGddZero.isFailure, isTrue);

      final resHeatZero = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 0,
        dailyTmaxSeries: [32.0],
      );
      expect(resHeatZero.isFailure, isTrue);
    });

    test(
      '7. Missing-data tolerance threshold: 10% exactly passes, > 10% fails',
      () {
        // 10 requested days:
        // 1 missing day = 1/10 = 10.0% -> <= 10% -> PASS
        // 2 missing days = 2/10 = 20.0% -> > 10% -> FAIL
        final series1Missing = List.generate(10, (i) => i == 0 ? null : 5.0);
        final series2Missing = List.generate(10, (i) => i < 2 ? null : 5.0);

        final res10Percent =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: series1Missing,
            );
        expect(res10Percent.isSuccess, isTrue);

        final res20Percent =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: series2Missing,
            );
        expect(res20Percent.isFailure, isTrue);
        expect(res20Percent.failureOrNull?.missingCount, equals(2));
      },
    );

    test('8. Growth-stage Kc selection boundaries across developmental fractions (FAO-56 linear interpolation)', () {
      // Wheat: kcIni=0.40, kcMid=1.15, kcEnd=0.35
      // Initial stage (<= 0.20): kcIni (0.40)
      expect(wheat.getKcForStageFraction(0.10), equals(0.40));
      expect(wheat.getKcForStageFraction(0.20), equals(0.40));

      // Development stage (0.20 - 0.50): linearly interpolated between kcIni (0.40) and kcMid (1.15)
      // At 0.35 (midpoint of dev stage): 0.40 + 0.5 * (1.15 - 0.40) = 0.775
      expect(wheat.getKcForStageFraction(0.35), closeTo(0.775, 0.001));

      // Mid-season stage (0.50 - 0.80): constant kcMid (1.15)
      expect(wheat.getKcForStageFraction(0.50), equals(1.15));
      expect(wheat.getKcForStageFraction(0.65), equals(1.15));
      expect(wheat.getKcForStageFraction(0.80), equals(1.15));

      // Late-season stage (0.80 - 1.00): linearly interpolated between kcMid (1.15) and kcEnd (0.35)
      // At 0.90 (midpoint of late stage): 1.15 + 0.5 * (0.35 - 1.15) = 0.75
      expect(wheat.getKcForStageFraction(0.90), closeTo(0.75, 0.001));
      // At 1.0 (harvest end): kcEnd (0.35)
      expect(wheat.getKcForStageFraction(1.00), closeTo(0.35, 0.0001));
    });
  });
}
