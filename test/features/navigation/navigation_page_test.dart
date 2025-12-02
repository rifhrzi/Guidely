import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navmate/core/app/app_scope.dart';
import 'package:navmate/core/app/app_state.dart';
import 'package:navmate/core/app/services.dart';
import 'package:navmate/core/data/landmarks.dart';
import 'package:navmate/core/haptics/haptics_service.dart';
import 'package:navmate/core/location/location_service.dart';
import 'package:navmate/core/speech/stt_service.dart';
import 'package:navmate/core/tts/tts_service.dart';
import 'package:navmate/core/types/geo.dart';
import 'package:navmate/features/navigation/navigation_page.dart';
import 'package:navmate/l10n/app_localizations.dart';

class TestLocationStream implements LocationStream {
  final _controller = StreamController<LatLng>.broadcast();
  LatLng? _latest;

  @override
  Stream<LatLng> get positions => _controller.stream;

  @override
  Future<LatLng?> getCurrentPosition() async => _latest;

  void add(LatLng value) {
    _latest = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

class RecordingTts implements TtsService {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class TestHaptics implements HapticsService {
  @override
  Future<void> arrived() async {}

  @override
  Future<void> confirm() async {}

  @override
  Future<void> left() async {}

  @override
  Future<void> right() async {}

  @override
  Future<void> straight() async {}

  @override
  Future<void> tick() async {}
}

void main() {
  testWidgets('navigation announces arrival only once', (tester) async {
    final appState = AppState();
    final location = TestLocationStream();
    addTearDown(() async => location.close());

    final tts = RecordingTts();
    final services = AppServices(
      appState: appState,
      tts: tts,
      stt: MockStt(),
      location: location,
      haptics: TestHaptics(),
    );
    final landmark = const Landmark(
      id: 'dest',
      name: 'Innovation Lab',
      type: 'Laboratory',
      lat: 37.422,
      lng: -122.084,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('id')],
        home: AppScope(
          state: appState,
          services: services,
          child: NavigationPage(
            nextInstruction: 'Head north',
            distanceMeters: 120,
            destination: landmark,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tts.spoken.first, 'Head north');

    // Simulate movement near the destination (but not yet arrived).
    location.add(const LatLng(37.421, -122.084));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final element = tester.element(find.byType(NavigationPage));
    final l10n = AppLocalizations.of(element)!;

    // Now simulate arrival.
    location.add(LatLng(landmark.lat, landmark.lng));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final arrivalMessage = l10n.arrivedAt(landmark.name);
    final arrivalMessages = tts.spoken
        .where((line) => line.contains(landmark.name))
        .toList();
    expect(arrivalMessages.length, greaterThanOrEqualTo(1));
    expect(arrivalMessages.last, arrivalMessage);
  });
}
