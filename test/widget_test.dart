import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navmate/core/app/app_scope.dart';
import 'package:navmate/core/app/app_state.dart';
import 'package:navmate/core/app/services.dart';
import 'package:navmate/core/haptics/haptics_service.dart';
import 'package:navmate/core/location/location_service.dart';
import 'package:navmate/core/speech/stt_service.dart';
import 'package:navmate/core/tts/tts_service.dart';
import 'package:navmate/main.dart';

void main() {
  testWidgets('App renders Home with Speak Destination button', (tester) async {
    final appState = AppState();
    final tts = ConsoleTts();
    final services = AppServices(
      appState: appState,
      tts: tts,
      stt: MockStt(),
      location: MockLocationStream(),
      haptics: NoopHaptics(),
    );

    await tester.pumpWidget(
      AppScope(state: appState, services: services, child: const NavMateApp()),
    );

    await tester.pumpAndSettle();

    expect(find.text('NavMate'), findsOneWidget);
    expect(find.byKey(const Key('home_primary_cta')), findsOneWidget);
  });
}
