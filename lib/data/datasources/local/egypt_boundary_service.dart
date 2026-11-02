import 'dart:convert';

import 'package:flutter/services.dart';

/// Lightweight representation of a polygon with exterior and interior rings.
class GeoPolygon {
  final List<List<double>> exterior; // [lon, lat]
  final List<List<List<double>>> holes;
  final double minLon;
  final double maxLon;
  final double minLat;
  final double maxLat;

  GeoPolygon({
    required this.exterior,
    required this.holes,
    required this.minLon,
    required this.maxLon,
    required this.minLat,
    required this.maxLat,
  });

  factory GeoPolygon.fromRings(List<dynamic> rings) {
    if (rings.isEmpty) {
      throw const FormatException('Empty polygon rings');
    }

    final exterior = (rings[0] as List).map<List<double>>((pt) {
      final p = pt as List;
      return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
    }).toList();

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final p in exterior) {
      if (p[0] < minX) minX = p[0];
      if (p[0] > maxX) maxX = p[0];
      if (p[1] < minY) minY = p[1];
      if (p[1] > maxY) maxY = p[1];
    }

    final holes = <List<List<double>>>[];
    for (int i = 1; i < rings.length; i++) {
      final hole = (rings[i] as List).map<List<double>>((pt) {
        final p = pt as List;
        return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
      }).toList();
      holes.add(hole);
    }

    return GeoPolygon(
      exterior: exterior,
      holes: holes,
      minLon: minX,
      maxLon: maxX,
      minLat: minY,
      maxLat: maxY,
    );
  }

  bool contains(double lon, double lat) {
    // Fast bounding box rejection
    if (lon < minLon || lon > maxLon || lat < minLat || lat > maxLat) {
      return false;
    }
    // Check exterior ring using ray-casting
    if (!_pointInRing(lon, lat, exterior)) {
      return false;
    }
    // Check holes: if point is inside any hole, it is outside polygon
    for (final hole in holes) {
      if (_pointInRing(lon, lat, hole)) {
        return false;
      }
    }
    return true;
  }

  static bool _pointInRing(double x, double y, List<List<double>> ring) {
    bool inside = false;
    final n = ring.length;
    if (n < 3) return false;

    double p1x = ring[0][0];
    double p1y = ring[0][1];

    for (int i = 1; i <= n; i++) {
      final p2x = ring[i % n][0];
      final p2y = ring[i % n][1];

      if ((p1y < y && p2y >= y) || (p2y < y && p1y >= y)) {
        if (p1x + (y - p1y) / (p2y - p1y) * (p2x - p1x) >= x) {
          inside = !inside;
        }
      }
      p1x = p2x;
      p1y = p2y;
    }
    return inside;
  }
}

/// An Egyptian administrative governorate entity with multi-polygon boundaries.
class GovernorateFeature {
  final String isoCode;
  final String nameEn;
  final String nameAr;
  final List<GeoPolygon> polygons;

  const GovernorateFeature({
    required this.isoCode,
    required this.nameEn,
    required this.nameAr,
    required this.polygons,
  });

  bool contains(double lon, double lat) {
    for (final poly in polygons) {
      if (poly.contains(lon, lat)) {
        return true;
      }
    }
    return false;
  }
}

/// Service that parses Egyptian administrative boundary GeoJSON and provides
/// verified point-in-polygon country validation and governorate lookup.
class EgyptBoundaryService {
  static const String assetPath = 'assets/geo/egypt_governorates.geojson';

  final List<GovernorateFeature> _governorates;

  EgyptBoundaryService._(this._governorates);

  List<GovernorateFeature> get governorates => List.unmodifiable(_governorates);

  /// Loads and parses the bundled Egypt boundary GeoJSON from assets.
  static Future<EgyptBoundaryService> loadFromBundle({
    AssetBundle? bundle,
    String path = assetPath,
  }) async {
    final effectiveBundle = bundle ?? rootBundle;
    final jsonStr = await effectiveBundle.loadString(path);
    return fromJsonString(jsonStr);
  }

  /// Parses GeoJSON string into EgyptBoundaryService.
  static EgyptBoundaryService fromJsonString(String jsonStr) {
    final dynamic decoded = json.decode(jsonStr);
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'FeatureCollection') {
      throw const FormatException('Invalid GeoJSON FeatureCollection');
    }

    final featuresRaw = decoded['features'];
    if (featuresRaw is! List) {
      throw const FormatException(
        'GeoJSON FeatureCollection missing features list',
      );
    }

    final list = <GovernorateFeature>[];

    for (final f in featuresRaw) {
      if (f is! Map<String, dynamic>) continue;
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final geom = f['geometry'] as Map<String, dynamic>? ?? {};

      final iso = props['shapeISO'] as String? ?? '';
      final nameEn = props['shapeName'] as String? ?? '';
      final nameAr = props['nameAr'] as String? ?? nameEn;
      final geomType = geom['type'] as String? ?? '';
      final coordinates = geom['coordinates'] as List? ?? [];

      final polys = <GeoPolygon>[];

      if (geomType == 'Polygon') {
        polys.add(GeoPolygon.fromRings(coordinates));
      } else if (geomType == 'MultiPolygon') {
        for (final p in coordinates) {
          polys.add(GeoPolygon.fromRings(p as List));
        }
      }

      list.add(
        GovernorateFeature(
          isoCode: iso,
          nameEn: nameEn,
          nameAr: nameAr,
          polygons: polys,
        ),
      );
    }

    return EgyptBoundaryService._(list);
  }

  /// Checks if coordinate is strictly inside Egypt's national polygon boundary.
  bool isWithinEgypt(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    for (final gov in _governorates) {
      if (gov.contains(longitude, latitude)) {
        return true;
      }
    }
    return false;
  }

  /// Finds the Egyptian governorate containing the coordinate.
  /// Returns Arabic governorate name or null if outside Egypt.
  /// In ambiguous border overlaps, returns the first matching governorate.
  String? findGovernorate(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return null;
    for (final gov in _governorates) {
      if (gov.contains(longitude, latitude)) {
        return gov.nameAr;
      }
    }
    return null;
  }
}
