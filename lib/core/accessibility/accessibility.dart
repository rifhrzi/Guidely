import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../app/app_state.dart';
import '../tts/tts_service.dart';

/// Handles accessibility announcements by preferring screen readers and
/// falling back to text-to-speech when voice hints are enabled.
class AccessibilityService {
  AccessibilityService({required AppState appState, required TtsService tts})
    : _appState = appState,
      _tts = tts;

  final AppState _appState;
  final TtsService _tts;

  bool get screenReaderOn =>
      WidgetsBinding.instance.platformDispatcher.semanticsEnabled;

  Future<void> announce(
    String message, {
    TextDirection direction = TextDirection.ltr,
  }) async {
    if (screenReaderOn) {
      await SemanticsService.announce(message, direction);
      return;
    }
    if (_appState.voiceHints.value) {
      await _tts.speak(message);
    }
  }
}
