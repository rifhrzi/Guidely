import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app/app_scope.dart';
import '../../core/data/landmarks.dart';
import '../../core/destination/landmark_matcher.dart';
import '../../core/logging/logger.dart';
import '../../core/permissions/permissions.dart';
import '../../l10n/app_localizations.dart';
import 'confirm_destination_page.dart';

/// Voice destination page optimized for blind/low-vision users.
///
/// Design principles:
/// - Auto-start listening on page open
/// - Large, clear visual feedback (for low-vision users)
/// - Strong haptic feedback at all state changes
/// - Clear audio cues for status changes
class VoiceDestinationPage extends StatefulWidget {
  const VoiceDestinationPage({super.key});

  @override
  State<VoiceDestinationPage> createState() => _VoiceDestinationPageState();
}

enum _VoiceFlowState {
  idle,
  requestingPermission,
  listening,
  processing,
  error,
  permissionDenied,
}

class _VoiceDestinationPageState extends State<VoiceDestinationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final TextEditingController _manualController = TextEditingController();
  final LandmarkMatcher _matcher = const LandmarkMatcher();

  _VoiceFlowState _state = _VoiceFlowState.idle;
  bool _listening = false;
  String? _recognized;
  String? _errorMessage;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = AppLocalizations.of(context)!;
      final services = context.services;
      services.haptics.tick();
      unawaited(SystemSound.play(SystemSoundType.click));
      final accessibility = services.accessibility;
      if (accessibility.screenReaderOn) {
        unawaited(accessibility.announce(l10n.speakDestinationTitle));
      }
      _startListening(l10n: l10n);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _startListening({
    required AppLocalizations l10n,
    bool reprompt = false,
  }) async {
    final services = context.services;
    setState(() {
      _state = _VoiceFlowState.requestingPermission;
      _errorMessage = null;
      if (!reprompt) {
        _recognized = null;
      }
    });
    
    final permission = await AppPermissions.requestMic();
    if (!mounted) return;
    
    if (!permission.granted) {
      final message = permission.deniedForever
          ? l10n.micPermissionDeniedForever
          : l10n.micPermissionDenied;
      setState(() {
        _state = permission.deniedForever
            ? _VoiceFlowState.permissionDenied
            : _VoiceFlowState.error;
        _listening = false;
        _errorMessage = message;
      });
      await services.haptics.tick();
      await SystemSound.play(SystemSoundType.alert);
      // Announce error for screen reader users
      await services.accessibility.announce(message);
      return;
    }

    setState(() {
      _state = _VoiceFlowState.listening;
      _listening = true;
      _errorMessage = null;
    });

    await services.tts.stop();
    await Future.delayed(const Duration(milliseconds: 250));
    services.haptics.tick();
    _pulse.repeat();
    await SystemSound.play(SystemSoundType.click);
    
    // Announce that we're listening
    await services.accessibility.announce(l10n.listening);
    
    await Future.delayed(const Duration(milliseconds: 250));
    final heard = await services.stt.listenOnce();
    if (!mounted) return;
    _pulse.stop();
    setState(() => _listening = false);

    if (heard == null || heard.trim().isEmpty) {
      _attempts += 1;
      final failure = _attempts >= 2
          ? l10n.listeningFailed
          : l10n.sorryNotCatch;
      setState(() {
        _state = _VoiceFlowState.error;
        _errorMessage = failure;
      });
      await services.haptics.tick();
      await SystemSound.play(SystemSoundType.alert);
      // Announce error
      await services.accessibility.announce(failure);
      return;
    }

    final value = heard.trim();
    await services.haptics.confirm();
    if (!mounted) return;
    await _processDestination(input: value, l10n: l10n, fromManual: false);
  }

  Future<void> _submitManual(AppLocalizations l10n) async {
    final value = _manualController.text.trim();
    await _processDestination(input: value, l10n: l10n, fromManual: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    final canListen =
        _state != _VoiceFlowState.listening &&
        _state != _VoiceFlowState.requestingPermission &&
        _state != _VoiceFlowState.processing;
    final showManual =
        _state == _VoiceFlowState.error ||
        _state == _VoiceFlowState.permissionDenied ||
        _attempts >= 2;

    final headline = _getHeadline(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(l10n.speakDestinationTitle),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // === MAIN MIC BUTTON / INDICATOR ===
              Center(
                child: _buildMicButton(context, canListen, l10n),
              ),
              
              const SizedBox(height: 24),
              
              // === STATUS TEXT ===
              Semantics(
                liveRegion: true,
                child: Text(
                  headline,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _state == _VoiceFlowState.error 
                        ? scheme.error 
                        : scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              if (_errorMessage != null &&
                  _state != _VoiceFlowState.permissionDenied) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // === LISTEN AGAIN BUTTON ===
              if (canListen) ...[
                Semantics(
                  button: true,
                  label: _state == _VoiceFlowState.idle
                      ? l10n.speakDestinationHint
                      : l10n.listenAgain,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.services.haptics.tick();
                      HapticFeedback.mediumImpact();
                      _startListening(
                        l10n: l10n,
                        reprompt: _state != _VoiceFlowState.idle,
                      );
                    },
                    icon: const Icon(Icons.mic_rounded, size: 28),
                    label: Text(
                      _state == _VoiceFlowState.idle
                          ? l10n.speakDestinationHint
                          : l10n.listenAgain,
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(72),
                    ),
                  ),
                ),
              ],
              
              // === PERMISSION DENIED - OPEN SETTINGS ===
              if (_state == _VoiceFlowState.permissionDenied) ...[
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: l10n.openAppSettings,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.services.haptics.tick();
                      AppPermissions.openSettings();
                    },
                    icon: const Icon(Icons.settings_rounded, size: 24),
                    label: Text(l10n.openAppSettings),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                  ),
                ),
              ],
              
              // === MANUAL INPUT (fallback) ===
              if (showManual) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                
                Text(
                  l10n.typeYourDestination,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                
                Semantics(
                  textField: true,
                  label: l10n.enterDestinationHint,
                  child: TextField(
                    controller: _manualController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitManual(l10n),
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: l10n.enterDestinationHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Semantics(
                  button: true,
                  label: l10n.submit,
                  child: FilledButton(
                    onPressed: () {
                      context.services.haptics.tick();
                      HapticFeedback.mediumImpact();
                      _submitManual(l10n);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    child: Text(l10n.submit),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getHeadline(AppLocalizations l10n) {
    switch (_state) {
      case _VoiceFlowState.listening:
        return l10n.listening;
      case _VoiceFlowState.permissionDenied:
        return l10n.micPermissionDeniedForever;
      case _VoiceFlowState.error:
        return _errorMessage ?? l10n.sorryNotCatch;
      case _VoiceFlowState.processing:
        return _recognized ?? l10n.sayYourDestination;
      case _VoiceFlowState.requestingPermission:
        return l10n.requestingPermission;
      case _VoiceFlowState.idle:
        return _recognized ?? l10n.sayYourDestination;
    }
  }

  Widget _buildMicButton(
    BuildContext context,
    bool canListen,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    const size = 160.0;
    
    if (_listening) {
      return _ListeningIndicator(
        animation: _pulse,
        scheme: scheme,
        size: size,
      );
    }
    
    // Tappable mic button when not listening
    return Semantics(
      button: true,
      label: l10n.speakDestination,
      hint: l10n.speakDestinationHint,
      child: GestureDetector(
        onTap: canListen
            ? () {
                context.services.haptics.tick();
                HapticFeedback.mediumImpact();
                _startListening(
                  l10n: l10n,
                  reprompt: _state != _VoiceFlowState.idle,
                );
              }
            : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _state == _VoiceFlowState.error
                ? scheme.errorContainer
                : scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: _state == _VoiceFlowState.error
                  ? scheme.error
                  : scheme.outline,
              width: 3,
            ),
          ),
          child: Icon(
            _state == _VoiceFlowState.error
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            size: 72,
            color: _state == _VoiceFlowState.error
                ? scheme.error
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _processDestination({
    required String input,
    required AppLocalizations l10n,
    required bool fromManual,
  }) async {
    if (!mounted) return;
    final services = context.services;
    final trimmed = input.trim();
    
    if (trimmed.isEmpty) {
      if (fromManual) {
        setState(() => _errorMessage = l10n.enterDestinationHint);
      } else {
        final message = l10n.sorryNotCatch;
        setState(() {
          _state = _VoiceFlowState.error;
          _errorMessage = message;
        });
        await services.haptics.tick();
        unawaited(services.tts.speak(message));
      }
      return;
    }

    final sanitised = _sanitizeQuery(trimmed);
    final query = sanitised.isNotEmpty ? sanitised : trimmed;

    setState(() {
      _recognized = trimmed;
      _state = _VoiceFlowState.processing;
      _errorMessage = null;
      if (fromManual) {
        _manualController.text = trimmed;
      }
    });

    try {
      final store = await LandmarkStore.loadFromAssets();
      final match = _matcher.bestMatch(query: query, store: store);
      if (!mounted) return;

      if (match == null) {
        if (!fromManual) {
          _attempts += 1;
        }
        final message = !fromManual && _attempts < 2
            ? l10n.sorryNotCatch
            : l10n.listeningFailed;
        setState(() {
          _state = _VoiceFlowState.error;
          _errorMessage = message;
        });
        if (!fromManual) {
          await services.haptics.tick();
          unawaited(services.tts.speak(message));
        }
        return;
      }

      _attempts = 0;
      setState(() {
        _recognized = match.name;
        _manualController.text = match.name;
        _errorMessage = null;
      });

      final navigator = Navigator.of(context);
      await navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              ConfirmDestinationPage(text: match.name, initialMatch: match),
        ),
      );
      if (!mounted) return;
      setState(() {
        _state = _VoiceFlowState.idle;
      });
    } catch (error, stackTrace) {
      logWarn(
        'Failed to process destination input',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _state = _VoiceFlowState.error;
        _errorMessage = l10n.listeningFailed;
      });
      if (!fromManual) {
        await services.haptics.tick();
        unawaited(services.tts.speak(l10n.listeningFailed));
      }
    }
  }

  String _sanitizeQuery(String input) {
    final lowered = input.toLowerCase();
    final cleaned = lowered.replaceAll(
      RegExp(r'[^\p{L}\p{Nd}\s]+', unicode: true),
      ' ',
    );
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return '';
    }
    final filtered = tokens
        .where((token) => !_stopWords.contains(token))
        .toList();
    return (filtered.isEmpty ? tokens : filtered).join(' ').trim();
  }
}

/// Animated listening indicator with pulsing rings.
class _ListeningIndicator extends StatelessWidget {
  const _ListeningIndicator({
    required this.animation,
    required this.scheme,
    required this.size,
  });

  final Animation<double> animation;
  final ColorScheme scheme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final wave = animation.value;
        final wave2 = (wave + 0.5) % 1.0;
        
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring 1
              Container(
                width: size * (1 + 0.5 * wave),
                height: size * (1 + 0.5 * wave),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.2 * (1 - wave)),
                ),
              ),
              // Outer pulse ring 2
              Container(
                width: size * (1 + 0.5 * wave2),
                height: size * (1 + 0.5 * wave2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.2 * (1 - wave2)),
                ),
              ),
              // Center circle
              Container(
                width: size * 0.85,
                height: size * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 72,
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const Set<String> _stopWords = {
  'saya',
  'aku',
  'ingin',
  'mau',
  'tolong',
  'pergi',
  'menuju',
  'arah',
  'ke',
  'please',
  'take',
  'me',
  'to',
  'go',
  'the',
  'want',
  'would',
  'like',
};
