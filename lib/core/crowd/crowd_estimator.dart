import 'dart:async';

import '../logging/logger.dart';
import 'beacon_scanner.dart';
import 'crowd_zone.dart';

/// Estimates crowd density based on Bluetooth beacon/device counts.
///
/// The estimator uses the number of nearby Bluetooth devices as a proxy
/// for crowd density. This is a rough approximation but can provide
/// useful relative density information.
class CrowdEstimator {
  CrowdEstimator({
    required this.scanner,
    this.maxDevicesForMaxDensity = 50,
    this.updateInterval = const Duration(seconds: 5),
  });

  final BeaconScanner scanner;
  
  /// Number of devices that corresponds to 100% density.
  /// Adjust based on typical crowd sizes in your environment.
  final int maxDevicesForMaxDensity;
  
  /// How often to update density estimates.
  final Duration updateInterval;

  Timer? _updateTimer;
  final _densityController = StreamController<int>.broadcast();
  int _currentDensity = 0;
  bool _isRunning = false;

  /// Stream of density updates (0-100).
  Stream<int> get densityStream => _densityController.stream;

  /// Current estimated density (0-100).
  int get currentDensity => _currentDensity;

  /// Current crowd level based on density.
  CrowdLevel get currentLevel {
    if (_currentDensity < 20) return CrowdLevel.empty;
    if (_currentDensity < 40) return CrowdLevel.low;
    if (_currentDensity < 60) return CrowdLevel.moderate;
    if (_currentDensity < 80) return CrowdLevel.high;
    return CrowdLevel.veryHigh;
  }

  /// Whether the estimator is currently running.
  bool get isRunning => _isRunning;

  /// Start estimating crowd density.
  Future<void> start() async {
    if (_isRunning) return;

    final available = await scanner.isBluetoothAvailable();
    if (!available) {
      logWarn('Bluetooth not available, cannot start crowd estimation');
      return;
    }

    _isRunning = true;
    logInfo('Starting crowd density estimation');

    // Start beacon scanning
    await scanner.startScan();

    // Start periodic density updates
    _updateTimer = Timer.periodic(updateInterval, (_) => _updateDensity());
  }

  /// Stop estimating crowd density.
  Future<void> stop() async {
    if (!_isRunning) return;

    _updateTimer?.cancel();
    _updateTimer = null;
    await scanner.stopScan();
    _isRunning = false;
    logInfo('Stopped crowd density estimation');
  }

  /// Update the current density estimate.
  void _updateDensity() {
    // Count nearby devices (using RSSI threshold for proximity)
    final nearbyCount = scanner.getNearbyBeacons(rssiThreshold: -75).length;
    final totalCount = scanner.beaconCount;

    // Calculate density as percentage of max expected devices
    // Weight nearby devices more heavily
    final weightedCount = (nearbyCount * 1.5) + (totalCount * 0.5);
    final density =
        ((weightedCount / maxDevicesForMaxDensity) * 100).clamp(0, 100).toInt();

    if (density != _currentDensity) {
      _currentDensity = density;
      _densityController.add(density);
      logDebug(
        'Crowd density updated: $density% '
        '(nearby: $nearbyCount, total: $totalCount)',
      );
    }
  }

  /// Estimate density for a specific zone based on its beacons.
  ///
  /// [zone] - The crowd zone to check.
  /// Returns the estimated density for that zone (0-100).
  int estimateZoneDensity(CrowdZone zone) {
    if (zone.beaconIds.isEmpty) {
      // If zone has no specific beacons, use general density
      return _currentDensity;
    }

    // Count beacons in this zone that we've detected
    final detectedBeacons = scanner.detectedBeacons;
    var zoneBeaconCount = 0;
    var totalRssi = 0;

    for (final beacon in detectedBeacons) {
      if (zone.beaconIds.contains(beacon.deviceId) ||
          zone.beaconIds.contains(beacon.uuid)) {
        zoneBeaconCount++;
        totalRssi += beacon.rssi;
      }
    }

    if (zoneBeaconCount == 0) return 0;

    // Calculate density based on beacon signal strengths
    final avgRssi = totalRssi / zoneBeaconCount;
    
    // Stronger signals (less negative) suggest more nearby devices
    // Map RSSI range (-100 to -40) to density (0 to 100)
    final density = (((avgRssi + 100) / 60) * 100).clamp(0, 100).toInt();
    
    return density;
  }

  /// Get a spoken description of the current crowd level.
  String getSpokenDescription() {
    final level = currentLevel;
    return '${level.displayName}. ${level.description}. '
        'Perkiraan kepadatan $currentDensity persen.';
  }

  /// Dispose resources.
  void dispose() {
    stop();
    _densityController.close();
  }
}

