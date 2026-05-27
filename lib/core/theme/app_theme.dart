import 'package:flutter/material.dart';

import 'colors.dart';
import 'text_styles.dart';

/// Calm Dense theme — light (paper) and dark (ink). Both equally polished.
class AppTheme {
  AppTheme._();

  // Motion — gentle and functional. Hover/state changes 120 / 180 / 240 ms.
  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionDefault = Duration(milliseconds: 180);
  static const Duration motionSlow = Duration(milliseconds: 240);
  static const Curve motionCurve = Curves.easeOutCubic;

  // Spacing scale
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space12 = 48;
  static const double space16 = 64;

  // Corner radii
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;

  static ThemeData light() {
    const scheme = ColorScheme.light(
      surface: AppColors.paperNeutral50,
      onSurface: AppColors.paperNeutral900,
      primary: AppColors.paperInk,
      onPrimary: AppColors.paperNeutral0,
      secondary: AppColors.paperNeutral700,
      onSecondary: AppColors.paperNeutral0,
      surfaceContainerLowest: AppColors.paperNeutral0,
      surfaceContainerLow: AppColors.paperNeutral50,
      surfaceContainer: AppColors.paperNeutral100,
      surfaceContainerHigh: AppColors.paperNeutral100,
      surfaceContainerHighest: AppColors.paperNeutral200,
      outline: AppColors.paperNeutral300,
      outlineVariant: AppColors.paperNeutral200,
      error: AppColors.accentRose,
      onError: Colors.white,
    );
    return _build(
      scheme: scheme,
      ink: AppColors.paperInk,
      neutral900: AppColors.paperNeutral900,
      neutral700: AppColors.paperNeutral700,
      neutral500: AppColors.paperNeutral500,
      neutral200: AppColors.paperNeutral200,
      neutral100: AppColors.paperNeutral100,
      neutral0: AppColors.paperNeutral0,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface: AppColors.inkNeutral50,
      onSurface: AppColors.inkNeutral900,
      primary: AppColors.inkInk,
      onPrimary: AppColors.inkNeutral0,
      secondary: AppColors.inkNeutral700,
      onSecondary: AppColors.inkNeutral0,
      surfaceContainerLowest: AppColors.inkNeutral0,
      surfaceContainerLow: AppColors.inkNeutral50,
      surfaceContainer: AppColors.inkNeutral100,
      surfaceContainerHigh: AppColors.inkNeutral100,
      surfaceContainerHighest: AppColors.inkNeutral200,
      outline: AppColors.inkNeutral300,
      outlineVariant: AppColors.inkNeutral200,
      error: AppColors.accentRose,
      onError: Colors.white,
    );
    return _build(
      scheme: scheme,
      ink: AppColors.inkInk,
      neutral900: AppColors.inkNeutral900,
      neutral700: AppColors.inkNeutral700,
      neutral500: AppColors.inkNeutral500,
      neutral200: AppColors.inkNeutral200,
      neutral100: AppColors.inkNeutral100,
      neutral0: AppColors.inkNeutral0,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color ink,
    required Color neutral900,
    required Color neutral700,
    required Color neutral500,
    required Color neutral200,
    required Color neutral100,
    required Color neutral0,
  }) {
    final base = scheme.brightness == Brightness.light
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: ink),
        displayMedium: AppTextStyles.displayMedium.copyWith(color: ink),
        headlineLarge: AppTextStyles.headlineLarge.copyWith(color: neutral900),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(color: neutral900),
        titleLarge: AppTextStyles.titleLarge.copyWith(color: neutral900),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: neutral900),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: neutral700),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: neutral500),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: neutral900),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: neutral500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.brightness == Brightness.light ? neutral0 : neutral100,
        indicatorColor: neutral200,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        height: 64,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: ink, size: 24);
          }
          return IconThemeData(color: neutral500, size: 24);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: neutral200,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: scheme.onPrimary,
          textStyle: AppTextStyles.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: space6, vertical: space3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neutral900,
          side: BorderSide(color: neutral200),
          textStyle: AppTextStyles.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: space6, vertical: space3),
        ),
      ),
    );
  }
}
