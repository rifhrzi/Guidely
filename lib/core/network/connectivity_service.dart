import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../logging/logger.dart';

/// Enumeration of connectivity states for the app.
enum ConnectivityStatus {
  /// Device has internet connection (WiFi, mobile, ethernet).
  online,

  /// Device has no internet connection.
  offline,

  /// Connectivity status is unknown (initial state).
  unknown,
}

/// Service to monitor network connectivity status.
///
/// This service wraps the connectivity_plus package and provides
/// a simple interface to check if the device is online or offline.
class ConnectivityService {
  ConnectivityService() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Current connectivity status.
  ConnectivityStatus get status => _currentStatus;

  /// Whether the device is currently online.
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  /// Whether the device is currently offline.
  bool get isOffline => _currentStatus == ConnectivityStatus.offline;

  /// Stream of connectivity status changes.
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  /// Value notifier for reactive UI updates.
  final ValueNotifier<ConnectivityStatus> statusNotifier =
      ValueNotifier(ConnectivityStatus.unknown);

  void _init() {
    // Get initial connectivity status
    _checkConnectivity();

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (error) {
        logWarn('Connectivity stream error: $error');
        _updateStatus(ConnectivityStatus.unknown);
      },
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      logWarn('Failed to check connectivity: $e');
      _updateStatus(ConnectivityStatus.unknown);
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);

    final newStatus =
        hasConnection ? ConnectivityStatus.online : ConnectivityStatus.offline;

    if (newStatus != _currentStatus) {
      logInfo('Connectivity changed: $_currentStatus -> $newStatus');
      _updateStatus(newStatus);
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    _currentStatus = newStatus;
    statusNotifier.value = newStatus;
    _statusController.add(newStatus);
  }

  /// Force refresh connectivity status.
  Future<void> refresh() async {
    await _checkConnectivity();
  }

  /// Dispose resources.
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
    statusNotifier.dispose();
  }
}

/// Singleton instance for global access.
/// Use AppServices for dependency injection in production code.
ConnectivityService? _instance;

ConnectivityService get connectivityService {
  _instance ??= ConnectivityService();
  return _instance!;
}

