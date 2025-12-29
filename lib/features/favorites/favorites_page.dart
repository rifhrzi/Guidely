import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app/app_scope.dart';
import '../../core/data/landmarks.dart';
import '../../core/types/geo.dart' as core_geo;
import '../../l10n/app_localizations.dart';
import '../navigation/navigation_page.dart';

/// Favorites page optimized for blind/low-vision users.
///
/// Design principles:
/// - Large, tappable list items (min 72dp height)
/// - Direct navigation on tap (no intermediate screens)
/// - Clear audio feedback
/// - Grouped by category for easier navigation
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  LandmarkStore? _store;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await LandmarkStore.loadFromAssets();
      if (mounted) setState(() => _store = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final store = _store;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(l10n.favorites),
        ),
      ),
      body: SafeArea(
        child: _error != null
            ? _ErrorView(error: _error!, l10n: l10n)
            : store == null
                ? const _LoadingView()
                : store.items.isEmpty
                    ? _EmptyView(l10n: l10n)
                    : _LandmarkList(
                        landmarks: store.items,
                        l10n: l10n,
                        theme: theme,
                        scheme: scheme,
                        onNavigate: _startNavigation,
                      ),
      ),
    );
  }

  Future<void> _startNavigation(Landmark landmark) async {
    final services = context.services;
    final l10n = AppLocalizations.of(context)!;

    // Provide haptic feedback
    services.haptics.confirm();
    HapticFeedback.mediumImpact();

    // Add to recent destinations
    context.appState.addRecentDestination(landmark);

    // Start simulation if enabled in settings
    if (context.appState.useSimulation.value) {
      await services.startSimulation(
        targetLat: landmark.lat,
        targetLng: landmark.lng,
      );
    }

    // Calculate initial distance (from simulation start position)
    double initialDistance = 0;
    try {
      final current = await services.location.getCurrentPosition();
      if (current != null) {
        final target = core_geo.LatLng(landmark.lat, landmark.lng);
        initialDistance = core_geo.haversineMeters(current, target);
      }
    } catch (_) {
      // Ignore permission issues
    }

    // Announce navigation start
    await services.accessibility.announce(
      l10n.navigateToName(landmark.name),
    );

    if (!mounted) return;
    
    // Navigate to navigation page
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          nextInstruction: l10n.headTowardsName(landmark.name),
          distanceMeters: initialDistance,
          destination: landmark,
        ),
      ),
    );

    // Stop simulation when returning from navigation
    if (mounted) {
      services.stopSimulation();
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading...',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.l10n});

  final Object error;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: scheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load favorites',
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_outline_rounded,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'No favorites yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LandmarkList extends StatelessWidget {
  const _LandmarkList({
    required this.landmarks,
    required this.l10n,
    required this.theme,
    required this.scheme,
    required this.onNavigate,
  });

  final List<Landmark> landmarks;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme scheme;
  final Future<void> Function(Landmark) onNavigate;

  @override
  Widget build(BuildContext context) {
    // Group landmarks by type
    final grouped = <String, List<Landmark>>{};
    for (final landmark in landmarks) {
      final type = landmark.type.isNotEmpty ? landmark.type : 'Other';
      grouped.putIfAbsent(type, () => []).add(landmark);
    }

    final sortedTypes = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: sortedTypes.length,
      itemBuilder: (context, index) {
        final type = sortedTypes[index];
        final items = grouped[type]!;
        
        return _CategorySection(
          type: type,
          items: items,
          theme: theme,
          scheme: scheme,
          l10n: l10n,
          onNavigate: onNavigate,
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.type,
    required this.items,
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.onNavigate,
  });

  final String type;
  final List<Landmark> items;
  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final Future<void> Function(Landmark) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Icon(
                _iconForType(type),
                size: 24,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Semantics(
                header: true,
                child: Text(
                  _formatType(type),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...items.map((landmark) => _LandmarkTile(
          landmark: landmark,
          theme: theme,
          scheme: scheme,
          l10n: l10n,
          onTap: () => onNavigate(landmark),
        )),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatType(String type) {
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
    switch (type.toLowerCase()) {
      case 'library':
        return Icons.local_library_rounded;
      case 'class':
      case 'kelas':
        return Icons.school_rounded;
      case 'prayer':
      case 'masjid':
        return Icons.mosque_rounded;
      case 'kantin':
        return Icons.restaurant_rounded;
      case 'asrama':
        return Icons.home_work_rounded;
      case 'toilet':
      case 'wc':
        return Icons.wc_rounded;
      case 'parkir':
      case 'parking':
        return Icons.local_parking_rounded;
      default:
        return Icons.place_rounded;
    }
  }
}

class _LandmarkTile extends StatelessWidget {
  const _LandmarkTile({
    required this.landmark,
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.onTap,
  });

  final Landmark landmark;
  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: landmark.name,
      hint: l10n.favoritesActionHint,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForType(landmark.type),
                      size: 28,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          landmark.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (landmark.type.isNotEmpty)
                          Text(
                            _formatType(landmark.type),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.navigation_rounded,
                      size: 24,
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatType(String type) {
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
    switch (type.toLowerCase()) {
      case 'library':
        return Icons.local_library_rounded;
      case 'class':
      case 'kelas':
        return Icons.school_rounded;
      case 'prayer':
      case 'masjid':
        return Icons.mosque_rounded;
      case 'kantin':
        return Icons.restaurant_rounded;
      case 'asrama':
        return Icons.home_work_rounded;
      case 'toilet':
      case 'wc':
        return Icons.wc_rounded;
      case 'parkir':
      case 'parking':
        return Icons.local_parking_rounded;
      default:
        return Icons.place_rounded;
    }
  }
}
