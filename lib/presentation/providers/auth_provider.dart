import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../data/models/household.dart';
import '../../data/models/profile.dart';

// ---------------------------------------------------------------------------
// Auth state data class
// ---------------------------------------------------------------------------

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
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      household: household ?? this.household,
      isLoading: isLoading ?? this.isLoading,
      error: error,
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
    svc.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        ref.invalidateSelf();
      } else if (event.event == AuthChangeEvent.signedOut) {
        state = const AsyncData(AuthState());
      }
    });

    return _buildFromCurrentSession(svc);
  }

  Future<AuthState> _buildFromCurrentSession(SupabaseService svc) async {
    final user = svc.getCurrentUser();
    if (user == null) return const AuthState();

    try {
      final profile = await svc.getCurrentProfile();
      if (profile == null) return AuthState(user: user);

      final household = await svc.getHousehold(profile.householdId);
      return AuthState(user: user, profile: profile, household: household);
    } catch (_) {
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
      await repo.signInWithEmail(email: email, password: password);
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).sendMagicLink(email);
      // Return current state unchanged — user isn't signed in yet,
      // they tap the link in their email to complete sign-in.
      return const AuthState();
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(AuthState());
  }

  Future<void> createHousehold({
    required String householdName,
    required String profileName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.createHousehold(
        householdName: householdName,
        profileName: profileName,
      );
      final user = repo.currentUser;
      return AuthState(
        user: user,
        profile: result.profile,
        household: result.household,
      );
    });
  }

  Future<void> joinHousehold({
    required String inviteCode,
    required String profileName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.joinHousehold(
        inviteCode: inviteCode,
        profileName: profileName,
      );
      final user = repo.currentUser;
      return AuthState(
        user: user,
        profile: result.profile,
        household: result.household,
      );
    });
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
