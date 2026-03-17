import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/error_utils.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../data/models/household.dart';
import '../../data/models/profile.dart';
import 'calendar_provider.dart';
import 'outfit_provider.dart';

// ---------------------------------------------------------------------------
// Auth state data class
// ---------------------------------------------------------------------------

// Sentinel so copyWith can distinguish "clear error" from "keep error".
const _kKeepError = Object();

class AuthState {
  const AuthState({
    this.user,
    this.profile,
    this.household,
    this.allHouseholds = const [],
    this.adminHouseholdIds = const {},
    this.isLoading = false,
    this.error,
  });

  final User? user;
  final Profile? profile;
  final Household? household;
  final List<Household> allHouseholds;

  /// IDs of households where the current user has admin role.
  final Set<String> adminHouseholdIds;

  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get hasProfile => profile != null;
  bool get hasHousehold => household != null;

  /// Authenticated but has no households at all → needs to create/join one.
  bool get needsHouseholdSetup =>
      isAuthenticated && allHouseholds.isEmpty && !hasHousehold;

  /// Authenticated with multiple households but none selected yet → show picker.
  bool get needsHouseholdSelection =>
      isAuthenticated && allHouseholds.isNotEmpty && !hasHousehold;

  /// Whether the user is admin in a specific household.
  bool isAdminInHousehold(String householdId) =>
      adminHouseholdIds.contains(householdId);

  AuthState copyWith({
    User? user,
    Profile? profile,
    Household? household,
    List<Household>? allHouseholds,
    Set<String>? adminHouseholdIds,
    bool? isLoading,
    // Pass null to clear, omit entirely to keep the existing value.
    Object? error = _kKeepError,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      household: household ?? this.household,
      allHouseholds: allHouseholds ?? this.allHouseholds,
      adminHouseholdIds: adminHouseholdIds ?? this.adminHouseholdIds,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _kKeepError) ? this.error : error as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

// SharedPreferences key for tracking intentionally-left household IDs.
// Prevents _fetchAndBackfillMissingHouseholds from re-adding them on restart
// (the RPC deletes the membership row but not the profile row, which the
// backfill would otherwise treat as a "legacy missing membership").
const _kLeftHouseholdsKey = 'left_household_ids';

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final svc = ref.watch(supabaseServiceProvider);

    // Listen to Supabase auth state changes and refresh accordingly.
    final subscription = svc.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        // Skip if an explicit sign-in method (signInWithEmail, etc.) is
        // already managing the state — it will call _buildFromCurrentSession
        // directly. Only invalidate for external events (magic link, OAuth,
        // token refresh) where no explicit method is in flight.
        // Also skip if an inner-AsyncData operation (createHousehold,
        // joinHousehold) is in flight — they use AuthState.isLoading instead
        // of AsyncValue.isLoading to avoid the router-redirect bug.
        final innerLoading = state.value?.isLoading ?? false;
        if (!state.isLoading && !innerLoading) {
          ref.invalidateSelf();
        }
      } else if (event.event == AuthChangeEvent.signedOut) {
        state = const AsyncData(AuthState());
      }
    });
    ref.onDispose(subscription.cancel);

    return _buildFromCurrentSession(svc);
  }

  Future<AuthState> _buildFromCurrentSession(
    SupabaseService svc, {
    bool forcePickerForMultiple = false,
  }) async {
    final user = svc.getCurrentUser();
    if (user == null) return const AuthState();

    // ── Step 1: fetch membership-based households ──────────────────────────
    final (:households, :adminIds) = await svc.fetchHouseholdMemberships();

    // Sync FCM token — fire-and-forget.
    unawaited(
      NotificationService.syncToken(svc.client, user.id).catchError((_) {}),
    );

    // ── Step 2: find and backfill any missing membership rows ──────────────
    // This handles both fully-legacy accounts (no rows at all) AND the mixed
    // case where some households have rows but others don't (e.g. a household
    // created before the memberships table was added, alongside a newer one
    // that was created via the app and has a proper row).
    final knownIds = households.map((h) => h.id).toSet();

    // Read intentionally-left household IDs from SharedPreferences and exclude
    // them from the backfill. The RPC removes the membership row but not the
    // profile, so without this exclusion the backfill treats every left
    // household as a "legacy missing membership" and re-inserts it on restart.
    final prefs = await SharedPreferences.getInstance();
    final leftIds = (prefs.getStringList(_kLeftHouseholdsKey) ?? []).toSet();

    final missingHouseholds = await _fetchAndBackfillMissingHouseholds(
      svc,
      user.id,
      excludeIds: knownIds.union(leftIds),
    );

    final allHouseholds = [...households, ...missingHouseholds];

    if (allHouseholds.isEmpty) {
      // Genuinely no households → router will redirect to /household-setup.
      return AuthState(user: user);
    }

    return _resolveHouseholds(
      svc: svc,
      user: user,
      households: allHouseholds,
      adminIds: adminIds,
      forcePickerForMultiple: forcePickerForMultiple,
    );
  }

  /// Selects or returns households for the final AuthState.
  Future<AuthState> _resolveHouseholds({
    required SupabaseService svc,
    required User user,
    required List<Household> households,
    required Set<String> adminIds,
    bool forcePickerForMultiple = false,
  }) async {
    // ── Single household: always auto-select (no choice to make) ──────────
    if (households.length == 1) {
      final household = households.first;

      // Check if there's a previously persisted selection in user_preferences.
      // If so (e.g. re-opening the app), honour it so the user stays in the
      // household they chose last time.
      final activeId = await svc.getActiveHouseholdId(user.id);
      final effectiveHousehold = (activeId != null && activeId != household.id)
          ? (await svc.getHousehold(activeId) ?? household)
          : household;

      unawaited(
        svc.upsertActiveHousehold(user.id, effectiveHousehold.id).catchError((_) {}),
      );

      Profile? profile;
      try {
        profile = await svc
            .getProfileForHousehold(effectiveHousehold.id)
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      return AuthState(
        user: user,
        profile: profile,
        household: effectiveHousehold,
        allHouseholds: households,
        adminHouseholdIds: adminIds,
      );
    }

    // ── Multiple households ────────────────────────────────────────────────
    // On explicit sign-in (forcePickerForMultiple=true) always show the picker
    // so the user consciously chooses which household to enter.
    // On app restart (forcePickerForMultiple=false) restore the last selection.
    if (!forcePickerForMultiple) {
      final activeId = await svc.getActiveHouseholdId(user.id);
      if (activeId != null) {
        final active = households.where((h) => h.id == activeId).firstOrNull;
        if (active != null) {
          Profile? profile;
          try {
            profile = await svc
                .getProfileForHousehold(active.id)
                .timeout(const Duration(seconds: 10));
          } catch (_) {}
          return AuthState(
            user: user,
            profile: profile,
            household: active,
            allHouseholds: households,
            adminHouseholdIds: adminIds,
          );
        }
      }
    }

    // No selection (or forced picker) — router redirects to /household-picker.
    return AuthState(
      user: user,
      allHouseholds: households,
      adminHouseholdIds: adminIds,
    );
  }

  /// Finds all households where the user has a profile but no membership row
  /// and returns them. Backfill is fire-and-forget so it never blocks login
  /// or causes the user to see "create household" if the insert fails.
  Future<List<Household>> _fetchAndBackfillMissingHouseholds(
    SupabaseService svc,
    String userId, {
    required Set<String> excludeIds,
  }) async {
    // ── Fetch phase — isolated try/catch, always returns what it found ──────
    final missing = <String, bool>{}; // householdId → isAdmin
    List<Household> result = [];
    try {
      // profiles_select_own: auth_user_id = auth.uid() — no dependency on
      // current_household_id(), safe to call regardless of active household.
      final profileRows = await svc.client
          .from('profiles')
          .select('household_id, is_admin')
          .eq('auth_user_id', userId);

      for (final row in profileRows as List) {
        final hId = row['household_id'] as String;
        if (!excludeIds.contains(hId)) {
          missing[hId] = (row['is_admin'] as bool?) ?? false;
        }
      }

      if (missing.isNotEmpty) {
        // SECURITY DEFINER RPC — scoped to households where caller has a
        // profile row (auth_user_id = auth.uid()). Replaces direct table query
        // which broke when the broad household_select_for_join policy was
        // replaced by the membership-scoped household_select_own policy.
        final householdsData = await svc.client.rpc(
          'get_households_by_ids_for_backfill',
          params: {'p_ids': missing.keys.toList()},
        ) as List<dynamic>;
        result = householdsData
            .map((h) => Household.fromJson(h as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fetch failed — return whatever we collected before the error.
    }

    // Backfill INSERT intentionally removed — the one-time SQL migration already
    // created membership rows for all legacy users. An RPC-based re-insert would
    // allow ex-members (whose profiles are retained after leave_household) to
    // rejoin without an invite. Any user genuinely missing a membership row after
    // the migration should rejoin via invite code.

    return result;
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo
          .signInWithEmail(email: email, password: password)
          .timeout(const Duration(seconds: 15),
              onTimeout: () => throw Exception(
                  'Connection timed out. Check your internet and try again.'));
      final svc = ref.read(supabaseServiceProvider);
      // forcePickerForMultiple=true: on explicit sign-in, multi-household users
      // always see the picker regardless of any previously persisted selection.
      // App restarts go through build() → _buildFromCurrentSession without this
      // flag, so the last-selected household is restored automatically.
      return _buildFromCurrentSession(svc, forcePickerForMultiple: true);
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signUpWithEmail(email: email, password: password);
      return _buildFromCurrentSession(ref.read(supabaseServiceProvider));
    });
  }

  Future<void> sendMagicLink(String email) async {
    // Capture before AsyncLoading wipes state.value.
    final prev = state.value ?? const AuthState();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).sendMagicLink(email);
      return prev;
    });
  }

  Future<void> signOut() async {
    final userId = state.value?.user?.id;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final svc = ref.read(supabaseServiceProvider);
      // Remove the device token before signing out.
      if (userId != null) {
        unawaited(
          NotificationService.removeToken(svc.client, userId).catchError((_) {}),
        );
      }
      await ref.read(authRepositoryProvider).signOut();
      return const AuthState();
    });
  }

  Future<void> createHousehold({
    required String householdName,
    required String profileName,
    required String hemisphere,
    required String gender,
    SkinTone? skinTone,
    bool dynamicPricing = true,
  }) async {
    // IMPORTANT: Do NOT use AsyncValue.guard here. If it throws, guard would
    // set AsyncError which makes valueOrNull == null, causing the router to
    // redirect the user back to /auth even though they are still authenticated.
    // Instead, keep state as AsyncData and store the error inside AuthState.
    final prev = state.value ?? const AuthState();
    state = AsyncData(prev.copyWith(isLoading: true, error: null));
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.createHousehold(
        householdName: householdName,
        profileName: profileName,
        hemisphere: hemisphere,
        gender: gender,
        skinTone: skinTone,
        dynamicPricing: dynamicPricing,
      );
      state = AsyncData(AuthState(
        user: repo.currentUser,
        profile: result.profile,
        household: result.household,
        // Preserve existing households — creating a new one adds to the list.
        allHouseholds: [...prev.allHouseholds, result.household],
        adminHouseholdIds: {...prev.adminHouseholdIds, result.household.id},
      ));
      // Clear stale caches so the new household shows fresh data.
      ref.invalidate(outfitProvider);
      ref.invalidate(calendarProvider);
      ref.read(generatedOutfitsProvider.notifier).clear();
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'createHousehold');
      state = AsyncData(prev.copyWith(isLoading: false, error: userFriendlyError(e)));
    }
  }

  Future<void> switchHousehold(String householdId) async {
    final prev = state.value ?? const AuthState();
    state = AsyncData(prev.copyWith(isLoading: true, error: null));
    try {
      final svc = ref.read(supabaseServiceProvider);

      // Persist active-household choice → drives current_household_id() RLS.
      await svc.upsertActiveHousehold(prev.user!.id, householdId);

      // Find household object from the already-loaded list (no extra DB call).
      final household = prev.allHouseholds.where((h) => h.id == householdId).firstOrNull
          ?? await svc.getHousehold(householdId);
      if (household == null) throw Exception('Household not found');

      // Fetch the user's profile for this specific household.
      // Failure is non-fatal — home screen handles null profile gracefully.
      Profile? profile;
      try {
        profile = await svc
            .getProfileForHousehold(householdId)
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      state = AsyncData(AuthState(
        user: prev.user,
        profile: profile,
        household: household,
        allHouseholds: prev.allHouseholds,
        adminHouseholdIds: prev.adminHouseholdIds,
      ));
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'switchHousehold');
      state = AsyncData(prev.copyWith(isLoading: false, error: userFriendlyError(e)));
      return;
    }
    // Invalidate caches AFTER success state is set — kept outside try so a
    // cache-clear failure can never roll back a successful household switch.
    ref.invalidate(outfitProvider);
    ref.invalidate(calendarProvider);
    ref.read(generatedOutfitsProvider.notifier).clear();
  }

  Future<void> leaveHousehold(String householdId) async {
    final prev = state.value ?? const AuthState();
    state = AsyncData(prev.copyWith(isLoading: true, error: null));
    try {
      final svc = ref.read(supabaseServiceProvider);
      // Use RPC instead of Edge Function — avoids JWT edge cases with
      // the functions gateway; uses the same auth path as all other DB calls.
      await svc.client.rpc(
        'leave_household',
        params: {'p_household_id': householdId},
      );

      // Persist the left household ID so _fetchAndBackfillMissingHouseholds
      // never re-adds it on subsequent app starts (RPC removes the membership
      // row but not the profile, which the backfill would otherwise treat as a
      // "legacy missing membership" and re-insert on every restart).
      final prefs = await SharedPreferences.getInstance();
      final leftIds = <String>[...(prefs.getStringList(_kLeftHouseholdsKey) ?? []), householdId];
      await prefs.setStringList(_kLeftHouseholdsKey, leftIds);

      // Derive new state directly from prev rather than calling
      // _buildFromCurrentSession. _buildFromCurrentSession runs
      // _fetchAndBackfillMissingHouseholds, which finds the user's profile in
      // the left household (the RPC only removes the membership row, not the
      // profile) and re-inserts the membership — undoing the leave entirely.
      final remaining = prev.allHouseholds
          .where((h) => h.id != householdId)
          .toList();
      final remainingAdminIds = {...prev.adminHouseholdIds}..remove(householdId);

      if (remaining.isEmpty) {
        // No households left → clear active preference and go to setup.
        await svc.upsertActiveHousehold(prev.user!.id, null).catchError((_) {});
        state = AsyncData(AuthState(user: prev.user));
        return;
      }

      // Auto-select the first remaining household so:
      //  • needsHouseholdSelection stays false → no picker redirect (Bug 2)
      //  • active_household_id is persisted → app restart restores it (Bug 3)
      final next = remaining.first;
      await svc.upsertActiveHousehold(prev.user!.id, next.id).catchError((_) {});

      Profile? profile;
      try {
        profile = await svc
            .getProfileForHousehold(next.id)
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      state = AsyncData(AuthState(
        user: prev.user,
        profile: profile,
        household: next,
        allHouseholds: remaining,
        adminHouseholdIds: remainingAdminIds,
      ));

      // Defer invalidations to after authProvider's state update propagates.
      // Calling ref.invalidate(calendarProvider) synchronously here triggers a
      // CircularDependencyError because calendarProvider watches authProvider —
      // Riverpod detects the cycle when both are mid-update at the same time.
      Future.microtask(() {
        ref.invalidate(outfitProvider);
        ref.invalidate(calendarProvider);
        ref.read(generatedOutfitsProvider.notifier).clear();
      });
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'leaveHousehold');
      state = AsyncData(prev.copyWith(isLoading: false, error: userFriendlyError(e)));
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    await ref.read(authRepositoryProvider).resendVerificationEmail(email);
  }

  Future<void> deleteAccount() async {
    // Same pattern as createHousehold — never set AsyncError while the user is
    // still mid-operation; store errors inside AuthState instead.
    final prev = state.value ?? const AuthState();
    state = AsyncData(prev.copyWith(isLoading: true, error: null));
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      state = const AsyncData(AuthState());
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'deleteAccount');
      state = AsyncData(prev.copyWith(isLoading: false, error: userFriendlyError(e)));
    }
  }

  Future<void> joinHousehold({
    required String inviteCode,
    required String profileName,
    required String gender,
    SkinTone? skinTone,
  }) async {
    // Same pattern as createHousehold — never AsyncError while authenticated.
    final prev = state.value ?? const AuthState();
    state = AsyncData(prev.copyWith(isLoading: true, error: null));
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.joinHousehold(
        inviteCode: inviteCode,
        profileName: profileName,
        gender: gender,
        skinTone: skinTone,
      );
      // If the user previously left this household, remove it from the
      // "left households" exclusion list so future backfills work correctly.
      final prefs = await SharedPreferences.getInstance();
      final leftIds = prefs.getStringList(_kLeftHouseholdsKey) ?? [];
      if (leftIds.contains(result.household.id)) {
        await prefs.setStringList(
          _kLeftHouseholdsKey,
          leftIds.where((id) => id != result.household.id).toList(),
        );
      }

      state = AsyncData(AuthState(
        user: repo.currentUser,
        profile: result.profile,
        household: result.household,
        allHouseholds: [...prev.allHouseholds, result.household],
        adminHouseholdIds: prev.adminHouseholdIds, // not admin in joined household
      ));

      // Notify existing household members — fire-and-forget, non-fatal.
      final householdId = result.household.id;
      final newUserId = repo.currentUser?.id;
      if (newUserId != null) {
        unawaited(() async {
          try {
            await ref.read(supabaseServiceProvider).client.functions.invoke(
              'notify-member-joined',
              body: {
                'household_id': householdId,
                'new_member_name': profileName,
                'new_user_id': newUserId,
              },
            );
          } catch (_) {}
        }());
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'joinHousehold');
      state = AsyncData(prev.copyWith(isLoading: false, error: userFriendlyError(e)));
    }
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
