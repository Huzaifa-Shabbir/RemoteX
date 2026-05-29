import 'package:flutter/material.dart';

class ConnectionFlowColors {
  const ConnectionFlowColors({
    required this.pageBackground,
    required this.cardBackground,
    required this.surfaceBackground,
    required this.mutedText,
    required this.primary,
    required this.successBackground,
    required this.successForeground,
    required this.successText,
    required this.iconCircle,
    required this.shadow,
  });

  final Color pageBackground;
  final Color cardBackground;
  final Color surfaceBackground;
  final Color mutedText;
  final Color primary;
  final Color successBackground;
  final Color successForeground;
  final Color successText;
  final Color iconCircle;
  final List<BoxShadow> shadow;
}

ConnectionFlowColors connectionFlowColors(bool isDark) {
  if (isDark) {
    return ConnectionFlowColors(
      pageBackground: const Color(0xFF0E1117),
      cardBackground: const Color(0xFF161B22),
      surfaceBackground: const Color(0xFF202734),
      mutedText: Colors.white70,
      primary: const Color(0xFF5E83FF),
      successBackground: const Color(0xFF143622),
      successForeground: const Color(0xFF22C55E),
      successText: const Color(0xFFA9EFC3),
      iconCircle: const Color(0xFF242B36),
      shadow: const [],
    );
  }

  return ConnectionFlowColors(
    pageBackground: const Color(0xFFF5F6F8),
    cardBackground: Colors.white,
    surfaceBackground: const Color(0xFFF1F3F6),
    mutedText: Colors.grey.shade600,
    primary: const Color(0xFF2F4BB2),
    successBackground: const Color(0xFFE8F8ED),
    successForeground: const Color(0xFF16A34A),
    successText: Colors.grey.shade700,
    iconCircle: Colors.grey.shade200,
    shadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
