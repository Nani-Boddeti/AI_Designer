import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../data/models/household.dart';
import '../../data/models/profile.dart';

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
    this.isLoading = false,
    this.error,
  });

  final User? user;
  final Profile? profile;
  final Household? household;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get hasProfile => profile != null;
  bool get hasHousehold => household != null;

  AuthState copyWith({
    User? user,
    Profile? profile,
    Household? household,
    bool? isLoading,
    // Pass null to clear, omit entirely to keep the existing value.
    Object? error = _kKeepError,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      household: household ?? this.household,
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

  Future<AuthState> _buildFromCurrentSession(SupabaseService svc) async {
    final user = svc.getCurrentUser();
    if (user == null) return const AuthState();

    try {
      final profile = await svc
          .getCurrentProfile()
          .timeout(const Duration(seconds: 10));
      if (profile == null) return AuthState(user: user);

      final household = await svc
          .getHousehold(profile.householdId)
          .timeout(const Duration(seconds: 10));
      return AuthState(user: user, profile: profile, household: household);
    } catch (_) {
      // Profile/household fetch failed (RLS, timeout, network) — user is still
      // authenticated, router will redirect to household-setup.
      return AuthState(user: user);
    }
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
      return _buildFromCurrentSession(ref.read(supabaseServiceProvider));
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return const AuthState();
    });
  }

  Future<void> createHousehold({
    required String householdName,
    required String profileName,
    required String hemisphere,
    required String gender,
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
      );
      state = AsyncData(AuthState(
        user: repo.currentUser,
        profile: result.profile,
        household: result.household,
      ));
    } catch (e) {
      state = AsyncData(prev.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> joinHousehold({
    required String inviteCode,
    required String profileName,
    required String gender,
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
      );
      state = AsyncData(AuthState(
        user: repo.currentUser,
        profile: result.profile,
        household: result.household,
      ));
    } catch (e) {
      state = AsyncData(prev.copyWith(isLoading: false, error: e.toString()));
    }
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
