import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';

void main() {
  late EgyptBoundaryService boundaryService;

  setUpAll(() async {
    final file = File('assets/geo/egypt_governorates.geojson');
    final jsonStr = await file.readAsString();
    boundaryService = EgyptBoundaryService.fromJsonString(jsonStr);
  });

  group('Egypt Boundary & Governorate Lookup Tests', () {
    test('Loads exactly 27 Egyptian governorates from GeoJSON', () {
      expect(boundaryService.governorates.length, equals(27));
    });

    test('Known valid points inside Egypt pass boundary check', () {
      // Sidi Salem, Kafr El-Sheikh
      expect(boundaryService.isWithinEgypt(31.27, 30.79), isTrue);
      // Tanta, Gharbia
      expect(boundaryService.isWithinEgypt(30.79, 31.00), isTrue);
      // Beni Mazar, Minya
      expect(boundaryService.isWithinEgypt(28.50, 30.80), isTrue);
      // Cairo Downtown
      expect(boundaryService.isWithinEgypt(30.0444, 31.2357), isTrue);
      // Alexandria
      expect(boundaryService.isWithinEgypt(31.2001, 29.9187), isTrue);
      // Aswan
      expect(boundaryService.isWithinEgypt(24.0889, 32.8998), isTrue);
      // Hurghada, Red Sea
      expect(boundaryService.isWithinEgypt(27.2579, 33.8116), isTrue);
      // Dakhla Oasis, New Valley
      expect(boundaryService.isWithinEgypt(25.5, 29.0), isTrue);
    });

    test('Known points correctly map to Arabic governorate names', () {
      expect(
        boundaryService.findGovernorate(31.27, 30.79),
        equals('كفر الشيخ'),
      );
      expect(boundaryService.findGovernorate(30.79, 31.00), equals('الغربية'));
      expect(boundaryService.findGovernorate(28.50, 30.80), equals('المنيا'));
      expect(
        boundaryService.findGovernorate(30.0444, 31.2357),
        equals('القاهرة'),
      );
      expect(
        boundaryService.findGovernorate(31.2001, 29.9187),
        equals('الإسكندرية'),
      );
      expect(
        boundaryService.findGovernorate(24.0889, 32.8998),
        equals('أسوان'),
      );
      expect(
        boundaryService.findGovernorate(27.2579, 33.8116),
        equals('البحر الأحمر'),
      );
      expect(
        boundaryService.findGovernorate(25.5, 29.0),
        equals('الوادي الجديد'),
      );
    });

    test('Point inside bounding box envelope but outside Egypt boundary is rejected', () {
      // Mediterranean offshore (Lat 31.6, Lon 30.0 is inside 22.0..31.8, 25.0..37.0 bbox, but outside Egypt land)
      expect(boundaryService.isWithinEgypt(31.60, 30.00), isFalse);
      expect(boundaryService.findGovernorate(31.60, 30.00), isNull);

      // Gulf of Suez open waters / international waters
      expect(boundaryService.isWithinEgypt(32.0, 31.0), isFalse);
    });

    test('Points clearly outside Egypt are rejected', () {
      // Northern Sudan (Lat 20.0, Lon 30.0)
      expect(boundaryService.isWithinEgypt(20.0, 30.0), isFalse);
      expect(boundaryService.findGovernorate(20.0, 30.0), isNull);

      // Eastern Libya (Lat 29.0, Lon 24.0)
      expect(boundaryService.isWithinEgypt(29.0, 24.0), isFalse);
      expect(boundaryService.findGovernorate(29.0, 24.0), isNull);

      // Northern Saudi Arabia (Lat 29.0, Lon 36.5)
      expect(boundaryService.isWithinEgypt(29.0, 36.5), isFalse);
      expect(boundaryService.findGovernorate(29.0, 36.5), isNull);
    });

    test('Invalid coordinates, NaN and Infinity are safely rejected', () {
      expect(boundaryService.isWithinEgypt(double.nan, 31.0), isFalse);
      expect(boundaryService.isWithinEgypt(30.0, double.nan), isFalse);
      expect(boundaryService.isWithinEgypt(double.infinity, 31.0), isFalse);
      expect(
        boundaryService.isWithinEgypt(30.0, double.negativeInfinity),
        isFalse,
      );

      expect(boundaryService.findGovernorate(double.nan, 31.0), isNull);
      expect(boundaryService.findGovernorate(30.0, double.nan), isNull);
    });

    test('Malformed GeoJSON throws FormatException', () {
      expect(
        () => EgyptBoundaryService.fromJsonString('{}'),
        throwsFormatException,
      );
      expect(
        () => EgyptBoundaryService.fromJsonString('{"type": "Feature"}'),
        throwsFormatException,
      );
    });
  });
}
