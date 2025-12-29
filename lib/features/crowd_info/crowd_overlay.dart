import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/crowd/crowd_zone.dart';

/// Overlay layer for showing crowd density on the map.
///
/// This creates circle markers for each crowd zone with colors
/// indicating the density level.
class CrowdOverlayLayer extends StatelessWidget {
  const CrowdOverlayLayer({
    super.key,
    required this.zones,
    this.onZoneTap,
  });

  final List<CrowdZone> zones;
  final void Function(CrowdZone zone)? onZoneTap;

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty) return const SizedBox.shrink();

    return CircleLayer(
      circles: zones.map((zone) => _buildCircle(zone)).toList(),
    );
  }

  CircleMarker _buildCircle(CrowdZone zone) {
    final color = _colorForLevel(zone.level);
    
    return CircleMarker(
      point: ll.LatLng(zone.lat, zone.lng),
      radius: zone.radiusMeters,
      useRadiusInMeter: true,
      color: color.withValues(alpha: 0.3),
      borderColor: color,
      borderStrokeWidth: 2,
    );
  }

  Color _colorForLevel(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.empty:
        return Colors.green;
      case CrowdLevel.low:
        return Colors.lightGreen;
      case CrowdLevel.moderate:
        return Colors.amber;
      case CrowdLevel.high:
        return Colors.orange;
      case CrowdLevel.veryHigh:
        return Colors.red;
    }
  }
}

/// Widget showing crowd density indicator.
class CrowdDensityIndicator extends StatelessWidget {
  const CrowdDensityIndicator({
    super.key,
    required this.density,
    required this.level,
    this.onTap,
  });

  final int density;
  final CrowdLevel level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _colorForLevel(level);

    return Semantics(
      button: onTap != null,
      label: 'Kepadatan area: ${level.displayName}, $density persen',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                level.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$density%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForLevel(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.empty:
        return Colors.green;
      case CrowdLevel.low:
        return Colors.lightGreen;
      case CrowdLevel.moderate:
        return Colors.amber;
      case CrowdLevel.high:
        return Colors.orange;
      case CrowdLevel.veryHigh:
        return Colors.red;
    }
  }
}

/// Card showing crowd zone information.
class CrowdZoneCard extends StatelessWidget {
  const CrowdZoneCard({
    super.key,
    required this.zone,
    this.onTap,
  });

  final CrowdZone zone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _colorForLevel(zone.level);

    return Semantics(
      button: onTap != null,
      label: '${zone.name}. ${zone.level.displayName}. '
          '${zone.level.description}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Density indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Icon(
                    _iconForLevel(zone.level),
                    color: color,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Zone info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zone.level.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Density percentage
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${zone.currentDensity}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
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

  Color _colorForLevel(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.empty:
        return Colors.green;
      case CrowdLevel.low:
        return Colors.lightGreen;
      case CrowdLevel.moderate:
        return Colors.amber;
      case CrowdLevel.high:
        return Colors.orange;
      case CrowdLevel.veryHigh:
        return Colors.red;
    }
  }

  IconData _iconForLevel(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.empty:
        return Icons.check_circle_outline_rounded;
      case CrowdLevel.low:
        return Icons.people_outline_rounded;
      case CrowdLevel.moderate:
        return Icons.people_rounded;
      case CrowdLevel.high:
        return Icons.groups_rounded;
      case CrowdLevel.veryHigh:
        return Icons.warning_rounded;
    }
  }
}

/// Legend for crowd density colors.
class CrowdLegend extends StatelessWidget {
  const CrowdLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kepadatan',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...CrowdLevel.values.map((level) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _colorForLevel(level),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  level.displayName,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _colorForLevel(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.empty:
        return Colors.green;
      case CrowdLevel.low:
        return Colors.lightGreen;
      case CrowdLevel.moderate:
        return Colors.amber;
      case CrowdLevel.high:
        return Colors.orange;
      case CrowdLevel.veryHigh:
        return Colors.red;
    }
  }
}

