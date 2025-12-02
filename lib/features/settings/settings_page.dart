import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navmate/l10n/app_localizations.dart';
import 'package:navmate/core/app/app_scope.dart';

/// Settings page optimized for blind/low-vision users.
///
/// Design principles:
/// - Large, clear controls
/// - Grouped by function
/// - Immediate audio feedback for changes
/// - Clear labels and descriptions
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool haptics = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = context.appState;
    final accessibility = context.services.accessibility;
    final tts = context.services.tts;
    final hapticsService = context.services.haptics;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(l10n.settings),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // === VOICE SECTION ===
            _SectionHeader(
              icon: Icons.record_voice_over_rounded,
              title: 'Voice & Audio',
              scheme: scheme,
            ),
            
            ValueListenableBuilder<bool>(
              valueListenable: state.voiceHints,
              builder: (_, value, __) => _SettingsSwitch(
                title: l10n.voiceHintsSetting,
                subtitle: 'Announce UI elements and actions',
                value: value,
                onChanged: (newValue) {
                  hapticsService.tick();
                  HapticFeedback.selectionClick();
                  state.setVoiceHints(newValue);
                  if (newValue) {
                    tts.speak('Voice hints enabled');
                  }
                },
              ),
            ),
            
            ValueListenableBuilder<bool>(
              valueListenable: state.clarityMode,
              builder: (_, value, __) => _SettingsSwitch(
                title: l10n.clarityModeSetting,
                subtitle: 'Slower, clearer speech for better understanding',
                value: value,
                onChanged: (newValue) {
                  hapticsService.tick();
                  HapticFeedback.selectionClick();
                  state.setClarityMode(newValue);
                  if (newValue) {
                    tts.speak('Clarity mode enabled');
                  }
                },
              ),
            ),
            
            ValueListenableBuilder<double>(
              valueListenable: state.ttsRate,
              builder: (_, rate, __) => _SettingsSlider(
                title: l10n.ttsSpeed,
                subtitle: 'Adjust speech speed (${rate.toStringAsFixed(1)})',
                value: rate,
                min: 0.4,
                max: 1.2,
                divisions: 8,
                onChanged: (newRate) {
                  state.setTtsRate(newRate);
                },
                onChangeEnd: (newRate) {
                  hapticsService.tick();
                  tts.speak('Speed ${newRate.toStringAsFixed(1)}');
                },
              ),
            ),
            
            _SettingsAction(
              title: l10n.testVoice,
              subtitle: 'Hear how the voice sounds',
              icon: Icons.play_circle_rounded,
              onTap: () {
                hapticsService.tick();
                HapticFeedback.mediumImpact();
                tts.speak(l10n.testVoice);
              },
            ),
            
            const SizedBox(height: 24),
            
            // === HAPTICS SECTION ===
            _SectionHeader(
              icon: Icons.vibration_rounded,
              title: l10n.haptics,
              scheme: scheme,
            ),
            
            _SettingsSwitch(
              title: l10n.haptics,
              subtitle: 'Vibration feedback for actions',
              value: haptics,
              onChanged: (value) {
                setState(() => haptics = value);
                if (value) {
                  hapticsService.confirm();
                }
                HapticFeedback.selectionClick();
              },
            ),
            
            const SizedBox(height: 24),
            
            // === ACCESSIBILITY STATUS ===
            _SectionHeader(
              icon: Icons.accessibility_new_rounded,
              title: 'Accessibility Status',
              scheme: scheme,
            ),
            
            _SettingsInfo(
              title: l10n.screenReader,
              value: accessibility.screenReaderOn ? l10n.active : l10n.inactive,
              icon: accessibility.screenReaderOn
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              iconColor: accessibility.screenReaderOn
                  ? Colors.green
                  : scheme.onSurfaceVariant,
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.talkbackNote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // === SIMULATION SECTION (Developer) ===
            _SectionHeader(
              icon: Icons.bug_report_rounded,
              title: 'Mode Simulasi',
              scheme: scheme,
            ),
            
            // Toggle to enable/disable simulation
            ValueListenableBuilder<bool>(
              valueListenable: state.useSimulation,
              builder: (_, useSimulation, __) => _SettingsSwitch(
                title: 'Gunakan Simulasi',
                subtitle: useSimulation 
                    ? 'Navigasi akan mensimulasikan perjalanan'
                    : 'Navigasi menggunakan GPS asli',
                value: useSimulation,
                onChanged: (newValue) {
                  hapticsService.tick();
                  HapticFeedback.selectionClick();
                  state.setUseSimulation(newValue);
                  if (newValue) {
                    tts.speak('Mode simulasi diaktifkan');
                  } else {
                    tts.speak('Mode simulasi dinonaktifkan, menggunakan GPS');
                  }
                },
              ),
            ),
            
            // Show current simulation status
            ValueListenableBuilder<bool>(
              valueListenable: state.simulationMode,
              builder: (_, isSimulating, __) => ValueListenableBuilder<bool>(
                valueListenable: state.useSimulation,
                builder: (_, useSimulation, __) => _SettingsInfo(
                  title: 'Status Saat Ini',
                  value: isSimulating 
                      ? 'Sedang Berjalan' 
                      : (useSimulation ? 'Siap (Menunggu Navigasi)' : 'Nonaktif'),
                  icon: isSimulating
                      ? Icons.directions_walk_rounded
                      : (useSimulation ? Icons.hourglass_empty_rounded : Icons.gps_fixed_rounded),
                  iconColor: isSimulating 
                      ? Colors.orange 
                      : (useSimulation ? Colors.blue : scheme.onSurfaceVariant),
                ),
              ),
            ),
            
            // Walking speed slider (only show when simulation is enabled)
            ValueListenableBuilder<bool>(
              valueListenable: state.useSimulation,
              builder: (_, useSimulation, __) {
                if (!useSimulation) return const SizedBox.shrink();
                return ValueListenableBuilder<double>(
                  valueListenable: state.simulationSpeed,
                  builder: (_, speed, __) => _SettingsSlider(
                    title: 'Kecepatan Jalan',
                    subtitle: '${speed.toStringAsFixed(1)} m/s (${(speed * 3.6).toStringAsFixed(1)} km/h)',
                    value: speed,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    onChanged: (newSpeed) {
                      state.setSimulationSpeed(newSpeed);
                    },
                    onChangeEnd: (newSpeed) {
                      hapticsService.tick();
                      tts.speak('Kecepatan ${newSpeed.toStringAsFixed(1)} meter per detik');
                    },
                  ),
                );
              },
            ),
            
            // Info box
            ValueListenableBuilder<bool>(
              valueListenable: state.useSimulation,
              builder: (_, useSimulation, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: useSimulation 
                        ? scheme.tertiaryContainer 
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            useSimulation ? Icons.info_outline_rounded : Icons.gps_fixed_rounded,
                            color: useSimulation 
                                ? scheme.onTertiaryContainer 
                                : scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            useSimulation ? 'Mode Simulasi Aktif' : 'Mode GPS Aktif',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: useSimulation 
                                  ? scheme.onTertiaryContainer 
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        useSimulation
                            ? 'Saat navigasi dimulai, posisi akan disimulasikan '
                              'berjalan dari gerbang kampus ke tujuan. '
                              'Cocok untuk testing tanpa perlu berjalan sungguhan.'
                            : 'Navigasi akan menggunakan GPS asli dari perangkat. '
                              'Pastikan lokasi diaktifkan dan Anda berada di area kampus.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: useSimulation 
                              ? scheme.onTertiaryContainer 
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // === LANGUAGE SECTION ===
            _SectionHeader(
              icon: Icons.language_rounded,
              title: l10n.language,
              scheme: scheme,
            ),
            
            ValueListenableBuilder<Locale?>(
              valueListenable: state.locale,
              builder: (_, locale, __) {
                final currentLanguage = switch (locale?.languageCode) {
                  null => l10n.systemDefault,
                  'id' => l10n.indonesian,
                  _ => l10n.english,
                };
                return _SettingsAction(
                  title: l10n.language,
                  subtitle: currentLanguage,
                  icon: Icons.chevron_right_rounded,
                  onTap: () async {
                    hapticsService.tick();
                    HapticFeedback.mediumImpact();
                    final choice = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => _LanguageSheet(l10n: l10n),
                    );
                    switch (choice) {
                      case 'system':
                        state.setLocale(null);
                        break;
                      case 'en':
                        state.setLocale(const Locale('en'));
                        break;
                      case 'id':
                        state.setLocale(const Locale('id'));
                        break;
                    }
                  },
                );
              },
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: scheme.primary),
          const SizedBox(width: 12),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Semantics(
      toggled: value,
      label: '$title, $subtitle',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Transform.scale(
                    scale: 1.2,
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
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
}

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Semantics(
      slider: true,
      value: value.toStringAsFixed(1),
      label: '$title, $subtitle',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: value.toStringAsFixed(1),
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slow',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Fast',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Semantics(
      button: true,
      label: '$title, $subtitle',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(icon, size: 28, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsInfo extends StatelessWidget {
  const _SettingsInfo({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Semantics(
      label: '$title: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(icon, size: 28, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              l10n.language,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _LanguageOption(
            icon: Icons.settings_suggest_outlined,
            title: l10n.systemDefault,
            onTap: () => Navigator.pop(context, 'system'),
          ),
          _LanguageOption(
            icon: Icons.language_rounded,
            title: l10n.english,
            onTap: () => Navigator.pop(context, 'en'),
          ),
          _LanguageOption(
            icon: Icons.language_rounded,
            title: l10n.indonesian,
            onTap: () => Navigator.pop(context, 'id'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Semantics(
      button: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(icon, size: 28, color: scheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
}
