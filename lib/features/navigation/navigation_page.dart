import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/app/app_scope.dart';
import '../../core/app/services.dart';
import '../../core/data/landmarks.dart';
import '../../core/logging/logger.dart';
import '../../core/map/campus_geojson.dart';
import '../../core/map/campus_map_view.dart';
import '../../core/map/mbtiles_tile_provider.dart';
import '../../core/obstacle/obstacle.dart';
import '../../core/routing/pathfinder.dart';
import '../../core/routing/turn_detector.dart';
import '../../core/types/geo.dart' as core_geo;
import '../../l10n/app_localizations.dart';
import 'report_obstacle_dialog.dart';

/// Navigation page optimized for blind/low-vision users.
///
/// Design principles:
/// - Audio-first: Voice announcements are primary feedback
/// - Large touch targets: All buttons minimum 72dp
/// - Simple layout: Linear, predictable navigation
/// - Strong haptic feedback: Different patterns for different events
/// - Distance is king: Large, prominent distance display
/// - Map is optional: Can be hidden for fully blind users
class NavigationPage extends StatefulWidget {
  const NavigationPage({
    super.key,
    required this.nextInstruction,
    required this.distanceMeters,
    this.destination,
  });

  final String nextInstruction;
  final double distanceMeters;
  final Landmark? destination;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

enum _HapticCue { none, tick, straight, confirm, arrived }

class _NavigationPageState extends State<NavigationPage> {
  static const ll.LatLng _mainGate = ll.LatLng(
    -6.131679420113894,
    106.16415037389211,
  );

  StreamSubscription<core_geo.LatLng>? _sub;
  late String _instruction;
  late double _distance;
  bool _paused = false;
  bool _initialized = false;
  bool _arrivalAnnounced = false;
  bool _showMap = false; // Map hidden by default for accessibility
  double? _initialDistance;
  AppServices? _services;
  core_geo.LatLng? _currentPosition;
  core_geo.LatLng? _startPosition;
  Object? _locationError;
  double? _previousDistance;
  final Set<int> _announcedMilestones = <int>{};
  DateTime? _lastGuidanceSpoken;

  // Turn detection
  final TurnDetector _turnDetector = const TurnDetector();
  List<Turn> _turns = [];
  List<ll.LatLng> _routePoints = [];
  Turn? _nextTurn;
  double _distanceTraveled = 0;
  double _totalRouteDistance = 0; // Total distance along route
  final Set<int> _announcedTurns = {};

  // Throttling for location updates (performance optimization)
  DateTime? _lastLocationUpdate;
  core_geo.LatLng? _lastProcessedPosition;
  static const Duration _locationUpdateThrottle = Duration(milliseconds: 500);
  static const double _minPositionChangeMeter = 2.0;
  
  // Obstacle tracking
  List<Obstacle> _nearbyObstacles = [];
  DateTime? _lastObstacleCheck;
  static const Duration _obstacleCheckInterval = Duration(seconds: 2);

  static const List<int> _guidanceMilestones = [
    200,
    150,
    120,
    100,
    80,
    60,
    50,
    40,
    30,
    20,
    10,
  ];
  static const Duration _guidanceCooldown = Duration(seconds: 6);

  AppServices get services => _services ??= context.services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _instruction = widget.nextInstruction;
    _distance = widget.distanceMeters;
    if (_distance.isFinite && _distance > 0) {
      _initialDistance = _distance;
    } else {
      _initialDistance = null;
    }
    _arrivalAnnounced = false;
    logInfo(
      'Starting navigation session to '
      '${widget.destination?.name ?? 'unknown destination'}',
    );
    _resetGuidanceState();
    unawaited(services.tts.speak(_instruction));
    _playHaptic(_HapticCue.straight);
    _startLocationTracking();
  }

  void _startLocationTracking() {
    _sub?.cancel();
    logDebug('Subscribing to location updates');
    setState(() => _locationError = null);
    final dest = widget.destination;
    final target = dest != null ? core_geo.LatLng(dest.lat, dest.lng) : null;
    final arrivalMessage = dest == null
        ? null
        : AppLocalizations.of(context)?.arrivedAt(dest.name) ??
              'You have arrived at ${dest.name}';

    if (target != null) {
      services.location
          .getCurrentPosition()
          .then((position) {
            if (!mounted || _paused) return;
            if (position == null) {
              logWarn('Initial location fix returned null');
              return;
            }
            logDebug(
              'Initial location fix: lat=${position.lat} lng=${position.lng}',
            );
            // Use route distance if available, otherwise fallback to straight-line
            final distance = _calculateRemainingRouteDistance(position) ??
                core_geo.haversineMeters(position, target);
            setState(() {
              _distance = distance;
              _currentPosition = position;
              _startPosition ??= position;
              if (distance.isFinite && distance > 0) {
                _initialDistance = _initialDistance == null
                    ? distance
                    : math.max(_initialDistance!, distance);
              }
            });
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!mounted) return;
            logWarn(
              'Failed to obtain initial location fix',
              error: error,
              stackTrace: stackTrace,
            );
            setState(() => _locationError = error);
          });
    }

    _sub = services.location.positions.listen(
      (position) {
        if (!mounted || _paused) return;
        
        // Throttling: Skip update if too soon or position hasn't changed enough
        final now = DateTime.now();
        final shouldThrottle = _shouldThrottleUpdate(position, now);
        
        // Always update current position for map display (lightweight)
        _currentPosition = position;
        _startPosition ??= position;
        
        if (shouldThrottle) {
          return; // Skip heavy calculations
        }
        
        // Update throttle tracking
        _lastLocationUpdate = now;
        _lastProcessedPosition = position;
        
        final previousDistance = _distance.isFinite
            ? _distance
            : _previousDistance;
        
        // Calculate remaining distance along route (not straight-line)
        double? nextDistance;
        if (target != null) {
          // Use route distance if available, otherwise fallback to straight-line
          nextDistance = _calculateRemainingRouteDistance(position) ??
              core_geo.haversineMeters(position, target);
        }
        
        final distanceForLog = nextDistance?.toStringAsFixed(1) ?? 'n/a';
        logDebug(
          'Position update: lat=${position.lat} lng=${position.lng} routeDistance=$distanceForLog',
        );
        setState(() {
          if (nextDistance != null) {
            _distance = nextDistance;
            if (nextDistance.isFinite && nextDistance > 0) {
              _initialDistance = _initialDistance == null
                  ? nextDistance
                  : math.max(_initialDistance!, nextDistance);
            }
          }
        });
        if (arrivalMessage != null &&
            nextDistance != null &&
            nextDistance < 8 &&
            !_arrivalAnnounced) {
          _arrivalAnnounced = true;
          logInfo(
            "Reached destination ${widget.destination?.name ?? 'unknown'}",
          );
          setState(() => _instruction = arrivalMessage);
          _playHaptic(_HapticCue.arrived);
          services.tts.stop();
          unawaited(services.tts.speak(arrivalMessage));
          _announcedMilestones.addAll(_guidanceMilestones);
          _lastGuidanceSpoken = DateTime.now();
          return;
        }
        if (nextDistance != null) {
          _handleGuidanceUpdate(
            previous: previousDistance,
            current: nextDistance,
          );
        }

        // Check for upcoming turns
        _checkTurns(position);
        
        // Check for nearby obstacles
        _checkObstacles(position, now);
      },
      onError: (error, stackTrace) {
        if (!mounted) return;
        logWarn('Location stream error', error: error, stackTrace: stackTrace);
        setState(() => _locationError = error);
      },
    );
  }
  
  /// Check for nearby obstacles and update state.
  void _checkObstacles(core_geo.LatLng position, DateTime now) {
    // Throttle obstacle checks
    if (_lastObstacleCheck != null &&
        now.difference(_lastObstacleCheck!) < _obstacleCheckInterval) {
      return;
    }
    _lastObstacleCheck = now;
    
    final monitor = services.obstacleMonitor;
    if (monitor == null || !monitor.enabled) return;
    
    // Check proximity and get nearby obstacles
    monitor.checkProximity(position).then((obstacles) {
      if (!mounted) return;
      if (obstacles.isNotEmpty && obstacles != _nearbyObstacles) {
        setState(() => _nearbyObstacles = obstacles);
      } else if (obstacles.isEmpty && _nearbyObstacles.isNotEmpty) {
        setState(() => _nearbyObstacles = []);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    services.tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dest = widget.destination;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(l10n.navigation),
        ),
        actions: [
          // Toggle map visibility
          Semantics(
            button: true,
            label: _showMap ? 'Hide map' : 'Show map',
            child: IconButton(
              icon: Icon(_showMap ? Icons.map_rounded : Icons.map_outlined),
              iconSize: 28,
              onPressed: () {
                services.haptics.tick();
                HapticFeedback.mediumImpact();
                setState(() => _showMap = !_showMap);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // === MAP (optional, collapsible) ===
            if (_showMap)
              Expanded(
                flex: 2,
                child: _buildMapSection(dest: dest),
              ),
            
            // === MAIN NAVIGATION UI ===
            Expanded(
              flex: _showMap ? 3 : 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // === DESTINATION HEADER ===
                    if (dest != null)
                      _DestinationHeader(
                        destination: dest,
                        l10n: l10n,
                        theme: theme,
                        scheme: scheme,
                      ),
                    
                    if (dest != null) const SizedBox(height: 24),
                    
                    // === DISTANCE DISPLAY (HUGE) ===
                    _DistanceDisplay(
                      distance: _distance,
                      initialDistance: _initialDistance,
                      arrived: _arrivalAnnounced,
                      l10n: l10n,
                      theme: theme,
                      scheme: scheme,
                      onTap: () {
                        // Tap to hear distance
                        services.haptics.tick();
                        HapticFeedback.mediumImpact();
                        final label = _distance.isFinite
                            ? l10n.meters(_distance.toStringAsFixed(0))
                            : l10n.gpsSignalLost;
                        services.tts.speak(label);
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // === NEXT TURN INDICATOR ===
                    if (_nextTurn != null && !_arrivalAnnounced)
                      _TurnIndicator(
                        turn: _nextTurn!,
                        distanceTraveled: _distanceTraveled,
                        theme: theme,
                        scheme: scheme,
                      ),
                    
                    if (_nextTurn != null && !_arrivalAnnounced)
                      const SizedBox(height: 16),
                    
                    // === OBSTACLE WARNING ===
                    if (_nearbyObstacles.isNotEmpty)
                      _ObstacleWarningCard(
                        obstacles: _nearbyObstacles,
                        currentPosition: _currentPosition,
                        theme: theme,
                        scheme: scheme,
                        onTap: () {
                          // Announce obstacles when tapped
                          services.haptics.warning();
                          final obstacleNames = _nearbyObstacles
                              .map((o) => o.name)
                              .join(', ');
                          services.tts.speak(
                            'Hambatan di sekitar: $obstacleNames',
                          );
                        },
                      ),
                    
                    if (_nearbyObstacles.isNotEmpty)
                      const SizedBox(height: 16),
                    
                    // === STATUS / INSTRUCTION ===
                    _InstructionCard(
                      instruction: _instruction,
                      paused: _paused,
                      arrived: _arrivalAnnounced,
                      locationError: _locationError,
                      l10n: l10n,
                      theme: theme,
                      scheme: scheme,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // === ACTION BUTTONS (LARGE) ===
                    _buildActionButtons(l10n, scheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection({required Landmark? dest}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CampusMapView(
          loadingBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Map not available',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          builder: (context, data) => _buildMap(data, dest),
        ),
      ),
    );
  }

  Widget _buildMap(CampusMapData data, Landmark? dest) {
    final destPoint = dest != null ? ll.LatLng(dest.lat, dest.lng) : null;
    final userPoint = _currentPosition != null
        ? _toMapLatLng(_currentPosition!)
        : (_startPosition != null ? _toMapLatLng(_startPosition!) : null);

    final routeColor = const Color(0xFF29B6F6);

    final routeStart = _selectRouteStart(
      userPoint,
      data.overlays.bounds,
      data.overlays.walkways,
    );

    final walkwayEnd = destPoint != null
        ? _nearestPointOnWalkways(data.overlays.walkways, destPoint)
        : null;
    final routePoints = <ll.LatLng>[];
    PathResult? walkwayPath;
    if (routeStart != null && walkwayEnd != null) {
      walkwayPath = computeWalkwayPath(
        data.overlays.walkways,
        routeStart,
        walkwayEnd,
      );
      if (walkwayPath != null) {
        routePoints.addAll(walkwayPath.points);
      }
    }
    if (routePoints.isEmpty && routeStart != null && walkwayEnd != null) {
      routePoints
        ..add(routeStart)
        ..add(walkwayEnd);
    } else if (routePoints.isEmpty && routeStart != null && destPoint != null) {
      routePoints
        ..add(routeStart)
        ..add(destPoint);
    }
    if (destPoint != null &&
        (routePoints.isEmpty ||
            _distanceBetween(routePoints.last, destPoint) > 0.5)) {
      routePoints.add(destPoint);
    }

    // Compute turns if we have a new route
    if (routePoints.length >= 2 && _routePoints.isEmpty) {
      _computeTurns(routePoints, dest?.name);
    }

    final routeLine = routePoints.length >= 2
        ? Polyline(points: routePoints, strokeWidth: 6, color: routeColor)
        : null;

    Polyline? approachLine;
    if (userPoint != null &&
        !_isInsideCampus(userPoint, data.overlays.bounds) &&
        _distanceBetween(userPoint, _mainGate) > 1.0) {
      approachLine = Polyline(
        points: [userPoint, _mainGate],
        strokeWidth: 3,
        color: routeColor.withValues(alpha: 0.5),
      );
    }

    final polylines = <Polyline>[
      ...data.overlays.walkways,
      if (routeLine != null) routeLine,
      if (approachLine != null) approachLine,
    ];

    final markers = <Marker>[];
    if (destPoint != null) {
      markers.add(
        Marker(
          point: destPoint,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: const Icon(Icons.flag, size: 30, color: Colors.redAccent),
        ),
      );
    }
    if (userPoint != null) {
      markers.add(
        Marker(
          point: userPoint,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.navigation_rounded, size: 24, color: routeColor),
          ),
        ),
      );
    }

    final center =
        (userPoint != null && _isInsideCampus(userPoint, data.overlays.bounds))
        ? userPoint
        : (destPoint ?? routeStart ?? data.overlays.center);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 18,
        interactionOptions: const InteractionOptions(
          enableMultiFingerGestureRace: true,
        ),
      ),
      children: [
        TileLayer(
          tileProvider: MbTilesTileProvider(data.db),
          urlTemplate: 'mbtiles://{z}/{x}/{y}',
          tileDimension: 256,
          minZoom: 12,
          maxZoom: 20,
        ),
        PolygonLayer(polygons: data.overlays.buildings),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // === REPEAT INSTRUCTION (Primary action for blind users) ===
        _LargeActionButton(
          icon: Icons.volume_up_rounded,
          label: l10n.repeatInstruction,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          onPressed: () {
            services.haptics.tick();
            HapticFeedback.mediumImpact();
            services.tts.speak(_instruction);
          },
        ),
        
        const SizedBox(height: 12),
        
        // === PAUSE / RESUME ===
        _LargeActionButton(
          icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: _paused ? l10n.resumeNavigation : l10n.pauseNavigation,
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          onPressed: () {
            services.haptics.tick();
            HapticFeedback.mediumImpact();
            setState(() => _paused = !_paused);
            if (_paused) {
              services.tts.stop();
              services.tts.speak(l10n.pauseNavigation);
            } else {
              services.tts.speak(_instruction);
            }
          },
        ),
        
        const SizedBox(height: 12),
        
        // === REPORT OBSTACLE ===
        _LargeActionButton(
          icon: Icons.warning_amber_rounded,
          label: l10n.reportObstacle,
          backgroundColor: scheme.tertiaryContainer,
          foregroundColor: scheme.onTertiaryContainer,
          onPressed: () => _showReportObstacleDialog(),
        ),
        
        const SizedBox(height: 12),
        
        // === END NAVIGATION ===
        _LargeActionButton(
          icon: Icons.close_rounded,
          label: l10n.endNavigation,
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
          onPressed: () {
            services.haptics.confirm();
            HapticFeedback.heavyImpact();
            services.tts.stop();
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }
  
  /// Show the report obstacle dialog.
  Future<void> _showReportObstacleDialog() async {
    final position = _currentPosition;
    if (position == null) {
      // Cannot report without a position
      services.haptics.warning();
      services.tts.speak('Lokasi tidak tersedia. Tunggu sinyal GPS.');
      return;
    }
    
    services.haptics.tick();
    HapticFeedback.mediumImpact();
    
    final obstacleId = await ReportObstacleDialog.show(context, position);
    
    if (obstacleId != null && mounted) {
      // Obstacle reported successfully - refresh nearby obstacles
      _checkObstacles(position, DateTime.now());
    }
  }

  ll.LatLng _toMapLatLng(core_geo.LatLng value) =>
      ll.LatLng(value.lat, value.lng);

  ll.LatLng? _selectRouteStart(
    ll.LatLng? userPoint,
    CampusBounds bounds,
    List<Polyline> walkways,
  ) {
    if (userPoint == null) {
      return _mainGate;
    }
    if (!_isInsideCampus(userPoint, bounds)) {
      return _mainGate;
    }
    return _nearestPointOnWalkways(walkways, userPoint) ?? userPoint;
  }

  bool _isInsideCampus(ll.LatLng? point, CampusBounds bounds) {
    if (point == null) return false;
    return bounds.contains(point);
  }

  ll.LatLng? _nearestPointOnWalkways(
    List<Polyline> polylines,
    ll.LatLng target,
  ) {
    ll.LatLng? bestPoint;
    var bestDistance = double.infinity;
    for (final polyline in polylines) {
      final points = polyline.points;
      for (var i = 0; i < points.length - 1; i++) {
        final candidate = _closestPointOnSegment(
          points[i],
          points[i + 1],
          target,
        );
        final distance = _distanceBetween(candidate, target);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestPoint = candidate;
        }
      }
    }
    return bestPoint;
  }

  ll.LatLng _closestPointOnSegment(ll.LatLng a, ll.LatLng b, ll.LatLng p) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) {
      return a;
    }
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clamped = math.max(0.0, math.min(1.0, t));
    final x = ax + clamped * dx;
    final y = ay + clamped * dy;
    return ll.LatLng(y, x);
  }

  double _distanceBetween(ll.LatLng a, ll.LatLng b) {
    return core_geo.haversineMeters(
      core_geo.LatLng(a.latitude, a.longitude),
      core_geo.LatLng(b.latitude, b.longitude),
    );
  }

  void _resetGuidanceState() {
    _announcedMilestones.clear();
    final current = _distance;
    if (current.isFinite) {
      for (final milestone in _guidanceMilestones) {
        if (current <= milestone) {
          _announcedMilestones.add(milestone);
        }
      }
      _previousDistance = current;
    } else {
      _previousDistance = null;
    }
    _lastGuidanceSpoken = DateTime.now();
  }

  /// Check if location update should be throttled to save CPU
  bool _shouldThrottleUpdate(core_geo.LatLng position, DateTime now) {
    // Calculate actual distance to destination from new position
    final dest = widget.destination;
    if (dest != null) {
      final distToDestination = core_geo.haversineMeters(
        position,
        core_geo.LatLng(dest.lat, dest.lng),
      );
      // Don't throttle if very close to arrival (need precision for arrival detection)
      if (distToDestination < 15) {
        return false;
      }
    }
    
    // Don't throttle if approaching a turn
    if (_nextTurn != null) {
      final distanceToTurn = _nextTurn!.distanceFromStart - _distanceTraveled;
      if (distanceToTurn > 0 && distanceToTurn < 25) {
        return false;
      }
    }
    
    // Throttle by time
    if (_lastLocationUpdate != null) {
      final elapsed = now.difference(_lastLocationUpdate!);
      if (elapsed < _locationUpdateThrottle) {
        return true;
      }
    }
    
    // Throttle by distance moved
    if (_lastProcessedPosition != null) {
      final moved = core_geo.haversineMeters(_lastProcessedPosition!, position);
      if (moved < _minPositionChangeMeter) {
        return true;
      }
    }
    
    return false;
  }

  void _handleGuidanceUpdate({
    required double? previous,
    required double current,
  }) {
    if (!mounted) return;
    _previousDistance = current;
    if (widget.destination == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return;
    }
    final now = DateTime.now();
    for (final milestone in _guidanceMilestones) {
      if (_announcedMilestones.contains(milestone)) {
        continue;
      }
      final crossedThreshold =
          (previous == null || previous > milestone) && current <= milestone;
      if (crossedThreshold) {
        _announcedMilestones.add(milestone);
        final message = milestone > 20
            ? l10n.continueForMeters(milestone.toString())
            : l10n.headTowardsDestination;
        final cue = milestone <= 20 ? _HapticCue.confirm : _HapticCue.straight;
        _announceGuidance(message, cue, now);
        return;
      }
    }
    if (_lastGuidanceSpoken == null ||
        now.difference(_lastGuidanceSpoken!) > const Duration(seconds: 25)) {
      final rounded = current.isFinite
          ? current.clamp(1, 9999).round().toString()
          : _distance.toStringAsFixed(0);
      final message = l10n.continueForMeters(rounded);
      _announceGuidance(message, _HapticCue.tick, now);
    }
  }

  void _announceGuidance(String message, _HapticCue cue, DateTime timestamp) {
    if (!mounted) return;
    if (_instruction == message &&
        _lastGuidanceSpoken != null &&
        timestamp.difference(_lastGuidanceSpoken!) < _guidanceCooldown) {
      return;
    }
    setState(() => _instruction = message);
    _lastGuidanceSpoken = timestamp;
    services.tts.stop();
    unawaited(services.tts.speak(message));
    _playHaptic(cue);
  }

  void _playHaptic(_HapticCue cue) {
    final haptics = services.haptics;
    switch (cue) {
      case _HapticCue.tick:
        unawaited(haptics.tick());
        break;
      case _HapticCue.straight:
        unawaited(haptics.straight());
        break;
      case _HapticCue.confirm:
        unawaited(haptics.confirm());
        break;
      case _HapticCue.arrived:
        unawaited(haptics.arrived());
        break;
      case _HapticCue.none:
        break;
    }
  }

  /// Compute turns from the route path.
  void _computeTurns(List<ll.LatLng> routePoints, String? destinationName) {
    if (routePoints.length < 2) return;

    _routePoints = List.from(routePoints);
    _turns = _turnDetector.detectTurns(routePoints, destinationName: destinationName);
    _announcedTurns.clear();
    _distanceTraveled = 0;

    // Calculate total route distance
    _totalRouteDistance = _calculateTotalRouteDistance();
    logInfo('Total route distance: ${_totalRouteDistance.toStringAsFixed(1)}m');

    if (_turns.isNotEmpty) {
      _nextTurn = _turns.first;
      logInfo('Detected ${_turns.length} turns in route');
      for (final turn in _turns) {
        logDebug('  $turn: ${turn.instruction}');
      }
    }

    // Update displayed distance with route distance
    if (_totalRouteDistance > 0) {
      setState(() {
        _distance = _totalRouteDistance;
        _initialDistance = _totalRouteDistance;
      });
    }
  }

  /// Calculate total distance along the route.
  double _calculateTotalRouteDistance() {
    if (_routePoints.length < 2) return 0;
    
    var total = 0.0;
    for (var i = 0; i < _routePoints.length - 1; i++) {
      total += _distanceBetween(_routePoints[i], _routePoints[i + 1]);
    }
    return total;
  }

  /// Calculate remaining distance along the route from current position.
  double? _calculateRemainingRouteDistance(core_geo.LatLng position) {
    if (_routePoints.isEmpty || _totalRouteDistance <= 0) return null;

    // Use the accurate distance calculation
    final (traveled, _) = _calculateDistanceTraveledAccurate(position);
    final remaining = _totalRouteDistance - traveled;
    
    return remaining.clamp(0, _totalRouteDistance);
  }

  /// Check and announce upcoming turns based on current position.
  void _checkTurns(core_geo.LatLng position) {
    if (_turns.isEmpty || _routePoints.isEmpty) return;

    // Update distance traveled using improved algorithm
    final (traveled, segmentIndex) = _calculateDistanceTraveledAccurate(position);
    _distanceTraveled = traveled;

    // Find the next turn that hasn't been passed
    Turn? nextTurn;
    int nextTurnIndex = -1;
    
    for (var i = 0; i < _turns.length; i++) {
      final turn = _turns[i];
      // Skip if we've passed this turn
      if (turn.distanceFromStart < _distanceTraveled - 5) continue;
      // Skip start instruction if we've moved
      if (turn.distanceFromStart == 0 && _distanceTraveled > 10) continue;
      nextTurn = turn;
      nextTurnIndex = i;
      break;
    }

    if (nextTurn == null) return;
    _nextTurn = nextTurn;

    // Calculate actual distance to this turn
    final distanceToTurn = nextTurn.distanceFromStart - _distanceTraveled;

    // Announce when approaching (within 20 meters)
    if (distanceToTurn > 0 && distanceToTurn <= 20) {
      if (!_announcedTurns.contains(nextTurnIndex)) {
        _announcedTurns.add(nextTurnIndex);
        _announceTurn(nextTurn);
      }
    }

    // Move to next turn when very close (within 5 meters)
    if (distanceToTurn.abs() <= 5) {
      if (nextTurnIndex + 1 < _turns.length) {
        _nextTurn = _turns[nextTurnIndex + 1];
      }
    }
  }

  /// Calculate distance traveled with improved accuracy.
  /// Returns (distanceTraveled, closestSegmentIndex).
  (double, int) _calculateDistanceTraveledAccurate(core_geo.LatLng position) {
    if (_routePoints.isEmpty) return (0, 0);
    if (_routePoints.length == 1) return (0, 0);

    // Find closest point on the route (not just vertex, but on segment)
    var minDistance = double.infinity;
    var closestSegmentIndex = 0;
    double projectionRatio = 0;

    for (var i = 0; i < _routePoints.length - 1; i++) {
      final segStart = _routePoints[i];
      final segEnd = _routePoints[i + 1];
      
      // Find closest point on this segment
      final (closest, ratio) = _closestPointOnSegmentWithRatio(
        segStart, segEnd, 
        ll.LatLng(position.lat, position.lng),
      );
      
      final d = core_geo.haversineMeters(
        position,
        core_geo.LatLng(closest.latitude, closest.longitude),
      );
      
      if (d < minDistance) {
        minDistance = d;
        closestSegmentIndex = i;
        projectionRatio = ratio;
      }
    }

    // Calculate distance traveled
    var traveled = 0.0;
    
    // Add full segments before the closest segment
    for (var i = 0; i < closestSegmentIndex; i++) {
      traveled += _distanceBetween(_routePoints[i], _routePoints[i + 1]);
    }
    
    // Add partial distance in the closest segment
    if (closestSegmentIndex < _routePoints.length - 1) {
      final segmentLength = _distanceBetween(
        _routePoints[closestSegmentIndex], 
        _routePoints[closestSegmentIndex + 1],
      );
      traveled += segmentLength * projectionRatio;
    }

    return (traveled, closestSegmentIndex);
  }

  /// Find closest point on a line segment and return the projection ratio.
  (ll.LatLng, double) _closestPointOnSegmentWithRatio(
    ll.LatLng a, ll.LatLng b, ll.LatLng p,
  ) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    
    if (dx == 0 && dy == 0) {
      return (a, 0);
    }
    
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clamped = math.max(0.0, math.min(1.0, t));
    
    final x = ax + clamped * dx;
    final y = ay + clamped * dy;
    
    return (ll.LatLng(y, x), clamped);
  }

  /// Announce an upcoming turn.
  void _announceTurn(Turn turn) {
    if (turn.instruction == null) return;

    final now = DateTime.now();
    if (_lastGuidanceSpoken != null &&
        now.difference(_lastGuidanceSpoken!) < const Duration(seconds: 3)) {
      return; // Don't announce too frequently
    }

    logInfo('Announcing turn: ${turn.instruction}');
    setState(() => _instruction = turn.instruction!);
    _lastGuidanceSpoken = now;
    
    services.tts.stop();
    unawaited(services.tts.speak(turn.instruction!));

    // Play appropriate haptic
    final cue = _hapticForTurn(turn.type);
    _playHaptic(cue);
  }

  /// Get the appropriate haptic cue for a turn type.
  _HapticCue _hapticForTurn(TurnType type) {
    switch (type) {
      case TurnType.straight:
        return _HapticCue.straight;
      case TurnType.slightLeft:
      case TurnType.slightRight:
        return _HapticCue.tick;
      case TurnType.left:
      case TurnType.right:
        return _HapticCue.confirm;
      case TurnType.sharpLeft:
      case TurnType.sharpRight:
      case TurnType.uTurn:
        return _HapticCue.confirm;
      case TurnType.roundabout:
        return _HapticCue.confirm;
      case TurnType.arrived:
        return _HapticCue.arrived;
    }
  }
}

/// Header showing destination name and type.
class _DestinationHeader extends StatelessWidget {
  const _DestinationHeader({
    required this.destination,
    required this.l10n,
    required this.theme,
    required this.scheme,
  });

  final Landmark destination;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.navigateToName(destination.name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.flag_rounded,
                size: 32,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.navigateToName(destination.name),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large, tappable distance display.
/// Tap to hear the distance spoken aloud.
class _DistanceDisplay extends StatelessWidget {
  const _DistanceDisplay({
    required this.distance,
    required this.initialDistance,
    required this.arrived,
    required this.l10n,
    required this.theme,
    required this.scheme,
    required this.onTap,
  });

  final double distance;
  final double? initialDistance;
  final bool arrived;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distanceText = distance.isFinite
        ? distance.toStringAsFixed(0)
        : '---';
    final label = distance.isFinite
        ? l10n.meters(distanceText)
        : l10n.gpsSignalLost;
    
    // Calculate progress
    double? progress;
    if (initialDistance != null && initialDistance! > 0 && distance.isFinite) {
      progress = 1 - (distance / initialDistance!).clamp(0.0, 1.0);
    }

    final bgColor = arrived
        ? Colors.green
        : (distance.isFinite ? scheme.primary : scheme.error);
    final fgColor = arrived
        ? Colors.white
        : (distance.isFinite ? scheme.onPrimary : scheme.onError);

    return Semantics(
      button: true,
      label: '$label. Tap to hear distance.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              if (arrived)
                Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: fgColor,
                )
              else
                Icon(
                  Icons.navigation_rounded,
                  size: 48,
                  color: fgColor.withValues(alpha: 0.8),
                ),
              
              const SizedBox(height: 12),
              
              // Distance number (HUGE)
              Text(
                arrived ? '✓' : distanceText,
                style: TextStyle(
                  fontSize: arrived ? 48 : 72,
                  fontWeight: FontWeight.w900,
                  color: fgColor,
                  height: 1,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Unit label
              Text(
                arrived ? l10n.arrivedAt('') : (distance.isFinite ? 'meter' : l10n.gpsSignalLost),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: fgColor.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              // Progress bar
              if (progress != null && !arrived) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: fgColor.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.navigationProgress(
                    (progress * 100).clamp(0, 100).round().toString(),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fgColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Instruction card showing current navigation instruction.
class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.instruction,
    required this.paused,
    required this.arrived,
    required this.locationError,
    required this.l10n,
    required this.theme,
    required this.scheme,
  });

  final String instruction;
  final bool paused;
  final bool arrived;
  final Object? locationError;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: instruction,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: paused
                ? scheme.outline
                : (arrived ? Colors.green : scheme.primary),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Status icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  paused
                      ? Icons.pause_circle_rounded
                      : (arrived
                          ? Icons.celebration_rounded
                          : Icons.directions_walk_rounded),
                  size: 28,
                  color: paused
                      ? scheme.outline
                      : (arrived ? Colors.green : scheme.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  paused
                      ? l10n.pauseNavigation
                      : (arrived ? 'Arrived!' : 'Navigating'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: paused
                        ? scheme.outline
                        : (arrived ? Colors.green : scheme.primary),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Instruction text
            Text(
              instruction,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Location error warning
            if (locationError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.gps_off_rounded,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.gpsSignalLost,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Large action button with minimum 72dp height.
class _LargeActionButton extends StatelessWidget {
  const _LargeActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: foregroundColor,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the upcoming turn with icon and distance.
class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({
    required this.turn,
    required this.distanceTraveled,
    required this.theme,
    required this.scheme,
  });

  final Turn turn;
  final double distanceTraveled;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final distanceToTurn = (turn.distanceFromStart - distanceTraveled).clamp(0, 9999);
    final isClose = distanceToTurn < 30;

    return Semantics(
      label: '${turn.instruction}, dalam ${distanceToTurn.round()} meter',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isClose ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClose ? scheme.secondary : scheme.outline.withValues(alpha: 0.3),
            width: isClose ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Turn icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isClose ? scheme.secondary : scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForTurn(turn.type),
                size: 32,
                color: isClose ? scheme.onSecondary : scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 16),
            // Turn info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelForTurn(turn.type),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isClose ? scheme.onSecondaryContainer : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dalam ${distanceToTurn.round()} meter',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isClose
                          ? scheme.onSecondaryContainer.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Distance badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isClose ? scheme.secondary : scheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${distanceToTurn.round()}m',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isClose ? scheme.onSecondary : scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForTurn(TurnType type) {
    switch (type) {
      case TurnType.straight:
        return Icons.arrow_upward_rounded;
      case TurnType.slightLeft:
        return Icons.turn_slight_left_rounded;
      case TurnType.slightRight:
        return Icons.turn_slight_right_rounded;
      case TurnType.left:
        return Icons.turn_left_rounded;
      case TurnType.right:
        return Icons.turn_right_rounded;
      case TurnType.sharpLeft:
        return Icons.turn_sharp_left_rounded;
      case TurnType.sharpRight:
        return Icons.turn_sharp_right_rounded;
      case TurnType.uTurn:
        return Icons.u_turn_left_rounded;
      case TurnType.roundabout:
        return Icons.roundabout_left_rounded;
      case TurnType.arrived:
        return Icons.flag_rounded;
    }
  }

  String _labelForTurn(TurnType type) {
    switch (type) {
      case TurnType.straight:
        return 'Lurus';
      case TurnType.slightLeft:
        return 'Sedikit ke Kiri';
      case TurnType.slightRight:
        return 'Sedikit ke Kanan';
      case TurnType.left:
        return 'Belok Kiri';
      case TurnType.right:
        return 'Belok Kanan';
      case TurnType.sharpLeft:
        return 'Tajam ke Kiri';
      case TurnType.sharpRight:
        return 'Tajam ke Kanan';
      case TurnType.uTurn:
        return 'Putar Balik';
      case TurnType.roundabout:
        return 'Bundaran';
      case TurnType.arrived:
        return 'Tujuan';
    }
  }
}

/// Warning card showing nearby obstacles.
/// 
/// Displays clustered obstacles (when 3+ reports are in the same area)
/// as a single entry with a report count indicator.
class _ObstacleWarningCard extends StatelessWidget {
  const _ObstacleWarningCard({
    required this.obstacles,
    required this.currentPosition,
    required this.theme,
    required this.scheme,
    required this.onTap,
  });

  final List<Obstacle> obstacles;
  final core_geo.LatLng? currentPosition;
  final ThemeData theme;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (obstacles.isEmpty) return const SizedBox.shrink();

    final obstacleCount = obstacles.length;
    final nearestObstacle = obstacles.first;
    
    // Calculate total report count (including obstacles with multiple reports)
    final totalReportCount = obstacles.fold<int>(
      0, 
      (sum, obstacle) => sum + obstacle.reportCount,
    );
    
    // Check if the nearest obstacle has multiple reports
    final hasMultipleReports = nearestObstacle.hasMultipleReports;
    
    // Calculate distance to nearest obstacle
    double? distance;
    if (currentPosition != null) {
      distance = core_geo.haversineMeters(
        currentPosition!,
        core_geo.LatLng(nearestObstacle.lat, nearestObstacle.lng),
      );
    }
    
    // Build title text based on report count
    String titleText;
    if (hasMultipleReports) {
      titleText = 'Area Hambatan (${nearestObstacle.reportCount} laporan)';
    } else if (obstacleCount == 1) {
      titleText = 'Hambatan Terdeteksi';
    } else {
      titleText = '$obstacleCount Hambatan Terdeteksi';
    }
    
    // Build subtitle text
    String subtitleText;
    if (hasMultipleReports) {
      subtitleText = nearestObstacle.type.displayName;
    } else {
      subtitleText = nearestObstacle.name;
    }
    
    // Build semantics label
    String semanticsLabel;
    if (hasMultipleReports) {
      semanticsLabel = 'Peringatan: Area dengan ${nearestObstacle.reportCount} '
          'laporan ${nearestObstacle.type.displayName}. Ketuk untuk detail.';
    } else {
      semanticsLabel = 'Peringatan: $obstacleCount hambatan di sekitar. '
          '${nearestObstacle.name}. Ketuk untuk detail.';
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.error,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Warning icon with cluster indicator
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      size: 32,
                      color: scheme.onError,
                    ),
                  ),
                  // Show report count badge for obstacles with multiple reports
                  if (hasMultipleReports || totalReportCount > obstacleCount)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: scheme.errorContainer,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '$totalReportCount',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onTertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Obstacle info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (distance != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${distance.round()} meter',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Distance badge
              if (distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${distance.round()}m',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onError,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
