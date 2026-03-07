// tier_calculator_test.dart
// Unit tests for TierCalculator — pure Dart, no Flutter/Supabase required.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/core/utils/tier_calculator.dart';
import 'package:ai_designer_assist/core/constants/app_constants.dart';
import 'package:ai_designer_assist/data/models/profile.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Profile _male(String id) => Profile(
      id: id,
      householdId: 'h1',
      name: 'M$id',
      ageGroup: AgeGroup.adult,
      gender: Gender.male,
      createdAt: DateTime(2024, 1, 1),
    );

Profile _female(String id) => Profile(
      id: id,
      householdId: 'h1',
      name: 'F$id',
      ageGroup: AgeGroup.adult,
      gender: Gender.female,
      createdAt: DateTime(2024, 1, 1),
    );

Profile _other(String id) => Profile(
      id: id,
      householdId: 'h1',
      name: 'O$id',
      ageGroup: AgeGroup.adult,
      gender: Gender.other,
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  // -------------------------------------------------------------------------
  group('TierCalculator.monthlyLimit — free tier', () {
    test('empty household → freeHouseholdLimit (15)', () {
      expect(
        TierCalculator.monthlyLimit('free', []),
        equals(TierLimits.freeHouseholdLimit),
      );
    });

    test('free tier ignores profile list and dynamic pricing', () {
      final profiles = [_male('1'), _female('2'), _other('3')];
      expect(
        TierCalculator.monthlyLimit('free', profiles),
        equals(TierLimits.freeHouseholdLimit),
      );
      expect(
        TierCalculator.monthlyLimit('free', profiles, dynamicPricing: false),
        equals(TierLimits.freeHouseholdLimit),
      );
    });

    test('unknown tier string falls through to free limit', () {
      expect(
        TierCalculator.monthlyLimit('enterprise', [_male('1')]),
        equals(TierLimits.freeHouseholdLimit),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TierCalculator.monthlyLimit — pro tier, dynamic pricing ON', () {
    test('empty profiles → pro minimum (50)', () {
      expect(
        TierCalculator.monthlyLimit('pro', []),
        equals(TierLimits.proMinSuggestions),
      );
    });

    test('1 male → max(10, 50) = 50 (floor applies)', () {
      expect(
        TierCalculator.monthlyLimit('pro', [_male('1')]),
        equals(50),
      );
    });

    test('1 female → max(15, 50) = 50 (floor applies)', () {
      expect(
        TierCalculator.monthlyLimit('pro', [_female('1')]),
        equals(50),
      );
    });

    test('5 males → max(50, 50) = 50 (exactly at floor)', () {
      final profiles = List.generate(5, (i) => _male('$i'));
      expect(
        TierCalculator.monthlyLimit('pro', profiles),
        equals(50),
      );
    });

    test('6 males → max(60, 50) = 60 (above floor)', () {
      final profiles = List.generate(6, (i) => _male('$i'));
      expect(
        TierCalculator.monthlyLimit('pro', profiles),
        equals(60),
      );
    });

    test('mixed: 2 female + 2 male = 15+15+10+10 = 50 → 50', () {
      final profiles = [_female('1'), _female('2'), _male('3'), _male('4')];
      expect(
        TierCalculator.monthlyLimit('pro', profiles),
        equals(50),
      );
    });

    test('mixed: 4 female + 1 male = 4×15+10 = 70 → 70 (above floor)', () {
      final profiles = [
        _female('1'), _female('2'), _female('3'), _female('4'), _male('5'),
      ];
      expect(
        TierCalculator.monthlyLimit('pro', profiles),
        equals(70),
      );
    });

    test('"other" gender counts as male allocation', () {
      final profiles = List.generate(6, (i) => _other('$i'));
      // 6 × proPerMale(10) = 60 > 50
      expect(
        TierCalculator.monthlyLimit('pro', profiles),
        equals(60),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TierCalculator.monthlyLimit — pro tier, dynamic pricing OFF', () {
    test('single member → flat proMinSuggestions (50)', () {
      expect(
        TierCalculator.monthlyLimit('pro', [_male('1')], dynamicPricing: false),
        equals(TierLimits.proMinSuggestions),
      );
    });

    test('10 members → still flat 50 (no scaling)', () {
      final profiles = List.generate(10, (i) => _female('$i'));
      expect(
        TierCalculator.monthlyLimit('pro', profiles, dynamicPricing: false),
        equals(TierLimits.proMinSuggestions),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TierCalculator.monthlyLimit — prime tier, dynamic pricing ON', () {
    test('empty profiles → prime minimum (200)', () {
      expect(
        TierCalculator.monthlyLimit('prime', []),
        equals(TierLimits.primeMinSuggestions),
      );
    });

    test('1 male → max(50, 200) = 200 (floor applies)', () {
      expect(
        TierCalculator.monthlyLimit('prime', [_male('1')]),
        equals(200),
      );
    });

    test('4 males → max(200, 200) = 200 (exactly at floor)', () {
      final profiles = List.generate(4, (i) => _male('$i'));
      expect(
        TierCalculator.monthlyLimit('prime', profiles),
        equals(200),
      );
    });

    test('5 males → max(250, 200) = 250 (above floor)', () {
      final profiles = List.generate(5, (i) => _male('$i'));
      expect(
        TierCalculator.monthlyLimit('prime', profiles),
        equals(250),
      );
    });

    test('4 females → max(220, 200) = 220', () {
      final profiles = List.generate(4, (i) => _female('$i'));
      // 4 × 55 = 220
      expect(
        TierCalculator.monthlyLimit('prime', profiles),
        equals(220),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TierCalculator.monthlyLimit — prime tier, dynamic pricing OFF', () {
    test('any number of members → flat 200', () {
      final profiles = List.generate(10, (i) => _female('$i'));
      expect(
        TierCalculator.monthlyLimit('prime', profiles, dynamicPricing: false),
        equals(TierLimits.primeMinSuggestions),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TierCalculator.pricePaisa — free tier', () {
    test('free always returns 0', () {
      expect(TierCalculator.pricePaisa('free', []), equals(0));
      expect(
        TierCalculator.pricePaisa('free', [_male('1'), _female('2')]),
        equals(0),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TierCalculator.pricePaisa — pro tier', () {
    test('empty profiles → pro floor price (25000 paisa = ₹250)', () {
      expect(
        TierCalculator.pricePaisa('pro', []),
        equals(TierLimits.proMinPaisa),
      );
    });

    test('1 male → 50 × 500 = 25000 (at floor)', () {
      expect(
        TierCalculator.pricePaisa('pro', [_male('1')]),
        equals(25000),
      );
    });

    test('6 males → 60 × 500 = 30000 (above floor)', () {
      final profiles = List.generate(6, (i) => _male('$i'));
      expect(
        TierCalculator.pricePaisa('pro', profiles),
        equals(30000),
      );
    });

    test('dynamic pricing OFF, any count → 50 × 500 = 25000', () {
      final profiles = List.generate(10, (i) => _female('$i'));
      expect(
        TierCalculator.pricePaisa('pro', profiles, dynamicPricing: false),
        equals(25000),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TierCalculator.pricePaisa — prime tier', () {
    test('empty profiles → prime floor price (100000 paisa = ₹1000)', () {
      expect(
        TierCalculator.pricePaisa('prime', []),
        equals(TierLimits.primeMinPaisa),
      );
    });

    test('5 males → 250 × 500 = 125000 (above floor)', () {
      final profiles = List.generate(5, (i) => _male('$i'));
      expect(
        TierCalculator.pricePaisa('prime', profiles),
        equals(125000),
      );
    });

    test('dynamic pricing OFF → 200 × 500 = 100000', () {
      final profiles = List.generate(10, (i) => _male('$i'));
      expect(
        TierCalculator.pricePaisa('prime', profiles, dynamicPricing: false),
        equals(100000),
      );
    });
  });
}
