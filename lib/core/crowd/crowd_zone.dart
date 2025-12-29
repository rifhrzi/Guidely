/// Represents a zone where crowd density is tracked.
class CrowdZone {
  const CrowdZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.beaconIds = const [],
    this.currentDensity = 0,
    this.updatedAt,
  });

  /// Unique identifier.
  final String id;

  /// Display name of the zone.
  final String name;

  /// Center latitude.
  final double lat;

  /// Center longitude.
  final double lng;

  /// Radius of the zone in meters.
  final double radiusMeters;

  /// List of beacon IDs associated with this zone.
  final List<String> beaconIds;

  /// Current crowd density (0-100).
  /// 0 = empty, 100 = very crowded.
  final int currentDensity;

  /// When the density was last updated.
  final DateTime? updatedAt;

  /// Get density level as an enum.
  CrowdLevel get level {
    if (currentDensity < 20) return CrowdLevel.empty;
    if (currentDensity < 40) return CrowdLevel.low;
    if (currentDensity < 60) return CrowdLevel.moderate;
    if (currentDensity < 80) return CrowdLevel.high;
    return CrowdLevel.veryHigh;
  }

  /// Create from Firebase/JSON data.
  factory CrowdZone.fromJson(Map<String, dynamic> json) {
    return CrowdZone(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 20.0,
      beaconIds: (json['beacon_ids'] as List?)?.cast<String>() ?? [],
      currentDensity: (json['current_density'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['updated_at'] is int
                  ? json['updated_at'] as int
                  : (json['updated_at'] as num).toInt(),
            )
          : null,
    );
  }

  /// Create from Firestore document.
  factory CrowdZone.fromFirestore(String docId, Map<String, dynamic> data) {
    return CrowdZone(
      id: docId,
      name: data['name'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (data['radius_meters'] as num?)?.toDouble() ?? 20.0,
      beaconIds: (data['beacon_ids'] as List?)?.cast<String>() ?? [],
      currentDensity: (data['current_density'] as num?)?.toInt() ?? 0,
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as dynamic).toDate()
          : null,
    );
  }

  /// Convert to JSON/Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius_meters': radiusMeters,
      'beacon_ids': beaconIds,
      'current_density': currentDensity,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Copy with new values.
  CrowdZone copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    double? radiusMeters,
    List<String>? beaconIds,
    int? currentDensity,
    DateTime? updatedAt,
  }) {
    return CrowdZone(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      beaconIds: beaconIds ?? this.beaconIds,
      currentDensity: currentDensity ?? this.currentDensity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'CrowdZone{id: $id, name: $name, density: $currentDensity}';
}

/// Crowd density levels.
enum CrowdLevel {
  empty(0, 'Sepi', 'Area ini kosong atau sangat sepi'),
  low(1, 'Sedikit', 'Beberapa orang di area ini'),
  moderate(2, 'Sedang', 'Cukup ramai'),
  high(3, 'Ramai', 'Area ini ramai'),
  veryHigh(4, 'Sangat Ramai', 'Area ini sangat padat');

  const CrowdLevel(this.value, this.displayName, this.description);

  final int value;
  final String displayName;
  final String description;
}

