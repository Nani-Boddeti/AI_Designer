import '../constants/app_constants.dart';
import '../../data/models/profile.dart';

/// Pure static utility — no Flutter/Riverpod imports.
/// Returns flat monthly limits and fixed prices for the household's tier.
class TierCalculator {
  TierCalculator._();

  /// Monthly outfit-generation limit for a household based on its tier.
  ///
  /// - free  → 15  (shared household pool)
  /// - pro   → 50  (flat, household-wide)
  /// - prime → 200 (flat, household-wide)
  ///
  /// The [profiles] parameter is accepted for API compatibility but is
  /// no longer used in the calculation (limits are flat, not per-member).
  static int monthlyLimit(String tier, List<Profile> profiles) {
    if (tier == 'prime') return TierLimits.primeHouseholdLimit;
    if (tier == 'pro') return TierLimits.proHouseholdLimit;
    return TierLimits.freeHouseholdLimit;
  }

  /// Total price in paisa for subscribing to [tier].
  /// Returns 0 for free tier.
  static int pricePaisa(String tier, List<Profile> profiles) {
    if (tier == 'prime') return TierLimits.primePricePaisa;
    if (tier == 'pro') return TierLimits.proPricePaisa;
    return 0;
  }
}
