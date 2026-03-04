## Summary
Four files reviewed; three real runtime bugs found across two files — one critical data-race, one silent data-corruption cast, and one stale-ref risk — plus one false alarm from the prompt that is actually fine.

## Issues

---

### FILE: lib/data/services/usage_service.dart

- **[severity: critical]** Correctness — Race condition in `incrementCount`: the read-then-write pattern (fetch count → upsert count+1) is not atomic. If two outfit generations fire concurrently (e.g. user double-taps), both reads return the same value N, both write N+1, and one increment is silently lost. The DB ends up at N+1 instead of N+2.

  **Fix:** Use a Postgres atomic increment instead of a client-side read-modify-write:
  ```dart
  Future<void> incrementCount(String householdId, String yearMonth) async {
    // Try insert first; on conflict increment in place — fully atomic.
    await _client.rpc('increment_household_usage', params: {
      'p_household_id': householdId,
      'p_year_month': yearMonth,
    });
  }
  ```
  And add a Supabase SQL function:
  ```sql
  CREATE OR REPLACE FUNCTION increment_household_usage(
    p_household_id TEXT, p_year_month TEXT
  ) RETURNS void LANGUAGE sql AS $$
    INSERT INTO household_usage (household_id, year_month, outfit_count)
    VALUES (p_household_id, p_year_month, 1)
    ON CONFLICT (household_id, year_month)
    DO UPDATE SET outfit_count = household_usage.outfit_count + 1;
  $$;
  ```
  Alternatively, if RPC is not desired, the minimal client-side fix is to remove `getMonthlyCount` and upsert with a raw SQL expression — but Supabase's Dart client does not support `outfit_count = outfit_count + 1` in upsert payloads, so the RPC approach is the right path.

---

### FILE: lib/data/services/gemini_service.dart

- **[severity: major]** Correctness — `_parseJsonList` uses `.cast<Map<String, dynamic>>()` (line 231), which is a lazy cast in Dart. It does not validate element types at call time; it creates a lazy `CastList` that throws a `TypeError` at the moment any element is accessed if Gemini returns a list that contains a non-Map element (e.g. a string, int, or nested list). Because Gemini is a generative model and its output is not guaranteed to be structurally perfect, this will surface as an unhandled runtime crash in the calling code.

  The project's own CLAUDE.md explicitly calls this out:
  > "never use `.cast<String>()` on Gemini responses — use `_toStringList(dynamic)` which checks `is List` before casting"

  The same rule applies to list-of-maps responses.

  **Fix:** Replace the lazy cast with an explicit element-by-element filter:
  ```dart
  List<Map<String, dynamic>> _parseJsonList(String text) {
    try {
      final clean = text.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      final decoded = jsonDecode(clean);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {}
    return [];
  }
  ```
  `whereType` does eager type checking and silently skips malformed elements rather than crashing.

---

### FILE: lib/presentation/providers/usage_provider.dart

- **[severity: major]** Correctness — `TierCalculator.monthlyLimit` receives `household.tier` (the raw DB string: `'free'`, `'pro'`, `'prime'`) but does not validate whether the subscription is actually active. `tier == 'pro'` in the DB does not mean the subscription is current — `tierExpiresAt` could be in the past. The `Household` model already has `isProActive` / `isPrimeActive` getters that check expiry, but the usage provider ignores them.

  **Concrete failure mode:** A household whose Pro subscription expired yesterday still has `tier = 'pro'` in the DB until it is downgraded server-side. If the server-side downgrade job is delayed, `TierCalculator.monthlyLimit('pro', profiles)` returns the Pro limit (e.g. 40) and `canGenerate` returns `true`, allowing free outfit generations beyond the free tier.

  **Fix:** Derive the effective tier from the active-subscription getters before passing to `TierCalculator`:
  ```dart
  final effectiveTier = household.isPrimeActive
      ? 'prime'
      : household.isProActive
          ? 'pro'
          : 'free';
  final limit = profiles.isEmpty
      ? TierLimits.freeHouseholdLimit
      : TierCalculator.monthlyLimit(effectiveTier, profiles);
  ```

---

### FILE: lib/presentation/screens/profiles/profile_list_screen.dart

- **[severity: low]** Readability / latent bug risk — `_AddProfileDialog` is a `ConsumerStatefulWidget` that receives and stores a parent `WidgetRef` in `widget.ref`. The `_AddProfileDialogState._add()` method correctly uses `ConsumerState.ref` (the dialog's own ref), not `widget.ref`. So there is no actual bug right now.

  However, the stored `widget.ref` field is dead code: it is never used inside the state, yet it exists as a public field. Its presence creates a maintenance trap — a future developer editing `_add()` may accidentally reach for `widget.ref` instead of `ref`, which would use a ref scoped to the parent widget (potentially after that widget is disposed) rather than the dialog's own ref. The `_AddProfileDialog` constructor parameter and field should be removed entirely. The dialog already has its own `ref` through `ConsumerState`.

  **Fix:**
  ```dart
  class _AddProfileDialog extends ConsumerStatefulWidget {
    const _AddProfileDialog();  // remove ref parameter
    @override
    ConsumerState<_AddProfileDialog> createState() => _AddProfileDialogState();
  }

  // In ProfileListScreen:
  void _showAddProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddProfileDialog(),
    );
  }
  ```

---

## Verdict
NEEDS CHANGES — two blocking issues that should be fixed before production: the increment race condition (data integrity) and the lazy `.cast<>()` crash on Gemini responses (runtime crash). The tier-expiry bypass is a billing correctness bug and should also be fixed. The stale-ref field is low priority but should be cleaned up.
