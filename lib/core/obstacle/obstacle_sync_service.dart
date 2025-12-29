import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../logging/logger.dart';
import '../network/connectivity_service.dart';
import 'obstacle.dart';
import 'obstacle_store.dart';

/// Service to synchronize obstacles between Firebase and local storage.
///
/// This service handles:
/// - Downloading obstacles from Firebase to local SQLite
/// - Real-time listening for obstacle updates
/// - Uploading user-reported obstacles (when online)
class ObstacleSyncService {
  ObstacleSyncService({
    required this.store,
    required this.connectivity,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final ObstacleStore store;
  final ConnectivityService connectivity;
  final FirebaseFirestore _firestore;

  StreamSubscription<QuerySnapshot>? _obstacleSubscription;
  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Collection reference for obstacles.
  CollectionReference<Map<String, dynamic>> get _obstaclesRef =>
      _firestore.collection('obstacles');

  /// Whether sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Initialize the sync service.
  ///
  /// If online, starts listening for real-time updates.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen for connectivity changes
    connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        _onConnected();
      } else {
        _onDisconnected();
      }
    });

    // Initial sync if online
    if (connectivity.isOnline) {
      await syncFromFirebase();
      _startRealtimeSync();
    }
  }

  void _onConnected() {
    logInfo('ObstacleSyncService: Connected, starting sync');
    syncFromFirebase();
    _startRealtimeSync();
  }

  void _onDisconnected() {
    logInfo('ObstacleSyncService: Disconnected, stopping real-time sync');
    _stopRealtimeSync();
  }

  /// Perform a full sync from Firebase to local storage.
  Future<void> syncFromFirebase() async {
    if (_isSyncing) {
      logDebug('Sync already in progress, skipping');
      return;
    }

    if (!connectivity.isOnline) {
      logDebug('Offline, skipping Firebase sync');
      return;
    }

    _isSyncing = true;
    logInfo('Starting obstacle sync from Firebase');

    try {
      // Query active obstacles
      final snapshot = await _obstaclesRef
          .where('is_active', isEqualTo: true)
          .get();

      final obstacles = <Obstacle>[];
      for (final doc in snapshot.docs) {
        try {
          final obstacle = Obstacle.fromFirestore(doc.id, doc.data());
          obstacles.add(obstacle);
        } catch (e) {
          logWarn('Failed to parse obstacle ${doc.id}: $e');
        }
      }

      // Replace local data with fresh data
      store.deleteAll();
      store.upsertAll(obstacles);

      logInfo('Synced ${obstacles.length} obstacles from Firebase');
    } catch (e, stackTrace) {
      logError('Failed to sync obstacles from Firebase',
          error: e, stackTrace: stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  /// Start real-time sync with Firestore.
  void _startRealtimeSync() {
    _stopRealtimeSync(); // Cancel existing subscription

    logDebug('Starting real-time obstacle sync');
    _obstacleSubscription = _obstaclesRef
        .where('is_active', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        _handleRealtimeUpdate(snapshot);
      },
      onError: (error) {
        logError('Real-time sync error: $error');
      },
    );
  }

  /// Stop real-time sync.
  void _stopRealtimeSync() {
    _obstacleSubscription?.cancel();
    _obstacleSubscription = null;
  }

  /// Handle real-time updates from Firestore.
  void _handleRealtimeUpdate(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final change in snapshot.docChanges) {
      final doc = change.doc;
      final docId = doc.id;

      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          try {
            final obstacle = Obstacle.fromFirestore(docId, doc.data()!);
            store.upsert(obstacle);
            logDebug('Real-time: Updated obstacle $docId');
          } catch (e) {
            logWarn('Failed to process real-time update for $docId: $e');
          }
          break;

        case DocumentChangeType.removed:
          store.delete(docId);
          logDebug('Real-time: Removed obstacle $docId');
          break;
      }
    }
  }

  /// Report a new obstacle (online only).
  ///
  /// Returns the ID of the created obstacle, or null if failed.
  Future<String?> reportObstacle({
    required String name,
    required String description,
    required double lat,
    required double lng,
    required ObstacleType type,
    double radiusMeters = 5.0,
    DateTime? expiresAt,
  }) async {
    if (!connectivity.isOnline) {
      logWarn('Cannot report obstacle while offline');
      return null;
    }

    try {
      final docRef = await _obstaclesRef.add({
        'name': name,
        'description': description,
        'lat': lat,
        'lng': lng,
        'radius_meters': radiusMeters,
        'type': type.code,
        'created_at': FieldValue.serverTimestamp(),
        'expires_at': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'is_active': true,
        'reported_by': 'user', // TODO: Add user ID when auth is implemented
      });

      logInfo('Reported new obstacle: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      logError('Failed to report obstacle', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Deactivate an obstacle (mark as resolved).
  Future<bool> deactivateObstacle(String obstacleId) async {
    if (!connectivity.isOnline) {
      logWarn('Cannot deactivate obstacle while offline');
      return false;
    }

    try {
      await _obstaclesRef.doc(obstacleId).update({
        'is_active': false,
      });

      store.delete(obstacleId);
      logInfo('Deactivated obstacle: $obstacleId');
      return true;
    } catch (e, stackTrace) {
      logError('Failed to deactivate obstacle: $obstacleId',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    _stopRealtimeSync();
    _isInitialized = false;
  }
}

