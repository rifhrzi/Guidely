import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:navmate/core/accessibility/accessibility.dart';
import 'package:navmate/core/app/app_scope.dart';
import 'package:navmate/core/app/app_state.dart';
import 'package:navmate/core/app/services.dart';
import 'package:navmate/core/haptics/haptics_service.dart';
import 'package:navmate/core/location/location_service.dart';
import 'package:navmate/core/speech/stt_service.dart';
import 'package:navmate/core/tts/tts_service.dart';
import 'package:navmate/main.dart';

class _FakeTtsService implements TtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class _FakeSttService implements SttService {
  const _FakeSttService();

  @override
  Future<String?> listenOnce({Duration timeout = const Duration(seconds: 5)}) {
    return Future<String?>.value('Main Library');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('primary navigation flows work without platform services', (
    tester,
  ) async {
    final appState = AppState();
    addTearDown(appState.dispose);

    final fakeTts = _FakeTtsService();
    final services = AppServices(
      appState: appState,
      tts: fakeTts,
      stt: const _FakeSttService(),
      location: MockLocationStream(),
      haptics: NoopHaptics(),
      accessibility: AccessibilityService(appState: appState, tts: fakeTts),
    );

    await tester.pumpWidget(
      AppScope(state: appState, services: services, child: const NavMateApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speak Destination'), findsWidgets);

    final favoritesButton = find.byKey(
      const Key('home_quick_action_favorites'),
    );
    expect(favoritesButton, findsOneWidget);
    await tester.tap(favoritesButton);
    await tester.pumpAndSettle();

    expect(find.text('Main Library'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final helpButton = find.byKey(const Key('home_quick_action_help'));
    expect(helpButton, findsOneWidget);
    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Voice commands'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final settingsButton = find.byTooltip('Settings');
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    final voiceHintsSwitchFinder = find.widgetWithText(
      SwitchListTile,
      'Voice hints (when TalkBack/VoiceOver is off)',
    );
    var voiceHintsTile = tester.widget<SwitchListTile>(voiceHintsSwitchFinder);
    expect(voiceHintsTile.value, isTrue);

    await tester.tap(voiceHintsSwitchFinder);
    await tester.pumpAndSettle();

    voiceHintsTile = tester.widget<SwitchListTile>(voiceHintsSwitchFinder);
    expect(voiceHintsTile.value, isFalse);

    final languageTile = find.widgetWithText(ListTile, 'Language');
    await tester.tap(languageTile);
    await tester.pumpAndSettle();

    final indonesianOption = find.text('Indonesian');
    expect(indonesianOption, findsWidgets);
    await tester.tap(indonesianOption.first);
    await tester.pumpAndSettle();

    expect(appState.locale.value?.languageCode, 'id');

    final backButtonFinder = find.byType(BackButton);
    if (backButtonFinder.evaluate().isNotEmpty) {
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();
    }

    final homeCtaVisible =
        find.text('Speak Destination').evaluate().isNotEmpty ||
        find.text('Ucapkan Tujuan').evaluate().isNotEmpty;
    expect(homeCtaVisible, isTrue);
  });
}
