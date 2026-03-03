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

  /// Increments the outfit count for [householdId] in [yearMonth] by 1.
  /// Creates the row if it doesn't exist yet.
  Future<void> incrementCount(String householdId, String yearMonth) async {
    final current = await getMonthlyCount(householdId, yearMonth);
    await _client.from(SupabaseTables.householdUsage).upsert(
      {
        'household_id': householdId,
        'year_month': yearMonth,
        'outfit_count': current + 1,
      },
      onConflict: 'household_id,year_month',
    );
  }
}

final usageServiceProvider = Provider<UsageService>((ref) {
  return UsageService(ref.watch(supabaseServiceProvider).client);
});
