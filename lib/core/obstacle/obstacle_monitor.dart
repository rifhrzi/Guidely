import 'dart:async';

import '../haptics/haptics_service.dart';
import '../logging/logger.dart';
import '../tts/tts_service.dart';
import '../types/geo.dart';
import 'obstacle.dart';
import 'obstacle_store.dart';

/// Callback type for obstacle proximity events.
typedef ObstacleProximityCallback = void Function(
  Obstacle obstacle,
  double distanceMeters,
);

/// Monitors user's proximity to obstacles and announces warnings via TTS.
///
/// This monitor:
/// - Tracks which obstacles have been announced to avoid repetition
/// - Provides different warning levels based on distance
/// - Integrates with haptic feedback for alerts
class ObstacleMonitor {
  ObstacleMonitor({
    required this.store,
    required this.tts,
    required this.haptics,
    this.onObstacleNearby,
    this.alertRadiusMeters = 30.0,
    this.warningRadiusMeters = 15.0,
    this.dangerRadiusMeters = 8.0,
  });

  final ObstacleStore store;
  final TtsService tts;
  final HapticsService haptics;
  
  /// Callback when an obstacle is nearby.
  final ObstacleProximityCallback? onObstacleNearby;

  /// Radius for initial alert (far warning).
  final double alertRadiusMeters;

  /// Radius for warning (getting closer).
  final double warningRadiusMeters;

  /// Radius for danger alert (very close).
  final double dangerRadiusMeters;

  /// Track announced obstacles to avoid repetition.
  /// Maps obstacle ID to the last warning level announced.
  final Map<String, _WarningLevel> _announcedObstacles = {};

  /// Cooldown between announcements for the same obstacle.
  final Map<String, DateTime> _lastAnnouncementTime = {};
  static const Duration _announcementCooldown = Duration(seconds: 20);

  /// Whether monitoring is enabled.
  bool enabled = true;

  /// Check for nearby obstacles at the given position.
  ///
  /// Call this method periodically (e.g., on each location update)
  /// to check for obstacles near the user.
  Future<List<Obstacle>> checkProximity(LatLng position) async {
    if (!enabled) return [];

    // Query obstacles within the alert radius
    final nearbyObstacles = store.getObstaclesNearby(
      position.lat,
      position.lng,
      alertRadiusMeters,
    );

    final foundObstacles = <Obstacle>[];

    for (final obstacle in nearbyObstacles) {
      if (!obstacle.shouldShow) continue;

      final obstaclePos = LatLng(obstacle.lat, obstacle.lng);
      final distance = haversineMeters(position, obstaclePos);

      // Skip if outside alert radius (accounting for obstacle's own radius)
      if (distance > alertRadiusMeters + obstacle.radiusMeters) continue;

      foundObstacles.add(obstacle);

      // Determine warning level
      final effectiveDistance = distance - obstacle.radiusMeters;
      final warningLevel = _getWarningLevel(effectiveDistance);

      // Check if we should announce
      if (_shouldAnnounce(obstacle.id, warningLevel)) {
        await _announceObstacle(obstacle, distance, warningLevel);
        onObstacleNearby?.call(obstacle, distance);
      }
    }

    return foundObstacles;
  }

  /// Get all obstacles that are currently being tracked (within alert range).
  List<Obstacle> getTrackedObstacles(LatLng position) {
    if (!enabled) return [];
    
    return store.getObstaclesNearby(
      position.lat,
      position.lng,
      alertRadiusMeters,
    ).where((o) => o.shouldShow).toList();
  }

  /// Determine the warning level based on distance.
  _WarningLevel _getWarningLevel(double effectiveDistance) {
    if (effectiveDistance <= dangerRadiusMeters) {
      return _WarningLevel.danger;
    } else if (effectiveDistance <= warningRadiusMeters) {
      return _WarningLevel.warning;
    } else if (effectiveDistance <= alertRadiusMeters) {
      return _WarningLevel.alert;
    }
    return _WarningLevel.none;
  }

  /// Check if we should announce this obstacle.
  bool _shouldAnnounce(String obstacleId, _WarningLevel newLevel) {
    if (newLevel == _WarningLevel.none) return false;

    final previousLevel = _announcedObstacles[obstacleId];
    final lastTime = _lastAnnouncementTime[obstacleId];

    // Always announce if we haven't announced this obstacle before
    if (previousLevel == null) return true;

    // Announce if warning level increased (getting closer)
    if (newLevel.index > previousLevel.index) return true;

    // Re-announce after cooldown if still at danger level
    if (newLevel == _WarningLevel.danger && lastTime != null) {
      final elapsed = DateTime.now().difference(lastTime);
      if (elapsed >= _announcementCooldown) return true;
    }

    return false;
  }

  /// Announce an obstacle via TTS and haptic feedback.
  Future<void> _announceObstacle(
    Obstacle obstacle,
    double distance,
    _WarningLevel level,
  ) async {
    // Update tracking
    _announcedObstacles[obstacle.id] = level;
    _lastAnnouncementTime[obstacle.id] = DateTime.now();

    // Build announcement message
    final message = _buildAnnouncementMessage(obstacle, distance, level);

    logInfo('Obstacle warning ($level): ${obstacle.name} at ${distance.round()}m');

    // Play haptic feedback based on warning level
    await _playHapticFeedback(level);

    // Stop any current speech and announce
    tts.stop();
    await tts.speak(message);
  }

  /// Build the TTS announcement message.
  String _buildAnnouncementMessage(
    Obstacle obstacle,
    double distance,
    _WarningLevel level,
  ) {
    final distanceText = distance.round().toString();
    final typeText = obstacle.type.displayName;

    switch (level) {
      case _WarningLevel.danger:
        return 'Perhatian! $typeText dalam $distanceText meter. '
            '${obstacle.name}. ${obstacle.description}';

      case _WarningLevel.warning:
        return 'Peringatan. Ada $typeText ${obstacle.name} '
            'dalam $distanceText meter. ${obstacle.description}';

      case _WarningLevel.alert:
        return 'Informasi. $typeText ${obstacle.name} terdeteksi '
            '$distanceText meter di depan.';

      case _WarningLevel.none:
        return '';
    }
  }

  /// Play haptic feedback based on warning level.
  Future<void> _playHapticFeedback(_WarningLevel level) async {
    switch (level) {
      case _WarningLevel.danger:
        // Strong vibration pattern for danger
        await haptics.danger();
        break;

      case _WarningLevel.warning:
        // Medium vibration for warning
        await haptics.warning();
        break;

      case _WarningLevel.alert:
        // Light vibration for alert
        await haptics.tick();
        break;

      case _WarningLevel.none:
        break;
    }
  }

  /// Clear tracking for an obstacle (e.g., when user passes it).
  void clearObstacleTracking(String obstacleId) {
    _announcedObstacles.remove(obstacleId);
    _lastAnnouncementTime.remove(obstacleId);
  }

  /// Clear all obstacle tracking.
  void clearAllTracking() {
    _announcedObstacles.clear();
    _lastAnnouncementTime.clear();
  }

  /// Force re-announcement of all nearby obstacles.
  void resetAnnouncements() {
    _announcedObstacles.clear();
    _lastAnnouncementTime.clear();
  }
}

/// Warning levels for obstacle proximity.
enum _WarningLevel {
  none,   // Outside alert range
  alert,  // Far - informational
  warning, // Getting closer - caution
  danger,  // Very close - immediate attention
}

