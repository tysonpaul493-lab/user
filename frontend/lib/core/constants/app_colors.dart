import 'package:flutter/material.dart';

/// App color tokens matching the reference UI design
/// featuring rich emergency red gradients, crisp light backgrounds,
/// and accessible high-contrast accents.
class AppColors {
  // Primary Red Palette (from the reference design)
  static const Color primaryRed = Color(0xFFE21B1B);
  static const Color primaryRedLight = Color(0xFFFF4D4D);
  static const Color primaryRedDark = Color(0xFFB71212);
  static const Color primaryRedGlow = Color(0x66FF3B30);

  // Red Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF4B4B), Color(0xFFD91616)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFCE1111)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerPillGradient = LinearGradient(
    colors: [Color(0xFFFF4444), Color(0xFFDF1818)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient pulseRingGradient = LinearGradient(
    colors: [Color(0x33FF3B30), Color(0x05FF3B30)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardAccentGradient = LinearGradient(
    colors: [Color(0xFFFFF1F1), Colors.white],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Neutral Colors
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color textPrimary = Color(0xFF1E2124);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF1F3F5);

  // Status & Utility Colors
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFEFF6FF);

  // Emergency 108 / 112 Colors
  static const Color emergencyBlue = Color(0xFF1E3A8A);
  static const Color gold = Color(0xFFF59E0B);

  // Shadows
  static List<BoxShadow> redGlowShadow = [
    BoxShadow(
      color: const Color(0xFFE21B1B).withValues(alpha: 0.35),
      blurRadius: 22,
      spreadRadius: 2,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> softCardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> floatButtonShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      spreadRadius: 1,
      offset: const Offset(0, 4),
    ),
  ];
}
