import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../app/app_state.dart';
import '../logging/logger.dart';

abstract class SttService {
  Future<String?> listenOnce({Duration timeout});
}

class MockStt implements SttService {
  @override
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 5),
  }) async => null;
}

class RealStt implements SttService {
  RealStt({
    required AppState appState,
    Future<void> Function()? beforeStartListening,
  }) : _appState = appState,
       _beforeStartListening = beforeStartListening;

  final AppState _appState;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Future<void> Function()? _beforeStartListening;

  bool _available = false;
  bool _initializing = false;
  List<stt.LocaleName>? _cachedLocales;
  _ActiveSession? _session;

  Future<bool> _ensureInit() async {
    if (_available && _speech.isAvailable) {
      return true;
    }
    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      return _available && _speech.isAvailable;
    }
    _initializing = true;
    try {
      final granted = await _requestMicPermission();
      if (!granted) {
        logWarn('Microphone permission denied for STT');
        _available = false;
        return false;
      }
      final ok = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: false,
        options: [stt.SpeechToText.androidIntentLookup],
      );
      _available = ok;
      if (!ok) {
        logWarn('Speech engine is unavailable');
      }
      return ok;
    } catch (error, stackTrace) {
      logWarn(
        'Failed to initialise speech engine',
        error: error,
        stackTrace: stackTrace,
      );
      _available = false;
      return false;
    } finally {
      _initializing = false;
    }
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  @override
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!await _ensureInit()) {
      return null;
    }

    final localeId = await _resolveLocaleId();
    if (localeId == null) {
      logWarn('Unable to resolve STT locale');
      return null;
    }
    logDebug('Starting STT session using locale $localeId');

    try {
      await _speech.stop();
    } catch (_) {
      // ignore
    }
    try {
      await _speech.cancel();
    } catch (_) {
      // ignore
    }

    // Give the audio system a moment to settle after stopping any previous session
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final session = _ActiveSession(
      localeId: localeId,
      completer: Completer<String?>(),
    );
    _session = session;

    final started = await _startPlatformListening(session, isRestart: false);
    if (!started) {
      _session = null;
      return null;
    }

    Timer? timeoutTimer;
    String? recognised;
    try {
      timeoutTimer = Timer(timeout, () {
        if (!session.completer.isCompleted) {
          session.completer.complete(session.bestPartial);
        }
      });
      recognised = await session.completer.future;
    } finally {
      timeoutTimer?.cancel();
      if (_session == session) {
        _session = null;
      }
      await _stopListening();
    }

    final cleaned = recognised?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      logWarn('No speech recognised within timeout');
      unawaited(_playFailureSound());
      return null;
    }
    logInfo('Speech recognised: "$cleaned"');
    unawaited(_playSuccessSound());
    return cleaned;
  }

  Future<bool> _startPlatformListening(
    _ActiveSession session, {
    required bool isRestart,
  }) async {
    if (_session != session) {
      return false;
    }
    try {
      final beforeStart = _beforeStartListening;
      if (beforeStart != null) {
        try {
          await beforeStart();
        } catch (error, stackTrace) {
          logWarn(
            'beforeStartListening hook failed',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      final started = await _speech.listen(
        onResult: (result) => _handleResult(session, result),
        pauseFor: const Duration(seconds: 6),
        localeId: session.localeId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      if (!started) {
        logWarn('Speech listen request was rejected');
        if (!session.completer.isCompleted) {
          session.completer.complete(session.bestPartial);
        }
        return false;
      }
      logDebug(isRestart ? 'Restarted STT listening' : 'STT listening started');
      return true;
    } catch (error, stackTrace) {
      logWarn(
        'Speech listen request failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!session.completer.isCompleted) {
        session.completer.complete(null);
      }
      return false;
    }
  }

  void _handleResult(
    _ActiveSession session,
    SpeechRecognitionResult recognition,
  ) {
    if (_session != session) {
      return;
    }
    final words = recognition.recognizedWords.trim();
    if (words.isEmpty) {
      return;
    }
    session.bestPartial = words;
    if (recognition.finalResult) {
      session.gotFinal = true;
      if (!session.completer.isCompleted) {
        session.completer.complete(words);
      }
    }
  }

  void _handleStatus(String status) {
    logDebug('STT status update: $status');
    final session = _session;
    if (session == null) {
      return;
    }
    final normalised = status.toLowerCase();
    if (normalised.contains('notlistening') || normalised.contains('done')) {
      if (session.gotFinal) {
        return;
      }
      // Always try to restart if we haven't listened long enough,
      // regardless of restart count (up to a reasonable limit).
      final shouldRestart = session.restarts < _ActiveSession.maxRestarts ||
          !session.hasListenedLongEnough;
      if (shouldRestart && session.restarts < 8) {
        session.restarts += 1;
        logDebug(
          'STT stopped early, restarting (attempt ${session.restarts}, '
          'listenedLongEnough=${session.hasListenedLongEnough})',
        );
        unawaited(_restartListening(session));
      } else if (!session.completer.isCompleted) {
        logDebug('STT giving up after ${session.restarts} restarts');
        session.completer.complete(session.bestPartial);
      }
    }
  }

  Future<void> _restartListening(_ActiveSession session) async {
    // Give the speech engine more time to reset between restarts
    final delay = session.restarts > 2
        ? const Duration(milliseconds: 300)
        : const Duration(milliseconds: 150);
    await Future<void>.delayed(delay);
    if (_session != session) {
      return;
    }
    // Stop any lingering session before restarting
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {
        // ignore
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_session != session) {
      return;
    }
    await _startPlatformListening(session, isRestart: true);
  }

  void _handleError(SpeechRecognitionError error) {
    logWarn(
      'Speech engine error: ${error.errorMsg} (permanent=${error.permanent})',
    );
    final session = _session;
    if (error.permanent) {
      _available = false;
      if (session != null && !session.completer.isCompleted) {
        session.completer.complete(session.bestPartial);
      }
    } else if (session != null && !session.completer.isCompleted) {
      // Non-permanent error - try to restart if we haven't given up yet
      final errorMsg = error.errorMsg.toLowerCase();
      // Common recoverable errors: "error_no_match", "error_speech_timeout"
      if (errorMsg.contains('no_match') || errorMsg.contains('timeout')) {
        if (session.restarts < _ActiveSession.maxRestarts ||
            !session.hasListenedLongEnough) {
          session.restarts += 1;
          logDebug('Recoverable STT error, attempting restart');
          unawaited(_restartListening(session));
        }
      }
    }
  }

  Future<void> _stopListening() async {
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (error) {
        logWarn('Failed to stop speech session gracefully', error: error);
      }
    }
    try {
      await _speech.cancel();
    } catch (error) {
      logWarn('Failed to cancel speech session', error: error);
    }
  }

  Future<String?> _resolveLocaleId() async {
    final locales = _cachedLocales ??= await _speech.locales();
    final appLocale =
        _appState.locale.value ?? ui.PlatformDispatcher.instance.locale;
    final preferred = appLocale
        .toLanguageTag()
        .replaceAll('-', '_')
        .toLowerCase();

    final match = _matchLocale(locales, preferred);
    if (match != null) {
      return match;
    }

    final fallback = await _speech.systemLocale();
    return fallback?.localeId;
  }

  String? _matchLocale(List<stt.LocaleName> locales, String? preferred) {
    if (preferred == null || preferred.isEmpty) {
      return null;
    }
    for (final locale in locales) {
      if (locale.localeId.toLowerCase() == preferred) {
        return locale.localeId;
      }
    }
    final languageOnly = preferred.split('_').first;
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(languageOnly)) {
        return locale.localeId;
      }
    }
    return null;
  }

  Future<void> _playSuccessSound() => SystemSound.play(SystemSoundType.click);

  Future<void> _playFailureSound() => SystemSound.play(SystemSoundType.alert);
}

class _ActiveSession {
  _ActiveSession({required this.localeId, required this.completer})
      : startTime = DateTime.now();

  static const int maxRestarts = 4;
  static const Duration minListenDuration = Duration(seconds: 2);

  final String localeId;
  final Completer<String?> completer;
  final DateTime startTime;

  String? bestPartial;
  bool gotFinal = false;
  int restarts = 0;

  /// Returns true if the session has been listening long enough to consider
  /// giving up when no speech is detected.
  bool get hasListenedLongEnough =>
      DateTime.now().difference(startTime) >= minListenDuration;
}
