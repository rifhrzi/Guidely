import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:navmate/core/app/app_scope.dart';
import 'package:navmate/core/app/app_state.dart';
import 'package:navmate/core/app/services.dart';
import 'package:navmate/features/splash/splash_page.dart';
import 'package:navmate/l10n/app_localizations.dart';
import 'package:navmate/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  final services = AppServices(appState: appState);
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
