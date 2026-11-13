import 'package:flutter/material.dart';

/// Centralized design tokens for SavageBot Neo-Fintech UI.
class AppColors {
  AppColors._();

  // Brand & Status Accents
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDark = Color(0xFF6D28D9);
  static const Color violetLight = Color(0xFFA78BFA);
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseDark = Color(0xFFE11D48);
  static const Color amber = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);

  // Light Palette
  static const Color lightScaffold = Color(0xFFF4F6FB);
  static const Color lightSurface = Colors.white;
  static const Color lightSecondarySurface = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Palette
  static const Color darkScaffold = Color(0xFF090E1A);
  static const Color darkNavigationBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF151F32);
  static const Color darkElevatedSurface = Color(0xFF1E293B);
  static const Color darkSecondarySurface = Color(0xFF0F172A);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkBorderStrong = Color(0xFF334155);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color secondarySurface(bool isDark) =>
      isDark ? darkSecondarySurface : lightSecondarySurface;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

class AppRadius {
  AppRadius._();

  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
}
