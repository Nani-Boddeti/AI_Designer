import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final missingHouseholds =
        await _fetchAndBackfillMissingHouseholds(svc, user.id, excludeIds: knownIds);

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
        // household_select_for_join (USING true) allows reading any household.
        final householdsData = await svc.client
            .from('households')
            .select()
            .inFilter('id', missing.keys.toList());
        result = (householdsData as List)
            .map((h) => Household.fromJson(h as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fetch failed — return whatever we collected before the error.
    }

    // ── Backfill phase — fire-and-forget, never blocks or hides result ──────
    if (result.isNotEmpty) {
      unawaited(() async {
        try {
          for (final h in result) {
            await svc.client.from('household_memberships').insert({
              'user_id': userId,
              'household_id': h.id,
              'is_admin': missing[h.id] ?? false,
            });
          }
        } catch (_) {}
      }());
    }

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
      // Invalidate caches so this household shows its own data.
      ref.invalidate(outfitProvider);
      ref.invalidate(calendarProvider);
      ref.read(generatedOutfitsProvider.notifier).clear();
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'switchHousehold');
      state = AsyncData(prev.copyWith(isLoading: false, error: userFriendlyError(e)));
    }
  }

  Future<void> leaveHousehold(String householdId) async {
    final prev = state.value ?? const AuthState();
    state = AsyncData(prev.copyWith(isLoading: true, error: null));
    try {
      final svc = ref.read(supabaseServiceProvider);
      await svc.client.functions.invoke(
        'leave-household',
        body: {'household_id': householdId},
      );
      // Clear the stale active-household preference so current_household_id()
      // doesn't keep returning the just-left household during the re-fetch.
      await svc.upsertActiveHousehold(prev.user!.id, null).catchError((_) {});
      // _buildFromCurrentSession will auto-select the correct remaining household
      // and sync user_preferences via upsertActiveHousehold.
      final next = await _buildFromCurrentSession(svc);
      state = AsyncData(next);
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
