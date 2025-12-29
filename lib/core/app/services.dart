import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../accessibility/accessibility.dart';
import '../haptics/haptics_service.dart';
import '../location/location_service.dart';
import '../map/campus_geojson.dart';
import '../network/connectivity_service.dart';
import '../obstacle/obstacle_monitor.dart';
import '../obstacle/obstacle_store.dart';
import '../obstacle/obstacle_sync_service.dart';
import '../routing/pathfinder.dart';
import '../speech/stt_service.dart';
import '../tts/tts_service.dart';
import '../types/geo.dart';
import 'app_state.dart';

/// Groups all runtime services so they can be injected and overridden in tests.
class AppServices {
  AppServices({
    required AppState appState,
    TtsService? tts,
    SttService? stt,
    LocationStream? location,
    HapticsService? haptics,
    AccessibilityService? accessibility,
    ConnectivityService? connectivity,
  }) : _appState = appState {
    final resolvedTts = tts ?? RealTts(appState: appState);
    this.tts = resolvedTts;
    this.stt =
        stt ??
        RealStt(appState: appState, beforeStartListening: resolvedTts.stop);
    
    // Use SwitchableLocationStream to support simulation mode
    if (location != null) {
      this.location = location;
      _switchableLocation = null;
    } else {
      final switchable = SwitchableLocationStream();
      this.location = switchable;
      _switchableLocation = switchable;
    }
    
    this.haptics = haptics ?? DeviceHaptics();
    this.accessibility =
        accessibility ??
        AccessibilityService(appState: appState, tts: resolvedTts);
    
    // Connectivity service
    this.connectivity = connectivity ?? ConnectivityService();
  }

  final AppState _appState;
  SwitchableLocationStream? _switchableLocation;

  late final AccessibilityService accessibility;
  late final TtsService tts;
  late final SttService stt;
  late final LocationStream location;
  late final HapticsService haptics;
  late final ConnectivityService connectivity;
  
  // Lazy-initialized services (require async setup)
  ObstacleStore? _obstacleStore;
  ObstacleSyncService? _obstacleSyncService;
  ObstacleMonitor? _obstacleMonitor;
  
  /// Get the obstacle store (lazy initialized).
  ObstacleStore? get obstacleStore => _obstacleStore;
  
  /// Get the obstacle sync service (lazy initialized).
  ObstacleSyncService? get obstacleSyncService => _obstacleSyncService;
  
  /// Get the obstacle monitor (lazy initialized).
  ObstacleMonitor? get obstacleMonitor => _obstacleMonitor;
  
  /// Initialize async services (call after AppServices is created).
  Future<void> initializeAsyncServices() async {
    // Initialize obstacle store
    _obstacleStore = await ObstacleStore.open();
    
    // Initialize sync service
    _obstacleSyncService = ObstacleSyncService(
      store: _obstacleStore!,
      connectivity: connectivity,
    );
    await _obstacleSyncService!.initialize();
    
    // Initialize obstacle monitor
    _obstacleMonitor = ObstacleMonitor(
      store: _obstacleStore!,
      tts: tts,
      haptics: haptics,
    );
    
    // Enable/disable obstacle monitor based on app state
    _obstacleMonitor!.enabled = _appState.obstacleWarnings.value;
    _appState.obstacleWarnings.addListener(_onObstacleWarningsChanged);
  }
  
  void _onObstacleWarningsChanged() {
    _obstacleMonitor?.enabled = _appState.obstacleWarnings.value;
  }
  
  /// Sync obstacles from Firebase (call when going online).
  Future<void> syncObstacles() async {
    if (_obstacleSyncService == null) return;
    _appState.setIsSyncing(true);
    try {
      await _obstacleSyncService!.syncFromFirebase();
      _appState.setLastSyncTime(DateTime.now());
    } finally {
      _appState.setIsSyncing(false);
    }
  }

  /// Whether simulation mode is available.
  bool get canSimulate => _switchableLocation != null;

  /// Whether simulation is currently active.
  bool get isSimulating => _switchableLocation?.isSimulating ?? false;

  // Cached map data for path computation
  CampusGeoJson? _cachedMapData;
  
  /// Start location simulation towards a destination.
  /// 
  /// [targetLat] and [targetLng] are the destination coordinates.
  /// [startLat] and [startLng] are optional starting coordinates.
  /// If not provided, simulation starts from the default campus gate.
  /// 
  /// The simulation will follow walkway paths if available.
  Future<void> startSimulation({
    required double targetLat,
    required double targetLng,
    double? startLat,
    double? startLng,
  }) async {
    final switchable = _switchableLocation;
    if (switchable == null) return;

    final speed = _appState.simulationSpeed.value;
    
    // Default start: FKIP main gate
    final start = ll.LatLng(
      startLat ?? -6.131679420113894,
      startLng ?? 106.16415037389211,
    );
    final target = ll.LatLng(targetLat, targetLng);

    // Try to compute path along walkways
    List<LatLng> pathPoints = await _computeWalkwayPath(start, target);

    // Fallback to straight line if no path found
    if (pathPoints.isEmpty) {
      pathPoints = [
        LatLng(start.latitude, start.longitude),
        LatLng(target.latitude, target.longitude),
      ];
    }

    final config = SimulationConfig.withPath(
      pathPoints: pathPoints,
      walkingSpeedMps: speed,
    );

    switchable.enableSimulation(config);
    _appState.setSimulationMode(true);
  }

  /// Compute the walkway path from start to end.
  Future<List<LatLng>> _computeWalkwayPath(ll.LatLng start, ll.LatLng end) async {
    try {
      // Load map data if not cached
      _cachedMapData ??= await loadCampusGeoJson();
      
      final mapData = _cachedMapData;
      if (mapData == null) return [];

      final walkways = mapData.walkways;
      if (walkways.isEmpty) return [];

      // Find nearest point on walkways for start
      final startOnWalkway = _nearestPointOnWalkways(walkways, start);
      final endOnWalkway = _nearestPointOnWalkways(walkways, end);

      // Compute path using Dijkstra
      final pathResult = computeWalkwayPath(walkways, startOnWalkway, endOnWalkway);
      if (pathResult == null) return [];

      // Convert to LatLng list
      final path = <LatLng>[];
      
      // Add original start if different from path start
      if (_distanceBetween(start, pathResult.points.first) > 1.0) {
        path.add(LatLng(start.latitude, start.longitude));
      }
      
      // Add path points
      for (final point in pathResult.points) {
        path.add(LatLng(point.latitude, point.longitude));
      }
      
      // Add original end if different from path end
      if (_distanceBetween(end, pathResult.points.last) > 1.0) {
        path.add(LatLng(end.latitude, end.longitude));
      }

      return path;
    } catch (e) {
      // Return empty list on error - will fallback to straight line
      return [];
    }
  }

  /// Find the nearest point on walkways to a given position.
  ll.LatLng _nearestPointOnWalkways(List<Polyline> walkways, ll.LatLng point) {
    var bestPoint = point;
    var bestDistance = double.infinity;

    for (final walkway in walkways) {
      for (final p in walkway.points) {
        final d = _distanceBetween(point, p);
        if (d < bestDistance) {
          bestDistance = d;
          bestPoint = p;
        }
      }
    }

    return bestPoint;
  }

  /// Calculate distance between two points in meters.
  double _distanceBetween(ll.LatLng a, ll.LatLng b) {
    return haversineMeters(
      LatLng(a.latitude, a.longitude),
      LatLng(b.latitude, b.longitude),
    );
  }

  /// Stop location simulation and switch back to real GPS.
  void stopSimulation() {
    _switchableLocation?.disableSimulation();
    _appState.setSimulationMode(false);
  }

  /// Pause the simulation (keeps current position).
  void pauseSimulation() {
    _switchableLocation?.simulation.pause();
  }

  /// Resume the simulation from current position.
  void resumeSimulation() {
    _switchableLocation?.simulation.resume();
  }

  /// Reset simulation to start position.
  void resetSimulation() {
    _switchableLocation?.simulation.reset();
  }
}
