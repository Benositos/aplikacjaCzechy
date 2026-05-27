import 'package:flutter/material.dart';

/// Calm Dense color tokens.
///
/// Chrome is grayscale — surfaces, borders, body text live on a 9-step neutral.
/// Color appears only when it carries meaning.
class AppColors {
  AppColors._();

  // Neutral scale — light (paper)
  static const Color paperNeutral0 = Color(0xFFFFFFFF);
  static const Color paperNeutral50 = Color(0xFFFAF8F2);
  static const Color paperNeutral100 = Color(0xFFF2F0E9);
  static const Color paperNeutral200 = Color(0xFFE5E3DD);
  static const Color paperNeutral300 = Color(0xFFCDCBC4);
  static const Color paperNeutral500 = Color(0xFF888880);
  static const Color paperNeutral700 = Color(0xFF3F3F3A);
  static const Color paperNeutral900 = Color(0xFF1A1A1A);
  static const Color paperInk = Color(0xFF0A0A0A);

  // Neutral scale — dark (ink)
  static const Color inkNeutral0 = Color(0xFF0A1116);
  static const Color inkNeutral50 = Color(0xFF0F1820);
  static const Color inkNeutral100 = Color(0xFF131D24);
  static const Color inkNeutral200 = Color(0xFF1B2630);
  static const Color inkNeutral300 = Color(0xFF2A3640);
  static const Color inkNeutral500 = Color(0xFF6B7680);
  static const Color inkNeutral700 = Color(0xFFA8B0B8);
  static const Color inkNeutral900 = Color(0xFFE5EBEF);
  static const Color inkInk = Color(0xFFFFFFFF);

  // Accents — one per page, used only where meaning is present
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentMagenta = Color(0xFFDB2777);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFEAB308);
  static const Color accentRose = Color(0xFFE11D48);
}
