import 'package:flutter/widgets.dart';

import '../accessibility/accessibility.dart';
import '../app/app_scope.dart';

class Announcer {
  Announcer.of(BuildContext context)
    : _accessibility = context.services.accessibility;

  final AccessibilityService _accessibility;

  Future<void> speak(String message) {
    return _accessibility.announce(message);
  }
}
