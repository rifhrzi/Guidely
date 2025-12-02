import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:navmate/core/permissions/permissions.dart';

import '../types/geo.dart';

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException({required this.permanentlyDenied});

  final bool permanentlyDenied;

  @override
  String toString() =>
      'LocationPermissionDeniedException(permanentlyDenied: $permanentlyDenied)';
}

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();

  @override
  String toString() => 'LocationServiceDisabledException()';
}

abstract class LocationStream {
  Stream<LatLng> get positions;
  Future<LatLng?> getCurrentPosition();
}

class MockLocationStream implements LocationStream {
  @override
  Stream<LatLng> get positions async* {}

  @override
  Future<LatLng?> getCurrentPosition() async => null;
}

class GeolocatorLocationStream implements LocationStream {
  Stream<LatLng>? _cached;

  Future<void> _ensurePermission() async {
    final result = await AppPermissions.requestLocation();
    if (!result.granted) {
      throw LocationPermissionDeniedException(
        permanentlyDenied: result.deniedForever,
      );
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationServiceDisabledException();
    }
  }

  @override
  Stream<LatLng> get positions {
    _cached ??= _create().asBroadcastStream();
    return _cached!;
  }

  Stream<LatLng> _create() async* {
    try {
      await _ensurePermission();
    } on LocationPermissionDeniedException catch (e) {
      yield* Stream<LatLng>.error(e);
      return;
    } on LocationServiceDisabledException catch (e) {
      yield* Stream<LatLng>.error(e);
      return;
    }
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    yield* Geolocator.getPositionStream(
      locationSettings: settings,
    ).map((p) => LatLng(p.latitude, p.longitude));
  }

  @override
  Future<LatLng?> getCurrentPosition() async {
    try {
      await _ensurePermission();
    } on LocationPermissionDeniedException catch (e) {
      return Future<LatLng?>.error(e);
    } on LocationServiceDisabledException catch (e) {
      return Future<LatLng?>.error(e);
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } on Exception {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        return null;
      }
      return LatLng(last.latitude, last.longitude);
    }
  }
}

/// Configuration for location simulation.
class SimulationConfig {
  const SimulationConfig({
    required this.pathPoints,
    this.walkingSpeedMps = 1.4, // Average walking speed ~1.4 m/s (~5 km/h)
    this.updateIntervalMs = 1000, // Update every 1 second
  });

  /// Path points to follow (computed from walkways).
  final List<LatLng> pathPoints;

  /// Walking speed in meters per second.
  final double walkingSpeedMps;

  /// How often to update position (in milliseconds).
  final int updateIntervalMs;

  /// Starting position (first point in path).
  LatLng get startPosition => pathPoints.isNotEmpty 
      ? pathPoints.first 
      : const LatLng(-6.131679420113894, 106.16415037389211);

  /// Target position (last point in path).
  LatLng get targetPosition => pathPoints.isNotEmpty 
      ? pathPoints.last 
      : startPosition;

  /// Create a config with a simple straight-line path (fallback).
  factory SimulationConfig.straightLine({
    required LatLng targetPosition,
    LatLng? startPosition,
    double walkingSpeedMps = 1.4,
  }) {
    // Default start: FKIP main gate
    final start = startPosition ?? const LatLng(
      -6.131679420113894,
      106.16415037389211,
    );
    return SimulationConfig(
      pathPoints: [start, targetPosition],
      walkingSpeedMps: walkingSpeedMps,
    );
  }

  /// Create a config with a computed path.
  factory SimulationConfig.withPath({
    required List<LatLng> pathPoints,
    double walkingSpeedMps = 1.4,
  }) {
    if (pathPoints.isEmpty) {
      throw ArgumentError('pathPoints cannot be empty');
    }
    return SimulationConfig(
      pathPoints: pathPoints,
      walkingSpeedMps: walkingSpeedMps,
    );
  }
}

/// Simulated location stream for testing navigation without GPS.
/// 
/// Simulates walking along a path of points (following walkways)
/// at a configurable walking speed.
class SimulatedLocationStream implements LocationStream {
  SimulatedLocationStream({
    SimulationConfig? config,
  }) : _config = config;

  SimulationConfig? _config;
  LatLng? _currentPosition;
  StreamController<LatLng>? _controller;
  Timer? _timer;
  bool _isRunning = false;
  
  /// Current index in the path.
  int _currentPathIndex = 0;
  
  /// Progress along current segment (0.0 to 1.0).
  double _segmentProgress = 0.0;

  /// Whether simulation is currently active.
  bool get isRunning => _isRunning;

  /// Current simulated position.
  LatLng? get currentPosition => _currentPosition;

  /// Current path being followed.
  List<LatLng> get pathPoints => _config?.pathPoints ?? [];

  /// Update the simulation configuration.
  void configure(SimulationConfig config) {
    _config = config;
    _currentPosition = config.startPosition;
    _currentPathIndex = 0;
    _segmentProgress = 0.0;
  }

  /// Start the simulation.
  void start() {
    if (_config == null) {
      throw StateError('SimulatedLocationStream not configured. Call configure() first.');
    }
    if (_isRunning) return;

    _isRunning = true;
    _currentPosition = _config!.startPosition;
    _currentPathIndex = 0;
    _segmentProgress = 0.0;
    
    _controller?.close();
    _controller = StreamController<LatLng>.broadcast();
    
    // Emit initial position
    _controller!.add(_currentPosition!);

    // Start simulation timer
    _timer = Timer.periodic(
      Duration(milliseconds: _config!.updateIntervalMs),
      (_) => _tick(),
    );
  }

  /// Stop the simulation.
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Reset simulation to start position.
  void reset() {
    stop();
    if (_config != null) {
      _currentPosition = _config!.startPosition;
      _currentPathIndex = 0;
      _segmentProgress = 0.0;
    }
  }

  /// Pause the simulation (keeps current position).
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Resume the simulation from current position.
  void resume() {
    if (!_isRunning || _config == null) return;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _config!.updateIntervalMs),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (_config == null || _currentPosition == null) return;

    final path = _config!.pathPoints;
    if (path.length < 2) {
      stop();
      return;
    }

    // Check if we've reached the end
    if (_currentPathIndex >= path.length - 1) {
      _currentPosition = path.last;
      _controller?.add(_currentPosition!);
      stop();
      return;
    }

    // Get current segment
    final segmentStart = path[_currentPathIndex];
    final segmentEnd = path[_currentPathIndex + 1];
    final segmentLength = haversineMeters(segmentStart, segmentEnd);

    // Calculate how far to move this tick
    final secondsPerTick = _config!.updateIntervalMs / 1000.0;
    final metersToMove = _config!.walkingSpeedMps * secondsPerTick;

    // Update progress along segment
    if (segmentLength > 0) {
      _segmentProgress += metersToMove / segmentLength;
    } else {
      _segmentProgress = 1.0;
    }

    // If we've completed the current segment, move to next
    while (_segmentProgress >= 1.0 && _currentPathIndex < path.length - 1) {
      final excess = _segmentProgress - 1.0;
      _currentPathIndex++;
      
      if (_currentPathIndex >= path.length - 1) {
        // Reached the end
        _currentPosition = path.last;
        _controller?.add(_currentPosition!);
        stop();
        return;
      }

      // Calculate progress in new segment
      final newSegmentStart = path[_currentPathIndex];
      final newSegmentEnd = path[_currentPathIndex + 1];
      final newSegmentLength = haversineMeters(newSegmentStart, newSegmentEnd);
      
      if (newSegmentLength > 0) {
        final excessMeters = excess * segmentLength;
        _segmentProgress = excessMeters / newSegmentLength;
      } else {
        _segmentProgress = 1.0;
      }
    }

    // Interpolate position along current segment
    final currentSegmentStart = path[_currentPathIndex];
    final currentSegmentEnd = path[_currentPathIndex + 1];
    _currentPosition = _interpolate(
      currentSegmentStart, 
      currentSegmentEnd, 
      _segmentProgress.clamp(0.0, 1.0),
    );

    // Emit new position
    _controller?.add(_currentPosition!);
  }

  /// Interpolate between two positions.
  LatLng _interpolate(LatLng from, LatLng to, double progress) {
    final lat = from.lat + (to.lat - from.lat) * progress;
    final lng = from.lng + (to.lng - from.lng) * progress;
    return LatLng(lat, lng);
  }

  @override
  Stream<LatLng> get positions {
    if (_controller == null || _controller!.isClosed) {
      _controller = StreamController<LatLng>.broadcast();
    }
    return _controller!.stream;
  }

  @override
  Future<LatLng?> getCurrentPosition() async {
    return _currentPosition ?? _config?.startPosition;
  }

  /// Clean up resources.
  void dispose() {
    stop();
    _controller?.close();
  }
}

/// A location stream that can switch between real GPS and simulation.
class SwitchableLocationStream implements LocationStream {
  SwitchableLocationStream({
    LocationStream? realLocation,
    SimulatedLocationStream? simulatedLocation,
  }) : _realLocation = realLocation ?? GeolocatorLocationStream(),
       _simulatedLocation = simulatedLocation ?? SimulatedLocationStream();

  final LocationStream _realLocation;
  final SimulatedLocationStream _simulatedLocation;
  
  bool _useSimulation = false;

  /// Whether simulation mode is active.
  bool get isSimulating => _useSimulation;

  /// The simulated location stream (for configuration).
  SimulatedLocationStream get simulation => _simulatedLocation;

  /// Enable simulation mode.
  void enableSimulation(SimulationConfig config) {
    _simulatedLocation.configure(config);
    _simulatedLocation.start();
    _useSimulation = true;
  }

  /// Disable simulation and switch to real GPS.
  void disableSimulation() {
    _simulatedLocation.stop();
    _useSimulation = false;
  }

  /// Toggle simulation mode.
  void toggleSimulation(SimulationConfig? config) {
    if (_useSimulation) {
      disableSimulation();
    } else if (config != null) {
      enableSimulation(config);
    }
  }

  @override
  Stream<LatLng> get positions {
    if (_useSimulation) {
      return _simulatedLocation.positions;
    }
    return _realLocation.positions;
  }

  @override
  Future<LatLng?> getCurrentPosition() {
    if (_useSimulation) {
      return _simulatedLocation.getCurrentPosition();
    }
    return _realLocation.getCurrentPosition();
  }

  void dispose() {
    _simulatedLocation.dispose();
  }
}
