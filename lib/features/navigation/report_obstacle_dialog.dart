import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app/app_scope.dart';
import '../../core/obstacle/obstacle.dart';
import '../../core/types/geo.dart';
import '../../l10n/app_localizations.dart';

/// Dialog for reporting obstacles on the route.
/// 
/// Shows a form where users can:
/// - Select obstacle type
/// - Enter a description
/// - Set radius of effect
/// - Optionally set expiration time
class ReportObstacleDialog extends StatefulWidget {
  const ReportObstacleDialog({
    super.key,
    required this.currentPosition,
  });

  /// Current user position (obstacle will be reported at this location).
  final LatLng currentPosition;

  /// Show the dialog and return the reported obstacle ID if successful.
  static Future<String?> show(BuildContext context, LatLng position) async {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportObstacleDialog(currentPosition: position),
    );
  }

  @override
  State<ReportObstacleDialog> createState() => _ReportObstacleDialogState();
}

class _ReportObstacleDialogState extends State<ReportObstacleDialog> {
  ObstacleType _selectedType = ObstacleType.temporary;
  final _descriptionController = TextEditingController();
  double _radiusMeters = 5.0;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Duration options for obstacle expiration
  Duration? _expirationDuration;
  static const List<_ExpirationOption> _expirationOptions = [
    _ExpirationOption(null, 'Tidak terbatas'),
    _ExpirationOption(Duration(hours: 1), '1 jam'),
    _ExpirationOption(Duration(hours: 3), '3 jam'),
    _ExpirationOption(Duration(hours: 6), '6 jam'),
    _ExpirationOption(Duration(hours: 12), '12 jam'),
    _ExpirationOption(Duration(days: 1), '1 hari'),
    _ExpirationOption(Duration(days: 3), '3 hari'),
    _ExpirationOption(Duration(days: 7), '1 minggu'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final services = context.services;
    final syncService = services.obstacleSyncService;

    if (syncService == null) {
      setState(() {
        _errorMessage = 'Layanan tidak tersedia';
      });
      return;
    }

    if (!services.connectivity.isOnline) {
      setState(() {
        _errorMessage = 'Tidak ada koneksi internet';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final expiresAt = _expirationDuration != null
          ? DateTime.now().add(_expirationDuration!)
          : null;

      final obstacleId = await syncService.reportObstacle(
        name: _selectedType.displayName,
        description: _descriptionController.text.trim(),
        lat: widget.currentPosition.lat,
        lng: widget.currentPosition.lng,
        type: _selectedType,
        radiusMeters: _radiusMeters,
        expiresAt: expiresAt,
      );

      if (!mounted) return;

      if (obstacleId != null) {
        // Success - announce and close
        services.haptics.confirm();
        services.tts.speak('Hambatan berhasil dilaporkan');
        Navigator.of(context).pop(obstacleId);
      } else {
        setState(() {
          _errorMessage = 'Gagal melaporkan hambatan';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Title
              Semantics(
                header: true,
                child: Text(
                  l10n.reportObstacle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle with location info
              Text(
                l10n.reportObstacleSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // === OBSTACLE TYPE SELECTION ===
              Text(
                l10n.obstacleType,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ObstacleType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${type.displayName}${isSelected ? ', dipilih' : ''}',
                    child: FilterChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedType = type);
                        }
                      },
                      selectedColor: scheme.primaryContainer,
                      checkmarkColor: scheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // === DESCRIPTION ===
              Text(
                l10n.obstacleDescription,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              Semantics(
                label: l10n.obstacleDescriptionHint,
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.obstacleDescriptionHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // === RADIUS SLIDER ===
              Text(
                l10n.obstacleRadius(_radiusMeters.round()),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              Semantics(
                slider: true,
                value: '${_radiusMeters.round()} meter',
                child: Slider(
                  value: _radiusMeters,
                  min: 2,
                  max: 20,
                  divisions: 18,
                  label: '${_radiusMeters.round()} m',
                  onChanged: (value) {
                    setState(() => _radiusMeters = value);
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // === EXPIRATION ===
              Text(
                l10n.obstacleExpiration,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              Semantics(
                label: l10n.obstacleExpirationHint,
                child: DropdownButtonFormField<Duration?>(
                  initialValue: _expirationDuration,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                  items: _expirationOptions.map((option) {
                    return DropdownMenuItem<Duration?>(
                      value: option.duration,
                      child: Text(option.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _expirationDuration = value);
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // === ERROR MESSAGE ===
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // === SUBMIT BUTTON ===
              Semantics(
                button: true,
                label: l10n.submitReport,
                hint: l10n.submitReportHint,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? l10n.submitting : l10n.submitReport,
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // === CANCEL BUTTON ===
              Semantics(
                button: true,
                label: l10n.cancel,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.cancel),
                ),
              ),
              
              // Extra padding for safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpirationOption {
  const _ExpirationOption(this.duration, this.label);
  final Duration? duration;
  final String label;
}

