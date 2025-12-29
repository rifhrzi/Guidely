import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../logging/logger.dart';
import '../network/connectivity_service.dart';
import '../tts/tts_service.dart';
import '../types/geo.dart';
import 'beacon_scanner.dart';
import 'crowd_estimator.dart';
import 'crowd_zone.dart';

/// Main service for crowd detection and reporting.
///
/// This service:
/// - Scans for Bluetooth devices to estimate local crowd density
/// - Syncs crowd zone data with Firebase
/// - Uploads local density estimates to help aggregate crowd data
/// - Provides TTS announcements about crowded areas
class CrowdService {
  CrowdService({
    required this.connectivity,
    required this.tts,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    _scanner = BeaconScanner();
    _estimator = CrowdEstimator(scanner: _scanner);
  }

  final ConnectivityService connectivity;
  final TtsService tts;
  final FirebaseFirestore _firestore;
  
  late final BeaconScanner _scanner;
  late final CrowdEstimator _estimator;
  
  StreamSubscription<QuerySnapshot>? _zoneSubscription;
  final Map<String, CrowdZone> _zones = {};
  bool _isInitialized = false;

  /// Get the beacon scanner.
  BeaconScanner get scanner => _scanner;

  /// Get the crowd estimator.
  CrowdEstimator get estimator => _estimator;

  /// Collection reference for crowd zones.
  CollectionReference<Map<String, dynamic>> get _zonesRef =>
      _firestore.collection('crowd_zones');

  /// All known crowd zones.
  List<CrowdZone> get zones => _zones.values.toList();

  /// Current local crowd density (0-100).
  int get localDensity => _estimator.currentDensity;

  /// Current local crowd level.
  CrowdLevel get localLevel => _estimator.currentLevel;

  /// Whether crowd detection is running.
  bool get isRunning => _estimator.isRunning;

  /// Initialize the crowd service.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen for connectivity changes
    connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        _onConnected();
      }
    });

    // Initial sync if online
    if (connectivity.isOnline) {
      await _syncZones();
      _startRealtimeSync();
    }
  }

  void _onConnected() {
    logInfo('CrowdService: Connected, syncing zones');
    _syncZones();
    _startRealtimeSync();
  }

  /// Start crowd detection.
  Future<void> startDetection() async {
    await _estimator.start();
    logInfo('Crowd detection started');

    // If online, periodically upload density to help aggregate
    if (connectivity.isOnline) {
      _startDensityUpload();
    }
  }

  /// Stop crowd detection.
  Future<void> stopDetection() async {
    await _estimator.stop();
    _stopDensityUpload();
    logInfo('Crowd detection stopped');
  }

  Timer? _uploadTimer;

  void _startDensityUpload() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _uploadLocalDensity();
    });
  }

  void _stopDensityUpload() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  /// Upload local density estimate to help with aggregate crowd data.
  Future<void> _uploadLocalDensity() async {
    if (!connectivity.isOnline) return;
    // This would upload to a separate collection for aggregation
    // For now, just log it
    logDebug(
      'Would upload local density: ${_estimator.currentDensity}%',
    );
  }

  /// Sync crowd zones from Firebase.
  Future<void> _syncZones() async {
    if (!connectivity.isOnline) return;

    try {
      final snapshot = await _zonesRef.get();
      _zones.clear();
      
      for (final doc in snapshot.docs) {
        final zone = CrowdZone.fromFirestore(doc.id, doc.data());
        _zones[zone.id] = zone;
      }
      
      logInfo('Synced ${_zones.length} crowd zones');
    } catch (e, stackTrace) {
      logError('Failed to sync crowd zones', error: e, stackTrace: stackTrace);
    }
  }

  /// Start real-time sync with Firestore.
  void _startRealtimeSync() {
    _zoneSubscription?.cancel();
    _zoneSubscription = _zonesRef.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          final doc = change.doc;
          if (change.type == DocumentChangeType.removed) {
            _zones.remove(doc.id);
          } else {
            final zone = CrowdZone.fromFirestore(doc.id, doc.data()!);
            _zones[zone.id] = zone;
          }
        }
      },
      onError: (error) {
        logError('Crowd zone sync error: $error');
      },
    );
  }

  /// Get crowd zone at a specific location.
  CrowdZone? getZoneAt(LatLng position) {
    for (final zone in _zones.values) {
      final distance = haversineMeters(
        position,
        LatLng(zone.lat, zone.lng),
      );
      if (distance <= zone.radiusMeters) {
        return zone;
      }
    }
    return null;
  }

  /// Get all zones within a radius of a position.
  List<CrowdZone> getZonesNearby(LatLng position, double radiusMeters) {
    return _zones.values.where((zone) {
      final distance = haversineMeters(
        position,
        LatLng(zone.lat, zone.lng),
      );
      return distance <= radiusMeters + zone.radiusMeters;
    }).toList();
  }

  /// Announce current crowd status via TTS.
  Future<void> announceCrowdStatus() async {
    final description = _estimator.getSpokenDescription();
    await tts.speak(description);
  }

  /// Announce crowd status for a specific zone.
  Future<void> announceZoneStatus(CrowdZone zone) async {
    final level = zone.level;
    final message = 'Area ${zone.name}. ${level.displayName}. '
        '${level.description}.';
    await tts.speak(message);
  }

  /// Dispose resources.
  void dispose() {
    _zoneSubscription?.cancel();
    _stopDensityUpload();
    _estimator.dispose();
    _scanner.dispose();
  }
}

