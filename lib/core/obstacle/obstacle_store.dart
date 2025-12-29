import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../logging/logger.dart';
import '../types/geo.dart';
import 'obstacle.dart';

/// Local SQLite storage for obstacles.
///
/// This store persists obstacles locally so they can be accessed
/// in offline mode. Data is synced from Firebase when online.
class ObstacleStore {
  ObstacleStore._(this._db);

  final sqlite.Database _db;
  static ObstacleStore? _instance;

  /// Open or create the obstacle database.
  static Future<ObstacleStore> open() async {
    if (_instance != null) return _instance!;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/obstacles.db';
      logInfo('Opening obstacle database at $dbPath');

      final db = sqlite.sqlite3.open(dbPath);
      final store = ObstacleStore._(db);
      store._initTable();
      _instance = store;
      return store;
    } catch (e, stackTrace) {
      logError('Failed to open obstacle database', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Initialize the database table.
  void _initTable() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS obstacles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radius_meters REAL DEFAULT 5.0,
        type TEXT NOT NULL,
        reported_at INTEGER NOT NULL,
        expires_at INTEGER,
        is_active INTEGER DEFAULT 1,
        reported_by TEXT,
        synced_at INTEGER
      )
    ''');

    // Create spatial index for faster proximity queries
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_obstacles_location ON obstacles (lat, lng)
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_obstacles_active ON obstacles (is_active)
    ''');

    logDebug('Obstacle table initialized');
  }

  /// Insert or update an obstacle.
  void upsert(Obstacle obstacle) {
    try {
      _db.execute('''
        INSERT OR REPLACE INTO obstacles 
        (id, name, description, lat, lng, radius_meters, type, 
         reported_at, expires_at, is_active, reported_by, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        obstacle.id,
        obstacle.name,
        obstacle.description,
        obstacle.lat,
        obstacle.lng,
        obstacle.radiusMeters,
        obstacle.type.code,
        obstacle.reportedAt.millisecondsSinceEpoch,
        obstacle.expiresAt?.millisecondsSinceEpoch,
        obstacle.isActive ? 1 : 0,
        obstacle.reportedBy,
        DateTime.now().millisecondsSinceEpoch,
      ]);
      logDebug('Upserted obstacle: ${obstacle.id}');
    } catch (e, stackTrace) {
      logError('Failed to upsert obstacle: ${obstacle.id}',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Insert or update multiple obstacles (batch operation).
  void upsertAll(List<Obstacle> obstacles) {
    if (obstacles.isEmpty) return;

    try {
      _db.execute('BEGIN TRANSACTION');
      for (final obstacle in obstacles) {
        _db.execute('''
          INSERT OR REPLACE INTO obstacles 
          (id, name, description, lat, lng, radius_meters, type, 
           reported_at, expires_at, is_active, reported_by, synced_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          obstacle.id,
          obstacle.name,
          obstacle.description,
          obstacle.lat,
          obstacle.lng,
          obstacle.radiusMeters,
          obstacle.type.code,
          obstacle.reportedAt.millisecondsSinceEpoch,
          obstacle.expiresAt?.millisecondsSinceEpoch,
          obstacle.isActive ? 1 : 0,
          obstacle.reportedBy,
          DateTime.now().millisecondsSinceEpoch,
        ]);
      }
      _db.execute('COMMIT');
      logInfo('Batch upserted ${obstacles.length} obstacles');
    } catch (e, stackTrace) {
      _db.execute('ROLLBACK');
      logError('Failed to batch upsert obstacles', error: e, stackTrace: stackTrace);
    }
  }

  /// Delete an obstacle by ID.
  void delete(String id) {
    try {
      _db.execute('DELETE FROM obstacles WHERE id = ?', [id]);
      logDebug('Deleted obstacle: $id');
    } catch (e, stackTrace) {
      logError('Failed to delete obstacle: $id', error: e, stackTrace: stackTrace);
    }
  }

  /// Delete all obstacles (useful for full sync).
  void deleteAll() {
    try {
      _db.execute('DELETE FROM obstacles');
      logInfo('Deleted all obstacles');
    } catch (e, stackTrace) {
      logError('Failed to delete all obstacles', error: e, stackTrace: stackTrace);
    }
  }

  /// Get all active obstacles.
  List<Obstacle> getActiveObstacles() {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = _db.select('''
        SELECT * FROM obstacles 
        WHERE is_active = 1 
        AND (expires_at IS NULL OR expires_at > ?)
        ORDER BY reported_at DESC
      ''', [now]);
      return result.map(_rowToObstacle).toList();
    } catch (e, stackTrace) {
      logError('Failed to get active obstacles', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get all obstacles (including inactive/expired).
  List<Obstacle> getAllObstacles() {
    try {
      final result = _db.select('''
        SELECT * FROM obstacles ORDER BY reported_at DESC
      ''');
      return result.map(_rowToObstacle).toList();
    } catch (e, stackTrace) {
      logError('Failed to get all obstacles', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get obstacles within a certain radius of a point.
  ///
  /// [lat] and [lng] are the center coordinates.
  /// [radiusMeters] is the search radius in meters.
  List<Obstacle> getObstaclesNearby(double lat, double lng, double radiusMeters) {
    // Convert radius to approximate degree delta for bounding box
    // 1 degree ≈ 111km at equator
    final radiusKm = radiusMeters / 1000.0;
    final delta = radiusKm / 111.0;

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // First filter by bounding box (fast)
      final result = _db.select('''
        SELECT * FROM obstacles
        WHERE is_active = 1
        AND (expires_at IS NULL OR expires_at > ?)
        AND lat BETWEEN ? AND ?
        AND lng BETWEEN ? AND ?
      ''', [
        now,
        lat - delta,
        lat + delta,
        lng - delta,
        lng + delta,
      ]);

      // Then filter by actual distance (accurate)
      final center = LatLng(lat, lng);
      return result.map(_rowToObstacle).where((obstacle) {
        final obstaclePos = LatLng(obstacle.lat, obstacle.lng);
        final distance = haversineMeters(center, obstaclePos);
        return distance <= radiusMeters + obstacle.radiusMeters;
      }).toList();
    } catch (e, stackTrace) {
      logError('Failed to get nearby obstacles', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get obstacle by ID.
  Obstacle? getById(String id) {
    try {
      final result = _db.select(
        'SELECT * FROM obstacles WHERE id = ? LIMIT 1',
        [id],
      );
      if (result.isEmpty) return null;
      return _rowToObstacle(result.first);
    } catch (e, stackTrace) {
      logError('Failed to get obstacle by id: $id', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Check if any obstacles exist in the database.
  bool hasObstacles() {
    try {
      final result = _db.select('SELECT COUNT(*) as count FROM obstacles');
      return (result.first['count'] as int) > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get count of active obstacles.
  int getActiveCount() {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = _db.select('''
        SELECT COUNT(*) as count FROM obstacles 
        WHERE is_active = 1 
        AND (expires_at IS NULL OR expires_at > ?)
      ''', [now]);
      return result.first['count'] as int;
    } catch (e) {
      return 0;
    }
  }

  /// Get last sync timestamp.
  DateTime? getLastSyncTime() {
    try {
      final result = _db.select('''
        SELECT MAX(synced_at) as last_sync FROM obstacles
      ''');
      final lastSync = result.first['last_sync'];
      if (lastSync == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(lastSync as int);
    } catch (e) {
      return null;
    }
  }

  /// Convert a database row to an Obstacle object.
  Obstacle _rowToObstacle(sqlite.Row row) {
    return Obstacle(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      lat: row['lat'] as double,
      lng: row['lng'] as double,
      radiusMeters: row['radius_meters'] as double? ?? 5.0,
      type: ObstacleType.fromCode(row['type'] as String),
      reportedAt: DateTime.fromMillisecondsSinceEpoch(row['reported_at'] as int),
      expiresAt: row['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int)
          : null,
      isActive: (row['is_active'] as int) == 1,
      reportedBy: row['reported_by'] as String?,
    );
  }

  /// Close the database connection.
  void close() {
    try {
      _db.dispose();
      _instance = null;
      logDebug('Obstacle database closed');
    } catch (e) {
      logWarn('Error closing obstacle database: $e');
    }
  }
}

