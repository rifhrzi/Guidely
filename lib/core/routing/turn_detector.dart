import 'dart:math' as math;

import 'package:latlong2/latlong.dart' as ll;

import '../types/geo.dart' as core_geo;

/// Types of turns that can be detected.
enum TurnType {
  straight,
  slightLeft,
  slightRight,
  left,
  right,
  sharpLeft,
  sharpRight,
  uTurn,
  roundabout,
  arrived,
}

/// A detected turn in the navigation route.
class Turn {
  const Turn({
    required this.type,
    required this.position,
    required this.angle,
    required this.distanceFromStart,
    required this.distanceToNext,
    this.instruction,
    this.pathIndex,
  });

  /// Type of turn.
  final TurnType type;

  /// Position of the turn.
  final ll.LatLng position;

  /// Angle of the turn in degrees (-180 to 180).
  /// Negative = left, Positive = right.
  final double angle;

  /// Distance from start of route to this turn (meters).
  final double distanceFromStart;

  /// Distance from this turn to the next turn or destination (meters).
  final double distanceToNext;

  /// Human-readable instruction for this turn.
  final String? instruction;

  /// Index in the original path (for matching with simulation).
  final int? pathIndex;

  @override
  String toString() => 'Turn($type, ${angle.toStringAsFixed(1)}°, ${distanceFromStart.toStringAsFixed(0)}m)';
}

/// Detects turns and generates navigation instructions from a path.
class TurnDetector {
  const TurnDetector({
    this.minTurnAngle = 35.0,        // Increased: only significant turns
    this.significantTurnAngle = 60.0, // Angle for "real" turns (not slight)
    this.minSegmentLength = 8.0,      // Increased: ignore micro-segments
    this.simplifyTolerance = 3.0,     // Douglas-Peucker tolerance in meters
    this.lookAheadDistance = 15.0,    // Look ahead for turn detection
    this.mergeDistance = 10.0,        // Merge turns within this distance
  });

  /// Minimum angle change to consider as a turn (degrees).
  final double minTurnAngle;

  /// Angle for significant (non-slight) turns.
  final double significantTurnAngle;

  /// Minimum segment length to consider for turn detection (meters).
  final double minSegmentLength;

  /// Tolerance for path simplification (meters).
  final double simplifyTolerance;

  /// Distance to look ahead when calculating turn angle.
  final double lookAheadDistance;

  /// Distance within which to merge consecutive turns.
  final double mergeDistance;

  /// Analyze a path and detect all turns.
  List<Turn> detectTurns(List<ll.LatLng> path, {String? destinationName}) {
    if (path.length < 2) return [];

    // Step 1: Simplify path to reduce noise
    final simplified = _simplifyPath(path, simplifyTolerance);
    if (simplified.length < 2) return [];

    final turns = <Turn>[];
    
    // Calculate cumulative distances for original path
    final cumulativeDistances = _calculateCumulativeDistances(path);
    final totalDistance = cumulativeDistances.isNotEmpty ? cumulativeDistances.last : 0.0;

    // Step 2: Start instruction with proper direction
    if (simplified.length >= 2) {
      final startBearing = _calculateBearing(simplified[0], simplified[1]);
      final startDirection = _bearingToDirection(startBearing);
      
      // Find distance to first turn or end
      final firstSegmentEnd = simplified.length > 2 ? 1 : simplified.length - 1;
      final distanceToNext = _distanceBetween(simplified[0], simplified[firstSegmentEnd]);
      
      turns.add(Turn(
        type: TurnType.straight,
        position: simplified[0],
        angle: 0,
        distanceFromStart: 0,
        distanceToNext: distanceToNext,
        instruction: 'Mulai berjalan ke arah $startDirection, lanjut ${distanceToNext.round()} meter',
        pathIndex: 0,
      ));
    }

    // Step 3: Detect turns using look-ahead method
    var cumulativeDistance = 0.0;
    
    for (var i = 1; i < simplified.length - 1; i++) {
      final prev = simplified[i - 1];
      final current = simplified[i];
      final next = simplified[i + 1];

      final segmentLength = _distanceBetween(prev, current);
      cumulativeDistance += segmentLength;

      // Calculate turn angle using look-ahead for better accuracy
      final angle = _calculateTurnAngleWithLookAhead(simplified, i);
      final absAngle = angle.abs();

      // Skip if angle is too small
      if (absAngle < minTurnAngle) continue;

      // Determine turn type with more accurate classification
      final turnType = _classifyTurn(angle);
      
      // Skip slight turns that are too close together (noise)
      if ((turnType == TurnType.slightLeft || turnType == TurnType.slightRight) &&
          segmentLength < minSegmentLength * 2) {
        continue;
      }

      // Calculate distance to next significant point
      final distanceToNext = _distanceBetween(current, next);

      // Generate instruction
      final instruction = _generateInstruction(
        turnType,
        angle,
        distanceToNext,
        destinationName: i == simplified.length - 2 ? destinationName : null,
      );

      // Find original path index
      final pathIndex = _findClosestPathIndex(path, current);

      turns.add(Turn(
        type: turnType,
        position: current,
        angle: angle,
        distanceFromStart: cumulativeDistance,
        distanceToNext: distanceToNext,
        instruction: instruction,
        pathIndex: pathIndex,
      ));
    }

    // Step 4: Merge close turns
    final mergedTurns = _mergeTurns(turns);

    // Step 5: Add arrival instruction
    if (simplified.length >= 2) {
      final lastDistance = _distanceBetween(
        simplified[simplified.length - 2],
        simplified.last,
      );
      cumulativeDistance += lastDistance;

      mergedTurns.add(Turn(
        type: TurnType.arrived,
        position: simplified.last,
        angle: 0,
        distanceFromStart: totalDistance,
        distanceToNext: 0,
        instruction: destinationName != null
            ? 'Anda telah sampai di $destinationName'
            : 'Anda telah sampai di tujuan',
        pathIndex: path.length - 1,
      ));
    }

    // Step 6: Recalculate distances to next turn
    return _recalculateDistances(mergedTurns, totalDistance);
  }

  /// Simplify path using Douglas-Peucker algorithm to reduce noise.
  List<ll.LatLng> _simplifyPath(List<ll.LatLng> path, double tolerance) {
    if (path.length < 3) return List.from(path);

    // Douglas-Peucker algorithm
    double maxDistance = 0;
    int maxIndex = 0;

    final first = path.first;
    final last = path.last;

    for (var i = 1; i < path.length - 1; i++) {
      final d = _perpendicularDistance(path[i], first, last);
      if (d > maxDistance) {
        maxDistance = d;
        maxIndex = i;
      }
    }

    if (maxDistance > tolerance) {
      final left = _simplifyPath(path.sublist(0, maxIndex + 1), tolerance);
      final right = _simplifyPath(path.sublist(maxIndex), tolerance);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [first, last];
    }
  }

  /// Calculate perpendicular distance from point to line.
  double _perpendicularDistance(ll.LatLng point, ll.LatLng lineStart, ll.LatLng lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      return _distanceBetween(point, lineStart);
    }

    final t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    final tClamped = t.clamp(0.0, 1.0);
    
    final nearest = ll.LatLng(
      lineStart.latitude + tClamped * dy,
      lineStart.longitude + tClamped * dx,
    );

    return _distanceBetween(point, nearest);
  }

  /// Calculate turn angle using look-ahead for better accuracy.
  double _calculateTurnAngleWithLookAhead(List<ll.LatLng> path, int turnIndex) {
    // Find incoming direction (look back)
    var incomingBearing = 0.0;
    var totalIncomingDist = 0.0;
    for (var i = turnIndex; i > 0 && totalIncomingDist < lookAheadDistance; i--) {
      totalIncomingDist += _distanceBetween(path[i], path[i - 1]);
      incomingBearing = _calculateBearing(path[i - 1], path[i]);
    }

    // Find outgoing direction (look ahead)
    var outgoingBearing = 0.0;
    var totalOutgoingDist = 0.0;
    for (var i = turnIndex; i < path.length - 1 && totalOutgoingDist < lookAheadDistance; i++) {
      totalOutgoingDist += _distanceBetween(path[i], path[i + 1]);
      outgoingBearing = _calculateBearing(path[i], path[i + 1]);
    }

    // Calculate angle difference
    var angle = outgoingBearing - incomingBearing;

    // Normalize to -180 to 180
    while (angle > 180) {
      angle -= 360;
    }
    while (angle < -180) {
      angle += 360;
    }

    return angle;
  }

  /// Calculate cumulative distances for each point in path.
  List<double> _calculateCumulativeDistances(List<ll.LatLng> path) {
    final distances = <double>[0.0];
    for (var i = 1; i < path.length; i++) {
      distances.add(distances.last + _distanceBetween(path[i - 1], path[i]));
    }
    return distances;
  }

  /// Find the closest index in original path to a given position.
  int _findClosestPathIndex(List<ll.LatLng> path, ll.LatLng position) {
    var minDist = double.infinity;
    var closestIndex = 0;
    for (var i = 0; i < path.length; i++) {
      final d = _distanceBetween(path[i], position);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  /// Merge turns that are too close together.
  List<Turn> _mergeTurns(List<Turn> turns) {
    if (turns.length < 2) return turns;

    final result = <Turn>[];
    var i = 0;

    while (i < turns.length) {
      final current = turns[i];
      
      // Check if next turn is too close
      if (i + 1 < turns.length) {
        final next = turns[i + 1];
        final distance = next.distanceFromStart - current.distanceFromStart;

        if (distance < mergeDistance && distance > 0) {
          // Merge turns - use the more significant one
          final combinedAngle = current.angle + next.angle;
          final dominantType = _classifyTurn(combinedAngle);
          
          result.add(Turn(
            type: dominantType,
            position: current.position,
            angle: combinedAngle,
            distanceFromStart: current.distanceFromStart,
            distanceToNext: current.distanceToNext + next.distanceToNext,
            instruction: _generateInstruction(dominantType, combinedAngle, current.distanceToNext + next.distanceToNext),
            pathIndex: current.pathIndex,
          ));
          i += 2; // Skip both
          continue;
        }
      }

      result.add(current);
      i++;
    }

    return result;
  }

  /// Recalculate distanceToNext for all turns.
  List<Turn> _recalculateDistances(List<Turn> turns, double totalDistance) {
    if (turns.isEmpty) return turns;

    final result = <Turn>[];
    for (var i = 0; i < turns.length; i++) {
      final current = turns[i];
      final nextDistance = i + 1 < turns.length
          ? turns[i + 1].distanceFromStart - current.distanceFromStart
          : totalDistance - current.distanceFromStart;

      // Update instruction with correct distance
      final instruction = current.type == TurnType.arrived
          ? current.instruction
          : _generateInstruction(current.type, current.angle, nextDistance);

      result.add(Turn(
        type: current.type,
        position: current.position,
        angle: current.angle,
        distanceFromStart: current.distanceFromStart,
        distanceToNext: nextDistance.clamp(0, double.infinity),
        instruction: instruction,
        pathIndex: current.pathIndex,
      ));
    }

    return result;
  }

  /// Calculate bearing from point A to point B in degrees (0-360).
  double _calculateBearing(ll.LatLng from, ll.LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    var bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Classify a turn based on its angle - more accurate thresholds.
  TurnType _classifyTurn(double angle) {
    final absAngle = angle.abs();

    if (absAngle < 25) {
      return TurnType.straight;
    } else if (absAngle < 50) {
      return angle < 0 ? TurnType.slightLeft : TurnType.slightRight;
    } else if (absAngle < 110) {
      return angle < 0 ? TurnType.left : TurnType.right;
    } else if (absAngle < 150) {
      return angle < 0 ? TurnType.sharpLeft : TurnType.sharpRight;
    } else {
      return TurnType.uTurn;
    }
  }

  /// Convert bearing to human-readable direction.
  String _bearingToDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'utara';
    if (bearing >= 22.5 && bearing < 67.5) return 'timur laut';
    if (bearing >= 67.5 && bearing < 112.5) return 'timur';
    if (bearing >= 112.5 && bearing < 157.5) return 'tenggara';
    if (bearing >= 157.5 && bearing < 202.5) return 'selatan';
    if (bearing >= 202.5 && bearing < 247.5) return 'barat daya';
    if (bearing >= 247.5 && bearing < 292.5) return 'barat';
    return 'barat laut';
  }

  /// Generate human-readable instruction for a turn.
  String _generateInstruction(
    TurnType type,
    double angle,
    double distanceToNext, {
    String? destinationName,
  }) {
    final distance = distanceToNext.round();
    final distanceText = distance > 0 ? ', lanjut $distance meter' : '';

    switch (type) {
      case TurnType.straight:
        return 'Lurus terus$distanceText';
      case TurnType.slightLeft:
        return 'Agak ke kiri$distanceText';
      case TurnType.slightRight:
        return 'Agak ke kanan$distanceText';
      case TurnType.left:
        return 'Belok kiri$distanceText';
      case TurnType.right:
        return 'Belok kanan$distanceText';
      case TurnType.sharpLeft:
        return 'Belok tajam ke kiri$distanceText';
      case TurnType.sharpRight:
        return 'Belok tajam ke kanan$distanceText';
      case TurnType.uTurn:
        return 'Putar balik$distanceText';
      case TurnType.roundabout:
        final exitDir = angle < 0 ? 'kiri' : 'kanan';
        return 'Masuk bundaran, ambil jalur $exitDir$distanceText';
      case TurnType.arrived:
        return destinationName != null
            ? 'Anda telah sampai di $destinationName'
            : 'Anda telah sampai di tujuan';
    }
  }

  double _distanceBetween(ll.LatLng a, ll.LatLng b) {
    return core_geo.haversineMeters(
      core_geo.LatLng(a.latitude, a.longitude),
      core_geo.LatLng(b.latitude, b.longitude),
    );
  }
}

/// Find the next upcoming turn based on current position.
Turn? findNextTurn(
  List<Turn> turns,
  core_geo.LatLng currentPosition,
  double distanceTraveled,
) {
  for (final turn in turns) {
    // Skip turns we've already passed (with buffer)
    if (turn.distanceFromStart < distanceTraveled - 8) continue;
    // Skip start instruction if we've moved significantly
    if (turn.distanceFromStart == 0 && distanceTraveled > 15) continue;
    return turn;
  }
  return null;
}

/// Check if user is approaching a turn (within threshold distance).
bool isApproachingTurn(Turn turn, double distanceTraveled, {double threshold = 25}) {
  final distanceToTurn = turn.distanceFromStart - distanceTraveled;
  return distanceToTurn > 0 && distanceToTurn <= threshold;
}

/// Check if user has reached a turn (within threshold distance).
bool hasReachedTurn(Turn turn, double distanceTraveled, {double threshold = 8}) {
  final distanceToTurn = (turn.distanceFromStart - distanceTraveled).abs();
  return distanceToTurn <= threshold;
}

/// Find the closest turn to current position by geographic distance.
Turn? findClosestTurn(List<Turn> turns, core_geo.LatLng position) {
  if (turns.isEmpty) return null;

  Turn? closest;
  var minDistance = double.infinity;

  for (final turn in turns) {
    final d = core_geo.haversineMeters(
      position,
      core_geo.LatLng(turn.position.latitude, turn.position.longitude),
    );
    if (d < minDistance) {
      minDistance = d;
      closest = turn;
    }
  }

  return closest;
}
