import 'dart:async';

import 'package:flutter/services.dart';

abstract class HapticsService {
  Future<void> tick();
  Future<void> confirm();
  Future<void> left();
  Future<void> right();
  Future<void> straight();
  Future<void> arrived();
}

class NoopHaptics implements HapticsService {
  @override
  Future<void> tick() async {}

  @override
  Future<void> confirm() async {}

  @override
  Future<void> arrived() async {}

  @override
  Future<void> left() async {}

  @override
  Future<void> right() async {}

  @override
  Future<void> straight() async {}
}

class DeviceHaptics implements HapticsService {
  @override
  Future<void> tick() async {
    await HapticFeedback.selectionClick();
  }

  @override
  Future<void> confirm() async {
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> arrived() async {
    await HapticFeedback.mediumImpact();
  }

  @override
  Future<void> left() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.selectionClick();
  }

  @override
  Future<void> right() async {
    await HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> straight() async {
    await HapticFeedback.selectionClick();
  }
}
