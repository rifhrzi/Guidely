import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../logging/logger.dart';

/// Result of a beacon scan.
class BeaconScanResult {
  const BeaconScanResult({
    required this.deviceId,
    required this.deviceName,
    required this.rssi,
    required this.timestamp,
    this.uuid,
    this.major,
    this.minor,
  });

  /// Device identifier (MAC address or platform ID).
  final String deviceId;

  /// Device name (may be empty).
  final String deviceName;

  /// Signal strength in dBm (more negative = weaker).
  final int rssi;

  /// When this beacon was detected.
  final DateTime timestamp;

  /// iBeacon UUID (if available).
  final String? uuid;

  /// iBeacon major value (if available).
  final int? major;

  /// iBeacon minor value (if available).
  final int? minor;

  /// Estimate distance based on RSSI.
  /// This is a rough approximation and varies by device/environment.
  double get estimatedDistance {
    // Using a simple path loss model
    // Reference: -59 dBm at 1 meter (typical for BLE)
    const txPower = -59;
    if (rssi == 0) return -1;

    final ratio = rssi / txPower;
    if (ratio < 1.0) {
      return ratio * ratio * ratio * ratio * ratio * ratio * ratio * ratio * ratio * ratio;
    }
    return (0.89976) * (ratio * ratio * ratio * ratio * ratio * ratio * ratio * ratio * ratio * ratio) + 0.111;
  }

  @override
  String toString() =>
      'BeaconScanResult{id: $deviceId, name: $deviceName, rssi: $rssi}';
}

/// Service for scanning Bluetooth beacons.
///
/// This is used for crowd detection by counting nearby devices.
/// Note: Requires BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions on Android 12+,
/// and Bluetooth permission on iOS.
class BeaconScanner {
  BeaconScanner();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final _resultsController = StreamController<List<BeaconScanResult>>.broadcast();
  final Map<String, BeaconScanResult> _detectedBeacons = {};
  bool _isScanning = false;

  /// Stream of detected beacons.
  Stream<List<BeaconScanResult>> get beaconStream => _resultsController.stream;

  /// Whether scanning is currently active.
  bool get isScanning => _isScanning;

  /// All currently detected beacons.
  List<BeaconScanResult> get detectedBeacons => _detectedBeacons.values.toList();

  /// Number of detected beacons.
  int get beaconCount => _detectedBeacons.length;

  /// Check if Bluetooth is available and enabled.
  Future<bool> isBluetoothAvailable() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        logWarn('Bluetooth not supported on this device');
        return false;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      logWarn('Error checking Bluetooth availability: $e');
      return false;
    }
  }

  /// Request to turn on Bluetooth (Android only).
  Future<void> requestBluetoothOn() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      logWarn('Failed to turn on Bluetooth: $e');
    }
  }

  /// Start scanning for beacons.
  ///
  /// [duration] - How long to scan. Null means continuous scanning.
  /// [filterByName] - Only include devices with names containing this string.
  Future<void> startScan({
    Duration? duration,
    String? filterByName,
  }) async {
    if (_isScanning) {
      logDebug('Already scanning, ignoring start request');
      return;
    }

    final available = await isBluetoothAvailable();
    if (!available) {
      logWarn('Bluetooth not available, cannot start scan');
      return;
    }

    try {
      _isScanning = true;
      _detectedBeacons.clear();
      logInfo('Starting beacon scan${duration != null ? ' for ${duration.inSeconds}s' : ''}');

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: duration,
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Listen for scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          _handleScanResults(results, filterByName);
        },
        onError: (error) {
          logError('Scan error: $error');
        },
      );

      // Handle scan completion if duration is set
      if (duration != null) {
        Future.delayed(duration, () {
          if (_isScanning) {
            stopScan();
          }
        });
      }
    } catch (e, stackTrace) {
      logError('Failed to start beacon scan', error: e, stackTrace: stackTrace);
      _isScanning = false;
    }
  }

  void _handleScanResults(List<ScanResult> results, String? filterByName) {
    final now = DateTime.now();
    var updated = false;

    for (final result in results) {
      final device = result.device;
      final name = device.platformName;

      // Apply name filter if specified
      if (filterByName != null &&
          !name.toLowerCase().contains(filterByName.toLowerCase())) {
        continue;
      }

      final beacon = BeaconScanResult(
        deviceId: device.remoteId.str,
        deviceName: name,
        rssi: result.rssi,
        timestamp: now,
        // Parse iBeacon data if available
        uuid: _extractUuid(result),
        major: _extractMajor(result),
        minor: _extractMinor(result),
      );

      _detectedBeacons[beacon.deviceId] = beacon;
      updated = true;
    }

    if (updated) {
      // Remove stale beacons (not seen in 10 seconds)
      final staleThreshold = now.subtract(const Duration(seconds: 10));
      _detectedBeacons.removeWhere(
        (_, beacon) => beacon.timestamp.isBefore(staleThreshold),
      );

      _resultsController.add(_detectedBeacons.values.toList());
    }
  }

  /// Extract iBeacon UUID from scan result (if available).
  String? _extractUuid(ScanResult result) {
    // iBeacon data is in manufacturer specific data
    final msd = result.advertisementData.manufacturerData;
    if (msd.isEmpty) return null;

    // Apple's company ID is 0x004C
    final appleData = msd[0x004C];
    if (appleData == null || appleData.length < 23) return null;

    // Check if it's an iBeacon (type 0x02, length 0x15)
    if (appleData[0] != 0x02 || appleData[1] != 0x15) return null;

    // Extract UUID (bytes 2-17)
    final uuidBytes = appleData.sublist(2, 18);
    return uuidBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// Extract iBeacon major value from scan result (if available).
  int? _extractMajor(ScanResult result) {
    final msd = result.advertisementData.manufacturerData;
    final appleData = msd[0x004C];
    if (appleData == null || appleData.length < 23) return null;
    if (appleData[0] != 0x02 || appleData[1] != 0x15) return null;

    return (appleData[18] << 8) + appleData[19];
  }

  /// Extract iBeacon minor value from scan result (if available).
  int? _extractMinor(ScanResult result) {
    final msd = result.advertisementData.manufacturerData;
    final appleData = msd[0x004C];
    if (appleData == null || appleData.length < 23) return null;
    if (appleData[0] != 0x02 || appleData[1] != 0x15) return null;

    return (appleData[20] << 8) + appleData[21];
  }

  /// Stop scanning for beacons.
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      logInfo('Beacon scan stopped, detected ${_detectedBeacons.length} devices');
    } catch (e) {
      logWarn('Error stopping scan: $e');
      _isScanning = false;
    }
  }

  /// Get beacons within a certain RSSI threshold.
  /// Higher RSSI = closer device. Default threshold is -70 dBm (~5m).
  List<BeaconScanResult> getNearbyBeacons({int rssiThreshold = -70}) {
    return _detectedBeacons.values
        .where((beacon) => beacon.rssi >= rssiThreshold)
        .toList();
  }

  /// Get average RSSI of all detected beacons.
  double get averageRssi {
    if (_detectedBeacons.isEmpty) return 0;
    final total =
        _detectedBeacons.values.map((b) => b.rssi).reduce((a, b) => a + b);
    return total / _detectedBeacons.length;
  }

  /// Dispose resources.
  void dispose() {
    stopScan();
    _resultsController.close();
  }
}

