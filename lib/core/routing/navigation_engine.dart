import '../types/geo.dart';
import 'graph.dart';

class RouteStep {
  final LatLng position;
  final String instruction;
  final double distanceMeters;
  const RouteStep({
    required this.position,
    required this.instruction,
    required this.distanceMeters,
  });
}

class RoutePlan {
  final List<RouteStep> steps;
  final double totalMeters;
  const RoutePlan({required this.steps, required this.totalMeters});
}

/// Very small stub for routing against a campus graph.
/// Replace with A*/Dijkstra over [CampusGraph] edges and rich instructions.
class NavigationEngine {
  final CampusGraph graph;
  const NavigationEngine(this.graph);

  RoutePlan plan(LatLng start, LatLng end) {
    // Stub: straight-line placeholder
    final d = haversineMeters(start, end);
    return RoutePlan(
      steps: [
        RouteStep(
          position: start,
          instruction: 'Head towards destination',
          distanceMeters: d,
        ),
        RouteStep(
          position: end,
          instruction: 'You have arrived',
          distanceMeters: 0,
        ),
      ],
      totalMeters: d,
    );
  }
}
