## Summary

The Gender field and 3-tier monetisation implementation is mostly solid, but contains one
critical data-integrity bug, three major logic errors that produce wrong limits or allow
unguarded downgrade payments, and several minor issues around type safety and UX.

---

## Issues

---

### CRITICAL

- **[severity: critical] correctness — `addProfile` uses INSERT + SELECT, triggering RLS failure for first-time household members**

  File: `lib/presentation/providers/profile_provider.dart`, line 46–54

  ```dart
  final data = await svc.client.from(SupabaseTables.profiles).insert({
    ...
  }).select().single();
  ```

  This is the exact pattern the project's own MEMORY.md explicitly bans under "Critical RLS
  Patterns". The `INSERT...RETURNING` triggers a SELECT policy. `current_household_id()`
  returns NULL when the profile being inserted is the first one in the household (the
  auth-linked one that all future calls rely on). Supabase filters the RETURNING rows through
  RLS, gets zero rows back, and the `.single()` call throws a `PostgrestException`.

  The household setup flow calls `createHousehold` which eventually calls this path. The
  first profile creation will throw every time for new households.

  **Fix:** Split into INSERT (no `.select()`) then a separate SELECT by the returned `id`,
  exactly as documented in MEMORY.md. The `updateProfile`, `updateAvatar` methods already
  do `.select().single()` but those run after the profile row exists and RLS resolves
  correctly, so they are fine.

---

### MAJOR

- **[severity: major] correctness — Empty profiles list gives Pro/Prime a limit of 0, which permanently locks out generation**

  File: `lib/core/utils/tier_calculator.dart`, lines 16–24 and `lib/presentation/providers/usage_provider.dart`, line 41

  ```dart
  // TierCalculator._sum with empty list returns 0
  static int _sum(List<Profile> profiles, int female, int other) =>
      profiles.fold(0, (s, p) => s + ...);
  ```

  When `profilesProvider` is still loading (returns `[]` as the fallback), `monthlyLimit`
  for 'pro' or 'prime' returns 0. `UsageNotifier.build()` reads `profilesProvider` via
  `ref.watch`, which means during the brief async window before profiles load, `limit = 0`.

  `UsageState.canGenerate` is `count < limit`, so `0 < 0 = false`. The generate button is
  effectively disabled and `_showLimitDialog` fires even though the user is well within
  their actual limit. Any user on a paid tier with even 1 outfit generated this month will
  see the "limit reached" dialog while profiles are loading.

  **Fix:** In `UsageNotifier.build()`, await profiles explicitly before computing the limit
  (or return early with a sentinel state if profiles are empty), and/or set a safe default
  floor: `final limit = profiles.isEmpty ? TierLimits.freeHouseholdLimit : TierCalculator.monthlyLimit(tier, profiles)`.

- **[severity: major] correctness — A Prime subscriber can trigger a Pro payment; no downgrade guard exists**

  File: `lib/presentation/screens/subscription/subscription_screen.dart`, lines 258–262

  ```dart
  _TierCard(
    ...
    isDisabled: isPrimeActive || _processingPayment,   // Pro card
    ...
  ),
  _TierCard(
    ...
    isDisabled: _processingPayment,                    // Prime card — no guard for isProActive
    ...
  ),
  ```

  The Pro card correctly disables itself when Prime is active. But the Prime card has no
  guard for `isProActive`. A user already on Pro can subscribe to Prime, which is a
  legitimate upgrade — but the upgrade writes a new 30-day window via a direct client
  UPDATE with no server-side proration or cancellation of the existing Pro sub. The old Pro
  `tier_expires_at` gets overwritten. Depending on how close to expiry the Pro sub was,
  the user may silently lose paid time.

  More critically: if the user is already on Prime and the payment succeeds again (e.g.,
  a double-tap race or a retry after a transient network error), `_processingPayment` is
  set to `true` only in `_handlePaymentSuccess`, which runs after Razorpay returns. There
  is a window between `_openCheckout` returning and the Razorpay success callback firing
  where `_processingPayment` is still `false` and a second tap on Subscribe is possible.

  **Fix for downgrade/re-subscribe:** Set `isDisabled: isPrimeActive || _processingPayment`
  on the Prime card (mirror the Pro card logic). For the race, set `_processingPayment =
  true` immediately in `_openCheckout` before calling `_razorpay.open(options)`, and clear
  it in both success and error/cancel callbacks.

- **[severity: major] correctness — `usageNotifierProvider` is NOT invalidated after payment, so the limit displayed stays stale**

  File: `lib/presentation/screens/subscription/subscription_screen.dart`, line 59

  ```dart
  ref.invalidate(authProvider);
  // Missing: ref.invalidate(usageNotifierProvider);
  ```

  `usageNotifierProvider.build()` recomputes when `authProvider` changes, which will happen
  after the invalidation. However, `ref.watch(authProvider)` is async and the provider
  rebuilds only after the future resolves. Until then, `UsageState.limit` still reflects
  the old tier's limit — the progress bar and remaining-count in both the subscription
  screen and the More tab show the wrong ceiling immediately after payment. For a Free→Pro
  upgrade this means the bar appears near-full (15 limit) even though the new limit is
  much higher.

  Since `UsageNotifier` already watches `authProvider` and `profilesProvider`, invalidating
  `authProvider` eventually cascades a rebuild — but this is indirect and timing-dependent.
  An explicit `ref.invalidate(usageNotifierProvider)` after the Supabase UPDATE guarantees
  an immediate fresh fetch.

  **Fix:** Add `ref.invalidate(usageNotifierProvider);` immediately after
  `ref.invalidate(authProvider);` in `_handlePaymentSuccess`.

---

### MINOR

- **[severity: minor] correctness — `Gender.fromString(null)` silently defaults to `Gender.other` instead of null**

  File: `lib/core/constants/app_constants.dart`, lines 257–264

  Unlike `SkinTone.fromString`, which returns `null` for a null/unrecognised input,
  `Gender.fromString(null)` returns `Gender.other`. This means a profile that has never
  had gender set in the database (`gender IS NULL`) will be read back as `Gender.other`
  and included in `TierCalculator._sum` as a non-female member (getting the lower
  `proPerMale` / `primePerMale` allowance). This is a semantic conflation: "not set" and
  "prefer not to say" are different states.

  The immediate impact is that households with legacy profiles that predate the gender
  column will have their limits computed correctly (treating null as "other") — which may
  or may not be intentional. The real risk is confusion when the limits shown to a user
  do not match what they expect after they set a gender.

  **Fix:** Either match `SkinTone`'s pattern (return `null` for null input, make `gender`
  nullable on `Profile`) or document clearly that null→`other` is intentional and add a
  comment in `TierLimits` stating that `proPerMale` applies to `other` as well.

- **[severity: minor] type safety — `_buildContent` `household` parameter is untyped (`dynamic`)**

  File: `lib/presentation/screens/subscription/subscription_screen.dart`, line 146

  ```dart
  Widget _buildContent(BuildContext context, {
    ...
    required household,          // ← inferred as dynamic
    ...
  }) {
  ```

  This is a Dart type-inference gap: named parameters without a type annotation become
  `dynamic`. The callers pass `Household?`, so `household?.isProActive` works at runtime,
  but the type-checker cannot catch misuse. If someone passes a wrong type, it fails at
  runtime. `flutter analyze` should flag this as an info-level warning.

  **Fix:** `required Household? household,`

- **[severity: minor] correctness — Profile edit screen Gender SegmentedButton shows full `displayName` with no `fontSize` override**

  File: `lib/presentation/screens/profiles/profile_edit_screen.dart`, lines 261–265

  The `_AddProfileDialog` uses `TextStyle(fontSize: 11)` on segment labels (line 192 of
  `profile_list_screen.dart`) to prevent overflow for the "Prefer not to say" label, but
  the `ProfileEditScreen` version of the same `SegmentedButton` omits that style:

  ```dart
  // profile_edit_screen.dart line 262-264 — no fontSize override
  label: Text(g.displayName),
  ```

  On narrow screens (< ~380 dp wide), "Prefer not to say" will overflow or be clipped
  inside the segment. The `_AddProfileDialog` already found and fixed this; the edit screen
  should apply the same fix.

  **Fix:** Add `style: const TextStyle(fontSize: 11)` to all three `SegmentedButton` Gender
  usages: `profile_edit_screen.dart`, `household_setup_screen.dart` (create form, line
  229), and `household_setup_screen.dart` (join form, line 297).

- **[severity: minor] correctness — `_showLimitDialog` displays `monthName` (current month) instead of the expiry month**

  File: `lib/presentation/screens/outfit/style_session_screen.dart`, lines 86–93

  ```dart
  final monthName = months[now.month - 1];   // used in the dialog body
  final resetStr  = '${nextReset.day} ${months[nextReset.month - 1]} ${nextReset.year}';
  ```

  `monthName` is declared but the dialog says "all ${usage.limit} outfit suggestions for
  $monthName". If the user generates their last outfit in December and the dialog fires on
  December 31, this reads "all 15 suggestions for Dec. Resets on 1 Jan 2027." — correct.
  However `monthName` is computed from `now.month`, not from the selected `_selectedDate`.
  If someone is generating for a next-month event on December 31 and the reset is in
  January, the message is still correct because the limit is tracked by the current calendar
  month, not the event date. This is fine as-is, but the variable `monthName` is slightly
  misleading in naming. No code change required — just clarify with a comment.

- **[severity: minor] correctness — `_processingPayment` is never reset to `false` when the user dismisses Razorpay without paying**

  File: `lib/presentation/screens/subscription/subscription_screen.dart`, lines 81–92 and 104–116

  `_processingPayment` is set to `true` inside `_handlePaymentSuccess` (line 45), then
  cleared in the `finally` block. But `_openCheckout` does NOT set `_processingPayment`
  to `true` before calling `_razorpay.open`. So the button is not blocked while Razorpay
  is open. If the user dismisses the Razorpay sheet without completing payment (no error,
  no success — just a back-dismiss), neither `_handlePaymentSuccess` nor
  `_handlePaymentError` fires. The button remains tappable and `_processingPayment` stays
  `false` — which is correct in this case, but the lack of any loading indicator during
  the open-to-callback window leaves the user uncertain whether anything is happening.

  The `EVENT_PAYMENT_ERROR` callback does fire for explicit user cancellations in most
  Razorpay builds, but the behaviour is SDK-version-dependent and not guaranteed for all
  dismiss paths. The safe fix is the same as the Major race condition fix above: set
  `_processingPayment = true` in `_openCheckout`, and ensure it is cleared in both the
  error handler and the external-wallet handler as well.

- **[severity: minor] correctness — `deleteProfile` uses a dead null-check after a throwing `orElse`**

  File: `lib/presentation/providers/profile_provider.dart`, lines 110–113

  ```dart
  final profile = state.value?.firstWhere((p) => p.id == profileId,
      orElse: () => throw Exception('Profile not found'));
  if (profile == null) return;   // ← unreachable
  ```

  `firstWhere` with an `orElse` that throws will never return `null`, and `state.value`
  being `null` would cause the `?.` to make `profile` null — but in that case the throw
  inside `orElse` never executes and `profile` is silently `null`, causing a no-op return
  instead of an error. The intent was to guard against both cases, but the implementation
  is logically inconsistent: if `state.value` is null, the profile is silently not deleted
  with no error surfaced.

  **Fix:**
  ```dart
  final profiles = state.value;
  if (profiles == null) throw StateError('Profile list not loaded');
  final profile = profiles.firstWhere((p) => p.id == profileId,
      orElse: () => throw Exception('Profile not found: $profileId'));
  ```

---

## Verdict

NEEDS CHANGES — The RLS INSERT+SELECT bug (Critical) will cause household creation to fail
for new users. The empty-profiles limit-of-zero bug (Major) will incorrectly block paid
users from generating outfits during the provider loading window. Both must be fixed before
release. The missing `usageNotifierProvider` invalidation and the Prime card downgrade gap
should also be resolved before going live with real payments.
