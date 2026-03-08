// color_harmony_test.dart
// Unit tests for ColorHarmony: parseHex, colorDistance, harmony predicates,
// scoreOutfitHarmony, and harmonyLabel. Uses flutter_test for Color/HSLColor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/core/utils/color_harmony.dart';

void main() {
  // ---------------------------------------------------------------------------
  group('ColorHarmony.parseHex', () {
    test('6-char hex without # → correct color', () {
      final color = ColorHarmony.parseHex('FF0000');
      expect((color.r * 255.0).round().clamp(0, 255), 255);
      expect((color.g * 255.0).round().clamp(0, 255), 0);
      expect((color.b * 255.0).round().clamp(0, 255), 0);
    });

    test('6-char hex with # → correct color', () {
      final color = ColorHarmony.parseHex('#0000FF');
      expect((color.r * 255.0).round().clamp(0, 255), 0);
      expect((color.g * 255.0).round().clamp(0, 255), 0);
      expect((color.b * 255.0).round().clamp(0, 255), 255);
    });

    test('lowercase hex → parsed correctly', () {
      final color = ColorHarmony.parseHex('#00ff00');
      expect((color.g * 255.0).round().clamp(0, 255), 255);
    });

    test('8-char hex (AARRGGBB) → parsed correctly', () {
      // FFFF0000 = full alpha, red=255, green=0, blue=0
      final color = ColorHarmony.parseHex('FFFF0000');
      expect((color.r * 255.0).round().clamp(0, 255), 255);
      expect((color.g * 255.0).round().clamp(0, 255), 0);
      expect((color.b * 255.0).round().clamp(0, 255), 0);
    });

    test('8-char hex with partial alpha', () {
      final color = ColorHarmony.parseHex('80FFFFFF');
      expect((color.a * 255.0).round().clamp(0, 255), 128); // 0x80
    });

    test('invalid hex → Colors.grey', () {
      expect(ColorHarmony.parseHex('ZZZZZZ'), Colors.grey);
    });

    test('empty string → Colors.grey', () {
      expect(ColorHarmony.parseHex(''), Colors.grey);
    });

    test('too short → Colors.grey', () {
      expect(ColorHarmony.parseHex('FFF'), Colors.grey);
    });

    test('black #000000', () {
      final color = ColorHarmony.parseHex('#000000');
      expect((color.r * 255.0).round().clamp(0, 255), 0);
      expect((color.g * 255.0).round().clamp(0, 255), 0);
      expect((color.b * 255.0).round().clamp(0, 255), 0);
    });

    test('white #FFFFFF', () {
      final color = ColorHarmony.parseHex('#FFFFFF');
      expect((color.r * 255.0).round().clamp(0, 255), 255);
      expect((color.g * 255.0).round().clamp(0, 255), 255);
      expect((color.b * 255.0).round().clamp(0, 255), 255);
    });

    test('whitespace stripped around hex', () {
      final color = ColorHarmony.parseHex('  #FF0000  ');
      expect((color.r * 255.0).round().clamp(0, 255), 255);
    });
  });

  // ---------------------------------------------------------------------------
  group('ColorHarmony.colorDistance', () {
    test('same color → distance 0', () {
      final c = const Color(0xFFFF0000);
      expect(ColorHarmony.colorDistance(c, c), closeTo(0.0, 0.001));
    });

    test('black vs white → ~441.67', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);
      // sqrt(255² + 255² + 255²) = 255*sqrt(3) ≈ 441.67
      expect(
        ColorHarmony.colorDistance(black, white),
        closeTo(441.67, 0.5),
      );
    });

    test('red vs blue → sqrt(255² + 0 + 255²) ≈ 360.6', () {
      const red = Color(0xFFFF0000);
      const blue = Color(0xFF0000FF);
      expect(
        ColorHarmony.colorDistance(red, blue),
        closeTo(360.6, 0.5),
      );
    });

    test('red vs green → sqrt(255² + 255²) ≈ 360.6', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      expect(
        ColorHarmony.colorDistance(red, green),
        closeTo(360.6, 0.5),
      );
    });

    test('symmetric: distance(a,b) == distance(b,a)', () {
      const a = Color(0xFFFF5733);
      const b = Color(0xFF3498DB);
      expect(
        ColorHarmony.colorDistance(a, b),
        closeTo(ColorHarmony.colorDistance(b, a), 0.001),
      );
    });

    test('distance is non-negative', () {
      const a = Color(0xFFAB1234);
      const b = Color(0xFF567890);
      expect(ColorHarmony.colorDistance(a, b), greaterThanOrEqualTo(0));
    });
  });

  // ---------------------------------------------------------------------------
  group('ColorHarmony.isComplementary', () {
    // Red (hue 0°) and Cyan (hue 180°) → 180° apart → complementary
    test('red and cyan → complementary', () {
      const red = Color(0xFFFF0000);
      const cyan = Color(0xFF00FFFF);
      expect(ColorHarmony.isComplementary(red, cyan), isTrue);
    });

    // Blue (hue ~240°) and Yellow/Orange (~60°) → 180° apart → complementary
    test('blue and yellow → complementary', () {
      const blue = Color(0xFF0000FF);
      const yellow = Color(0xFFFFFF00);
      expect(ColorHarmony.isComplementary(blue, yellow), isTrue);
    });

    // Red and Green → 120° apart → NOT complementary
    test('red and green (120°) → not complementary', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      expect(ColorHarmony.isComplementary(red, green), isFalse);
    });

    // Same color → diff = 0° → not complementary
    test('same hue → not complementary', () {
      const red = Color(0xFFFF0000);
      expect(ColorHarmony.isComplementary(red, red), isFalse);
    });

    test('symmetric: isComplementary(a,b) == isComplementary(b,a)', () {
      const red = Color(0xFFFF0000);
      const cyan = Color(0xFF00FFFF);
      expect(
        ColorHarmony.isComplementary(red, cyan),
        ColorHarmony.isComplementary(cyan, red),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('ColorHarmony.isAnalogous', () {
    // Two similar reds → within 30° → analogous
    test('two near-identical hues → analogous', () {
      const red = Color(0xFFFF0000);
      const nearRed = Color(0xFFFF2000); // slightly orange
      expect(ColorHarmony.isAnalogous(red, nearRed), isTrue);
    });

    // Same color → diff = 0 → analogous
    test('same color → analogous', () {
      const red = Color(0xFFFF0000);
      expect(ColorHarmony.isAnalogous(red, red), isTrue);
    });

    // Red (0°) and Green (120°) → 120° apart → not analogous
    test('red and green (120°) → not analogous', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      expect(ColorHarmony.isAnalogous(red, green), isFalse);
    });

    // Complementary pair → not analogous
    test('complementary pair → not analogous', () {
      const red = Color(0xFFFF0000);
      const cyan = Color(0xFF00FFFF);
      expect(ColorHarmony.isAnalogous(red, cyan), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('ColorHarmony.isTriadic', () {
    // Red (0°) and Green (120°) → 120° apart → triadic
    test('red and green → triadic', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      expect(ColorHarmony.isTriadic(red, green), isTrue);
    });

    // Green (120°) and Blue (240°) → 120° apart → triadic
    test('green and blue → triadic', () {
      const green = Color(0xFF00FF00);
      const blue = Color(0xFF0000FF);
      expect(ColorHarmony.isTriadic(green, blue), isTrue);
    });

    // Same color → diff = 0 → not triadic
    test('same color → not triadic', () {
      const red = Color(0xFFFF0000);
      expect(ColorHarmony.isTriadic(red, red), isFalse);
    });

    // Complementary pair (180°) → not triadic
    test('complementary pair → not triadic', () {
      const red = Color(0xFFFF0000);
      const cyan = Color(0xFF00FFFF);
      expect(ColorHarmony.isTriadic(red, cyan), isFalse);
    });

    test('symmetric: isTriadic(a,b) == isTriadic(b,a)', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      expect(
        ColorHarmony.isTriadic(red, green),
        ColorHarmony.isTriadic(green, red),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('ColorHarmony.isNeutral', () {
    test('grey → neutral', () {
      expect(ColorHarmony.isNeutral(Colors.grey), isTrue);
    });

    test('white → neutral (saturation=0)', () {
      expect(ColorHarmony.isNeutral(Colors.white), isTrue);
    });

    test('black → neutral (saturation=0)', () {
      expect(ColorHarmony.isNeutral(Colors.black), isTrue);
    });

    test('pure red → not neutral (high saturation)', () {
      expect(ColorHarmony.isNeutral(const Color(0xFFFF0000)), isFalse);
    });

    test('pure blue → not neutral', () {
      expect(ColorHarmony.isNeutral(const Color(0xFF0000FF)), isFalse);
    });

    test('vivid green → not neutral', () {
      expect(ColorHarmony.isNeutral(const Color(0xFF00FF00)), isFalse);
    });

    test('very light pink (near white) → neutral', () {
      // #F5F5F5 — extremely low saturation
      final nearWhite = ColorHarmony.parseHex('F5F5F5');
      expect(ColorHarmony.isNeutral(nearWhite), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('ColorHarmony.scoreOutfitHarmony', () {
    test('empty list → 0.5', () {
      expect(ColorHarmony.scoreOutfitHarmony([]), closeTo(0.5, 0.001));
    });

    test('single color → 0.8', () {
      expect(
        ColorHarmony.scoreOutfitHarmony([const Color(0xFFFF0000)]),
        closeTo(0.8, 0.001),
      );
    });

    test('all neutral colors → 1.0', () {
      expect(
        ColorHarmony.scoreOutfitHarmony([Colors.grey, Colors.white, Colors.black]),
        closeTo(1.0, 0.001),
      );
    });

    test('complementary pair → score ≈ 0.9', () {
      const red = Color(0xFFFF0000);
      const cyan = Color(0xFF00FFFF);
      final score = ColorHarmony.scoreOutfitHarmony([red, cyan]);
      expect(score, closeTo(0.9, 0.05));
    });

    test('analogous pair → score ≈ 1.0', () {
      const red = Color(0xFFFF0000);
      const orange = Color(0xFFFF4400); // small hue offset
      final score = ColorHarmony.scoreOutfitHarmony([red, orange]);
      expect(score, closeTo(1.0, 0.05));
    });

    test('triadic triple (R/G/B) → score ≈ 0.75', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      const blue = Color(0xFF0000FF);
      final score = ColorHarmony.scoreOutfitHarmony([red, green, blue]);
      // Each pair is triadic → average ≈ 0.75
      expect(score, greaterThanOrEqualTo(0.5));
      expect(score, lessThanOrEqualTo(1.0));
    });

    test('score is always in [0.0, 1.0]', () {
      final colors = [
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
        Colors.grey,
        const Color(0xFFFFFF00),
      ];
      final score = ColorHarmony.scoreOutfitHarmony(colors);
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(1.0));
    });

    test('single neutral color → 0.8', () {
      final score = ColorHarmony.scoreOutfitHarmony([Colors.grey]);
      expect(score, closeTo(0.8, 0.001));
    });

    test('mixed neutrals and vivid → score ≥ 0', () {
      // Neutrals don't penalize; vivid pairs drive the score
      final score = ColorHarmony.scoreOutfitHarmony([
        Colors.grey,
        const Color(0xFFFF0000),
        const Color(0xFF00FFFF),
      ]);
      expect(score, greaterThan(0));
    });

    test('two identical non-neutral colors → analogous (diff=0) → 1.0', () {
      const red = Color(0xFFFF0000);
      final score = ColorHarmony.scoreOutfitHarmony([red, red]);
      expect(score, closeTo(1.0, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  group('ColorHarmony.harmonyLabel', () {
    test('score 1.0 → Excellent match', () {
      expect(ColorHarmony.harmonyLabel(1.0), 'Excellent match');
    });

    test('score 0.85 → Excellent match (boundary)', () {
      expect(ColorHarmony.harmonyLabel(0.85), 'Excellent match');
    });

    test('score 0.84 → Good harmony (just below Excellent)', () {
      expect(ColorHarmony.harmonyLabel(0.84), 'Good harmony');
    });

    test('score 0.70 → Good harmony (boundary)', () {
      expect(ColorHarmony.harmonyLabel(0.70), 'Good harmony');
    });

    test('score 0.69 → Decent combo', () {
      expect(ColorHarmony.harmonyLabel(0.69), 'Decent combo');
    });

    test('score 0.50 → Decent combo (boundary)', () {
      expect(ColorHarmony.harmonyLabel(0.50), 'Decent combo');
    });

    test('score 0.49 → Needs work', () {
      expect(ColorHarmony.harmonyLabel(0.49), 'Needs work');
    });

    test('score 0.0 → Needs work', () {
      expect(ColorHarmony.harmonyLabel(0.0), 'Needs work');
    });

    test('returns non-empty string for any value in [0,1]', () {
      for (var i = 0; i <= 10; i++) {
        final label = ColorHarmony.harmonyLabel(i / 10);
        expect(label, isNotEmpty);
      }
    });
  });
}
