import 'package:agro_shift/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/domain/environment/models/coordinate.dart';
import 'package:agro_shift/domain/validation/scientific_range_validator.dart';
import 'package:agro_shift/domain/agronomy/models/crop.dart';
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

    test('Rejects non-finite coordinates (NaN and Infinities)', () {
      // Latitude NaN
      const nanLat = Coordinate(latitude: double.nan, longitude: 30.0);
      expect(nanLat.isWithinEgypt, isFalse);
      expect(nanLat.validate().isFailure, isTrue);

      // Longitude NaN
      const nanLon = Coordinate(latitude: 30.0, longitude: double.nan);
      expect(nanLon.isWithinEgypt, isFalse);
      expect(nanLon.validate().isFailure, isTrue);

      // Positive and negative infinity
      const posInfLat = Coordinate(latitude: double.infinity, longitude: 30.0);
      expect(posInfLat.isWithinEgypt, isFalse);
      expect(posInfLat.validate().isFailure, isTrue);

      const negInfLat = Coordinate(
        latitude: double.negativeInfinity,
        longitude: 30.0,
      );
      expect(negInfLat.isWithinEgypt, isFalse);
      expect(negInfLat.validate().isFailure, isTrue);

      const posInfLon = Coordinate(latitude: 30.0, longitude: double.infinity);
      expect(posInfLon.isWithinEgypt, isFalse);
      expect(posInfLon.validate().isFailure, isTrue);

      const negInfLon = Coordinate(
        latitude: 30.0,
        longitude: double.negativeInfinity,
      );
      expect(negInfLon.isWithinEgypt, isFalse);
      expect(negInfLon.validate().isFailure, isTrue);
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

    test('calculateAccumulatedGddValidated tests for input validation', () {
      final baseDate = DateTime.utc(2026, 6, 1);
      final validObs =
          List<({DateTime date, double? tMax, double? tMin})>.generate(
            10,
            (i) =>
                (date: baseDate.add(Duration(days: i)), tMax: 30.0, tMin: 20.0),
          );

      // 1. Valid Tmax/Tmin inputs produce expected GDD
      final validRes = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 10,
        observations: validObs,
        tBase: 10.0,
      );
      expect(validRes.isSuccess, isTrue);
      expect(
        validRes.dataOrNull,
        closeTo(150.0, 0.001),
      ); // (30+20)/2 - 10 = 15 per day * 10 = 150

      // 2. Finite Tmax outside configured screening range (> 55°C) fails with PhysicalRangeFailure
      final highTmaxObs = List.of(validObs);
      highTmaxObs[0] = (date: baseDate, tMax: 56.0, tMin: 20.0);
      final highTmaxRes = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 10,
        observations: highTmaxObs,
        tBase: 10.0,
      );
      expect(highTmaxRes.isFailure, isTrue);
      expect(highTmaxRes.failureOrNull, isA<PhysicalRangeFailure>());

      // 3. Finite Tmin outside configured screening range (< -5°C) fails with PhysicalRangeFailure
      final lowTminObs = List.of(validObs);
      lowTminObs[0] = (date: baseDate, tMax: 30.0, tMin: -5.1);
      final lowTminRes = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 10,
        observations: lowTminObs,
        tBase: 10.0,
      );
      expect(lowTminRes.isFailure, isTrue);
      expect(lowTminRes.failureOrNull, isA<PhysicalRangeFailure>());

      // 4. NaN and Infinities in either temperature field fail with PhysicalRangeFailure
      final nanTmaxObs = List.of(validObs);
      nanTmaxObs[0] = (date: baseDate, tMax: double.nan, tMin: 20.0);
      expect(
        GddCalculator.calculateAccumulatedGddValidated(
          totalRequestedDays: 10,
          observations: nanTmaxObs,
          tBase: 10.0,
        ).failureOrNull,
        isA<PhysicalRangeFailure>(),
      );

      final infTminObs = List.of(validObs);
      infTminObs[0] = (date: baseDate, tMax: 30.0, tMin: double.infinity);
      expect(
        GddCalculator.calculateAccumulatedGddValidated(
          totalRequestedDays: 10,
          observations: infTminObs,
          tBase: 10.0,
        ).failureOrNull,
        isA<PhysicalRangeFailure>(),
      );

      final negInfTmaxObs = List.of(validObs);
      negInfTmaxObs[0] = (
        date: baseDate,
        tMax: double.negativeInfinity,
        tMin: 20.0,
      );
      expect(
        GddCalculator.calculateAccumulatedGddValidated(
          totalRequestedDays: 10,
          observations: negInfTmaxObs,
          tBase: 10.0,
        ).failureOrNull,
        isA<PhysicalRangeFailure>(),
      );

      // 5. Tmax < Tmin fails with PhysicalRangeFailure
      final invertedObs = List.of(validObs);
      invertedObs[0] = (date: baseDate, tMax: 20.0, tMin: 25.0);
      final invRes = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 10,
        observations: invertedObs,
        tBase: 10.0,
      );
      expect(invRes.isFailure, isTrue);
      expect(invRes.failureOrNull, isA<PhysicalRangeFailure>());

      // 6. Missing observations at existing threshold (10% = 1 day out of 10) -> Success
      final missing1Obs = List.of(validObs);
      missing1Obs[0] = (date: baseDate, tMax: null, tMin: null);
      final missing1Res = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 10,
        observations: missing1Obs,
        tBase: 10.0,
      );
      expect(missing1Res.isSuccess, isTrue);
      expect(
        missing1Res.dataOrNull,
        closeTo(135.0, 0.001),
      ); // 9 valid days * 15

      // Missing observations beyond threshold (20% = 2 days out of 10) -> InsufficientEvidenceFailure
      final missing2Obs = List.of(validObs);
      missing2Obs[0] = (date: baseDate, tMax: null, tMin: null);
      missing2Obs[1] = (
        date: baseDate.add(const Duration(days: 1)),
        tMax: null,
        tMin: null,
      );
      final missing2Res = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 10,
        observations: missing2Obs,
        tBase: 10.0,
      );
      expect(missing2Res.isFailure, isTrue);
      expect(missing2Res.failureOrNull, isA<InsufficientEvidenceFailure>());

      // 7. Zero requested days fails closed
      final zeroDaysRes = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 0,
        observations: validObs,
        tBase: 10.0,
      );
      expect(zeroDaysRes.isFailure, isTrue);
      expect(zeroDaysRes.failureOrNull, isA<InsufficientEvidenceFailure>());

      // 8. Input list shorter than requested period fails when missingness > 10%
      final shortObs = validObs
          .take(7)
          .toList(); // 7 obs for 10 requested = 30% missing
      final shortRes = GddCalculator.calculateAccumulatedGddValidated(
        totalRequestedDays: 10,
        observations: shortObs,
        tBase: 10.0,
      );
      expect(shortRes.isFailure, isTrue);
      expect(shortRes.failureOrNull, isA<InsufficientEvidenceFailure>());
    });
  });

  group('Independent ETc Numerical Oracle Tests', () {
    // Case 1: Daily ETc arithmetic check
    // Inputs: ET0 = 5.0 mm/day, Kc = 1.15
    // Independent calculation: 5.0 * 1.15 = 5.75 mm/day
    test('Independent oracle: daily ETc equals ET0 multiplied by Kc', () {
      const et0 = 5.0;
      const kc = 1.15;
      const expectedEtc = 5.75;

      final actualEtc = EtcCalculator.calculateDailyEtc(
        referenceEt0Mm: et0,
        cropKc: kc,
      );

      expect(actualEtc, closeTo(expectedEtc, 1e-9));
    });

    // Case 2: Configured feddan volume conversion
    // Inputs: Water depth = 100.0 mm, configured conversion constant = 4.2 m³/feddan/mm
    // Independent calculation: 100.0 * 4.2 = 420.0 m³/feddan
    test('Independent oracle: configured feddan volume conversion', () {
      const waterDepthMm = 100.0;
      const expectedVolumeM3PerFeddan = 420.0;

      final actualVolume = EtcCalculator.convertMmToCubicMetersPerFeddan(
        waterDepthMm,
      );

      expect(actualVolume, closeTo(expectedVolumeM3PerFeddan, 1e-9));
    });

    // Case 3: Multi-day ETc with explicit Kc values and independent hand calculation
    // Using a fixed 5-day cycle with known ET0 series and fixed crop profile:
    // Crop: kcIni = 0.40, kcMid = 1.00, kcEnd = 0.60
    // Stage fractions for N = 5 days: (dayIndex + 1) / 5
    // Day 1: p = 1/5 = 0.20 (<= 0.20 -> stage 1: Kc = kcIni = 0.40). ET0 = 4.0 mm/day.
    //        ETc(1) = 4.0 * 0.40 = 1.60 mm.
    // Day 2: p = 2/5 = 0.40 (0.20 < p <= 0.50 -> stage 2 development linear interpolation:
    //        weight = (0.40 - 0.20) / 0.30 = 2/3.
    //        Kc = 0.40 + (2/3) * (1.00 - 0.40) = 0.40 + 0.40 = 0.80). ET0 = 6.0 mm/day.
    //        ETc(2) = 6.0 * 0.80 = 4.80 mm.
    // Day 3: p = 3/5 = 0.60 (0.50 < p <= 0.80 -> stage 3 mid-season plateau: Kc = kcMid = 1.00). ET0 = 5.0 mm/day.
    //        ETc(3) = 5.0 * 1.00 = 5.00 mm.
    // Day 4: p = 4/5 = 0.80 (0.50 < p <= 0.80 -> stage 3 mid-season plateau: Kc = kcMid = 1.00). ET0 = 5.5 mm/day.
    //        ETc(4) = 5.5 * 1.00 = 5.50 mm.
    // Day 5: p = 5/5 = 1.00 (0.80 < p <= 1.00 -> stage 4 late-season linear interpolation:
    //        weight = (1.00 - 0.80) / 0.20 = 1.0.
    //        Kc = 1.00 + 1.0 * (0.60 - 1.00) = 0.60). ET0 = 3.0 mm/day.
    //        ETc(5) = 3.0 * 0.60 = 1.80 mm.
    // Independent manual sum:
    // Total ETc = 1.60 + 4.80 + 5.00 + 5.50 + 1.80 = 18.70 mm.
    // Independent volume = 18.70 mm * 4.2 m³/feddan/mm = 78.54 m³/feddan.
    test('Independent oracle: multi-day ETc with hand-calculated Kc and cumulative demand', () {
      const testCrop = Crop(
        id: 'oracle_test_crop',
        nameAr: 'محصول اختبار مستقل',
        nameEn: 'Oracle Test Crop',
        season: CropSeason.summer,
        baseTemperatureC: 10.0,
        criticalHeatTemperatureC: 35.0,
        kcIni: 0.40,
        kcMid: 1.00,
        kcEnd: 0.60,
        typicalDurationDays: 5,
        soilNutrientImpact: SoilNutrientImpact.moderate,
        scientificNotesAr:
            'ملف محصول اختباري للتحقق الحسابي المستقل من معادلات البخر نتح',
      );

      final dailyEt0 = <double>[4.0, 6.0, 5.0, 5.5, 3.0];
      const expectedTotalEtcMm = 18.70;
      const expectedVolumeM3PerFeddan = 78.54;

      final result = EtcCalculator.calculateCycleWaterRequirement(
        crop: testCrop,
        dailyEt0Series: dailyEt0,
      );

      expect(result.totalEtcMm, closeTo(expectedTotalEtcMm, 1e-9));
      expect(
        result.totalVolumeM3PerFeddan,
        closeTo(expectedVolumeM3PerFeddan, 1e-9),
      );

      // Also verify through calculateCycleWaterRequirementValidated
      final validatedResult =
          EtcCalculator.calculateCycleWaterRequirementValidated(
            crop: testCrop,
            totalRequestedDays: 5,
            dailyEt0Series: dailyEt0,
          );

      expect(validatedResult.isSuccess, isTrue);
      expect(
        validatedResult.dataOrNull!.totalEtcMm,
        closeTo(expectedTotalEtcMm, 1e-9),
      );
      expect(
        validatedResult.dataOrNull!.totalVolumeM3PerFeddan,
        closeTo(expectedVolumeM3PerFeddan, 1e-9),
      );
    });
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

    test('Comprehensive ETc missingness and variable-Kc growth-stage alignment verification', () {
      // Use maize (kcIni = 0.30, kcMid = 1.20, kcEnd = 0.60) whose Kc varies strictly across stages
      final maize = EgyptianCropsCatalog.maize;
      const totalDays = 20;

      // 1. Complete ET0 series calculates expected ETc and volumetric demand
      final completeEt0 = List.generate(totalDays, (i) => 5.0 + (i % 3) * 0.5);
      final completeRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: totalDays,
        dailyEt0Series: completeEt0,
      );
      expect(completeRes.isSuccess, isTrue);
      final expectedCompleteEtc = [
        for (var i = 0; i < totalDays; i++)
          completeEt0[i] * maize.getKcForStageFraction((i + 1) / totalDays),
      ].reduce((a, b) => a + b);
      expect(
        completeRes.dataOrNull!.totalEtcMm,
        closeTo(expectedCompleteEtc, 0.0001),
      );
      expect(
        completeRes.dataOrNull!.totalVolumeM3PerFeddan,
        closeTo(expectedCompleteEtc * 4.2, 0.001),
      );

      // 2. A missing ET0 observation (null) is counted as incomplete day (1 / 20 = 5% <= 10% threshold -> PASS)
      final withNull = List<double?>.from(completeEt0);
      withNull[4] = null; // Day index 4 (5th day) missing
      final nullRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: totalDays,
        dailyEt0Series: withNull,
      );
      expect(nullRes.isSuccess, isTrue);

      // 3. A non-finite ET0 observation (NaN / Inf) fails immediately with PhysicalRangeFailure
      final withNan = List<double?>.from(completeEt0);
      withNan[4] = double.nan;
      final nanRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: totalDays,
        dailyEt0Series: withNan,
      );
      expect(nanRes.isFailure, isTrue);
      expect(nanRes.failureOrNull, isA<PhysicalRangeFailure>());

      final withInf = List<double?>.from(completeEt0);
      withInf[4] = double.infinity;
      final infRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: totalDays,
        dailyEt0Series: withInf,
      );
      expect(infRes.isFailure, isTrue);
      expect(infRes.failureOrNull, isA<PhysicalRangeFailure>());

      // 4 & 5. Missing days in the middle do not shift subsequent Kc assignments
      // If index 4 was removed from list, subsequent days would shift left by 1
      // Check that day 10 still receives Kc for fraction (10+1)/20, not (9+1)/20
      final day4Contribution =
          completeEt0[4] * maize.getKcForStageFraction((4 + 1) / totalDays);
      expect(
        nullRes.dataOrNull!.totalEtcMm,
        closeTo(expectedCompleteEtc - day4Contribution, 0.0001),
      );

      // 6 & 7. Growth-stage fraction uses (dayIndex + 1) / totalRequestedDays (denominator is 20, not 19 valid days)
      // If denominator were 19, total would differ significantly
      final wrongCompactedSeries = List<double>.from(completeEt0)..removeAt(4);
      final wrongCompactedSum = [
        for (var i = 0; i < wrongCompactedSeries.length; i++)
          wrongCompactedSeries[i] * maize.getKcForStageFraction((i + 1) / 19),
      ].reduce((a, b) => a + b);
      expect(
        (nullRes.dataOrNull!.totalEtcMm - wrongCompactedSum).abs(),
        greaterThan(0.01),
      );

      // 8. Observations beyond totalRequestedDays are ignored
      final longSeries = [...completeEt0, 100.0, 200.0, null];
      final longRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: totalDays,
        dailyEt0Series: longSeries,
      );
      expect(longRes.isSuccess, isTrue);
      expect(
        longRes.dataOrNull!.totalEtcMm,
        closeTo(completeRes.dataOrNull!.totalEtcMm, 0.0001),
      );

      // 9. Series shorter than requested period correctly counts absent trailing days as incomplete
      // 18 days provided for 20 days requested -> 2 missing days = 10% -> PASS (<= 10%)
      final short18 = completeEt0.sublist(0, 18);
      final short18Res = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: totalDays,
        dailyEt0Series: short18,
      );
      expect(short18Res.isSuccess, isTrue);

      // 17 days provided for 20 days requested -> 3 missing days = 15% > 10% -> FAIL
      final short17 = completeEt0.sublist(0, 17);
      final short17Res = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: totalDays,
        dailyEt0Series: short17,
      );
      expect(short17Res.isFailure, isTrue);
      expect(short17Res.failureOrNull, isA<InsufficientEvidenceFailure>());
      final short17Fail =
          short17Res.failureOrNull as InsufficientEvidenceFailure;
      expect(short17Fail.missingCount, equals(3));
      expect(short17Fail.missingRatio, closeTo(3 / 20, 0.001));

      // 10 & 11. Missingness ratio policy: strict '>' 10%
      // 2 out of 20 = 10.0% exactly -> PASS
      final exact10PercentMissing = List<double?>.from(completeEt0);
      exact10PercentMissing[0] = null;
      exact10PercentMissing[1] = null;
      final exact10Res = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: 20,
        dailyEt0Series: exact10PercentMissing,
      );
      expect(
        exact10Res.isSuccess,
        isTrue,
        reason: 'Exactly 10% missingness must pass strict > policy',
      );

      // 3 out of 20 = 15.0% > 10% -> FAIL
      exact10PercentMissing[2] = null;
      final over10Res = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: 20,
        dailyEt0Series: exact10PercentMissing,
      );
      expect(
        over10Res.isFailure,
        isTrue,
        reason: 'Over 10% missingness must fail',
      );

      // 12. Non-positive requested period returns failure
      final nonPositiveRes =
          EtcCalculator.calculateCycleWaterRequirementValidated(
            crop: maize,
            totalRequestedDays: 0,
            dailyEt0Series: completeEt0,
          );
      expect(nonPositiveRes.isFailure, isTrue);

      final negRes = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: maize,
        totalRequestedDays: -5,
        dailyEt0Series: completeEt0,
      );
      expect(negRes.isFailure, isTrue);

      // 13. Current ETc equation and volume conversion remain unchanged (1 mm = 4.2 m3/feddan)
      final etcSingle = EtcCalculator.calculateDailyEtc(
        referenceEt0Mm: 10.0,
        cropKc: 1.2,
      );
      expect(etcSingle, equals(12.0));
      final volSingle = EtcCalculator.convertMmToCubicMetersPerFeddan(12.0);
      expect(volSingle, closeTo(12.0 * 4.2, 0.001));
    });

    test(
      'ETc preserves original growth-stage day indices when ET0 is missing',
      () {
        // 10 requested days: Day 2 (index 1) is null (missing), all others 5.0 mm/day
        // Missing ratio = 1/10 = 10% <= 10% threshold -> validated calculation succeeds
        final dailyEt0Series = List<double?>.generate(
          10,
          (index) => index == 1 ? null : 5.0,
        );

        final result = EtcCalculator.calculateCycleWaterRequirementValidated(
          crop: EgyptianCropsCatalog.maize,
          totalRequestedDays: 10,
          dailyEt0Series: dailyEt0Series,
        );

        expect(result.isSuccess, isTrue);

        // Independent numerical oracle for EgyptianCropsCatalog.maize (kcIni=0.30, kcMid=1.20, kcEnd=0.60):
        // Day 1 (p=0.10, <=0.20): Kc=0.30 -> 5.0 * 0.30 = 1.50 mm
        // Day 2 (p=0.20, <=0.20): Missing -> 0.00 mm
        // Day 3 (p=0.30, 0.20..0.50): Kc=0.30 + (0.10/0.30)*(1.20-0.30) = 0.60 -> 5.0 * 0.60 = 3.00 mm
        // Day 4 (p=0.40, 0.20..0.50): Kc=0.30 + (0.20/0.30)*(1.20-0.30) = 0.90 -> 5.0 * 0.90 = 4.50 mm
        // Day 5 (p=0.50, <=0.50): Kc=1.20 -> 5.0 * 1.20 = 6.00 mm
        // Day 6 (p=0.60, 0.50..0.80): Kc=1.20 -> 5.0 * 1.20 = 6.00 mm
        // Day 7 (p=0.70, 0.50..0.80): Kc=1.20 -> 5.0 * 1.20 = 6.00 mm
        // Day 8 (p=0.80, <=0.80): Kc=1.20 -> 5.0 * 1.20 = 6.00 mm
        // Day 9 (p=0.90, 0.80..1.00): Kc=1.20 + (0.10/0.20)*(0.60-1.20) = 0.90 -> 5.0 * 0.90 = 4.50 mm
        // Day 10 (p=1.00, <=1.00): Kc=0.60 -> 5.0 * 0.60 = 3.00 mm
        // Sum = 1.50 + 0 + 3.00 + 4.50 + 6.00 + 6.00 + 6.00 + 6.00 + 4.50 + 3.00 = 40.5 mm
        // Volume = 40.5 * 4.2 = 170.1 m³/feddan
        expect(result.dataOrNull?.totalEtcMm, closeTo(40.5, 0.001));

        expect(
          result.dataOrNull?.totalVolumeM3PerFeddan,
          closeTo(170.1, 0.001),
        );

        // Verification against incorrect compacted series (where Day 2 is shifted out and denominator becomes 9):
        // If compacted to 9 days, Day 3 would be evaluated at fraction 2/9, Day 4 at 3/9, etc., yielding a different sum.
        final compacted9Et0 = List.filled(9, 5.0);
        final compactedSum = [
          for (var i = 0; i < 9; i++)
            compacted9Et0[i] *
                EgyptianCropsCatalog.maize.getKcForStageFraction((i + 1) / 9),
        ].reduce((a, b) => a + b);
        expect(
          (result.dataOrNull!.totalEtcMm - compactedSum).abs(),
          greaterThan(0.01),
        );
      },
    );

    test(
      'Non-finite and negative input handling in EtcCalculator entry points',
      () {
        // 1. calculateDailyEtc negative values clamp to 0.0
        expect(
          EtcCalculator.calculateDailyEtc(referenceEt0Mm: -5.0, cropKc: 1.15),
          equals(0.0),
        );
        expect(
          EtcCalculator.calculateDailyEtc(referenceEt0Mm: 5.0, cropKc: -0.5),
          equals(0.0),
        );

        // 2. convertMmToCubicMetersPerFeddan non-positive values return 0.0
        expect(EtcCalculator.convertMmToCubicMetersPerFeddan(0.0), equals(0.0));
        expect(
          EtcCalculator.convertMmToCubicMetersPerFeddan(-10.0),
          equals(0.0),
        );

        // 3. calculateCycleWaterRequirementValidated rejects non-finite observations (NaN, +/-Infinity)
        // with PhysicalRangeFailure rather than counting them as missing observations.
        final wheat = EgyptianCropsCatalog.wheat;

        final seriesWithNan = List<double?>.generate(
          10,
          (i) => i == 0 ? double.nan : 4.0,
        );
        final nanRes = EtcCalculator.calculateCycleWaterRequirementValidated(
          crop: wheat,
          totalRequestedDays: 10,
          dailyEt0Series: seriesWithNan,
        );
        expect(nanRes.isFailure, isTrue);
        expect(nanRes.failureOrNull, isA<PhysicalRangeFailure>());

        final seriesWithInfinities = List<double?>.generate(10, (i) {
          if (i == 0) return double.infinity;
          if (i == 1) return double.negativeInfinity;
          return 4.0;
        });
        final infRes = EtcCalculator.calculateCycleWaterRequirementValidated(
          crop: wheat,
          totalRequestedDays: 10,
          dailyEt0Series: seriesWithInfinities,
        );
        expect(infRes.isFailure, isTrue);
        expect(infRes.failureOrNull, isA<PhysicalRangeFailure>());

        // 4. Case A — Lower boundary (ET0 = 0.0): Calculation succeeds, not treated as missing, daily contribution is 0.0
        final seriesBoundaryZero = List<double?>.filled(10, 0.0);
        final resBoundaryZero =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: seriesBoundaryZero,
            );
        expect(resBoundaryZero.isSuccess, isTrue);
        expect(resBoundaryZero.dataOrNull?.totalEtcMm, equals(0.0));
        expect(resBoundaryZero.dataOrNull?.totalVolumeM3PerFeddan, equals(0.0));

        // 5. Case B — Upper boundary (ET0 = 25.0): Range validator accepts 25.0, calculation succeeds
        final seriesBoundaryMax = List<double?>.filled(10, 25.0);
        final resBoundaryMax =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: seriesBoundaryMax,
            );
        expect(resBoundaryMax.isSuccess, isTrue);
        expect(resBoundaryMax.dataOrNull!.totalEtcMm, greaterThan(0.0));

        // 6. Case C — Below lower boundary (ET0 = -0.01): Calculation fails with PhysicalRangeFailure on et0
        final seriesBelowLower = [...List<double?>.filled(9, 5.0), -0.01];
        final resBelowLower =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: seriesBelowLower,
            );
        expect(resBelowLower.isFailure, isTrue);
        expect(resBelowLower.failureOrNull, isA<PhysicalRangeFailure>());
        final failBelow = resBelowLower.failureOrNull as PhysicalRangeFailure;
        expect(failBelow.variableName, equals('et0'));
        expect(failBelow.actualValue, equals(-0.01));

        // 7. Case D — Above upper boundary (ET0 = 25.01): Calculation fails with PhysicalRangeFailure on et0
        final seriesAboveUpper = [...List<double?>.filled(9, 5.0), 25.01];
        final resAboveUpper =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: seriesAboveUpper,
            );
        expect(resAboveUpper.isFailure, isTrue);
        expect(resAboveUpper.failureOrNull, isA<PhysicalRangeFailure>());
        final failAbove = resAboveUpper.failureOrNull as PhysicalRangeFailure;
        expect(failAbove.variableName, equals('et0'));
        expect(failAbove.actualValue, equals(25.01));

        // 8. Case E — Preserve missingness semantics: null observations remain missing
        final seriesPreserveMissing = [
          null,
          null,
          ...List<double?>.filled(8, 5.0),
        ]; // 2 out of 10 missing = 20% > 10%
        final resPreserveMissing =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: seriesPreserveMissing,
            );
        expect(resPreserveMissing.isFailure, isTrue);
        expect(
          resPreserveMissing.failureOrNull,
          isA<InsufficientEvidenceFailure>(),
        );
        final failMissing =
            resPreserveMissing.failureOrNull as InsufficientEvidenceFailure;
        expect(failMissing.missingCount, equals(2));

        // And NaN in series returns PhysicalRangeFailure, not InsufficientEvidenceFailure
        final seriesWithNanItem = [
          null,
          double.nan,
          ...List<double?>.filled(8, 5.0),
        ];
        final resWithNanItem =
            EtcCalculator.calculateCycleWaterRequirementValidated(
              crop: wheat,
              totalRequestedDays: 10,
              dailyEt0Series: seriesWithNanItem,
            );
        expect(resWithNanItem.isFailure, isTrue);
        expect(resWithNanItem.failureOrNull, isA<PhysicalRangeFailure>());
      },
    );
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

    test('evaluateCropHeatStressValidated validates Tmax range and non-finite inputs', () {
      final wheat = EgyptianCropsCatalog.wheat; // Tcritical = 31°C

      // 1. Empty input / zero requested days fails closed with InsufficientEvidenceFailure
      final emptyRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 0,
        dailyTmaxSeries: [],
      );
      expect(emptyRes.isFailure, isTrue);
      expect(emptyRes.failureOrNull, isA<InsufficientEvidenceFailure>());

      // 2. Valid values below crop threshold -> low risk
      final lowRiskTemps = List<double?>.filled(10, 25.0);
      final lowRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: lowRiskTemps,
      );
      expect(lowRes.isSuccess, isTrue);
      expect(lowRes.dataOrNull!.riskLevel, equals(HeatRiskLevel.low));
      expect(lowRes.dataOrNull!.totalExceedanceDays, equals(0));

      // 3. Valid values above crop threshold -> severe risk
      final highRiskTemps = List<double?>.filled(10, 35.0);
      final highRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: highRiskTemps,
      );
      expect(highRes.isSuccess, isTrue);
      expect(highRes.dataOrNull!.riskLevel, equals(HeatRiskLevel.severe));
      expect(highRes.dataOrNull!.totalExceedanceDays, equals(10));

      // 4. Tmax at exact configured operational limits (-5.0 and 55.0) are accepted
      final boundaryTemps = [-5.0, 55.0, ...List<double?>.filled(8, 25.0)];
      final boundaryRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: boundaryTemps,
      );
      expect(boundaryRes.isSuccess, isTrue);
      expect(boundaryRes.dataOrNull!.peakObservedTempC, equals(55.0));

      // 5. Tmax outside operational limits (< -5.0 or > 55.0) fails with PhysicalRangeFailure
      final aboveMaxTemps = [55.1, ...List<double?>.filled(9, 25.0)];
      final aboveMaxRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: aboveMaxTemps,
      );
      expect(aboveMaxRes.isFailure, isTrue);
      expect(aboveMaxRes.failureOrNull, isA<PhysicalRangeFailure>());

      final belowMinTemps = [-5.1, ...List<double?>.filled(9, 25.0)];
      final belowMinRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: belowMinTemps,
      );
      expect(belowMinRes.isFailure, isTrue);
      expect(belowMinRes.failureOrNull, isA<PhysicalRangeFailure>());

      // 6. NaN and Infinities fail with PhysicalRangeFailure
      final nanTemps = [double.nan, ...List<double?>.filled(9, 25.0)];
      final nanRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: nanTemps,
      );
      expect(nanRes.isFailure, isTrue);
      expect(nanRes.failureOrNull, isA<PhysicalRangeFailure>());

      final infTemps = [double.infinity, ...List<double?>.filled(9, 25.0)];
      final infRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: infTemps,
      );
      expect(infRes.isFailure, isTrue);
      expect(infRes.failureOrNull, isA<PhysicalRangeFailure>());

      final negInfTemps = [
        double.negativeInfinity,
        ...List<double?>.filled(9, 25.0),
      ];
      final negInfRes = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: negInfTemps,
      );
      expect(negInfRes.isFailure, isTrue);
      expect(negInfRes.failureOrNull, isA<PhysicalRangeFailure>());

      // 7. Missing null observations at accepted threshold (10% = 1 day) -> Success
      final missing1Temps = [null, ...List<double?>.filled(9, 25.0)];
      final missing1Res = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: missing1Temps,
      );
      expect(missing1Res.isSuccess, isTrue);

      // Missing null observations beyond threshold (20% = 2 days) -> InsufficientEvidenceFailure
      final missing2Temps = [null, null, ...List<double?>.filled(8, 25.0)];
      final missing2Res = HeatStressEvaluator.evaluateCropHeatStressValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyTmaxSeries: missing2Temps,
      );
      expect(missing2Res.isFailure, isTrue);
      expect(missing2Res.failureOrNull, isA<InsufficientEvidenceFailure>());
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
        expect(res.failureOrNull, isA<InsufficientEvidenceFailure>());
        final fail = res.failureOrNull! as InsufficientEvidenceFailure;
        expect(fail.missingCount, equals(2)); // Union count is 2, not 3
        expect(fail.technicalMessage, contains('2/10 = 20.0%'));
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
        expect(res.failureOrNull, isA<InsufficientEvidenceFailure>());
        final failRes = res.failureOrNull as InsufficientEvidenceFailure;
        expect(failRes.missingCount, equals(2));
        expect(failRes.missingRatio, closeTo(0.20, 0.001));
        expect(
          failRes.variableName,
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
      expect(res.failureOrNull, isA<InsufficientEvidenceFailure>());
      final failRes = res.failureOrNull as InsufficientEvidenceFailure;
      expect(failRes.missingCount, equals(2));
      expect(failRes.missingRatio, closeTo(2 / 7, 0.001));
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

    test('3. ETc: Non-finite values (NaN / Infinity) within requested period fail immediately with PhysicalRangeFailure', () {
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
      expect(res.failureOrNull, isA<PhysicalRangeFailure>());
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
        expect(res20Percent.failureOrNull, isA<InsufficientEvidenceFailure>());
        final fail20 =
            res20Percent.failureOrNull as InsufficientEvidenceFailure;
        expect(fail20.missingCount, equals(2));
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
