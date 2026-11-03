import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:agro_shift/data/datasources/local/egypt_boundary_service.dart';

/// Validates a single GeoJSON coordinate pair according to RFC 7946:
/// - Must be a list of at least 2 numbers [longitude, latitude]
/// - Must not be NaN or Infinite
/// - Longitude must be within [-180, 180]
/// - Latitude must be within [-90, 90]
bool isValidCoordinate(dynamic position) {
  if (position is! List || position.length < 2) return false;
  final x = position[0];
  final y = position[1];
  if (x is! num || y is! num) return false;
  final dx = x.toDouble();
  final dy = y.toDouble();
  if (dx.isNaN || dx.isInfinite || dy.isNaN || dy.isInfinite) return false;
  if (dx < -180.0 || dx > 180.0 || dy < -90.0 || dy > 90.0) return false;
  return true;
}

/// Validates that a linear ring satisfies GeoJSON specification:
/// - Must have at least 4 positions
/// - First and last positions must be identical (closed ring)
/// - Every position must be a valid coordinate
bool isValidRing(dynamic ring) {
  if (ring is! List || ring.length < 4) return false;
  for (final coord in ring) {
    if (!isValidCoordinate(coord)) return false;
  }
  final first = ring.first as List;
  final last = ring.last as List;
  return (first[0] as num).toDouble() == (last[0] as num).toDouble() &&
      (first[1] as num).toDouble() == (last[1] as num).toDouble();
}

/// Geometrically determines if point P(px, py) lies on line segment AB:
/// A(ax, ay) to B(bx, by) within a numerical tolerance.
/// Uses 2D cross-product for collinearity and axis-aligned bounding box for segment bounds.
bool isPointOnSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by, {
  double tolerance = 1e-9,
}) {
  // Collinearity check: cross product of (P - A) and (B - A)
  final crossProduct = ((py - ay) * (bx - ax) - (px - ax) * (by - ay)).abs();
  if (crossProduct > tolerance) return false;

  // Segment bounds check (dot product / bounding box)
  final minX = (ax < bx ? ax : bx) - tolerance;
  final maxX = (ax > bx ? ax : bx) + tolerance;
  final minY = (ay < by ? ay : by) - tolerance;
  final maxY = (ay > by ? ay : by) + tolerance;

  return px >= minX && px <= maxX && py >= minY && py <= maxY;
}

/// Checks whether an undirected line segment [p1, p2] exists as an actual consecutive
/// boundary edge in the rings of a GeoJSON geometry (supports Polygon and MultiPolygon).
bool geometryContainsSegment(
  Map<String, dynamic> geometry,
  List<double> p1,
  List<double> p2, {
  double tolerance = 1e-7,
}) {
  final type = geometry['type'] as String;
  final List<List<dynamic>> allRings = [];

  if (type == 'Polygon') {
    final coords = geometry['coordinates'] as List;
    for (final ring in coords) {
      allRings.add(ring as List<dynamic>);
    }
  } else if (type == 'MultiPolygon') {
    final polys = geometry['coordinates'] as List;
    for (final poly in polys) {
      for (final ring in poly as List) {
        allRings.add(ring as List<dynamic>);
      }
    }
  }

  for (final ring in allRings) {
    final n = ring.length;
    for (int i = 0; i < n - 1; i++) {
      final a = ring[i] as List;
      final b = ring[i + 1] as List;
      final ax = (a[0] as num).toDouble();
      final ay = (a[1] as num).toDouble();
      final bx = (b[0] as num).toDouble();
      final by = (b[1] as num).toDouble();

      final forwardMatch =
          (ax - p1[0]).abs() <= tolerance &&
          (ay - p1[1]).abs() <= tolerance &&
          (bx - p2[0]).abs() <= tolerance &&
          (by - p2[1]).abs() <= tolerance;

      final reverseMatch =
          (ax - p2[0]).abs() <= tolerance &&
          (ay - p2[1]).abs() <= tolerance &&
          (bx - p1[0]).abs() <= tolerance &&
          (by - p1[1]).abs() <= tolerance;

      if (forwardMatch || reverseMatch) {
        return true;
      }
    }
  }
  return false;
}

/// Checks whether a vertex coordinate exists in any ring of a GeoJSON geometry.
bool geometryContainsVertex(
  Map<String, dynamic> geometry,
  List<double> target, {
  double tolerance = 1e-7,
}) {
  final type = geometry['type'] as String;
  final List<List<dynamic>> allRings = [];

  if (type == 'Polygon') {
    final coords = geometry['coordinates'] as List;
    for (final ring in coords) {
      allRings.add(ring as List<dynamic>);
    }
  } else if (type == 'MultiPolygon') {
    final polys = geometry['coordinates'] as List;
    for (final poly in polys) {
      for (final ring in poly as List) {
        allRings.add(ring as List<dynamic>);
      }
    }
  }

  for (final ring in allRings) {
    for (final pt in ring) {
      final coord = pt as List;
      final x = (coord[0] as num).toDouble();
      final y = (coord[1] as num).toDouble();
      if ((x - target[0]).abs() <= tolerance &&
          (y - target[1]).abs() <= tolerance) {
        return true;
      }
    }
  }
  return false;
}

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

    test('Exhaustive GeoJSON structural, ring closure, and coordinate validation across all 27 governorates', () {
      final decoded = json.decode(geoJsonContent) as Map<String, dynamic>;
      expect(decoded['type'], equals('FeatureCollection'));
      final features = decoded['features'] as List<dynamic>;
      expect(features.length, equals(27));

      final seenIsos = <String>{};
      final seenNamesAr = <String>{};
      final seenNamesEn = <String>{};

      int polygonCount = 0;
      int multiPolygonCount = 0;
      int totalRings = 0;
      int exteriorRings = 0;
      int interiorRings = 0;
      int totalCoordinates = 0;

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

          for (int rIdx = 0; rIdx < rings.length; rIdx++) {
            totalRings++;
            if (rIdx == 0) {
              exteriorRings++;
            } else {
              interiorRings++;
            }
            final ring = rings[rIdx];
            expect(
              isValidRing(ring),
              isTrue,
              reason: 'Invalid Polygon ring in $iso (ring index $rIdx)',
            );
            for (final coord in ring as List) {
              totalCoordinates++;
              expect(
                isValidCoordinate(coord),
                isTrue,
                reason: 'Invalid coordinate in $iso: $coord',
              );
            }
          }
        } else {
          multiPolygonCount++;
          final parts = geom['coordinates'] as List;
          expect(parts.isNotEmpty, isTrue);

          for (int pIdx = 0; pIdx < parts.length; pIdx++) {
            final rings = parts[pIdx] as List;
            expect(rings.isNotEmpty, isTrue);

            for (int rIdx = 0; rIdx < rings.length; rIdx++) {
              totalRings++;
              if (rIdx == 0) {
                exteriorRings++;
              } else {
                interiorRings++;
              }
              final ring = rings[rIdx];
              expect(
                isValidRing(ring),
                isTrue,
                reason:
                    'Invalid MultiPolygon ring in $iso (part $pIdx, ring $rIdx)',
              );
              for (final coord in ring as List) {
                totalCoordinates++;
                expect(
                  isValidCoordinate(coord),
                  isTrue,
                  reason: 'Invalid coordinate in $iso: $coord',
                );
              }
            }
          }
        }
      }

      expect(polygonCount, equals(19));
      expect(multiPolygonCount, equals(8));
      expect(seenIsos.length, equals(27));
      expect(seenNamesAr.length, equals(27));
      expect(seenNamesEn.length, equals(27));
      expect(totalRings, equals(62));
      expect(exteriorRings, equals(62));
      expect(
        interiorRings,
        equals(0),
      ); // geoBoundaries ADM1 simplified contains no holes
      expect(totalCoordinates, equals(6773));
    });

    test('Rejects malformed coordinate positions and unclosed or degenerate rings (Workstream A fixture validation)', () {
      // Coordinate level rejections
      expect(isValidCoordinate([double.nan, 30.0]), isFalse);
      expect(isValidCoordinate([30.0, double.nan]), isFalse);
      expect(isValidCoordinate([double.infinity, 30.0]), isFalse);
      expect(isValidCoordinate([30.0, double.negativeInfinity]), isFalse);
      expect(isValidCoordinate([190.0, 30.0]), isFalse); // Lon > 180
      expect(isValidCoordinate([-190.0, 30.0]), isFalse); // Lon < -180
      expect(isValidCoordinate([30.0, 95.0]), isFalse); // Lat > 90
      expect(isValidCoordinate([30.0, -95.0]), isFalse); // Lat < -90
      expect(isValidCoordinate(['30.0', 31.0]), isFalse); // Non-numeric
      expect(isValidCoordinate([30.0]), isFalse); // Insufficient dimensions
      expect(isValidCoordinate('not-a-list'), isFalse);

      // Ring level rejections
      expect(
        isValidRing([
          [30.0, 30.0],
          [31.0, 30.0],
          [31.0, 31.0],
          [30.0, 30.5], // Unclosed (first != last)
        ]),
        isFalse,
      );

      expect(
        isValidRing([
          [30.0, 30.0],
          [31.0, 30.0],
          [30.0, 30.0], // Degenerate: only 3 points
        ]),
        isFalse,
      );

      expect(
        isValidRing([
          [30.0, 30.0],
          [double.nan, 30.0], // Contaminated with NaN
          [31.0, 31.0],
          [30.0, 30.0],
        ]),
        isFalse,
      );
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

    test('Shared boundary segment is verified directly in actual GeoJSON geometry of Gharbia and Kafr El-Sheikh (Workstream A)', () {
      final decoded = json.decode(geoJsonContent) as Map<String, dynamic>;
      final features = (decoded['features'] as List)
          .cast<Map<String, dynamic>>();

      // 1. Locate both features in the loaded GeoJSON
      final ghFeature = features.firstWhere(
        (f) => f['properties']['shapeISO'] == 'EG-GH',
      );
      final kfsFeature = features.firstWhere(
        (f) => f['properties']['shapeISO'] == 'EG-KFS',
      );

      expect(ghFeature, isNotNull);
      expect(kfsFeature, isNotNull);

      // 2. Candidate shared segment endpoints [lon, lat]
      const double aLon = 31.0235506;
      const double aLat = 30.9865686;
      const double bLon = 30.9252878;
      const double bLat = 30.9865686;

      const candidateA = [aLon, aLat];
      const candidateB = [bLon, bLat];

      // 3. Verify that the candidate segment genuinely exists in Gharbia's loaded geometry
      expect(
        geometryContainsSegment(ghFeature['geometry'], candidateA, candidateB),
        isTrue,
        reason: 'Candidate segment AB must exist in Gharbia (EG-GH) geometry',
      );

      // 4. Verify that the same segment genuinely exists in Kafr El-Sheikh's loaded geometry
      expect(
        geometryContainsSegment(kfsFeature['geometry'], candidateA, candidateB),
        isTrue,
        reason: 'Candidate segment AB must exist in Kafr El-Sheikh (EG-KFS) geometry',
      );

      // 5. Negative control: Arbitrary unshared segment must be rejected
      const fakeP1 = [31.0000, 30.0000];
      const fakeP2 = [31.5000, 30.5000];
      expect(
        geometryContainsSegment(ghFeature['geometry'], fakeP1, fakeP2),
        isFalse,
      );
      expect(
        geometryContainsSegment(kfsFeature['geometry'], fakeP1, fakeP2),
        isFalse,
      );

      // 6. Compute midpoint P of the verified source segment
      const double pLon = (aLon + bLon) / 2.0; // 30.9744192
      const double pLat = 30.9865686;

      // Mathematical proof: P lies strictly on segment AB
      expect(isPointOnSegment(pLon, pLat, aLon, aLat, bLon, bLat), isTrue);

      // 7. Interior point tests on opposite sides of the verified shared boundary
      // South of segment: Interior to Gharbia
      const double southLat = 30.9765686; // 0.01 deg south
      const double southLon = pLon;
      expect(boundaryService.isWithinEgypt(southLat, southLon), isTrue);
      expect(
        boundaryService.findGovernorate(southLat, southLon),
        equals('الغربية'),
      );

      // North of segment: Interior to Kafr El-Sheikh
      const double northLat = 30.9965686; // 0.01 deg north
      const double northLon = pLon;
      expect(boundaryService.isWithinEgypt(northLat, northLon), isTrue);
      expect(
        boundaryService.findGovernorate(northLat, northLon),
        equals('كفر الشيخ'),
      );

      // 8. Deterministic boundary resolution:
      // Midpoint on the shared boundary segment is within Egypt.
      expect(boundaryService.isWithinEgypt(pLat, pLon), isTrue);

      // Under deterministic first-match in dataset order:
      // Gharbia (EG-GH, index 9) precedes Kafr El-Sheikh (EG-KFS, index 24).
      // Midpoint P resolves to Gharbia.
      final govAtBoundary = boundaryService.findGovernorate(pLat, pLon);
      expect(
        govAtBoundary,
        equals('الغربية'),
        reason: 'Boundary point must resolve deterministically to the first matching feature in dataset order (Gharbia)',
      );
    });

    test('Exact boundary vertex is verified in actual GeoJSON and deterministically resolves to Al Beheira (Workstream B)', () {
      final decoded = json.decode(geoJsonContent) as Map<String, dynamic>;
      final features = (decoded['features'] as List)
          .cast<Map<String, dynamic>>();

      // Tripoint vertex shared between Beheira (EG-BH), Gharbia (EG-GH), and Kafr El-Sheikh (EG-KFS)
      const double sharedVertexLat = 30.9870359;
      const double sharedVertexLon = 30.7613501;
      const tripoint = [sharedVertexLon, sharedVertexLat];

      // 1. Locate the three relevant features in loaded GeoJSON
      final bhFeature = features.firstWhere(
        (f) => f['properties']['shapeISO'] == 'EG-BH',
      );
      final ghFeature = features.firstWhere(
        (f) => f['properties']['shapeISO'] == 'EG-GH',
      );
      final kfsFeature = features.firstWhere(
        (f) => f['properties']['shapeISO'] == 'EG-KFS',
      );

      // 2. Independently verify the coordinate corresponds to the actual shared vertex in all three geometries
      expect(
        geometryContainsVertex(bhFeature['geometry'], tripoint),
        isTrue,
        reason: 'Tripoint vertex must exist in Beheira (EG-BH) boundary ring',
      );
      expect(
        geometryContainsVertex(ghFeature['geometry'], tripoint),
        isTrue,
        reason: 'Tripoint vertex must exist in Gharbia (EG-GH) boundary ring',
      );
      expect(
        geometryContainsVertex(kfsFeature['geometry'], tripoint),
        isTrue,
        reason: 'Tripoint vertex must exist in Kafr El-Sheikh (EG-KFS) boundary ring',
      );

      // 3. Verify that the vertex is recognized as within Egypt
      expect(
        boundaryService.isWithinEgypt(sharedVertexLat, sharedVertexLon),
        isTrue,
      );

      // 4. Lock down the exact, deterministic expected result:
      // In the production point-in-polygon half-open ray casting:
      // ((p1y < y && p2y >= y) || (p2y < y && p1y >= y))
      // Beheira (EG-BH, index 19) contains edges meeting this condition for the ray from [30.7613501, 30.9870359].
      // Although Gharbia is at index 9, the ray test for Gharbia evaluates to false for this specific vertex,
      // while Beheira evaluates to true.
      // Therefore, the deterministic resolution is exclusively 'البحيرة'.
      final gov = boundaryService.findGovernorate(
        sharedVertexLat,
        sharedVertexLon,
      );
      expect(
        gov,
        equals('البحيرة'),
        reason: 'The boundary tripoint vertex must deterministically resolve to Al Beheira (البحيرة)',
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

  group('Synthetic GeoJSON Geometry, Parsing & Defensive Correctness Tests (Workstream A)', () {
    test('Synthetic Polygon with interior hole correctly includes exterior and excludes hole', () {
      final syntheticHoleGeoJson = json.encode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'shapeISO': 'SYN-HOLE',
              'shapeName': 'Synthetic Governorate with Oasis Hole',
              'nameAr': 'محافظة تجريبية بها بحيرة',
            },
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [30.0, 28.0],
                  [34.0, 28.0],
                  [34.0, 32.0],
                  [30.0, 32.0],
                  [30.0, 28.0],
                ],
                [
                  [31.0, 29.0],
                  [33.0, 29.0],
                  [33.0, 31.0],
                  [31.0, 31.0],
                  [31.0, 29.0],
                ],
              ],
            },
          },
        ],
      });

      final service = EgyptBoundaryService.fromJsonString(syntheticHoleGeoJson);
      expect(service.governorates.length, equals(1));
      expect(service.governorates.first.polygons.first.holes.length, equals(1));

      expect(service.isWithinEgypt(28.5, 30.5), isTrue);
      expect(
        service.findGovernorate(28.5, 30.5),
        equals('محافظة تجريبية بها بحيرة'),
      );

      expect(service.isWithinEgypt(30.0, 32.0), isFalse);
      expect(service.findGovernorate(30.0, 32.0), isNull);

      expect(service.isWithinEgypt(27.0, 32.0), isFalse);
      expect(service.findGovernorate(27.0, 32.0), isNull);
    });

    test('Synthetic MultiPolygon evaluates each component and respects holes per component', () {
      final syntheticMultiPolyGeoJson = json.encode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'shapeISO': 'SYN-MULTI',
              'shapeName': 'Synthetic Multi-Islands',
              'nameAr': 'محافظة الجزر التجريبية',
            },
            'geometry': {
              'type': 'MultiPolygon',
              'coordinates': [
                [
                  [
                    [30.0, 28.0],
                    [31.0, 28.0],
                    [31.0, 29.0],
                    [30.0, 29.0],
                    [30.0, 28.0],
                  ],
                ],
                [
                  [
                    [33.0, 30.0],
                    [35.0, 30.0],
                    [35.0, 32.0],
                    [33.0, 32.0],
                    [33.0, 30.0],
                  ],
                  [
                    [33.8, 30.8],
                    [34.2, 30.8],
                    [34.2, 31.2],
                    [33.8, 31.2],
                    [33.8, 30.8],
                  ],
                ],
              ],
            },
          },
        ],
      });

      final service = EgyptBoundaryService.fromJsonString(
        syntheticMultiPolyGeoJson,
      );
      expect(service.governorates.first.polygons.length, equals(2));

      expect(service.isWithinEgypt(28.5, 30.5), isTrue);
      expect(
        service.findGovernorate(28.5, 30.5),
        equals('محافظة الجزر التجريبية'),
      );

      expect(service.isWithinEgypt(30.2, 33.2), isTrue);
      expect(
        service.findGovernorate(30.2, 33.2),
        equals('محافظة الجزر التجريبية'),
      );

      expect(service.isWithinEgypt(31.0, 34.0), isFalse);
      expect(service.findGovernorate(31.0, 34.0), isNull);

      expect(service.isWithinEgypt(29.5, 32.0), isFalse);
      expect(service.findGovernorate(29.5, 32.0), isNull);
    });

    test('Strict GeoJSON validation throws FormatException on invalid inputs and structures', () {
      expect(
        () => EgyptBoundaryService.fromJsonString('"invalid"'),
        throwsFormatException,
      );
      expect(
        () => EgyptBoundaryService.fromJsonString('[1, 2, 3]'),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection"}',
        ),
        throwsFormatException,
      );
      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": null}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": ["not-a-map"]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Polygon"}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Point", "coordinates": [30.0, 31.0]}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "MultiPolygon", "coordinates": []}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "MultiPolygon", "coordinates": ["not-a-list"]}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Polygon", "coordinates": []}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Polygon", "coordinates": ["not-a-ring"]}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Polygon", "coordinates": [[[30.0, 30.0], [31.0, 31.0]]]}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Polygon", "coordinates": [[[30.0], [31.0], [32.0]]]}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Polygon", "coordinates": [[["30.0", 30.0], [31.0, 31.0], [30.0, 31.0]]]}}]}',
        ),
        throwsFormatException,
      );

      expect(
        () => EgyptBoundaryService.fromJsonString(
          '{"type": "FeatureCollection", "features": [{"properties": {}, "geometry": {"type": "Polygon", "coordinates": [[[1e999, 30.0], [31.0, 31.0], [30.0, 31.0]]]}}]}',
        ),
        throwsFormatException,
      );
    });

    test('Latitude and longitude parameters are strictly validated and not accidentally reversed', () {
      expect(boundaryService.isWithinEgypt(30.0444, 31.2357), isTrue);
      expect(
        boundaryService.findGovernorate(30.0444, 31.2357),
        equals('القاهرة'),
      );

      final swappedGov = boundaryService.findGovernorate(31.2357, 30.0444);
      expect(swappedGov, isNot(equals('القاهرة')));

      expect(boundaryService.isWithinEgypt(90.1, 31.0), isFalse);
      expect(boundaryService.isWithinEgypt(-90.1, 31.0), isFalse);
      expect(boundaryService.isWithinEgypt(30.0, 180.1), isFalse);
      expect(boundaryService.isWithinEgypt(30.0, -180.1), isFalse);
      expect(boundaryService.findGovernorate(90.1, 31.0), isNull);
      expect(boundaryService.findGovernorate(-90.1, 31.0), isNull);
      expect(boundaryService.findGovernorate(30.0, 180.1), isNull);
      expect(boundaryService.findGovernorate(30.0, -180.1), isNull);
    });
  });

  group('Direct Parser GeoJSON Linear Ring Validation Tests (Task B)', () {
    Map<String, dynamic> createPolygonFixture(List<dynamic> rings) {
      return {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'shapeISO': 'EG-TEST',
              'shapeName': 'Test Governorate',
              'nameAr': 'محافظة اختبار',
            },
            'geometry': {'type': 'Polygon', 'coordinates': rings},
          },
        ],
      };
    }

    Map<String, dynamic> createMultiPolygonFixture(List<dynamic> multiRings) {
      return {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'shapeISO': 'EG-MULTI-TEST',
              'shapeName': 'Test Multi Governorate',
              'nameAr': 'محافظة متعددة اختبار',
            },
            'geometry': {'type': 'MultiPolygon', 'coordinates': multiRings},
          },
        ],
      };
    }

    test('accepts a valid closed ring with three distinct vertices', () {
      final geoJson = createPolygonFixture([
        [
          [30.0, 28.0],
          [31.0, 28.0],
          [31.0, 29.0],
          [30.0, 28.0],
        ],
      ]);

      final service = EgyptBoundaryService.fromJsonString(jsonEncode(geoJson));
      expect(service.governorates.length, equals(1));
      expect(service.governorates.first.nameAr, equals('محافظة اختبار'));
      expect(service.governorates.first.nameEn, equals('Test Governorate'));
      expect(service.isWithinEgypt(28.3, 30.6), isTrue);
      expect(service.findGovernorate(28.3, 30.6), equals('محافظة اختبار'));
    });

    test('rejects a ring with only three coordinate positions', () {
      final geoJson = createPolygonFixture([
        [
          [30.0, 28.0],
          [31.0, 28.0],
          [30.0, 28.0],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects a ring with four positions but fewer than three distinct vertices', () {
      final geoJson = createPolygonFixture([
        [
          [30.0, 28.0],
          [31.0, 28.0],
          [30.0, 28.0],
          [30.0, 28.0],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects a ring with fewer than three distinct vertices when coordinates differ only by zero signs', () {
      final geoJson = createPolygonFixture([
        [
          [-0.0, 0.0],
          [1.0, 0.0],
          [0.0, 0.0],
          [-0.0, 0.0],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects a ring whose first and last positions do not match', () {
      final geoJson = createPolygonFixture([
        [
          [30.0, 28.0],
          [31.0, 28.0],
          [31.0, 29.0],
          [30.0, 29.0],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects longitude below the valid GeoJSON range (-180)', () {
      final geoJson = createPolygonFixture([
        [
          [-180.1, 28.0],
          [31.0, 28.0],
          [31.0, 29.0],
          [-180.1, 28.0],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects longitude above the valid GeoJSON range (180)', () {
      final geoJson = createPolygonFixture([
        [
          [180.1, 28.0],
          [31.0, 28.0],
          [31.0, 29.0],
          [180.1, 28.0],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects latitude below the valid GeoJSON range (-90)', () {
      final geoJson = createPolygonFixture([
        [
          [30.0, -90.1],
          [31.0, 28.0],
          [31.0, 29.0],
          [30.0, -90.1],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects latitude above the valid GeoJSON range (90)', () {
      final geoJson = createPolygonFixture([
        [
          [30.0, 90.1],
          [31.0, 28.0],
          [31.0, 29.0],
          [30.0, 90.1],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects a ring containing NaN coordinate', () {
      final geoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'shapeISO': 'EG-TEST',
              'shapeName': 'Test',
              'nameAr': 'اختبار',
            },
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  ['NaN', 28.0],
                  [31.0, 28.0],
                  [31.0, 29.0],
                  ['NaN', 28.0],
                ],
              ],
            },
          },
        ],
      };
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects a ring containing Infinite coordinate', () {
      final rawJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"shapeISO": "EG-TEST", "shapeName": "Test", "nameAr": "اختبار"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [1e999, 28.0],
            [31.0, 28.0],
            [31.0, 29.0],
            [1e999, 28.0]
          ]
        ]
      }
    }
  ]
}''';
      expect(
        () => EgyptBoundaryService.fromJsonString(rawJson),
        throwsFormatException,
      );
    });

    test('rejects an invalid Polygon exterior ring', () {
      final geoJson = createPolygonFixture(['not-a-list-of-positions']);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects an invalid Polygon interior ring', () {
      final geoJson = createPolygonFixture([
        [
          [30.0, 28.0],
          [34.0, 28.0],
          [34.0, 32.0],
          [30.0, 32.0],
          [30.0, 28.0],
        ],
        [
          [31.0, 29.0],
          [33.0, 29.0],
          [33.0, 31.0],
          [31.0, 31.0],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });

    test('rejects an invalid ring inside a MultiPolygon component', () {
      final geoJson = createMultiPolygonFixture([
        [
          [
            [30.0, 28.0],
            [31.0, 28.0],
            [31.0, 29.0],
            [30.0, 28.0],
          ],
        ],
        [
          [
            [33.0, 30.0],
            [34.0, 30.0],
            [33.0, 30.0],
            [33.0, 30.0],
          ],
        ],
      ]);
      expect(
        () => EgyptBoundaryService.fromJsonString(jsonEncode(geoJson)),
        throwsFormatException,
      );
    });
  });
}
