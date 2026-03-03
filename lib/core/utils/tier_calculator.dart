import 'dart:math' show max;

import '../constants/app_constants.dart';
import '../../data/models/profile.dart';

/// Pure static utility — no Flutter/Riverpod imports.
/// Centralises all per-member tier arithmetic so that limits are always
/// computed consistently regardless of where in the app they are needed.
class TierCalculator {
  TierCalculator._();

  /// Monthly outfit-generation limit for a household based on its tier and
  /// the current member list.
  ///
  /// - free  → flat 15 (shared household pool)
  /// - pro   → Σ(female ? 15 : 10) per member
  /// - prime → Σ(female ? 55 : 50) per member
  static int monthlyLimit(String tier, List<Profile> profiles) {
    if (tier == 'prime') {
      return _sum(profiles, TierLimits.primePerFemale, TierLimits.primePerMale);
    }
    if (tier == 'pro') {
      return _sum(profiles, TierLimits.proPerFemale, TierLimits.proPerMale);
    }
    return TierLimits.freeHouseholdLimit;
  }

  /// Total price in paisa for subscribing to [tier] given current members.
  ///
  /// Returns 0 for free tier. Paid tiers have a minimum floor:
  ///   Pro  → max(raw, ₹250)  = 25 000 paisa
  ///   Prime → max(raw, ₹1000) = 100 000 paisa
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
