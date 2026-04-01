import 'package:flutter/material.dart';

/// SplitSmart V1.0 — Single source of truth for all colors.
/// Never use a Color value anywhere else in the codebase.
abstract final class AppColors {
  // ─── Core Neutrals ──────────────────────────────────────────────────────────
  /// Deep near-black. Primary text, dark cards, CTA button fill.
  static const Color obsidian = Color(0xFF0F0E0C);

  /// Off-white page background. NOT pure white — slightly warm.
  static const Color chalk = Color(0xFFF7F6F3);

  /// Pure white card surfaces and elevated elements.
  static const Color white = Color(0xFFFFFFFF);

  /// Secondary surfaces, inactive tabs.
  static const Color subtle = Color(0xFFF0EDE8);

  /// Secondary text, metadata, placeholders.
  static const Color stone = Color(0xFF7A7870);

  /// All borders and dividers. Use at 0.5px weight.
  static const Color border = Color(0xFFE0DDD8);

  // ─── Brand Accent ────────────────────────────────────────────────────────────
  /// Forest green — primary accent, FAB, active states, positive amounts.
  static const Color forest = Color(0xFF1A6B4A);

  // ─── Semantic: Money direction ───────────────────────────────────────────────
  /// "You get back" row background.
  static const Color mint = Color(0xFFE8F5EF);

  /// "You owe" amount text. Deliberately muted — informs, doesn't alarm.
  static const Color ember = Color(0xFFC0392B);

  /// "You owe" row background.
  static const Color rose = Color(0xFFFDF0EE);

  // ─── Semantic: OCR Confidence ────────────────────────────────────────────────
  /// Amber — low-confidence OCR price highlight text.
  static const Color amber = Color(0xFFD4760A);

  /// Amber-bg — uncertain item card background.
  static const Color amberBg = Color(0xFFFEF6E8);

  // ─── Dark Mode equivalents ───────────────────────────────────────────────────
  static const Color dmBackground = Color(0xFF121212);
  static const Color dmSurface = Color(0xFF1E1E1E);
  static const Color dmSurfaceElevated = Color(0xFF252525);
  static const Color dmBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color dmText = Color(0xFFF0EDE8);

  // Semantic colors (Forest, Ember, Mint) are unchanged in dark mode.

  // ─── Hero card internals ─────────────────────────────────────────────────────
  /// Muted white label on the dark hero card.
  static const Color heroLabel = Color(0x73FFFFFF); // rgba(255,255,255,0.45)
}
