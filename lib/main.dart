import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app/app_scope.dart';
import 'core/app/app_state.dart';
import 'core/app/services.dart';
import 'core/logging/logger.dart';
import 'features/splash/splash_page.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (optional - may fail if not configured)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logInfo('Firebase initialized successfully');
  } catch (e) {
    logWarn('Firebase initialization failed (online features disabled): $e');
    // App can still work in offline mode without Firebase
  }
  
  final appState = AppState();
  final services = AppServices(appState: appState);
  
  // Initialize async services (obstacle detection, etc.)
  try {
    await services.initializeAsyncServices();
    logInfo('Async services initialized successfully');
  } catch (e) {
    logWarn('Async services initialization failed: $e');
    // App can still work without obstacle detection
  }
  
  runApp(
    AppScope(state: appState, services: services, child: const NavMateApp()),
  );
}

class NavMateApp extends StatelessWidget {
  const NavMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.appState;
    return ValueListenableBuilder<Locale?>(
      valueListenable: appState.locale,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'NavMate',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('id')],
          home: const SplashPage(),
        );
      },
    );
  }
}
