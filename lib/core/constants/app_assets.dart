/// Central registry for all brand SVG assets.
///
/// Rule of thumb:
///   gradient / hero backgrounds  →  [AppAssets.hero]
///   compact in-UI usage          →  [AppAssets.appIcon]
///   dark background / dark mode  →  [AppAssets.monoBlack]  (white-on-dark icon)
///   light background / light mode →  [AppAssets.monoWhite] (dark-on-light icon)
abstract final class AppAssets {
  /// Primary brand / hero logo — storytelling variant with vault + weather + style.
  /// Use on: splash screen, auth header, marketing screens.
  static const hero = 'assets/images/vault-hero.svg';

  /// Simplified app icon — strong geometry, survives small sizes.
  /// Use on: AppBar title, compact in-app logo placements.
  static const appIcon = 'assets/images/vault-app-icon.svg';

  /// Monochrome (single-color) icon designed for DARK backgrounds.
  /// Use on: dark-mode AppBars, dark photo overlays, Android status bar,
  /// iOS notification icons.
  static const monoBlack = 'assets/images/vault-monochrome-black.svg';

  /// Monochrome (single-color) icon designed for LIGHT backgrounds.
  /// Use on: light-mode AppBars, print, accessibility / embossing contexts.
  static const monoWhite = 'assets/images/vault-monochrome-white.svg';
}
