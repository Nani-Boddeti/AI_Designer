import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Application theme using FlexColorScheme for a modern, fashion-forward
/// Material 3 design with deep purple/violet as the primary color.
class AppTheme {
  AppTheme._();

  // Use the deepPurple scheme which gives a rich violet primary.
  static const FlexScheme _scheme = FlexScheme.deepPurple;

  static ThemeData get light => FlexColorScheme.light(
        scheme: _scheme,
        useMaterial3: true,
        appBarElevation: 0,
        subThemesData: const FlexSubThemesData(
          useM2StyleDividerInM3: true,
          defaultRadius: 12.0,
          cardRadius: 16.0,
          elevatedButtonRadius: 12.0,
          outlinedButtonRadius: 12.0,
          filledButtonRadius: 12.0,
          inputDecoratorRadius: 12.0,
          chipRadius: 8.0,
          dialogRadius: 24.0,
          bottomSheetRadius: 24.0,
          navigationBarIndicatorSchemeColor: SchemeColor.secondaryContainer,
          navigationBarSelectedLabelSchemeColor: SchemeColor.secondary,
          navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurface,
          navigationBarSelectedIconSchemeColor: SchemeColor.onSecondaryContainer,
          navigationBarUnselectedIconSchemeColor: SchemeColor.onSurface,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        fontFamily: 'Roboto',
      ).toTheme;

  static ThemeData get dark => FlexColorScheme.dark(
        scheme: _scheme,
        useMaterial3: true,
        appBarElevation: 0,
        subThemesData: const FlexSubThemesData(
          useM2StyleDividerInM3: true,
          defaultRadius: 12.0,
          cardRadius: 16.0,
          elevatedButtonRadius: 12.0,
          outlinedButtonRadius: 12.0,
          filledButtonRadius: 12.0,
          inputDecoratorRadius: 12.0,
          chipRadius: 8.0,
          dialogRadius: 24.0,
          bottomSheetRadius: 24.0,
          navigationBarIndicatorSchemeColor: SchemeColor.secondaryContainer,
          navigationBarSelectedLabelSchemeColor: SchemeColor.secondary,
          navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurface,
          navigationBarSelectedIconSchemeColor: SchemeColor.onSecondaryContainer,
          navigationBarUnselectedIconSchemeColor: SchemeColor.onSurface,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        fontFamily: 'Roboto',
      ).toTheme;

  /// Gradient used on hero / splash backgrounds.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAD42C4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle card background tint.
  static const Color cardTint = Color(0xFFF3E5F5);
}
