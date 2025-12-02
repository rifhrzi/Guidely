import '../types/geo.dart';
import 'navigation_engine.dart';

typedef Announce = void Function(String message);

/// Decides when and what to announce during navigation.
class AnnouncementScheduler {
  final Announce announce;
  const AnnouncementScheduler(this.announce);

  void start(RoutePlan plan) {
    if (plan.steps.isEmpty) return;
    announce(
      'Navigation started. ${_round(plan.totalMeters)} meters to destination.',
    );
    // In a real app, hook into location updates and call [tick] as user moves.
  }

  void tick(LatLng user, RoutePlan plan) {
    // Placeholder: could compute distance to next step and announce thresholds.
  }

  String _round(double m) => m.toStringAsFixed(0);
}
