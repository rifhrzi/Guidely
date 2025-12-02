import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../logging/logger.dart';

class Landmark {
  final String id;
  final String name;
  final String type; // e.g., library, class, prayer, poi
  final double lat;
  final double lng;
  const Landmark({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) => Landmark(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
  );
}

class LandmarkStore {
  final List<Landmark> items;
  const LandmarkStore(this.items);

  static Future<LandmarkStore> loadFromAssets([
    String path = 'assets/data/landmarks.json',
  ]) async {
    final raw = await rootBundle.loadString(path);
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final baseLandmarks = list.map(Landmark.fromJson).toList();
    final poiLandmarks = await _loadPoiLandmarks();

    final mergedByName = <String, Landmark>{};
    for (final landmark in baseLandmarks) {
      final key = _normalizeName(landmark.name);
      mergedByName.putIfAbsent(key, () => landmark);
    }
    for (final poi in poiLandmarks) {
      final key = _normalizeName(poi.name);
      mergedByName[key] = poi; // Prefer POI over base landmark
    }

    final merged = mergedByName.values.toList();
    logInfo(
      'Loaded ${merged.length} landmarks (base=${baseLandmarks.length}, poi=${poiLandmarks.length})',
    );
    return LandmarkStore(merged);
  }
}

Future<List<Landmark>> _loadPoiLandmarks() async {
  try {
    final raw = await rootBundle.loadString('assets/data/poi_fkip.geojson');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final features =
        (map['features'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final result = <Landmark>[];
    for (final feature in features) {
      final props =
          (feature['properties'] as Map<String, dynamic>?) ?? const {};
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      final coords = (geometry?['coordinates'] as List?)?.cast<num>();
      if (coords == null || coords.length < 2) {
        logWarn('Skipping POI with invalid coordinates: $feature');
        continue;
      }
      final name = (props['nama'] ?? props['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        logWarn('Skipping POI with missing name: $feature');
        continue;
      }
      final id = _poiIdForName(name, props['id']);
      final type =
          (props['kategori'] ?? props['tipe'] ?? props['type'] ?? 'poi')
              .toString();
      result.add(
        Landmark(
          id: id,
          name: name,
          type: type,
          lat: coords[1].toDouble(),
          lng: coords[0].toDouble(),
        ),
      );
    }
    return result;
  } catch (error, stackTrace) {
    logWarn('Failed to load POI landmarks: $error', stackTrace: stackTrace);
    return const [];
  }
}

String _poiIdForName(String name, Object? rawId) {
  if (rawId is String && rawId.trim().isNotEmpty) {
    return 'poi_${rawId.trim()}';
  }
  final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final collapsed = normalized.replaceAll(RegExp('_+'), '_');
  final trimmed = collapsed.replaceAll(RegExp(r'^_|_$'), '');
  return 'poi_$trimmed';
}

String _normalizeName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
