import 'package:flutter/services.dart';

/// SplitSmart V1.0 — Centralized haptic feedback.
///
/// Never call HapticFeedback directly — always use this class
/// so the haptic map stays consistent and easy to audit.
///
/// Haptic Map:
///  • lightTap    — item assigned to person, quick-action chip tap
///  • shutter     — scanner captures receipt (double light)
///  • settlement  — payment settled (heavy — the money moment)
///  • deletion    — delete expense confirmed (medium)
///  • navSwitch   — bottom nav tab switch (selection)
abstract final class Haptics {
  /// Light tick — item assignment, general taps.
  static Future<void> lightTap() => HapticFeedback.lightImpact();

  /// Double light — camera shutter feel.
  static Future<void> shutter() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Heavy — successful settlement. The money moment.
  static Future<void> settlement() => HapticFeedback.heavyImpact();

  /// Medium — destructive action confirmed (delete expense).
  static Future<void> deletion() => HapticFeedback.mediumImpact();

  /// Selection — nav tab switch.
  static Future<void> navSwitch() => HapticFeedback.selectionClick();
}
