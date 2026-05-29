import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Resolves the correct colour for the current [Brightness].
/// Usage:  RXColors.of(context).bg
class RXColors {
  final bool isDark;
  const RXColors._(this.isDark);

  factory RXColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RXColors._(dark);
  }

  // ── Page backgrounds ───────────────────────────────────────
  Color get bg           => isDark ? AppTheme.darkBg           : AppTheme.lightBg;
  Color get surface      => isDark ? AppTheme.darkSurface      : AppTheme.lightSurface;
  Color get surfaceLight => isDark ? AppTheme.darkSurfaceLight : AppTheme.lightSurfaceLight;
  Color get cardBg       => isDark ? AppTheme.darkCardBg       : AppTheme.lightCardBg;
  Color get fieldBg      => isDark ? AppTheme.darkFieldBg      : AppTheme.lightFieldBg;
  Color get border       => isDark ? AppTheme.darkBorder       : AppTheme.lightBorder;

  // ── Dashboard layout ───────────────────────────────────────
  Color get sidebarBg         => isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get sidebarBorder     => isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get sidebarActive     => AppTheme.blue;
  Color get sidebarActiveTxt  => Colors.white;
  Color get sidebarInactiveTxt=> isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get contentBg         => isDark ? const Color(0xFF0D1424) : const Color(0xFFF8FAFC);
  Color get navbarBg          => isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get navbarBorder      => isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get dashCard          => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get dashCardBorder    => isDark ? const Color(0xFF2D3F57) : const Color(0xFFE2E8F0);
  Color get dropdownBg        => isDark ? const Color(0xFF1E2D42) : Colors.white;
  Color get dropdownBorder    => isDark ? const Color(0xFF2D3F57) : const Color(0xFFE2E8F0);
  Color get dropdownShadow    =>
      isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.10);

  // ── Quick action card icon backgrounds ─────────────────────
  // Start Screen Streaming — blue-ish
  Color get qaScreenBg   => isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);
  Color get qaScreenIcon => isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  // Enable Remote Control — purple
  Color get qaRemoteBg   => isDark ? const Color(0xFF2E1A4A) : const Color(0xFFEDE9FE);
  Color get qaRemoteIcon => isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  // Open Shared Folder — amber/orange
  Color get qaFolderBg   => isDark ? const Color(0xFF3D2800) : const Color(0xFFFEF3C7);
  Color get qaFolderIcon => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  // Connect Device — green
  Color get qaConnectBg  => isDark ? const Color(0xFF0A2E1F) : const Color(0xFFD1FAE5);
  Color get qaConnectIcon=> isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

  // ── Quick action card text ─────────────────────────────────
  Color get qaScreenTitleColor => isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  Color get qaRemoteTitleColor => isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  Color get qaFolderTitleColor => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  Color get qaConnectTitleColor=> isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

  // ── Text ──────────────────────────────────────────────────
  Color get textPrimary   => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get textMuted     => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get link          => isDark ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B);

  // ── Brand (always same) ────────────────────────────────────
  Color get blue      => AppTheme.blue;
  Color get blueDark  => AppTheme.blueDark;
  Color get blueLight => AppTheme.blueLight;
  Color get cyan      => AppTheme.cyan;
  Color get purple    => AppTheme.purple;
  Color get green     => AppTheme.green;

  // ── Auth page specifics ────────────────────────────────────
  bool   get avatarIsGradient => isDark;
  Color  get avatarSolid      => AppTheme.blue;
  double get bgOverlayOpacity => isDark ? 0.65 : 0.30;
  Color  get cardShadow       =>
      isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.08);
  Color  get checkboxBorder   =>
      isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
}