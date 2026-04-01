import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'spacing.dart';

/// SplitSmart V1.0 — Main theme configuration.
/// Applies the Obsidian+Forest+Chalk design system to Flutter's ThemeData.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          brightness: Brightness.light,
          surface: AppColors.chalk,
          onSurface: AppColors.obsidian,
          primary: AppColors.forest,
          onPrimary: AppColors.white,
          error: AppColors.ember,
        ),
        scaffoldBackgroundColor: AppColors.chalk,
        cardColor: AppColors.white,
        dividerColor: AppColors.border,
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 0.5,
          space: 0,
        ),

        // ─── AppBar ─────────────────────────────────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.chalk,
          foregroundColor: AppColors.obsidian,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          centerTitle: true,
          titleTextStyle: AppTextStyles.title(),
          iconTheme: const IconThemeData(color: AppColors.obsidian, size: 22),
        ),

        // ─── Bottom Navigation ────────────────────────────────────────────
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.forest,
          unselectedItemColor: AppColors.stone,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),

        // ─── Input Fields ─────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          hintStyle: AppTextStyles.body(color: AppColors.stone),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.base,
            vertical: Spacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.ember, width: 1.5),
          ),
        ),

        // ─── Buttons ─────────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.obsidian,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: AppTextStyles.bodyMedium(color: AppColors.white),
            elevation: 0,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: AppTextStyles.bodyMedium(color: AppColors.white),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.stone,
            side: const BorderSide(color: AppColors.border, width: 0.5),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: AppTextStyles.bodyMedium(color: AppColors.stone),
          ),
        ),

        // ─── Cards ────────────────────────────────────────────────────────
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),

        // ─── Text theme (base) ────────────────────────────────────────────
        textTheme: GoogleFonts.dmSansTextTheme().copyWith(
          displayLarge: AppTextStyles.displayMono(),
          titleLarge: AppTextStyles.title(),
          titleMedium: AppTextStyles.subtitle(),
          bodyLarge: AppTextStyles.body(),
          bodyMedium: AppTextStyles.body(),
          bodySmall: AppTextStyles.caption(),
          labelSmall: AppTextStyles.overline(),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          brightness: Brightness.dark,
          surface: AppColors.dmBackground,
          onSurface: AppColors.dmText,
          primary: AppColors.forest,
          onPrimary: AppColors.white,
          error: AppColors.ember,
        ),
        scaffoldBackgroundColor: AppColors.dmBackground,
        cardColor: AppColors.dmSurface,
        dividerColor: AppColors.dmBorder,
        // Semantic colors stay identical in dark mode
        // Full dark theme mirrors light structure above
      );
}
