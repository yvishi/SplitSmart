import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// SplitSmart V1.0 — Typography system.
///
/// Rules:
///  • DM Sans for all UI text.
///  • DM Mono for ALL monetary values, with tabularFigures enabled.
///  • Never use Inter, Roboto, or system fonts.
abstract final class AppTextStyles {
  // ─── DM Sans styles ──────────────────────────────────────────────────────────

  /// 32px / 500 — Hero balance. Obsidian or white depending on surface.
  static TextStyle displayMono({Color color = AppColors.obsidian}) =>
      GoogleFonts.dmMono(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        letterSpacing: -1,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 18px / 600 — Screen headers, expense names.
  static TextStyle title({Color color = AppColors.obsidian}) =>
      GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color,
      );

  /// 15px / 500 — Section labels, card subtitles.
  static TextStyle subtitle({Color color = AppColors.obsidian}) =>
      GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// 14px / 400 — General prose, expense descriptions.
  static TextStyle body({Color color = AppColors.obsidian}) =>
      GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// 14px / 500 — Emphasis body (button labels, item names).
  static TextStyle bodyMedium({Color color = AppColors.obsidian}) =>
      GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// 12px / 400 — Timestamps, metadata, audit trail.
  static TextStyle caption({Color color = AppColors.stone}) =>
      GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// 11px / 500 UPPERCASE — Section headers in lists ("RECENT", "YOU OWE").
  static TextStyle overline({Color color = AppColors.stone}) =>
      GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.08 * 11,
        color: color,
      ).copyWith(
        textBaseline: TextBaseline.alphabetic,
      );

  // ─── DM Mono (monetary) styles ───────────────────────────────────────────────
  // CRITICAL: Every rupee amount in the app uses one of these styles.
  // tabularFigures() ensures numbers never shift width when they update.

  /// 14px / 500 DM Mono — All amounts in expense lists. Tabular figures.
  static TextStyle amountMono({Color color = AppColors.obsidian}) =>
      GoogleFonts.dmMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 20px / 500 DM Mono — Currency input field amount.
  static TextStyle amountInput({Color color = AppColors.obsidian}) =>
      GoogleFonts.dmMono(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 28px / 600 DM Mono — Settle-up sheet amount.
  static TextStyle amountLarge({Color color = AppColors.ember}) =>
      GoogleFonts.dmMono(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
