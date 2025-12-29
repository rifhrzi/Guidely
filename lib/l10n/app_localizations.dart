import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NavMate'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'NavMate'**
  String get homeTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to NavMate'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Voice-first campus navigation'**
  String get welcomeSubtitle;

  /// No description provided for @speakDestination.
  ///
  /// In en, this message translates to:
  /// **'Speak Destination'**
  String get speakDestination;

  /// No description provided for @speakDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to speak your destination'**
  String get speakDestinationHint;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @recentDestinations.
  ///
  /// In en, this message translates to:
  /// **'Recent destinations'**
  String get recentDestinations;

  /// No description provided for @recentVisitedAt.
  ///
  /// In en, this message translates to:
  /// **'Last used at {time}'**
  String recentVisitedAt(String time);

  /// No description provided for @homeVoiceWelcome.
  ///
  /// In en, this message translates to:
  /// **'Speak Destination to begin navigation. Quick actions and recent destinations follow.'**
  String get homeVoiceWelcome;

  /// No description provided for @favoritesActionHint.
  ///
  /// In en, this message translates to:
  /// **'Browse your saved campus landmarks.'**
  String get favoritesActionHint;

  /// No description provided for @helpActionHint.
  ///
  /// In en, this message translates to:
  /// **'Hear tips and voice commands for NavMate.'**
  String get helpActionHint;

  /// No description provided for @mapActionHint.
  ///
  /// In en, this message translates to:
  /// **'Open the offline campus map.'**
  String get mapActionHint;

  /// No description provided for @settingsActionHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust voice and accessibility preferences.'**
  String get settingsActionHint;

  /// No description provided for @recentReopenHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to restart navigation to this place.'**
  String get recentReopenHint;

  /// No description provided for @navigationProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String navigationProgress(String percent);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @campusMap.
  ///
  /// In en, this message translates to:
  /// **'Campus Map'**
  String get campusMap;

  /// No description provided for @speakDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Speak Destination'**
  String get speakDestinationTitle;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @sayYourDestination.
  ///
  /// In en, this message translates to:
  /// **'Say your destination'**
  String get sayYourDestination;

  /// No description provided for @listenAgain.
  ///
  /// In en, this message translates to:
  /// **'Listen again'**
  String get listenAgain;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmTitle;

  /// No description provided for @didYouSay.
  ///
  /// In en, this message translates to:
  /// **'Did you say \'{text}\'?'**
  String didYouSay(Object text);

  /// No description provided for @didYouMean.
  ///
  /// In en, this message translates to:
  /// **'Did you mean: {name}'**
  String didYouMean(Object name);

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @confirmDestination.
  ///
  /// In en, this message translates to:
  /// **'Confirm destination'**
  String get confirmDestination;

  /// No description provided for @headTowardsName.
  ///
  /// In en, this message translates to:
  /// **'Head towards {name}'**
  String headTowardsName(Object name);

  /// No description provided for @navigateToName.
  ///
  /// In en, this message translates to:
  /// **'Navigate to {name}?'**
  String navigateToName(Object name);

  /// No description provided for @sorryNotCatch.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I did not catch that'**
  String get sorryNotCatch;

  /// No description provided for @micPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get micPermissionDenied;

  /// No description provided for @listeningAgain.
  ///
  /// In en, this message translates to:
  /// **'Listening again'**
  String get listeningAgain;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @headTowardsDestination.
  ///
  /// In en, this message translates to:
  /// **'Head towards destination'**
  String get headTowardsDestination;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'{count} meters'**
  String meters(Object count);

  /// No description provided for @arrivedAt.
  ///
  /// In en, this message translates to:
  /// **'You have arrived at {name}'**
  String arrivedAt(Object name);

  /// No description provided for @voiceHintsSetting.
  ///
  /// In en, this message translates to:
  /// **'Voice hints (when TalkBack/VoiceOver is off)'**
  String get voiceHintsSetting;

  /// No description provided for @clarityModeSetting.
  ///
  /// In en, this message translates to:
  /// **'Clarity mode (slower, clearer TTS)'**
  String get clarityModeSetting;

  /// No description provided for @screenReader.
  ///
  /// In en, this message translates to:
  /// **'Screen reader'**
  String get screenReader;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active (TalkBack/VoiceOver)'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @ttsSpeed.
  ///
  /// In en, this message translates to:
  /// **'TTS speed'**
  String get ttsSpeed;

  /// No description provided for @testVoice.
  ///
  /// In en, this message translates to:
  /// **'Test voice'**
  String get testVoice;

  /// No description provided for @talkbackNote.
  ///
  /// In en, this message translates to:
  /// **'Note: TalkBack/VoiceOver speed is controlled by system accessibility settings.'**
  String get talkbackNote;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get indonesian;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @helpBody.
  ///
  /// In en, this message translates to:
  /// **'Voice commands:\n- Speak Destination: Say building or place name.\n- Repeat: Hear the last instruction again.\n- Cancel: Stop navigation.\n\nTips:\n- Keep phone upright for better compass accuracy.\n- Allow precise location while navigating.'**
  String get helpBody;

  /// No description provided for @repeatInstruction.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatInstruction;

  /// No description provided for @pauseNavigation.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseNavigation;

  /// No description provided for @resumeNavigation.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeNavigation;

  /// No description provided for @endNavigation.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endNavigation;

  /// No description provided for @continueForMeters.
  ///
  /// In en, this message translates to:
  /// **'Continue for {count} meters.'**
  String continueForMeters(Object count);

  /// No description provided for @offRoute.
  ///
  /// In en, this message translates to:
  /// **'You seem off route. Recalculating...'**
  String get offRoute;

  /// No description provided for @gpsSignalLost.
  ///
  /// In en, this message translates to:
  /// **'GPS signal lost. Hold still and try again.'**
  String get gpsSignalLost;

  /// No description provided for @arrivalComplete.
  ///
  /// In en, this message translates to:
  /// **'You have arrived.'**
  String get arrivalComplete;

  /// No description provided for @requestingPermission.
  ///
  /// In en, this message translates to:
  /// **'Requesting microphone permission...'**
  String get requestingPermission;

  /// No description provided for @micPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission permanently denied. Enable it in Settings to use voice input.'**
  String get micPermissionDeniedForever;

  /// No description provided for @listeningFailed.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t understand that. You can try again or type instead.'**
  String get listeningFailed;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openAppSettings;

  /// No description provided for @typeYourDestination.
  ///
  /// In en, this message translates to:
  /// **'Type your destination'**
  String get typeYourDestination;

  /// No description provided for @enterDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a building or place name'**
  String get enterDestinationHint;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @reportObstacle.
  ///
  /// In en, this message translates to:
  /// **'Report Obstacle'**
  String get reportObstacle;

  /// No description provided for @reportObstacleHint.
  ///
  /// In en, this message translates to:
  /// **'Report an obstacle or barrier at your current location'**
  String get reportObstacleHint;

  /// No description provided for @reportObstacleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Obstacle will be reported at your current location'**
  String get reportObstacleSubtitle;

  /// No description provided for @obstacleType.
  ///
  /// In en, this message translates to:
  /// **'Obstacle Type'**
  String get obstacleType;

  /// No description provided for @obstacleDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get obstacleDescription;

  /// No description provided for @obstacleDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Briefly describe the obstacle...'**
  String get obstacleDescriptionHint;

  /// No description provided for @obstacleRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius of effect: {meters} meters'**
  String obstacleRadius(int meters);

  /// No description provided for @obstacleExpiration.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get obstacleExpiration;

  /// No description provided for @obstacleExpirationHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how long this obstacle is active'**
  String get obstacleExpirationHint;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// No description provided for @submitReportHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to submit the obstacle report'**
  String get submitReportHint;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Obstacle reported successfully'**
  String get reportSuccess;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to report obstacle'**
  String get reportFailed;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @serviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get serviceUnavailable;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'id': return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
