import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/tier_calculator.dart';
import '../../data/models/profile.dart';
import '../../data/services/usage_service.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

// ---------------------------------------------------------------------------
// State data class
// ---------------------------------------------------------------------------

class UsageState {
  const UsageState({
    this.count = 0,
    this.limit = TierLimits.freeHouseholdLimit,
  });

  final int count;
  final int limit;

  int get remaining => (limit - count).clamp(0, limit);
  bool get canGenerate => count < limit;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class UsageNotifier extends AsyncNotifier<UsageState> {
  @override
  Future<UsageState> build() async {
    // Re-build whenever auth or profiles change (tier + member list drive limit).
    final authState = ref.watch(authProvider).value;
    final profiles = ref.watch(profilesProvider).value ?? <Profile>[];
    final household = authState?.household;
    if (household == null) return const UsageState();

    final tier = household.tier;
    // Guard: while profilesProvider is still loading its value is [].
    // TierCalculator._sum([]) == 0 which makes canGenerate false for paid
    // users. Fall back to freeHouseholdLimit until the real list arrives;
    // the notifier will rebuild automatically once profilesProvider resolves.
    final limit = profiles.isEmpty
        ? TierLimits.freeHouseholdLimit
        : TierCalculator.monthlyLimit(tier, profiles);

    final yearMonth = _currentYearMonth();
    final count = await ref
        .read(usageServiceProvider)
        .getMonthlyCount(household.id, yearMonth);

    return UsageState(count: count, limit: limit);
  }

  /// Increments the counter locally and persists to Supabase.
  Future<void> increment() async {
    final household = ref.read(authProvider).value?.household;
    if (household == null) return;

    final yearMonth = _currentYearMonth();
    await ref
        .read(usageServiceProvider)
        .incrementCount(household.id, yearMonth);

    // Update local state optimistically.
    final current = state.value ?? const UsageState();
    state = AsyncData(UsageState(
      count: current.count + 1,
      limit: current.limit,
    ));
  }

  static String _currentYearMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}

final usageNotifierProvider =
    AsyncNotifierProvider<UsageNotifier, UsageState>(UsageNotifier.new);
