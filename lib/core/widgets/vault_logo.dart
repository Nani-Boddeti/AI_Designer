import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_assets.dart';

/// Which logo variant to render.
enum VaultLogoVariant {
  /// Full hero / storytelling logo — for gradient/splash backgrounds.
  hero,

  /// Compact app-icon version — for AppBar titles and small UI placements.
  appIcon,

  /// Auto-selects [AppAssets.monoBlack] (dark bg) or [AppAssets.monoWhite]
  /// (light bg) based on the current theme brightness.
  adaptive,
}

/// Renders the VibeVault logo using the correct SVG asset for the context.
///
/// Usage:
/// ```dart
/// // Splash / auth header (on gradient)
/// VaultLogo(size: 110, variant: VaultLogoVariant.hero)
///
/// // AppBar title area (auto light/dark)
/// VaultLogo(size: 28, variant: VaultLogoVariant.adaptive)
///
/// // Compact in-UI icon
/// VaultLogo(size: 32, variant: VaultLogoVariant.appIcon)
/// ```
class VaultLogo extends StatelessWidget {
  const VaultLogo({
    super.key,
    required this.size,
    this.variant = VaultLogoVariant.hero,
  });

  final double size;
  final VaultLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final asset = switch (variant) {
      VaultLogoVariant.hero => AppAssets.hero,
      VaultLogoVariant.appIcon => AppAssets.appIcon,
      VaultLogoVariant.adaptive =>
        Theme.of(context).brightness == Brightness.dark
            ? AppAssets.monoBlack   // white icon on dark background
            : AppAssets.monoWhite,  // dark icon on light background
    };

    return SvgPicture.asset(asset, width: size, height: size);
  }
}
