import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'supabase_service.dart';

/// Reads and increments the per-household monthly outfit-generation counter.
class UsageService {
  UsageService(this._client);

  final SupabaseClient _client;

  /// Returns the number of outfit generations for [householdId] in [yearMonth]
  /// (format: 'YYYY-MM'). Returns 0 if no row exists yet.
  Future<int> getMonthlyCount(String householdId, String yearMonth) async {
    final row = await _client
        .from(SupabaseTables.householdUsage)
        .select('outfit_count')
        .eq('household_id', householdId)
        .eq('year_month', yearMonth)
        .maybeSingle();
    return (row?['outfit_count'] as int?) ?? 0;
  }

  /// Atomically increments the outfit count for [householdId] in [yearMonth]
  /// by 1 using a DB-level INSERT … ON CONFLICT DO UPDATE.
  ///
  /// This replaces the previous read-then-write pattern which had a race
  /// condition: two concurrent calls would both read the same count and each
  /// write count+1 instead of count+2, allowing users to exceed their limits.
  ///
  /// Returns the new count after increment.
  Future<int> incrementCount(String householdId, String yearMonth) async {
    final result = await _client.rpc(
      'increment_household_usage',
      params: {
        'p_household_id': householdId,
        'p_year_month': yearMonth,
      },
    );
    return (result as int?) ?? 0;
  }
}

final usageServiceProvider = Provider<UsageService>((ref) {
  return UsageService(ref.watch(supabaseServiceProvider).client);
});
