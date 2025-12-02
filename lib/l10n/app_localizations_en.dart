// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NavMate';

  @override
  String get homeTitle => 'NavMate';

  @override
  String get welcomeTitle => 'Welcome to NavMate';

  @override
  String get welcomeSubtitle => 'Voice-first campus navigation';

  @override
  String get speakDestination => 'Speak Destination';

  @override
  String get speakDestinationHint => 'Double tap to speak your destination';

  @override
  String get favorites => 'Favorites';

  @override
  String get help => 'Help';

  @override
  String get recentDestinations => 'Recent destinations';

  @override
  String recentVisitedAt(String time) {
    return 'Last used at $time';
  }

  @override
  String get homeVoiceWelcome =>
      'Speak Destination to begin navigation. Quick actions and recent destinations follow.';

  @override
  String get favoritesActionHint => 'Browse your saved campus landmarks.';

  @override
  String get helpActionHint => 'Hear tips and voice commands for NavMate.';

  @override
  String get mapActionHint => 'Open the offline campus map.';

  @override
  String get settingsActionHint =>
      'Adjust voice and accessibility preferences.';

  @override
  String get recentReopenHint =>
      'Double tap to restart navigation to this place.';

  @override
  String navigationProgress(String percent) {
    return '$percent% complete';
  }

  @override
  String get settings => 'Settings';

  @override
  String get campusMap => 'Campus Map';

  @override
  String get speakDestinationTitle => 'Speak Destination';

  @override
  String get listening => 'Listening...';

  @override
  String get sayYourDestination => 'Say your destination';

  @override
  String get listenAgain => 'Listen again';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmTitle => 'Confirm';

  @override
  String didYouSay(Object text) {
    return 'Did you say \'$text\'?';
  }

  @override
  String didYouMean(Object name) {
    return 'Did you mean: $name';
  }

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get tryAgain => 'Try again';

  @override
  String get confirmDestination => 'Confirm destination';

  @override
  String headTowardsName(Object name) {
    return 'Head towards $name';
  }

  @override
  String navigateToName(Object name) {
    return 'Navigate to $name?';
  }

  @override
  String get sorryNotCatch => 'Sorry, I did not catch that';

  @override
  String get micPermissionDenied => 'Microphone permission denied';

  @override
  String get listeningAgain => 'Listening again';

  @override
  String get navigation => 'Navigation';

  @override
  String get headTowardsDestination => 'Head towards destination';

  @override
  String meters(Object count) {
    return '$count meters';
  }

  @override
  String arrivedAt(Object name) {
    return 'You have arrived at $name';
  }

  @override
  String get voiceHintsSetting =>
      'Voice hints (when TalkBack/VoiceOver is off)';

  @override
  String get clarityModeSetting => 'Clarity mode (slower, clearer TTS)';

  @override
  String get screenReader => 'Screen reader';

  @override
  String get active => 'Active (TalkBack/VoiceOver)';

  @override
  String get inactive => 'Inactive';

  @override
  String get haptics => 'Haptics';

  @override
  String get ttsSpeed => 'TTS speed';

  @override
  String get testVoice => 'Test voice';

  @override
  String get talkbackNote =>
      'Note: TalkBack/VoiceOver speed is controlled by system accessibility settings.';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get indonesian => 'Indonesian';

  @override
  String get english => 'English';

  @override
  String get helpBody =>
      'Voice commands:\n- Speak Destination: Say building or place name.\n- Repeat: Hear the last instruction again.\n- Cancel: Stop navigation.\n\nTips:\n- Keep phone upright for better compass accuracy.\n- Allow precise location while navigating.';

  @override
  String get repeatInstruction => 'Repeat';

  @override
  String get pauseNavigation => 'Pause';

  @override
  String get resumeNavigation => 'Resume';

  @override
  String get endNavigation => 'End';

  @override
  String continueForMeters(Object count) {
    return 'Continue for $count meters.';
  }

  @override
  String get offRoute => 'You seem off route. Recalculating...';

  @override
  String get gpsSignalLost => 'GPS signal lost. Hold still and try again.';

  @override
  String get arrivalComplete => 'You have arrived.';

  @override
  String get requestingPermission => 'Requesting microphone permission...';

  @override
  String get micPermissionDeniedForever =>
      'Microphone permission permanently denied. Enable it in Settings to use voice input.';

  @override
  String get listeningFailed =>
      'I couldn\'t understand that. You can try again or type instead.';

  @override
  String get openAppSettings => 'Open Settings';

  @override
  String get typeYourDestination => 'Type your destination';

  @override
  String get enterDestinationHint => 'Enter a building or place name';

  @override
  String get submit => 'Submit';
}
