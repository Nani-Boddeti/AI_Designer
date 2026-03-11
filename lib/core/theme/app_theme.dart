import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Application theme — VibeVault Indian pastel edition.
/// Light mode only. Warm cream base + dusty rose + marigold + sage green.
class AppTheme {
  AppTheme._();

  // ── Brand palette ──────────────────────────────────────────────────────────
  static const Color primary            = Color(0xFFC17067); // dusty rose
  static const Color primaryContainer   = Color(0xFFFFE8E4); // blush
  static const Color secondary          = Color(0xFFD4956A); // warm marigold
  static const Color secondaryContainer = Color(0xFFFFF3E2); // soft saffron
  static const Color tertiary           = Color(0xFF7B9E7A); // sage green
  static const Color tertiaryContainer  = Color(0xFFD8EBD7); // mint
  static const Color scaffoldBg         = Color(0xFFFAF7F2); // warm cream
  static const Color surfaceColor       = Color(0xFFFFFFFF); // white
  static const Color onBgColor          = Color(0xFF2D2417); // warm charcoal
  static const Color onSurfaceVar       = Color(0xFF7A6E65); // warm grey
  static const Color dividerColor       = Color(0xFFEDE4D8); // soft warm divider
  static const Color inputFill          = Color(0xFFF5EFE8); // input fill

  // Studio lightbox gradient for garment image containers
  static const RadialGradient garmentBackground = RadialGradient(
    center: Alignment.center,
    radius: 0.9,
    colors: [Color(0xFFF8F2EC), Color(0xFFEDE4D8)],
  );

  // Hero gradient (splash, auth)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFE8E4), Color(0xFFFFF3E2), Color(0xFFD8EBD7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color cardTint = Color(0xFFFFE8E4);

  // ── Light theme ────────────────────────────────────────────────────────────
  static ThemeData get light {
    final base = FlexColorScheme.light(
      colors: const FlexSchemeColor(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        secondaryContainer: secondaryContainer,
        tertiary: tertiary,
        tertiaryContainer: tertiaryContainer,
        appBarColor: scaffoldBg,
        error: Color(0xFFB00020),
      ),
      scaffoldBackground: scaffoldBg,
      surface: surfaceColor,
      useMaterial3: true,
      appBarElevation: 0,
      appBarStyle: FlexAppBarStyle.scaffoldBackground,
      subThemesData: const FlexSubThemesData(
        useM2StyleDividerInM3: false,
        defaultRadius: 12.0,
        cardRadius: 16.0,
        elevatedButtonRadius: 14.0,
        outlinedButtonRadius: 14.0,
        filledButtonRadius: 14.0,
        inputDecoratorRadius: 12.0,
        chipRadius: 20.0,
        dialogRadius: 24.0,
        bottomSheetRadius: 28.0,
        // Navigation bar — white bg, rose active
        navigationBarBackgroundSchemeColor: SchemeColor.surface,
        navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
        navigationBarElevation: 8,
        navigationBarHeight: 64,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      fontFamily: 'Roboto',
    ).toTheme;

    return base.copyWith(
      // ── Scaffold & surface ──────────────────────────────────────────────
      scaffoldBackgroundColor: scaffoldBg,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scaffoldBg,
        foregroundColor: onBgColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A7A6E65),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          color: onBgColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        iconTheme: const IconThemeData(color: onBgColor),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: const Color(0x14B07050),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input decoration ────────────────────────────────────────────────
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: inputFill,
        hintStyle: const TextStyle(color: Color(0xFFAA9E97), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB00020), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryContainer,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: onBgColor),
        secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: primary),
        side: const BorderSide(color: Color(0xFFE8DDD6), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom sheet ────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: const Color(0xFFCEC5BE),
        dragHandleSize: const Size(40, 4),
        elevation: 8,
        shadowColor: const Color(0x1A7A6E65),
      ),

      // ── Floating action button ───────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      // ── Elevated button ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined button ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Text button ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── List tile ────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        iconColor: onSurfaceVar,
        titleTextStyle: TextStyle(
          color: onBgColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: onSurfaceVar,
          fontSize: 13,
        ),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: onBgColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: onSurfaceVar,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ── Icon ─────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: onSurfaceVar, size: 22),

      // ── Text ─────────────────────────────────────────────────────────────
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(color: onBgColor),
        displayMedium: base.textTheme.displayMedium?.copyWith(color: onBgColor),
        displaySmall: base.textTheme.displaySmall?.copyWith(color: onBgColor),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          color: onBgColor,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: onBgColor,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: onBgColor,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: onBgColor,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: onBgColor,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          color: onBgColor,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: onBgColor),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: onBgColor),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: onSurfaceVar),
        labelLarge: base.textTheme.labelLarge?.copyWith(color: onBgColor),
        labelMedium: base.textTheme.labelMedium?.copyWith(color: onSurfaceVar),
        labelSmall: base.textTheme.labelSmall?.copyWith(color: onSurfaceVar),
      ),
    );
  }
}
