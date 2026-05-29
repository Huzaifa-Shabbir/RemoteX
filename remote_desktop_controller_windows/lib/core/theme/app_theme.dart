import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand blue (same in both modes) ───────────────────────
  static const blue       = Color(0xFF3B82F6);
  static const blueDark   = Color(0xFF1D4ED8);
  static const blueLight  = Color(0xFF60A5FA);
  static const cyan       = Color(0xFF06B6D4);
  static const purple     = Color(0xFF8B5CF6);
  static const green      = Color(0xFF22C55E);
  static const orange     = Color(0xFFF59E0B); // light-mode links

  // ── Dark palette ───────────────────────────────────────────
  static const darkBg           = Color(0xFF0F172A);
  static const darkSurface      = Color(0xFF1E293B);
  static const darkSurfaceLight = Color(0xFF263044);
  static const darkBorder       = Color(0xFF2D3F57);
  static const darkCardBg       = Color(0xFF1A2535);
  static const darkFieldBg      = Color(0xFF0F1B2D);
  static const darkTextPrimary  = Color(0xFFFFFFFF);
  static const darkTextSecondary= Color(0xFF94A3B8);
  static const darkTextMuted    = Color(0xFF64748B);
  static const darkLink         = Color(0xFF38BDF8);

  // ── Light palette ──────────────────────────────────────────
  static const lightBg           = Color(0xFFFFFFFF);
  static const lightSurface      = Color(0xFFF8FAFC);
  static const lightSurfaceLight = Color(0xFFF1F5F9);
  static const lightBorder       = Color(0xFFE2E8F0);
  static const lightCardBg       = Color(0xFFFFFFFF);
  static const lightFieldBg      = Color(0xFFFFFFFF);
  static const lightTextPrimary  = Color(0xFF0F172A);
  static const lightTextSecondary= Color(0xFF475569);
  static const lightTextMuted    = Color(0xFF94A3B8);
  static const lightLink         = Color(0xFFF59E0B); // orange in light

  // ── ThemeData ──────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: blue,
      surface: darkSurface,
      onSurface: darkTextPrimary,
    ),
    fontFamily: 'Segoe UI',
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: blue,
      surface: lightSurface,
      onSurface: lightTextPrimary,
    ),
    fontFamily: 'Segoe UI',
  );
}