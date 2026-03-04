import 'dart:math' show max;

import '../constants/app_constants.dart';
import '../../data/models/profile.dart';

/// Pure static utility — no Flutter/Riverpod imports.
///
/// Monthly limits are calculated per-member (gender-aware), then floored at
/// the tier minimums so a single-person household always gets at least:
///   Pro  → 50 suggestions / ₹250
///   Prime → 200 suggestions / ₹1000
class TierCalculator {
  TierCalculator._();

  /// Monthly outfit-generation limit for a household.
  ///
  /// - free  → 15 (flat household pool)
  /// - pro   → max(Σ per-member, 50)
  /// - prime → max(Σ per-member, 200)
  static int monthlyLimit(String tier, List<Profile> profiles) {
    if (tier == 'prime') {
      final raw = _sum(profiles, TierLimits.primePerFemale, TierLimits.primePerMale);
      return max(raw, TierLimits.primeMinSuggestions);
    }
    if (tier == 'pro') {
      final raw = _sum(profiles, TierLimits.proPerFemale, TierLimits.proPerMale);
      return max(raw, TierLimits.proMinSuggestions);
    }
    return TierLimits.freeHouseholdLimit;
  }

  /// Total price in paisa. Returns 0 for free.
  /// Floored at ₹250 (pro) and ₹1000 (prime).
  static int pricePaisa(String tier, List<Profile> profiles) {
    if (tier == 'free') return 0;
    final raw = monthlyLimit(tier, profiles) * TierLimits.pricePerSuggestionPaisa;
    if (tier == 'prime') return max(raw, TierLimits.primeMinPaisa);
    if (tier == 'pro')   return max(raw, TierLimits.proMinPaisa);
    return raw;
  }

  static int _sum(List<Profile> profiles, int female, int other) =>
      profiles.fold(
        0,
        (s, p) => s + (p.gender == Gender.female ? female : other),
      );
}
