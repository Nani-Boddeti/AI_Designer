import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utility functions for color theory and outfit harmony scoring.
class ColorHarmony {
  ColorHarmony._();

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parses a hex color string (with or without leading '#') to a [Color].
  /// Returns [Colors.grey] as a fallback for invalid inputs.
  static Color parseHex(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '').trim();
      if (cleaned.length == 6) {
        final value = int.parse('FF$cleaned', radix: 16);
        return Color(value);
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return Colors.grey;
  }

  // ---------------------------------------------------------------------------
  // Distance & hue helpers
  // ---------------------------------------------------------------------------

  /// Euclidean RGB distance between two colors (0–441).
  static double colorDistance(Color a, Color b) {
    final dr = ((a.r - b.r) * 255.0);
    final dg = ((a.g - b.g) * 255.0);
    final db = ((a.b - b.b) * 255.0);
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  /// Returns the hue (0–360) of a [Color].
  static double _hue(Color c) {
    final hslColor = HSLColor.fromColor(c);
    return hslColor.hue;
  }

  /// Angular distance between two hues on the 360° wheel.
  static double _hueDiff(Color a, Color b) {
    final diff = (_hue(a) - _hue(b)).abs();
    return diff > 180 ? 360 - diff : diff;
  }

  // ---------------------------------------------------------------------------
  // Harmony predicates
  // ---------------------------------------------------------------------------

  /// Two colors are complementary when their hues are ~180° apart (±30°).
  static bool isComplementary(Color a, Color b) {
    return (_hueDiff(a, b) - 180).abs() <= 30;
  }

  /// Two colors are analogous when their hues are within 30°.
  static bool isAnalogous(Color a, Color b) {
    return _hueDiff(a, b) <= 30;
  }

  /// Two colors are triadic when their hues are ~120° apart (±25°).
  static bool isTriadic(Color a, Color b) {
    return (_hueDiff(a, b) - 120).abs() <= 25;
  }

  /// Returns true if a color is considered neutral (low saturation).
  static bool isNeutral(Color c) {
    return HSLColor.fromColor(c).saturation < 0.15;
  }

  // ---------------------------------------------------------------------------
  // Outfit harmony scoring
  // ---------------------------------------------------------------------------

  /// Scores how harmonious an outfit palette is.
  ///
  /// Returns a value from 0.0 (clashing) to 1.0 (perfectly harmonious).
  /// Algorithm:
  ///  1. Neutrals are always welcome — don't penalise them.
  ///  2. Non-neutral pairs earn points for being analogous, complementary,
  ///     or triadic; lose points for clashing (large hue gap that is not
  ///     complementary/triadic).
  ///  3. Final score is averaged across all non-neutral pairs.
  static double scoreOutfitHarmony(List<Color> colors) {
    if (colors.isEmpty) return 0.5;
    if (colors.length == 1) return 0.8;

    final nonNeutral = colors.where((c) => !isNeutral(c)).toList();
    if (nonNeutral.isEmpty) return 1.0; // all neutrals → perfect

    double total = 0.0;
    int pairs = 0;

    for (int i = 0; i < nonNeutral.length; i++) {
      for (int j = i + 1; j < nonNeutral.length; j++) {
        final a = nonNeutral[i];
        final b = nonNeutral[j];
        pairs++;
        if (isAnalogous(a, b)) {
          total += 1.0;
        } else if (isComplementary(a, b)) {
          total += 0.9;
        } else if (isTriadic(a, b)) {
          total += 0.75;
        } else {
          // Penalty scaled by how far from any harmony the pair is.
          final hd = _hueDiff(a, b);
          // Worst clash is around 60–90° off from any reference point.
          final penalty = 1.0 - (math.min(hd, 180 - hd) / 90.0) * 0.8;
          total += penalty.clamp(0.0, 0.6);
        }
      }
    }

    if (pairs == 0) return 0.8;
    return (total / pairs).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Returns a human-readable harmony label for a score.
  static String harmonyLabel(double score) {
    if (score >= 0.85) return 'Excellent match';
    if (score >= 0.7) return 'Good harmony';
    if (score >= 0.5) return 'Decent combo';
    return 'Needs work';
  }
}
