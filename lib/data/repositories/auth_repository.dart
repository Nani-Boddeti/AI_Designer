import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';


import '../models/household.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseServiceProvider));
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class AuthRepository {
  AuthRepository(this._service);

  final SupabaseService _service;

  SupabaseClient get _client => _service.client;

  // ---------------------------------------------------------------------------
  // Auth operations
  // ---------------------------------------------------------------------------

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'io.supabase.aidesignerassist://login-callback',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Deletes the account via the `delete-account` Edge Function.
  ///
  /// The Edge Function runs with service_role credentials so it can:
  ///  - Delete all storage files before touching the auth user
  ///  - Delete DB rows via the `delete_account_for_user` RPC
  ///  - Delete the auth user via the Admin API
  /// If any step fails the function returns an error and the account
  /// remains intact — the user can retry.
  Future<void> deleteAccount() async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    final result = await _client.functions.invoke('delete-account');

    final data = result.data as Map<String, dynamic>?;
    if (data?['success'] != true) {
      throw Exception(data?['error'] ?? 'Account deletion failed');
    }
  }

  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.aidesignerassist://login-callback',
    );
  }

  Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
      emailRedirectTo: 'io.supabase.aidesignerassist://login-callback',
    );
  }

  Future<void> resendVerificationEmail(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  User? get currentUser => _service.getCurrentUser();

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Household operations
  // ---------------------------------------------------------------------------

  /// Creates a new household and a profile for the current user.
  Future<({Household household, Profile profile})> createHousehold({
    required String householdName,
    required String profileName,
    required String hemisphere,
    required String gender,
    SkinTone? skinTone,
    bool dynamicPricing = true,
  }) async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    final householdId = const Uuid().v4();
    final inviteCode = _generateInviteCode();

    // Single atomic RPC: all 4 steps (household → profile → membership →
    // user_preferences) run in one transaction on the server.
    // SECURITY DEFINER bypasses RLS internally, so no recursion possible.
    // PostgREST rolls back everything on failure — no orphaned rows.
    final response = await _client.rpc('create_household', params: {
      'p_household_id':    householdId,
      'p_name':            householdName,
      'p_invite_code':     inviteCode,
      'p_hemisphere':      hemisphere,
      'p_dynamic_pricing': dynamicPricing,
      'p_profile_name':    profileName,
      'p_gender':          gender,
      if (skinTone != null) 'p_skin_tone': skinTone.value,
    }) as Map<String, dynamic>;

    return (
      household: Household.fromJson(response['household'] as Map<String, dynamic>),
      profile:   Profile.fromJson(response['profile']   as Map<String, dynamic>),
    );
  }

  /// Joins an existing household using an invite code.
  Future<({Household household, Profile profile})> joinHousehold({
    required String inviteCode,
    required String profileName,
    required String gender,
    SkinTone? skinTone,
  }) async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    final household = await _service.getHouseholdByInviteCode(inviteCode);
    if (household == null) {
      throw Exception('No household found for that invite code.');
    }

    // Insert profile + membership atomically via SECURITY DEFINER RPC.
    // The RPC validates the invite code, inserts the profile (bypassing the
    // memberless-household guard on profiles_insert), then inserts the
    // membership row (bypassing the first-member-only memberships_insert policy).
    await _client.rpc('join_household_with_invite', params: {
      'p_household_id': household.id,
      'p_invite_code': inviteCode,
      'p_profile_name': profileName,
      'p_gender': gender,
      if (skinTone != null) 'p_skin_tone': skinTone.value,
    });
    await _service.upsertActiveHousehold(user.id, household.id);

    // Profile is committed — current_household_id() now works.
    final profileData = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('auth_user_id', user.id)
        .eq('household_id', household.id)
        .single();

    return (household: household, profile: Profile.fromJson(profileData));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generates a cryptographically random 8-character alphanumeric invite code.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // omit O,0,I,1 — confusing
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
