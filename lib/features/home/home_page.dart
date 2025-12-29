import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app/app_scope.dart';
import '../../core/app/app_state.dart';
import '../../core/data/landmarks.dart';
import '../../core/types/geo.dart' as core_geo;
import '../../l10n/app_localizations.dart';
import '../destination/voice_destination_page.dart';
import '../favorites/favorites_page.dart';
import '../help/help_page.dart';
import '../map/campus_map_page.dart';
import '../navigation/navigation_page.dart';
import '../settings/settings_page.dart';

/// Home page optimized for blind/low-vision users.
/// 
/// Design principles:
/// - Voice-first: Primary CTA is the large voice button
/// - Simple layout: Linear, predictable navigation
/// - Large touch targets: Minimum 72dp for primary actions
/// - Clear feedback: Haptic and audio on all interactions
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final services = context.services;
      final l10n = AppLocalizations.of(context)!;
      services.accessibility.announce(l10n.homeVoiceWelcome);
    });
  }

  void _onButtonTap(VoidCallback action) {
    final services = context.services;
    services.haptics.tick();
    HapticFeedback.mediumImpact();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appState = context.appState;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(l10n.homeTitle),
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.settings,
            hint: l10n.settingsActionHint,
            child: IconButton(
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings),
              iconSize: 28,
              onPressed: () => _onButtonTap(() {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // === PRIMARY ACTION: Voice Button ===
              _VoiceButton(
                key: const Key('home_primary_cta'),
                l10n: l10n,
                scheme: scheme,
                onTap: () => _onButtonTap(() {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VoiceDestinationPage(),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 24),
              
              // === SECONDARY ACTIONS ===
              _AccessibleActionButton(
                icon: Icons.star_rounded,
                label: l10n.favorites,
                hint: l10n.favoritesActionHint,
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                onTap: () => _onButtonTap(() {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FavoritesPage()),
                  );
                }),
              ),
              
              const SizedBox(height: 12),
              
              _AccessibleActionButton(
                icon: Icons.map_rounded,
                label: l10n.campusMap,
                hint: l10n.mapActionHint,
                backgroundColor: scheme.tertiaryContainer,
                foregroundColor: scheme.onTertiaryContainer,
                onTap: () => _onButtonTap(() {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CampusMapPage()),
                  );
                }),
              ),
              
              const SizedBox(height: 12),
              
              _AccessibleActionButton(
                icon: Icons.help_rounded,
                label: l10n.help,
                hint: l10n.helpActionHint,
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurface,
                onTap: () => _onButtonTap(() {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpPage()),
                  );
                }),
              ),
              
              const SizedBox(height: 24),
              
              // === RECENT DESTINATIONS (if any) ===
              _RecentDestinationsSection(appState: appState, l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large, prominent voice activation button.
/// This is the primary CTA - designed to be easy to find and tap.
class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    super.key,
    required this.l10n,
    required this.scheme,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Semantics(
      button: true,
      label: l10n.speakDestination,
      hint: l10n.speakDestinationHint,
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(24),
        elevation: 4,
        shadowColor: scheme.primary.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 160),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    size: 48,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.speakDestination,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.speakDestinationHint,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Accessible action button with large touch target and clear labels.
class _AccessibleActionButton extends StatelessWidget {
  const _AccessibleActionButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: foregroundColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
                  color: foregroundColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows recent destinations for quick re-navigation.
class _RecentDestinationsSection extends StatelessWidget {
  const _RecentDestinationsSection({
    required this.appState,
    required this.l10n,
  });

  final AppState appState;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RecentDestination>>(
      valueListenable: appState.recentDestinations,
      builder: (context, recents, _) {
        if (recents.isEmpty) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final top = recents.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 24,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.recentDestinations,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...top.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecentDestinationTile(
                entry: entry,
                l10n: l10n,
                onTap: () => _startNavigation(context, entry),
              ),
            )),
          ],
        );
      },
    );
  }

  Future<void> _startNavigation(
    BuildContext context,
    RecentDestination entry,
  ) async {
    final services = context.services;
    final l10n = AppLocalizations.of(context)!;
    
    services.haptics.confirm();
    HapticFeedback.mediumImpact();
    
    final destination = Landmark(
      id: entry.id,
      name: entry.name,
      type: entry.type,
      lat: entry.lat,
      lng: entry.lng,
    );

    context.appState.addRecentDestination(destination);

    // Start simulation if enabled in settings
    if (context.appState.useSimulation.value) {
      await services.startSimulation(
        targetLat: destination.lat,
        targetLng: destination.lng,
      );
    }

    double initialDistance = 0;
    try {
      final current = await services.location.getCurrentPosition();
      if (current != null) {
        final target = core_geo.LatLng(destination.lat, destination.lng);
        initialDistance = core_geo.haversineMeters(current, target);
      }
    } catch (_) {
      // Ignore permission issues
    }

    await services.accessibility.announce(
      l10n.navigateToName(destination.name),
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          nextInstruction: l10n.headTowardsName(destination.name),
          distanceMeters: initialDistance,
          destination: destination,
        ),
      ),
    );

    // Stop simulation when returning from navigation
    if (context.mounted) {
      services.stopSimulation();
    }
  }
}

/// Individual recent destination tile with large touch target.
class _RecentDestinationTile extends StatelessWidget {
  const _RecentDestinationTile({
    required this.entry,
    required this.l10n,
    required this.onTap,
  });

  final RecentDestination entry;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: entry.name,
      hint: l10n.recentReopenHint,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _iconForType(entry.type),
                    size: 24,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatType(entry.type),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.navigation_rounded,
                  size: 24,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatType(String type) {
    if (type.isEmpty) return '';
    final words = type
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) =>
            word.substring(0, 1).toUpperCase() +
            word.substring(1).toLowerCase());
    return words.join(' ');
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'library':
        return Icons.local_library;
      case 'class':
      case 'kelas':
        return Icons.school;
      case 'prayer':
      case 'masjid':
        return Icons.mosque;
      case 'kantin':
        return Icons.restaurant;
      case 'asrama':
        return Icons.home_work;
      default:
        return Icons.place;
    }
  }
}
