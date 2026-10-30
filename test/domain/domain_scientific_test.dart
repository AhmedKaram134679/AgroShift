import 'package:agro_shift/core/constants/agro_constants.dart';
import 'package:agro_shift/core/error/failures.dart';
import 'package:agro_shift/domain/agronomy/models/farm_field.dart';
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

    test(
      'Validates crop coefficient Kc and rejects negative or non-finite values',
      () {
        expect(ScientificRangeValidator.validateKc(0.0).isSuccess, isTrue);
        expect(ScientificRangeValidator.validateKc(1.15).isSuccess, isTrue);
        expect(ScientificRangeValidator.validateKc(2.5).isSuccess, isTrue);
        expect(ScientificRangeValidator.validateKc(-0.01).isFailure, isTrue);
        expect(ScientificRangeValidator.validateKc(-1.0).isFailure, isTrue);
        expect(
          ScientificRangeValidator.validateKc(double.nan).isFailure,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateKc(double.infinity).isFailure,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateKc(double.negativeInfinity)
              .isFailure,
          isTrue,
        );
      },
    );

    test(
      'Validates areaInFeddan and rejects zero, negative, or non-finite values',
      () {
        expect(
          ScientificRangeValidator.validateAreaInFeddan(5.0).isSuccess,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateAreaInFeddan(0.1).isSuccess,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateAreaInFeddan(0.0).isFailure,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateAreaInFeddan(-1.0).isFailure,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateAreaInFeddan(double.nan).isFailure,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateAreaInFeddan(double.infinity)
              .isFailure,
          isTrue,
        );
        expect(
          ScientificRangeValidator.validateAreaInFeddan(double.negativeInfinity)
              .isFailure,
          isTrue,
        );

        final zeroRes = ScientificRangeValidator.validateAreaInFeddan(0.0);
        expect(zeroRes.failureOrNull, isA<PhysicalRangeFailure>());
        final zeroFail = zeroRes.failureOrNull as PhysicalRangeFailure;
        expect(zeroFail.variableName, equals('areaInFeddan'));
        expect(zeroFail.actualValue, equals(0.0));
      },
    );

    test('FarmField.validate validates coordinates, areaInFeddan, and non-empty strings', () {
      const validField = FarmField(
        id: 'field_val_test',
        nameAr: 'حقل اختبار الصلاحية',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 31.10, longitude: 30.95),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );
      expect(validField.validate().isSuccess, isTrue);

      // Empty and whitespace-only field ID
      for (final badId in ['', '   ', '\t\n']) {
        final f = FarmField(
          id: badId,
          nameAr: 'حقل اختبار',
          governorateAr: 'كفر الشيخ',
          coordinate: const Coordinate(latitude: 31.10, longitude: 30.95),
          areaInFeddan: 5.0,
          soilType: SoilType.clay,
        );
        final res = f.validate();
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<PhysicalRangeFailure>());
        final fail = res.failureOrNull as PhysicalRangeFailure;
        expect(fail.variableName, equals('id'));
      }

      // Empty and whitespace-only nameAr
      for (final badName in ['', '   ', '\n']) {
        final f = FarmField(
          id: 'field_val_test',
          nameAr: badName,
          governorateAr: 'كفر الشيخ',
          coordinate: const Coordinate(latitude: 31.10, longitude: 30.95),
          areaInFeddan: 5.0,
          soilType: SoilType.clay,
        );
        final res = f.validate();
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<PhysicalRangeFailure>());
        final fail = res.failureOrNull as PhysicalRangeFailure;
        expect(fail.variableName, equals('nameAr'));
      }

      // Empty and whitespace-only governorateAr
      for (final badGov in ['', '   ', '\t']) {
        final f = FarmField(
          id: 'field_val_test',
          nameAr: 'حقل اختبار',
          governorateAr: badGov,
          coordinate: const Coordinate(latitude: 31.10, longitude: 30.95),
          areaInFeddan: 5.0,
          soilType: SoilType.clay,
        );
        final res = f.validate();
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<PhysicalRangeFailure>());
        final fail = res.failureOrNull as PhysicalRangeFailure;
        expect(fail.variableName, equals('governorateAr'));
      }

      // Existing invalid coordinate behavior remains unchanged
      const invalidCoordField = FarmField(
        id: 'field_val_test',
        nameAr: 'حقل اختبار',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 99.0, longitude: 30.95),
        areaInFeddan: 5.0,
        soilType: SoilType.clay,
      );
      expect(
        invalidCoordField.validate().failureOrNull,
        isA<CoordinateOutOfBoundsFailure>(),
      );

      // Existing zero and negative area behavior remains unchanged
      const zeroAreaField = FarmField(
        id: 'field_val_test',
        nameAr: 'حقل اختبار',
        governorateAr: 'كفر الشيخ',
        coordinate: Coordinate(latitude: 31.10, longitude: 30.95),
        areaInFeddan: 0.0,
        soilType: SoilType.clay,
      );
      expect(
        zeroAreaField.validate().failureOrNull,
        isA<PhysicalRangeFailure>(),
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

    // Task A: Comprehensive daily ETc edge cases and numeric contracts
    test('Task A: calculateDailyEtc arithmetic, zeroes, negatives, and non-finite values', () {
      // 1. Normal valid values
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: 6.0, cropKc: 1.10),
        closeTo(6.60, 1e-9),
      );
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: 3.5, cropKc: 0.40),
        closeTo(1.40, 1e-9),
      );

      // 2. Zero ET0
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: 0.0, cropKc: 1.15),
        equals(0.0),
      );

      // 3. Zero Kc
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: 5.0, cropKc: 0.0),
        equals(0.0),
      );

      // 4. Both zero
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: 0.0, cropKc: 0.0),
        equals(0.0),
      );

      // 5. Negative ET0 clamps to 0.0
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: -0.01, cropKc: 1.0),
        equals(0.0),
      );
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: -5.0, cropKc: 1.15),
        equals(0.0),
      );

      // 6. Negative Kc clamps to 0.0
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: 5.0, cropKc: -0.1),
        equals(0.0),
      );
      expect(
        EtcCalculator.calculateDailyEtc(referenceEt0Mm: 5.0, cropKc: -1.0),
        equals(0.0),
      );

      // 7. Non-finite values in unvalidated arithmetic
      // Hardened contract: calculateDailyEtc safely clamps non-finite inputs (NaN, +/-Infinity) to 0.0
      expect(
        EtcCalculator.calculateDailyEtc(
          referenceEt0Mm: double.nan,
          cropKc: 1.0,
        ),
        equals(0.0),
      );
      expect(
        EtcCalculator.calculateDailyEtc(
          referenceEt0Mm: 5.0,
          cropKc: double.nan,
        ),
        equals(0.0),
      );
      expect(
        EtcCalculator.calculateDailyEtc(
          referenceEt0Mm: double.infinity,
          cropKc: 1.0,
        ),
        equals(0.0),
      );
      expect(
        EtcCalculator.calculateDailyEtc(
          referenceEt0Mm: double.negativeInfinity,
          cropKc: 1.0,
        ),
        equals(0.0),
      );
      expect(
        EtcCalculator.calculateDailyEtc(
          referenceEt0Mm: 5.0,
          cropKc: double.infinity,
        ),
        equals(0.0),
      );
      expect(
        EtcCalculator.calculateDailyEtc(
          referenceEt0Mm: 5.0,
          cropKc: double.negativeInfinity,
        ),
        equals(0.0),
      );
    });

    // Task B: Independent verification of piecewise Kc interpolation for all 8 required boundary & interior points
    test('Task B: Crop.getKcForStageFraction piecewise interpolation across all boundaries and intervals', () {
      // Using benchmark Egyptian wheat: kcIni = 0.40, kcMid = 1.15, kcEnd = 0.35
      // Documented four-stage partitioning:
      // Initial: [0.0, 0.20] -> kcIni = 0.40
      // Development: (0.20, 0.50] -> linear from 0.40 to 1.15
      // Mid-season: (0.50, 0.80] -> kcMid = 1.15
      // Late-season: (0.80, 1.00] -> linear from 1.15 to 0.35
      final wheat = EgyptianCropsCatalog.wheat;

      // 1. Stage fraction 0.0 (exact start) -> kcIni
      expect(wheat.getKcForStageFraction(0.0), closeTo(0.40, 1e-9));

      // 2. Initial-stage boundary 0.20 -> kcIni
      expect(wheat.getKcForStageFraction(0.20), closeTo(0.40, 1e-9));

      // 3. Development-stage boundary 0.50 -> kcMid
      expect(wheat.getKcForStageFraction(0.50), closeTo(1.15, 1e-9));

      // 4. Mid-season boundary 0.80 -> kcMid
      expect(wheat.getKcForStageFraction(0.80), closeTo(1.15, 1e-9));

      // 5. Final boundary 1.0 (harvest) -> kcEnd
      expect(wheat.getKcForStageFraction(1.0), closeTo(0.35, 1e-9));

      // 6. Representative points inside each interpolation interval:
      // Interval 1 interior (Initial: e.g. 0.10) -> exactly 0.40
      expect(wheat.getKcForStageFraction(0.10), closeTo(0.40, 1e-9));

      // Interval 2 interior (Development: e.g. 0.35, exact midpoint between 0.20 and 0.50):
      // weight p = (0.35 - 0.20) / 0.30 = 0.15 / 0.30 = 0.50
      // Expected Kc = 0.40 + 0.50 * (1.15 - 0.40) = 0.40 + 0.375 = 0.775
      expect(wheat.getKcForStageFraction(0.35), closeTo(0.775, 1e-9));

      // Interval 3 interior (Mid-season: e.g. 0.65, midpoint between 0.50 and 0.80):
      // Expected Kc = kcMid = 1.15
      expect(wheat.getKcForStageFraction(0.65), closeTo(1.15, 1e-9));

      // Interval 4 interior (Late-season: e.g. 0.90, exact midpoint between 0.80 and 1.00):
      // weight p = (0.90 - 0.80) / 0.20 = 0.10 / 0.20 = 0.50
      // Expected Kc = 1.15 + 0.50 * (0.35 - 1.15) = 1.15 + 0.50 * (-0.80) = 1.15 - 0.40 = 0.75
      expect(wheat.getKcForStageFraction(0.90), closeTo(0.750, 1e-9));

      // 7. Below 0.0 (clamping to 0.0 -> returns kcIni)
      expect(wheat.getKcForStageFraction(-0.01), closeTo(0.40, 1e-9));
      expect(wheat.getKcForStageFraction(-1.0), closeTo(0.40, 1e-9));

      // 8. Above 1.0 (clamping to 1.0 -> returns kcEnd)
      expect(wheat.getKcForStageFraction(1.05), closeTo(0.35, 1e-9));
      expect(wheat.getKcForStageFraction(2.5), closeTo(0.35, 1e-9));
    });

    // Task C: Cumulative ETc and Growth-Stage Alignment comprehensive oracle checks
    test('Task C: Cumulative cycle water requirement on small independently calculable sequences', () {
      final wheat =
          EgyptianCropsCatalog.wheat; // kcIni=0.40, kcMid=1.15, kcEnd=0.35

      // 1. Empty ET0 sequence -> 0.0 totalEtc and 0.0 volume
      final emptyUnvalidated = EtcCalculator.calculateCycleWaterRequirement(
        crop: wheat,
        dailyEt0Series: [],
      );
      expect(emptyUnvalidated.totalEtcMm, equals(0.0));
      expect(emptyUnvalidated.totalVolumeM3PerFeddan, equals(0.0));

      final emptyValidated =
          EtcCalculator.calculateCycleWaterRequirementValidated(
            crop: wheat,
            totalRequestedDays: 0,
            dailyEt0Series: [],
          );
      expect(emptyValidated.isFailure, isTrue);
      expect(emptyValidated.failureOrNull, isA<InsufficientEvidenceFailure>());

      // 2. Single-day crop cycle (N = 1, fraction = 1/1 = 1.0 -> stage 4 harvest Kc = kcEnd = 0.35)
      // ET0 = 6.0 mm/day -> daily ETc = 6.0 * 0.35 = 2.10 mm
      // Volume = 2.10 * 4.2 = 8.82 m³/feddan
      final singleDayUnvalidated = EtcCalculator.calculateCycleWaterRequirement(
        crop: wheat,
        dailyEt0Series: [6.0],
      );
      expect(singleDayUnvalidated.totalEtcMm, closeTo(2.10, 1e-9));
      expect(singleDayUnvalidated.totalVolumeM3PerFeddan, closeTo(8.82, 1e-9));

      final singleDayValidated =
          EtcCalculator.calculateCycleWaterRequirementValidated(
            crop: wheat,
            totalRequestedDays: 1,
            dailyEt0Series: [6.0],
          );
      expect(singleDayValidated.isSuccess, isTrue);
      expect(singleDayValidated.dataOrNull!.totalEtcMm, closeTo(2.10, 1e-9));
      expect(
        singleDayValidated.dataOrNull!.totalVolumeM3PerFeddan,
        closeTo(8.82, 1e-9),
      );

      // 3. Multiple days with constant ET0 (e.g., 4 days with ET0 = 5.0 mm/day)
      // N = 4:
      // Day 1: p = 1/4 = 0.25 (Dev stage: weight = (0.25-0.20)/0.30 = 1/6. Kc = 0.40 + (1/6)*0.75 = 0.40 + 0.125 = 0.525). ETc = 5.0 * 0.525 = 2.625 mm
      // Day 2: p = 2/4 = 0.50 (Dev boundary: Kc = 1.15). ETc = 5.0 * 1.15 = 5.750 mm
      // Day 3: p = 3/4 = 0.75 (Mid stage: Kc = 1.15). ETc = 5.0 * 1.15 = 5.750 mm
      // Day 4: p = 4/4 = 1.00 (Late boundary: Kc = 0.35). ETc = 5.0 * 0.35 = 1.750 mm
      // Sum = 2.625 + 5.750 + 5.750 + 1.750 = 15.875 mm
      // Volume = 15.875 * 4.2 = 66.675 m³/feddan
      final constEt0Res = EtcCalculator.calculateCycleWaterRequirement(
        crop: wheat,
        dailyEt0Series: [5.0, 5.0, 5.0, 5.0],
      );
      expect(constEt0Res.totalEtcMm, closeTo(15.875, 1e-9));
      expect(constEt0Res.totalVolumeM3PerFeddan, closeTo(66.675, 1e-9));

      // 4. Changing ET0 sequence between days (e.g. 4 days with ET0 = [4.0, 6.0, 5.0, 3.0])
      // Day 1: 4.0 * 0.525 = 2.10 mm
      // Day 2: 6.0 * 1.15  = 6.90 mm
      // Day 3: 5.0 * 1.15  = 5.75 mm
      // Day 4: 3.0 * 0.35  = 1.05 mm
      // Sum = 2.10 + 6.90 + 5.75 + 1.05 = 15.80 mm
      // Volume = 15.80 * 4.2 = 66.36 m³/feddan
      final changingEt0Res = EtcCalculator.calculateCycleWaterRequirement(
        crop: wheat,
        dailyEt0Series: [4.0, 6.0, 5.0, 3.0],
      );
      expect(changingEt0Res.totalEtcMm, closeTo(15.80, 1e-9));
      expect(changingEt0Res.totalVolumeM3PerFeddan, closeTo(66.36, 1e-9));

      // 5. Valid missing-data cases: Missing at Beginning, Middle, and End (1 missing day out of 10 days = 10% <= 10%)
      // Complete 10-day ET0 at 5.0 mm/day:
      // Fractions i=1..10 (p = 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)
      // Kc values:
      // Day 1 (0.1): 0.40 -> 2.0 mm
      // Day 2 (0.2): 0.40 -> 2.0 mm
      // Day 3 (0.3): 0.40 + (1/3)*0.75 = 0.65 -> 3.25 mm
      // Day 4 (0.4): 0.40 + (2/3)*0.75 = 0.90 -> 4.50 mm
      // Day 5 (0.5): 1.15 -> 5.75 mm
      // Day 6 (0.6): 1.15 -> 5.75 mm
      // Day 7 (0.7): 1.15 -> 5.75 mm
      // Day 8 (0.8): 1.15 -> 5.75 mm
      // Day 9 (0.9): 1.15 + 0.5*(-0.80) = 0.75 -> 3.75 mm
      // Day 10 (1.0): 0.35 -> 1.75 mm
      // Complete sum = 2.0 + 2.0 + 3.25 + 4.50 + 5.75 + 5.75 + 5.75 + 5.75 + 3.75 + 1.75 = 40.25 mm

      // 5a. Missing at Beginning (Day 1 null):
      // Expected = 40.25 - 2.0 = 38.25 mm
      final missingStart = [null, ...List.filled(9, 5.0)];
      final resMissingStart =
          EtcCalculator.calculateCycleWaterRequirementValidated(
            crop: wheat,
            totalRequestedDays: 10,
            dailyEt0Series: missingStart,
          );
      expect(resMissingStart.isSuccess, isTrue);
      expect(resMissingStart.dataOrNull!.totalEtcMm, closeTo(38.25, 1e-9));

      // 5b. Missing in Middle (Day 5 null):
      // Expected = 40.25 - 5.75 = 34.50 mm
      final missingMid = [...List.filled(4, 5.0), null, ...List.filled(5, 5.0)];
      final resMissingMid =
          EtcCalculator.calculateCycleWaterRequirementValidated(
            crop: wheat,
            totalRequestedDays: 10,
            dailyEt0Series: missingMid,
          );
      expect(resMissingMid.isSuccess, isTrue);
      expect(resMissingMid.dataOrNull!.totalEtcMm, closeTo(34.50, 1e-9));

      // 5c. Missing at End (Day 10 null):
      // Expected = 40.25 - 1.75 = 38.50 mm
      final missingEnd = [...List.filled(9, 5.0), null];
      final resMissingEnd =
          EtcCalculator.calculateCycleWaterRequirementValidated(
            crop: wheat,
            totalRequestedDays: 10,
            dailyEt0Series: missingEnd,
          );
      expect(resMissingEnd.isSuccess, isTrue);
      expect(resMissingEnd.dataOrNull!.totalEtcMm, closeTo(38.50, 1e-9));

      // 6. Data list shorter than totalRequestedDays:
      // Requested 10 days, provided 8 days (2 days missing at end = 20% > 10% tolerance -> FAIL)
      final shorterList = List.filled(8, 5.0);
      final resShorter = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyEt0Series: shorterList,
      );
      expect(resShorter.isFailure, isTrue);
      expect(resShorter.failureOrNull, isA<InsufficientEvidenceFailure>());

      // 7. Data list longer than totalRequestedDays:
      // Requested 10 days, provided 15 days (days 11-15 must be completely ignored)
      final longerList = List.filled(15, 5.0);
      final resLonger = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 10,
        dailyEt0Series: longerList,
      );
      expect(resLonger.isSuccess, isTrue);
      // Result must match exactly the 10-day complete sum (40.25 mm)
      expect(resLonger.dataOrNull!.totalEtcMm, closeTo(40.25, 1e-9));

      // 8. Zero and Negative requested days:
      final resZero = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: 0,
        dailyEt0Series: [5.0, 5.0],
      );
      expect(resZero.isFailure, isTrue);
      expect(resZero.failureOrNull, isA<InsufficientEvidenceFailure>());

      final resNeg = EtcCalculator.calculateCycleWaterRequirementValidated(
        crop: wheat,
        totalRequestedDays: -5,
        dailyEt0Series: [5.0, 5.0],
      );
      expect(resNeg.isFailure, isTrue);
      expect(resNeg.failureOrNull, isA<InsufficientEvidenceFailure>());
    });

    // Task D: Independent verification of water-volume conversion
    test('Task D: convertMmToCubicMetersPerFeddan depth conversion and domain consistency', () {
      // Configured constant: 4.2 m³ / feddan / mm
      expect(AgroConstants.cubicMetersPerFeddanPerMm, equals(4.2));

      // 1. Zero depth -> 0.0 m³
      expect(EtcCalculator.convertMmToCubicMetersPerFeddan(0.0), equals(0.0));

      // 2. Negative depth -> maps to 0.0 m³ (non-positive depth guard)
      expect(
        EtcCalculator.convertMmToCubicMetersPerFeddan(-0.001),
        equals(0.0),
      );
      expect(EtcCalculator.convertMmToCubicMetersPerFeddan(-50.0), equals(0.0));

      // 3. Representative positive depth: 1.0 mm -> 4.2 m³/feddan
      expect(
        EtcCalculator.convertMmToCubicMetersPerFeddan(1.0),
        closeTo(4.2, 1e-9),
      );

      // 4. Known seasonal ETc depth: e.g. 500.0 mm -> 500.0 * 4.2 = 2100.0 m³/feddan
      expect(
        EtcCalculator.convertMmToCubicMetersPerFeddan(500.0),
        closeTo(2100.0, 1e-9),
      );

      // 5. Fractional depth: 23.45 mm -> 23.45 * 4.2 = 98.49 m³/feddan
      expect(
        EtcCalculator.convertMmToCubicMetersPerFeddan(23.45),
        closeTo(98.49, 1e-9),
      );

      // 6. Non-finite depth values safely clamp to 0.0
      expect(
        EtcCalculator.convertMmToCubicMetersPerFeddan(double.nan),
        equals(0.0),
      );
      expect(
        EtcCalculator.convertMmToCubicMetersPerFeddan(double.infinity),
        equals(0.0),
      );
      expect(
        EtcCalculator.convertMmToCubicMetersPerFeddan(double.negativeInfinity),
        equals(0.0),
      );
    });

    // Task E: Benchmark Crop Catalogue consistency and baseline preservation
    test('Task E: Egyptian benchmark crops catalog baseline integrity and Kc interpolation', () {
      final allCrops = EgyptianCropsCatalog.allCrops;
      expect(allCrops.length, equals(6));

      // Verify each crop has valid identifiers, non-empty names, positive durations, and valid Kc bounds
      for (final crop in allCrops) {
        expect(crop.id.isNotEmpty, isTrue);
        expect(crop.nameAr.isNotEmpty, isTrue);
        expect(crop.nameEn.isNotEmpty, isTrue);
        expect(crop.typicalDurationDays, greaterThan(0));
        expect(crop.baseTemperatureC, greaterThanOrEqualTo(0.0));
        expect(
          crop.criticalHeatTemperatureC,
          greaterThan(crop.baseTemperatureC),
        );
        expect(crop.kcIni, greaterThan(0.0));
        expect(crop.kcMid, greaterThan(crop.kcIni));
        expect(crop.kcEnd, greaterThan(0.0));

        // Verify findById lookup returns the exact crop instance
        expect(EgyptianCropsCatalog.findById(crop.id), equals(crop));

        // Verify getKcForStageFraction runs without error and stays within [0.0, 2.0]
        for (double fraction = 0.0; fraction <= 1.0; fraction += 0.2) {
          final kc = crop.getKcForStageFraction(fraction);
          expect(kc, greaterThan(0.0));
          expect(kc, lessThan(2.0));
        }
      }

      // Explicit verification of baseline Kc parameters to prevent accidental regression:
      // Wheat
      expect(EgyptianCropsCatalog.wheat.kcIni, equals(0.40));
      expect(EgyptianCropsCatalog.wheat.kcMid, equals(1.15));
      expect(EgyptianCropsCatalog.wheat.kcEnd, equals(0.35));

      // Berseem Clover
      expect(EgyptianCropsCatalog.berseemClover.kcIni, equals(0.45));
      expect(EgyptianCropsCatalog.berseemClover.kcMid, equals(1.05));
      expect(EgyptianCropsCatalog.berseemClover.kcEnd, equals(0.90));

      // Faba Bean
      expect(EgyptianCropsCatalog.fabaBean.kcIni, equals(0.50));
      expect(EgyptianCropsCatalog.fabaBean.kcMid, equals(1.15));
      expect(EgyptianCropsCatalog.fabaBean.kcEnd, equals(0.30));

      // Maize
      expect(EgyptianCropsCatalog.maize.kcIni, equals(0.30));
      expect(EgyptianCropsCatalog.maize.kcMid, equals(1.20));
      expect(EgyptianCropsCatalog.maize.kcEnd, equals(0.60));

      // Rice
      expect(EgyptianCropsCatalog.rice.kcIni, equals(1.05));
      expect(EgyptianCropsCatalog.rice.kcMid, equals(1.20));
      expect(EgyptianCropsCatalog.rice.kcEnd, equals(0.90));

      // Cotton
      expect(EgyptianCropsCatalog.cotton.kcIni, equals(0.35));
      expect(EgyptianCropsCatalog.cotton.kcMid, equals(1.20));
      expect(EgyptianCropsCatalog.cotton.kcEnd, equals(0.65));
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

        // 9. Case F — Crop Kc validation: Non-finite or negative Kc values fail closed with PhysicalRangeFailure
        final validSeries = List<double?>.filled(10, 5.0);

        final nanKcCrop = Crop(
          id: 'nan_kc_test',
          nameAr: 'محصول اختبار',
          nameEn: 'NaN Kc Test',
          season: CropSeason.summer,
          baseTemperatureC: 10.0,
          criticalHeatTemperatureC: 35.0,
          kcIni: double.nan,
          kcMid: 1.0,
          kcEnd: 0.5,
          typicalDurationDays: 100,
          soilNutrientImpact: SoilNutrientImpact.moderate,
          scientificNotesAr: 'اختبار معامل محصول غير منتهٍ',
        );
        final nanKcRes = EtcCalculator.calculateCycleWaterRequirementValidated(
          crop: nanKcCrop,
          totalRequestedDays: 10,
          dailyEt0Series: validSeries,
        );
        expect(nanKcRes.isFailure, isTrue);
        expect(nanKcRes.failureOrNull, isA<PhysicalRangeFailure>());
        expect(
          (nanKcRes.failureOrNull as PhysicalRangeFailure).variableName,
          equals('kcIni'),
        );

        final negKcCrop = Crop(
          id: 'neg_kc_test',
          nameAr: 'محصول اختبار سالب',
          nameEn: 'Neg Kc Test',
          season: CropSeason.summer,
          baseTemperatureC: 10.0,
          criticalHeatTemperatureC: 35.0,
          kcIni: 0.4,
          kcMid: -0.5,
          kcEnd: 0.5,
          typicalDurationDays: 100,
          soilNutrientImpact: SoilNutrientImpact.moderate,
          scientificNotesAr: 'اختبار معامل محصول سالب',
        );
        final negKcRes = EtcCalculator.calculateCycleWaterRequirementValidated(
          crop: negKcCrop,
          totalRequestedDays: 10,
          dailyEt0Series: validSeries,
        );
        expect(negKcRes.isFailure, isTrue);
        expect(negKcRes.failureOrNull, isA<PhysicalRangeFailure>());
        expect(
          (negKcRes.failureOrNull as PhysicalRangeFailure).variableName,
          equals('kcMid'),
        );
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

  group('Crop Growth Stage & Forecast ETc Scientific Validation Tests', () {
    const wheat = EgyptianCropsCatalog
        .wheat; // 150 days, kcIni=0.40, kcMid=1.15, kcEnd=0.35

    test('1. A 7-day forecast at cycle start (crop age 0-6 days) does NOT progress through entire lifecycle', () {
      final plantingDate = DateTime.utc(2024, 11, 15);
      final forecastDates = List.generate(
        7,
        (i) => plantingDate.add(Duration(days: i)),
      );
      final et0Series = List.generate(7, (_) => 5.0);

      final res = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 7,
      );

      expect(res.isSuccess, isTrue);
      final data = res.dataOrNull!;
      // Typical duration = 150 days. Days 0..6 gives stageFraction 0/150 to 6/150 (<= 0.04 <= 0.20)
      // All 7 days must strictly receive kcIni = 0.40!
      for (final kc in data.dailyKcSeries) {
        expect(kc, equals(0.40));
      }
      for (final dailyEtc in data.dailyEtcMmSeries) {
        expect(dailyEtc, equals(2.0)); // 5.0 * 0.40
      }
      expect(data.totalEtcMm, equals(14.0)); // 7 * 2.0
      expect(data.totalVolumeM3PerFeddan, equals(14.0 * 4.2));
    });

    test('2. A 7-day forecast in mid-season uses the corresponding mid-season Kc plateau', () {
      final plantingDate = DateTime.utc(2024, 11, 15);
      // Mid-season for wheat (150 days) is stageFraction 0.50 to 0.80 -> day 75 to day 120
      // Let forecast start at day 80 after planting
      final forecastStart = plantingDate.add(const Duration(days: 80));
      final forecastDates = List.generate(
        7,
        (i) => forecastStart.add(Duration(days: i)),
      );
      final et0Series = List.generate(7, (_) => 4.0);

      final res = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 7,
      );

      expect(res.isSuccess, isTrue);
      final data = res.dataOrNull!;
      // Days 80..86 correspond to fractions 80/150 (0.533) to 86/150 (0.573) - all in mid-season plateau!
      for (final kc in data.dailyKcSeries) {
        expect(kc, equals(1.15));
      }
      for (final dailyEtc in data.dailyEtcMmSeries) {
        expect(dailyEtc, equals(4.6)); // 4.0 * 1.15
      }
      expect(data.totalEtcMm, closeTo(32.2, 1e-9));
    });

    test('3. Identical ET0 series for identical crop age produces reproducible results', () {
      final plantingDate = DateTime.utc(2024, 11, 15);
      final forecastDates = List.generate(
        7,
        (i) => plantingDate.add(Duration(days: 40 + i)),
      );
      final et0Series = [3.5, 4.0, 4.2, 3.8, 4.5, 5.0, 4.1];

      final res1 = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 7,
      );

      final res2 = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 7,
      );

      expect(res1.dataOrNull?.totalEtcMm, equals(res2.dataOrNull?.totalEtcMm));
      expect(
        res1.dataOrNull?.totalVolumeM3PerFeddan,
        equals(res2.dataOrNull?.totalVolumeM3PerFeddan),
      );
      expect(
        res1.dataOrNull?.dailyKcSeries,
        equals(res2.dataOrNull?.dailyKcSeries),
      );
    });

    test('4. Advancing planting date/crop age changes Kc across interpolation boundaries', () {
      final forecastStart = DateTime.utc(2025, 1, 1);
      final forecastDates = List.generate(
        7,
        (i) => forecastStart.add(Duration(days: i)),
      );
      final et0Series = List.generate(7, (_) => 5.0);

      // Crop planted 10 days ago (Initial stage, fraction 10/150 = 0.066 <= 0.20) -> Kc = 0.40
      final resEarly = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: forecastStart.subtract(const Duration(days: 10)),
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 7,
      );

      // Crop planted 60 days ago (Development stage, fraction 60/150 = 0.40 in (0.20, 0.50])
      // Interpolation: 0.40 + (0.40 - 0.20)/0.30 * (1.15 - 0.40) = 0.40 + 2/3 * 0.75 = 0.90
      final resDev = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: forecastStart.subtract(const Duration(days: 60)),
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 7,
      );

      // Crop planted 90 days ago (Mid-season plateau, fraction 90/150 = 0.60) -> Kc = 1.15
      final resMid = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: forecastStart.subtract(const Duration(days: 90)),
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 7,
      );

      expect(resEarly.dataOrNull!.dailyKcSeries.first, equals(0.40));
      expect(resDev.dataOrNull!.dailyKcSeries.first, closeTo(0.90, 1e-4));
      expect(resMid.dataOrNull!.dailyKcSeries.first, equals(1.15));
    });

    test('5. Calendar date handling correctly handles month-end and leap-year boundaries without off-by-one errors', () {
      // Leap year 2024: Feb has 29 days
      final plantingDate = DateTime.utc(2024, 2, 27);
      // Crossing Feb 27, 28, 29, Mar 1, 2
      final forecastDates = [
        DateTime.utc(2024, 2, 28), // day 1 after planting
        DateTime.utc(2024, 2, 29), // day 2
        DateTime.utc(2024, 3, 1), // day 3
        DateTime.utc(2024, 3, 2), // day 4
      ];

      final res = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: [4.0, 4.0, 4.0, 4.0],
        totalRequestedDays: 4,
      );

      expect(res.isSuccess, isTrue);
      // Stage fractions should be exactly 1/150, 2/150, 3/150, 4/150
      final data = res.dataOrNull!;
      expect(data.dailyKcSeries.length, equals(4));
      expect(data.dailyKcSeries.every((kc) => kc == 0.40), isTrue);
    });

    test('6. Crop typicalDurationDays directly controls developmental stage fraction', () {
      final forecastDate = [DateTime.utc(2025, 3, 1)];
      final plantingDate = DateTime.utc(2025, 1, 1); // 59 days prior

      // Test with 120-day crop vs 180-day crop
      const maize120 = EgyptianCropsCatalog.maize; // 120 days
      const cotton180 = EgyptianCropsCatalog.cotton; // 180 days

      final resMaize = EtcCalculator.calculateForecastEtcValidated(
        crop: maize120,
        plantingDate: plantingDate,
        forecastDates: forecastDate,
        dailyEt0Series: [5.0],
        totalRequestedDays: 1,
      );

      final resCotton = EtcCalculator.calculateForecastEtcValidated(
        crop: cotton180,
        plantingDate: plantingDate,
        forecastDates: forecastDate,
        dailyEt0Series: [5.0],
        totalRequestedDays: 1,
      );

      // 59/120 = ~0.4916 (near end of development stage)
      // 59/180 = ~0.3277 (early in development stage)
      final kcMaize = resMaize.dataOrNull!.dailyKcSeries.first;
      final kcCotton = resCotton.dataOrNull!.dailyKcSeries.first;
      expect(kcMaize, isNot(equals(kcCotton)));
    });

    test('7. Missing ET0 observations do NOT shift subsequent forecast dates or crop stages', () {
      final plantingDate = DateTime.utc(2024, 11, 15);
      final forecastStart = plantingDate.add(
        const Duration(days: 58),
      ); // development stage
      final forecastDates = List.generate(
        10,
        (i) => forecastStart.add(Duration(days: i)),
      );
      // Day 3 (index 2) is missing
      final et0Series = List<double?>.generate(10, (i) => i == 2 ? null : 5.0);

      final res = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: et0Series,
        totalRequestedDays: 10,
      );

      expect(res.isSuccess, isTrue);
      final data = res.dataOrNull!;
      // Missing day has null etc contribution
      expect(data.dailyEtcMmSeries[2], isNull);
      // Day 4 (index 3) retains its exact biological Kc corresponding to day 61 after planting
      final expectedKcDay4 = wheat.getKcForStageFraction(61 / 150);
      expect(data.dailyKcSeries[3], closeTo(expectedKcDay4, 1e-6));
      expect(data.dailyEtcMmSeries[3], closeTo(5.0 * expectedKcDay4, 1e-6));
    });

    test(
      '8. Missing plantingDate fails closed with MissingCropStageFailure',
      () {
        final forecastDates = List.generate(
          7,
          (i) => DateTime.utc(2025, 1, 1 + i),
        );
        final res = EtcCalculator.calculateForecastEtcValidated(
          crop: wheat,
          plantingDate: null,
          forecastDates: forecastDates,
          dailyEt0Series: [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0],
          totalRequestedDays: 7,
        );

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<MissingCropStageFailure>());
        expect(
          res.failureOrNull?.userMessageAr.contains('تاريخ زراعة المحصول'),
          isTrue,
        );
      },
    );

    test('9. Planting date in the future relative to forecast period fails closed with MissingCropStageFailure', () {
      final forecastDates = [DateTime.utc(2025, 1, 1)];
      final futurePlanting = DateTime.utc(2025, 1, 10);

      final res = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: futurePlanting,
        forecastDates: forecastDates,
        dailyEt0Series: [5.0],
        totalRequestedDays: 1,
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<MissingCropStageFailure>());
      expect(res.failureOrNull?.userMessageAr.contains('المستقبل'), isTrue);
    });

    test('10. Invalid typicalDurationDays (<= 0) fails closed with MissingCropStageFailure', () {
      final invalidCrop = Crop(
        id: 'bad_crop',
        nameAr: 'محصول غير صالح',
        nameEn: 'Invalid Crop',
        season: CropSeason.winter,
        baseTemperatureC: 5.0,
        criticalHeatTemperatureC: 30.0,
        kcIni: 0.40,
        kcMid: 1.15,
        kcEnd: 0.35,
        typicalDurationDays: 0, // Invalid!
        soilNutrientImpact: SoilNutrientImpact.moderate,
        scientificNotesAr: '',
      );

      final res = EtcCalculator.calculateForecastEtcValidated(
        crop: invalidCrop,
        plantingDate: DateTime.utc(2024, 1, 1),
        forecastDates: [DateTime.utc(2024, 1, 5)],
        dailyEt0Series: [5.0],
        totalRequestedDays: 1,
      );

      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<MissingCropStageFailure>());
    });

    test('11. Operational ET0 envelope, NaN/Infinities, and missingness policy enforcement', () {
      final plantingDate = DateTime.utc(2024, 1, 1);
      final forecastDates = List.generate(
        10,
        (i) => DateTime.utc(2024, 1, 10 + i),
      );

      // Negative ET0 -> PhysicalRangeFailure
      final negRes = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: [-1.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0],
        totalRequestedDays: 10,
      );
      expect(negRes.isFailure, isTrue);
      expect(negRes.failureOrNull, isA<PhysicalRangeFailure>());

      // ET0 > 25.0 -> PhysicalRangeFailure
      final highRes = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: [25.1, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0],
        totalRequestedDays: 10,
      );
      expect(highRes.isFailure, isTrue);
      expect(highRes.failureOrNull, isA<PhysicalRangeFailure>());

      // NaN ET0 -> PhysicalRangeFailure
      final nanRes = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: [
          double.nan,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
        ],
        totalRequestedDays: 10,
      );
      expect(nanRes.isFailure, isTrue);
      expect(nanRes.failureOrNull, isA<PhysicalRangeFailure>());

      // Missing > 10% (2 missing out of 10) -> InsufficientEvidenceFailure
      final missingRes = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: [null, null, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0],
        totalRequestedDays: 10,
      );
      expect(missingRes.isFailure, isTrue);
      expect(missingRes.failureOrNull, isA<InsufficientEvidenceFailure>());

      // Extra observations beyond requested period are ignored
      final extraRes = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: [...forecastDates, DateTime.utc(2024, 1, 20)],
        dailyEt0Series: [
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          5.0,
          999.0,
        ], // 11th observation is invalid but beyond requested
        totalRequestedDays: 10,
      );
      expect(extraRes.isSuccess, isTrue);
      expect(extraRes.dataOrNull!.dailyEtcMmSeries.length, equals(10));
    });

    test('12. Crop age beyond typicalDurationDays clamps fraction to 1.0 returning kcEnd', () {
      final plantingDate = DateTime.utc(2024, 1, 1);
      // Wheat duration is 150 days; forecast date is 200 days after planting
      final forecastDates = [plantingDate.add(const Duration(days: 200))];

      final res = EtcCalculator.calculateForecastEtcValidated(
        crop: wheat,
        plantingDate: plantingDate,
        forecastDates: forecastDates,
        dailyEt0Series: [5.0],
        totalRequestedDays: 1,
      );

      expect(res.isSuccess, isTrue);
      final data = res.dataOrNull!;
      expect(data.dailyKcSeries.first, closeTo(wheat.kcEnd, 1e-6)); // 0.35
      expect(data.dailyEtcMmSeries.first, closeTo(5.0 * wheat.kcEnd, 1e-6));
    });
  });
}
