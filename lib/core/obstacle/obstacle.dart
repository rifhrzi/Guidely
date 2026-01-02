/// Types of obstacles that can be reported.
enum ObstacleType {
  /// Construction or road work.
  construction('construction', 'Konstruksi'),

  /// Flooding or water accumulation.
  flooding('flooding', 'Genangan Air'),

  /// Campus event blocking the path.
  event('event', 'Acara Kampus'),

  /// Path is officially closed.
  closedPath('closed_path', 'Jalur Ditutup'),

  /// Fallen tree or debris.
  debris('debris', 'Rintangan/Puing'),

  /// General temporary obstacle.
  temporary('temporary', 'Hambatan Sementara');

  const ObstacleType(this.code, this.displayName);

  /// Code used for storage/serialization.
  final String code;

  /// Human-readable display name in Indonesian.
  final String displayName;

  /// Get ObstacleType from code string.
  static ObstacleType fromCode(String code) {
    return ObstacleType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => ObstacleType.temporary,
    );
  }
}

/// Radius in meters for considering obstacles as duplicates.
/// Reports within this distance are consolidated into one obstacle.
const double duplicateReportRadiusMeters = 5.0;

/// Represents an obstacle or temporary barrier on the campus.
class Obstacle {
  const Obstacle({
    required this.id,
    required this.name,
    required this.description,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.type,
    required this.reportedAt,
    this.expiresAt,
    this.isActive = true,
    this.reportedBy,
    this.reportCount = 1,
  });

  /// Unique identifier.
  final String id;

  /// Short name/title of the obstacle.
  final String name;

  /// Detailed description of the obstacle.
  final String description;

  /// Latitude coordinate.
  final double lat;

  /// Longitude coordinate.
  final double lng;

  /// Radius of effect in meters.
  final double radiusMeters;

  /// Type of obstacle.
  final ObstacleType type;

  /// When the obstacle was reported.
  final DateTime reportedAt;

  /// When the obstacle is expected to expire/be removed.
  /// Null means indefinite.
  final DateTime? expiresAt;

  /// Whether the obstacle is currently active.
  final bool isActive;

  /// Who reported this obstacle (optional).
  final String? reportedBy;

  /// Number of times this obstacle has been reported.
  /// Multiple reports at the same location increment this count
  /// instead of creating duplicate obstacles.
  final int reportCount;

  /// Whether the obstacle has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether the obstacle should be shown (active and not expired).
  bool get shouldShow => isActive && !isExpired;

  /// Create from JSON/Map (for Firebase/API).
  factory Obstacle.fromJson(Map<String, dynamic> json) {
    return Obstacle(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 5.0,
      type: ObstacleType.fromCode(json['type'] as String? ?? 'temporary'),
      reportedAt: json['reported_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['reported_at'] is int
                  ? json['reported_at'] as int
                  : (json['reported_at'] as num).toInt(),
            )
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['expires_at'] is int
                  ? json['expires_at'] as int
                  : (json['expires_at'] as num).toInt(),
            )
          : null,
      isActive: json['is_active'] as bool? ?? true,
      reportedBy: json['reported_by'] as String?,
      reportCount: (json['report_count'] as num?)?.toInt() ?? 1,
    );
  }

  /// Create from Firestore document.
  factory Obstacle.fromFirestore(String docId, Map<String, dynamic> data) {
    return Obstacle(
      id: docId,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (data['radius_meters'] as num?)?.toDouble() ?? 5.0,
      type: ObstacleType.fromCode(data['type'] as String? ?? 'temporary'),
      reportedAt: data['created_at'] != null
          ? (data['created_at'] as dynamic).toDate()
          : DateTime.now(),
      expiresAt: data['expires_at'] != null
          ? (data['expires_at'] as dynamic).toDate()
          : null,
      isActive: data['is_active'] as bool? ?? true,
      reportedBy: data['reported_by'] as String?,
      reportCount: (data['report_count'] as num?)?.toInt() ?? 1,
    );
  }

  /// Convert to JSON/Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'lat': lat,
      'lng': lng,
      'radius_meters': radiusMeters,
      'type': type.code,
      'reported_at': reportedAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'is_active': isActive,
      'reported_by': reportedBy,
      'report_count': reportCount,
    };
  }

  /// Copy with new values.
  Obstacle copyWith({
    String? id,
    String? name,
    String? description,
    double? lat,
    double? lng,
    double? radiusMeters,
    ObstacleType? type,
    DateTime? reportedAt,
    DateTime? expiresAt,
    bool? isActive,
    String? reportedBy,
    int? reportCount,
  }) {
    return Obstacle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      type: type ?? this.type,
      reportedAt: reportedAt ?? this.reportedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      reportedBy: reportedBy ?? this.reportedBy,
      reportCount: reportCount ?? this.reportCount,
    );
  }

  @override
  String toString() {
    return 'Obstacle{id: $id, name: $name, type: ${type.code}, '
        'lat: $lat, lng: $lng, radius: $radiusMeters}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Obstacle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Whether this obstacle has multiple reports (same location reported by
  /// multiple users).
  bool get hasMultipleReports => reportCount > 1;
}
