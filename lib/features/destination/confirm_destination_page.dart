import 'package:flutter/material.dart';

import '../../core/app/app_scope.dart';
import '../../core/data/landmarks.dart';
import '../../core/destination/landmark_matcher.dart';
import '../../core/types/geo.dart' as core_geo;
import '../../l10n/app_localizations.dart';
import '../navigation/navigation_page.dart';

class ConfirmDestinationPage extends StatefulWidget {
  const ConfirmDestinationPage({
    super.key,
    required this.text,
    this.initialMatch,
  });

  final String text;
  final Landmark? initialMatch;

  @override
  State<ConfirmDestinationPage> createState() => _ConfirmDestinationPageState();
}

class _ConfirmDestinationPageState extends State<ConfirmDestinationPage> {
  final LandmarkMatcher _matcher = const LandmarkMatcher();
  Landmark? _best;

  @override
  void initState() {
    super.initState();
    _best = widget.initialMatch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        context.services.accessibility.announce(l10n.confirmTitle);
      }
      _load(initialL10n: l10n);
    });
  }

  Future<void> _load({AppLocalizations? initialL10n}) async {
    final existing = widget.initialMatch;
    if (existing != null) {
      await _announceMatch(match: existing, initialL10n: initialL10n);
      return;
    }
    final store = await LandmarkStore.loadFromAssets();
    final match = _matcher.bestMatch(query: widget.text, store: store);
    if (!mounted) return;
    setState(() => _best = match);
    if (match == null) return;
    await _announceMatch(match: match, initialL10n: initialL10n);
  }

  Future<void> _announceMatch({
    required Landmark match,
    AppLocalizations? initialL10n,
  }) async {
    if (!mounted) return;
    final services = context.services;
    final l10n = initialL10n ?? AppLocalizations.of(context);
    final prompt =
        l10n?.navigateToName(match.name) ?? 'Navigate to ${match.name}?';
    await services.tts.speak(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.confirmTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.confirmDestination,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(widget.text, style: Theme.of(context).textTheme.headlineSmall),
            if (_best != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.didYouMean(_best!.name),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.navigation),
                onPressed: () async {
                  final services = context.services;
                  final dest = _best;
                  var initialDistance = 0.0;
                  if (dest == null) {
                    await services.tts.speak(l10n.headTowardsDestination);
                  } else {
                    // Start simulation if enabled in settings
                    if (context.appState.useSimulation.value) {
                      await services.startSimulation(
                        targetLat: dest.lat,
                        targetLng: dest.lng,
                      );
                    }
                    
                    try {
                      final current = await services.location
                          .getCurrentPosition();
                      if (current != null) {
                        final target = core_geo.LatLng(dest.lat, dest.lng);
                        initialDistance = core_geo.haversineMeters(
                          current,
                          target,
                        );
                      }
                    } catch (_) {
                      // Ignore and fall back to default distance.
                    }
                  }
                  if (!context.mounted) return;
                  final navigator = Navigator.of(context);
                  if (dest != null) {
                    context.appState.addRecentDestination(dest);
                  }
                  final instruction = dest != null
                      ? l10n.headTowardsName(dest.name)
                      : l10n.headTowardsDestination;
                  await navigator.push(
                    MaterialPageRoute(
                      builder: (_) => NavigationPage(
                        nextInstruction: instruction,
                        distanceMeters: initialDistance,
                        destination: dest,
                      ),
                    ),
                  );
                  
                  // Stop simulation when returning from navigation
                  if (context.mounted) {
                    services.stopSimulation();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
