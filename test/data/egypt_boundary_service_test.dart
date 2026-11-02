import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';

void main() {
  late EgyptBoundaryService boundaryService;
  late String geoJsonContent;

  setUpAll(() async {
    final file = File('assets/geo/egypt_governorates.geojson');
    geoJsonContent = await file.readAsString();
    boundaryService = EgyptBoundaryService.fromJsonString(geoJsonContent);
  });

  group('Egypt Boundary & Governorate Lookup Tests', () {
    test('Loads exactly 27 Egyptian governorates from GeoJSON', () {
      expect(boundaryService.governorates.length, equals(27));
    });

    test('Dataset completeness and property schema integrity', () {
      final decoded = json.decode(geoJsonContent) as Map<String, dynamic>;
      expect(decoded['type'], equals('FeatureCollection'));
      final features = decoded['features'] as List<dynamic>;
      expect(features.length, equals(27));

      final seenIsos = <String>{};
      final seenNamesAr = <String>{};
      final seenNamesEn = <String>{};

      int polygonCount = 0;
      int multiPolygonCount = 0;

      for (final f in features) {
        final feature = f as Map<String, dynamic>;
        final props = feature['properties'] as Map<String, dynamic>;
        final geom = feature['geometry'] as Map<String, dynamic>;

        final iso = props['shapeISO'] as String?;
        final nameAr = props['nameAr'] as String?;
        final nameEn = props['shapeName'] as String?;

        expect(iso, isNotNull);
        expect(iso!.trim(), isNotEmpty);
        expect(seenIsos.add(iso), isTrue, reason: 'Duplicate ISO: $iso');

        expect(nameAr, isNotNull);
        expect(nameAr!.trim(), isNotEmpty);
        expect(
          seenNamesAr.add(nameAr),
          isTrue,
          reason: 'Duplicate nameAr: $nameAr',
        );

        expect(nameEn, isNotNull);
        expect(nameEn!.trim(), isNotEmpty);
        expect(
          seenNamesEn.add(nameEn),
          isTrue,
          reason: 'Duplicate nameEn: $nameEn',
        );

        final geomType = geom['type'] as String;
        expect(geomType, isIn(['Polygon', 'MultiPolygon']));
        if (geomType == 'Polygon') {
          polygonCount++;
          final rings = geom['coordinates'] as List;
          expect(rings.isNotEmpty, isTrue);
          final ext = rings[0] as List;
          expect(ext.length, greaterThanOrEqualTo(4));
          // Ring must be closed
          expect(ext.first, equals(ext.last));
        } else {
          multiPolygonCount++;
          final parts = geom['coordinates'] as List;
          expect(parts.isNotEmpty, isTrue);
          for (final part in parts) {
            final rings = part as List;
            expect(rings.isNotEmpty, isTrue);
            final ext = rings[0] as List;
            expect(ext.length, greaterThanOrEqualTo(4));
            expect(ext.first, equals(ext.last));
          }
        }
      }

      expect(polygonCount, equals(19));
      expect(multiPolygonCount, equals(8));
      expect(seenIsos.length, equals(27));
      expect(seenNamesAr.length, equals(27));
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

    test('MultiPolygon non-primary component resolves accurately (South Sinai: Tiran Island)', () {
      // Tiran Island is part 0 of EG-JS (South Sinai Governorate MultiPolygon)
      // Coordinates: Lat 27.962878, Lon 34.558708
      const double tiranLat = 27.962878;
      const double tiranLon = 34.558708;

      expect(boundaryService.isWithinEgypt(tiranLat, tiranLon), isTrue);
      expect(
        boundaryService.findGovernorate(tiranLat, tiranLon),
        equals('جنوب سيناء'),
      );
    });

    test('Boundary-adjacent points on opposite sides of shared border resolve to correct governorates', () {
      // Shared boundary between Gharbia (EG-GH) and Kafr El-Sheikh (EG-KFS) near vertex [30.7613501, 30.9870359]
      // Point 1: South of border in Gharbia interior (Lat 30.9767, Lon 30.7785)
      const double gharbiaLat = 30.9767;
      const double gharbiaLon = 30.7785;
      expect(boundaryService.isWithinEgypt(gharbiaLat, gharbiaLon), isTrue);
      expect(
        boundaryService.findGovernorate(gharbiaLat, gharbiaLon),
        equals('الغربية'),
      );

      // Point 2: North of border in Kafr El-Sheikh interior (Lat 31.0070, Lon 30.7602)
      const double kfsLat = 31.0070;
      const double kfsLon = 30.7602;
      expect(boundaryService.isWithinEgypt(kfsLat, kfsLon), isTrue);
      expect(
        boundaryService.findGovernorate(kfsLat, kfsLon),
        equals('كفر الشيخ'),
      );
    });

    test('Exact boundary vertex semantics document deterministic point-in-polygon partitioning', () {
      // Vertex [30.7613501, 30.9870359] is an administrative tripoint shared by Beheira (EG-BH), Gharbia (EG-GH), and Kafr El-Sheikh (EG-KFS).
      // Standard half-open ray-casting evaluates edges with (p1y < y && p2y >= y) || (p2y < y && p1y >= y).
      // On boundary vertices and edges, this deterministic partition assigns the shared point to an adjacent
      // polygon rather than failing or double-counting across governorates.
      const double sharedVertexLat = 30.9870359;
      const double sharedVertexLon = 30.7613501;

      expect(
        boundaryService.isWithinEgypt(sharedVertexLat, sharedVertexLon),
        isTrue,
      );
      final gov = boundaryService.findGovernorate(
        sharedVertexLat,
        sharedVertexLon,
      );
      expect(gov, isNotNull);
      expect(gov, isIn(['البحيرة', 'الغربية', 'كفر الشيخ']));
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
      expect(boundaryService.findGovernorate(double.infinity, 31.0), isNull);
      expect(
        boundaryService.findGovernorate(30.0, double.negativeInfinity),
        isNull,
      );

      // Out of world coordinate ranges
      expect(boundaryService.isWithinEgypt(95.0, 30.0), isFalse);
      expect(boundaryService.isWithinEgypt(-95.0, 30.0), isFalse);
      expect(boundaryService.isWithinEgypt(30.0, 190.0), isFalse);
      expect(boundaryService.isWithinEgypt(30.0, -190.0), isFalse);
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
      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection"}',
        ),
        throwsFormatException,
      );
    });
  });
}
