import 'package:flutter/widgets.dart';

import 'app_state.dart';
import 'services.dart';

/// Top-level dependency container that exposes [AppState] and [AppServices]
/// to the widget tree without relying on global singletons.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.state,
    required this.services,
    required super.child,
  });

  final AppState state;
  final AppServices services;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!;
  }

  static AppState stateOf(BuildContext context) => of(context).state;
  static AppServices servicesOf(BuildContext context) => of(context).services;

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) {
    return state != oldWidget.state || services != oldWidget.services;
  }
}

extension AppScopeX on BuildContext {
  AppState get appState => AppScope.stateOf(this);
  AppServices get services => AppScope.servicesOf(this);
}
