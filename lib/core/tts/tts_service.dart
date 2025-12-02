import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../app/app_state.dart';

abstract class TtsService {
  Future<void> speak(String text);
  Future<void> stop();
}

class ConsoleTts implements TtsService {
  @override
  Future<void> speak(String text) async {
    // ignore: avoid_print
    print('[TTS] $text');
  }

  @override
  Future<void> stop() async {}
}

class RealTts implements TtsService {
  RealTts({required AppState appState}) : _appState = appState;

  final FlutterTts _tts = FlutterTts();
  final AppState _appState;
  bool _init = false;

  Future<void> _ensureInit() async {
    if (_init) return;
    _init = true;
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<void> speak(String text) async {
    await _ensureInit();
    final baseRate = _appState.ttsRate.value;
    final effectiveRate = _appState.clarityMode.value
        ? baseRate.clamp(0.4, 0.8)
        : baseRate;
    final loc = _appState.locale.value;
    if (loc != null) {
      final tag = _localeToTag(loc);
      if (tag != null) {
        await _tts.setLanguage(tag);
      }
    }
    await _tts.setSpeechRate(effectiveRate.toDouble());
    await _tts.stop();
    for (final chunk in _chunk(text)) {
      if (chunk.isEmpty) continue;
      await _tts.speak(chunk);
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

List<String> _chunk(String text) {
  final parts = <String>[];
  final buffer = StringBuffer();
  for (final codePoint in text.runes) {
    final ch = String.fromCharCode(codePoint);
    buffer.write(ch);
    if (ch == '.' || ch == '!' || ch == '?') {
      parts.add(buffer.toString().trim());
      buffer.clear();
    }
  }
  final rest = buffer.toString().trim();
  if (rest.isNotEmpty) parts.add(rest);
  return parts;
}

String? _localeToTag(Locale loc) {
  final language = loc.languageCode.toLowerCase();
  switch (language) {
    case 'id':
      return 'id-ID';
    case 'en':
      return 'en-US';
  }
  return null;
}
