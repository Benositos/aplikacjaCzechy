import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  // Tabular figures everywhere — numbers align so the eye can scan a column.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        height: 1.05,
        letterSpacing: -1.0,
        fontFeatures: _tabular,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.5,
        fontFeatures: _tabular,
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.2,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.1,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.6,
      );

  // Monospace numerics — for stat cards, charts, timestamps.
  static TextStyle mono({double fontSize = 14, FontWeight fontWeight = FontWeight.w400}) =>
      GoogleFonts.ibmPlexMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFeatures: _tabular,
      );
}
