import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../logging/logger.dart';

class CampusBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const CampusBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  bool contains(ll.LatLng value) {
    return value.latitude >= minLat &&
        value.latitude <= maxLat &&
        value.longitude >= minLng &&
        value.longitude <= maxLng;
  }

  ll.LatLng clamp(ll.LatLng value) {
    final lat = value.latitude.clamp(minLat, maxLat);
    final lng = value.longitude.clamp(minLng, maxLng);
    return ll.LatLng(lat, lng);
  }
}

class GeoJsonLoadException implements Exception {
  const GeoJsonLoadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'GeoJsonLoadException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

class CampusGeoJson {
  final List<Polygon> buildings;
  final List<Polyline> walkways;
  final List<Marker> pointsOfInterest;
  final ll.LatLng center;
  final CampusBounds bounds;

  const CampusGeoJson({
    required this.buildings,
    required this.walkways,
    required this.pointsOfInterest,
    required this.center,
    required this.bounds,
  });
}

/// Singleton cache for GeoJSON data to avoid repeated loading
CampusGeoJson? _cachedGeoJson;
Future<CampusGeoJson>? _loadingFuture;

/// Clear the cached GeoJSON data (useful for testing or hot reload)
void clearGeoJsonCache() {
  _cachedGeoJson = null;
  _loadingFuture = null;
}

Future<CampusGeoJson> loadCampusGeoJson() async {
  // Return cached data if available
  if (_cachedGeoJson != null) {
    return _cachedGeoJson!;
  }
  
  // If already loading, wait for the existing future
  if (_loadingFuture != null) {
    return _loadingFuture!;
  }
  
  // Start loading and cache the future to prevent duplicate loads
  _loadingFuture = _loadCampusGeoJsonInternal();
  try {
    _cachedGeoJson = await _loadingFuture;
    return _cachedGeoJson!;
  } finally {
    _loadingFuture = null;
  }
}

Future<CampusGeoJson> _loadCampusGeoJsonInternal() async {
  final accumulator = _BoundsAccumulator();
  try {
    final buildings = await _loadPolygons(
      assetPath: 'assets/data/gedung_fkip.geojson',
      fillColor: const Color(0x553F51B5),
      borderColor: const Color(0xFF3F51B5),
      bounds: accumulator,
    );

    final walkways = await _loadPolylines(
      assetPath: 'assets/data/jalan_fkip.geojson',
      color: const Color(0xFF546E7A),
      strokeWidth: 4,
      bounds: accumulator,
    );

    final pois = await _loadMarkers(
      assetPath: 'assets/data/poi_fkip.geojson',
      bounds: accumulator,
    );

    final center = accumulator.center ?? const ll.LatLng(-6.200000, 106.816666);
    final campusBounds = accumulator.toBounds(center);

    logInfo(
      'Loaded campus overlays: buildings=${buildings.length} walkways=${walkways.length} pois=${pois.length}',
    );

    return CampusGeoJson(
      buildings: buildings,
      walkways: walkways,
      pointsOfInterest: pois,
      center: center,
      bounds: campusBounds,
    );
  } catch (error, stackTrace) {
    logError(
      'Failed to load campus GeoJSON overlays',
      error: error,
      stackTrace: stackTrace,
    );
    if (error is GeoJsonLoadException) {
      rethrow;
    }
    throw GeoJsonLoadException('Unable to load campus overlays', error);
  }
}

Future<List<Polygon>> _loadPolygons({
  required String assetPath,
  required Color fillColor,
  required Color borderColor,
  required _BoundsAccumulator bounds,
}) async {
  final collection = await _loadCollection(assetPath);
  final polygons = <Polygon>[];
  for (final feature in collection.features) {
    if (feature == null) continue;
    final geometry = feature.geometry;
    if (geometry == null) continue;
    final label = feature.properties?['nama']?.toString();
    switch (geometry.type) {
      case GeoJSONType.polygon:
        polygons.add(
          _polygonFromCoords(
            (geometry as GeoJSONPolygon).coordinates,
            fillColor,
            borderColor,
            bounds,
            label,
          ),
        );
        break;
      case GeoJSONType.multiPolygon:
        final multi = geometry as GeoJSONMultiPolygon;
        for (final coords in multi.coordinates) {
          polygons.add(
            _polygonFromCoords(coords, fillColor, borderColor, bounds, label),
          );
        }
        break;
      default:
        break;
    }
  }
  return polygons;
}

Future<List<Polyline>> _loadPolylines({
  required String assetPath,
  required Color color,
  required double strokeWidth,
  required _BoundsAccumulator bounds,
}) async {
  final collection = await _loadCollection(assetPath);
  final polylines = <Polyline>[];
  for (final feature in collection.features) {
    if (feature == null) continue;
    final geometry = feature.geometry;
    if (geometry == null) continue;
    switch (geometry.type) {
      case GeoJSONType.lineString:
        polylines.add(
          _polylineFromCoords(
            [(geometry as GeoJSONLineString).coordinates],
            color,
            strokeWidth,
            bounds,
          ),
        );
        break;
      case GeoJSONType.multiLineString:
        final multi = geometry as GeoJSONMultiLineString;
        polylines.add(
          _polylineFromCoords(multi.coordinates, color, strokeWidth, bounds),
        );
        break;
      default:
        break;
    }
  }
  return polylines;
}

Future<List<Marker>> _loadMarkers({
  required String assetPath,
  required _BoundsAccumulator bounds,
}) async {
  final collection = await _loadCollection(assetPath);
  final markers = <Marker>[];
  for (final feature in collection.features) {
    if (feature == null) continue;
    final geometry = feature.geometry;
    if (geometry == null) continue;
    final name = feature.properties?['nama']?.toString();
    switch (geometry.type) {
      case GeoJSONType.point:
        final point = geometry as GeoJSONPoint;
        final coords = point.coordinates;
        if (coords.length >= 2) {
          final latLng = ll.LatLng(coords[1], coords[0]);
          bounds.include(latLng);
          markers.add(
            Marker(
              point: latLng,
              width: 80,
              height: 80,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 32,
                    color: Color(0xFFD32F2F),
                  ),
                  if (name != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        break;
      default:
        break;
    }
  }
  return markers;
}

Polygon _polygonFromCoords(
  List<List<List<double>>> coords,
  Color fillColor,
  Color borderColor,
  _BoundsAccumulator bounds,
  String? label,
) {
  final outerRing = _ringToLatLngs(coords.first, bounds);
  final holes = <List<ll.LatLng>>[];
  if (coords.length > 1) {
    for (var i = 1; i < coords.length; i++) {
      holes.add(_ringToLatLngs(coords[i], bounds));
    }
  }
  return Polygon(
    points: outerRing,
    holePointsList: holes.isEmpty ? null : holes,
    color: fillColor,
    borderStrokeWidth: 1.5,
    borderColor: borderColor,
    label: label,
    labelStyle: const TextStyle(
      fontSize: 12,
      color: Color(0xFF1A237E),
      fontWeight: FontWeight.w600,
    ),
  );
}

Polyline _polylineFromCoords(
  List<List<List<double>>> segments,
  Color color,
  double strokeWidth,
  _BoundsAccumulator bounds,
) {
  final points = <ll.LatLng>[];
  for (final segment in segments) {
    for (final coord in segment) {
      if (coord.length < 2) continue;
      final latLng = ll.LatLng(coord[1], coord[0]);
      bounds.include(latLng);
      points.add(latLng);
    }
  }
  return Polyline(points: points, strokeWidth: strokeWidth, color: color);
}

List<ll.LatLng> _ringToLatLngs(
  List<List<double>> ring,
  _BoundsAccumulator bounds,
) {
  final result = <ll.LatLng>[];
  for (final coord in ring) {
    if (coord.length < 2) continue;
    final latLng = ll.LatLng(coord[1], coord[0]);
    bounds.include(latLng);
    result.add(latLng);
  }
  if (result.length > 1) {
    final first = result.first;
    final last = result.last;
    if ((first.latitude - last.latitude).abs() < 1e-9 &&
        (first.longitude - last.longitude).abs() < 1e-9) {
      result.removeLast();
    }
  }
  return result;
}

Future<GeoJSONFeatureCollection> _loadCollection(String assetPath) async {
  try {
    final data = await rootBundle.loadString(assetPath);
    final map = jsonDecode(data) as Map<String, dynamic>;
    return GeoJSONFeatureCollection.fromMap(map);
  } on FlutterError catch (error, stackTrace) {
    logError(
      'GeoJSON asset not found: $assetPath',
      error: error,
      stackTrace: stackTrace,
    );
    throw GeoJsonLoadException('GeoJSON asset not found: $assetPath', error);
  } on FormatException catch (error, stackTrace) {
    logError(
      'GeoJSON asset is malformed: $assetPath',
      error: error,
      stackTrace: stackTrace,
    );
    throw GeoJsonLoadException('GeoJSON asset is malformed: $assetPath', error);
  } catch (error, stackTrace) {
    logError(
      'Unexpected error loading GeoJSON: $assetPath',
      error: error,
      stackTrace: stackTrace,
    );
    throw GeoJsonLoadException(
      'Unexpected error loading GeoJSON: $assetPath',
      error,
    );
  }
}

class _BoundsAccumulator {
  double? _minLat;
  double? _maxLat;
  double? _minLng;
  double? _maxLng;

  void include(ll.LatLng point) {
    _minLat = _minLat == null
        ? point.latitude
        : math.min(_minLat!, point.latitude);
    _maxLat = _maxLat == null
        ? point.latitude
        : math.max(_maxLat!, point.latitude);
    _minLng = _minLng == null
        ? point.longitude
        : math.min(_minLng!, point.longitude);
    _maxLng = _maxLng == null
        ? point.longitude
        : math.max(_maxLng!, point.longitude);
  }

  ll.LatLng? get center {
    if (_minLat == null ||
        _maxLat == null ||
        _minLng == null ||
        _maxLng == null) {
      return null;
    }
    return ll.LatLng((_minLat! + _maxLat!) / 2, (_minLng! + _maxLng!) / 2);
  }

  CampusBounds toBounds(ll.LatLng fallback) {
    if (_minLat == null ||
        _maxLat == null ||
        _minLng == null ||
        _maxLng == null) {
      return CampusBounds(
        minLat: fallback.latitude,
        maxLat: fallback.latitude,
        minLng: fallback.longitude,
        maxLng: fallback.longitude,
      );
    }
    return CampusBounds(
      minLat: _minLat!,
      maxLat: _maxLat!,
      minLng: _minLng!,
      maxLng: _maxLng!,
    );
  }
}
