import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
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
  }) async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    final inviteCode = _generateInviteCode();

    final householdData = await _client
        .from(SupabaseTables.households)
        .insert({
          'name': householdName,
          'invite_code': inviteCode,
        })
        .select()
        .single();

    final household = Household.fromJson(householdData);

    final profileData = await _client
        .from(SupabaseTables.profiles)
        .insert({
          'household_id': household.id,
          'auth_user_id': user.id,
          'name': profileName,
          'age_group': AgeGroup.adult.value,
          'style_persona': <String>[],
          'fit_preferences': <String, dynamic>{},
        })
        .select()
        .single();

    final profile = Profile.fromJson(profileData);
    return (household: household, profile: profile);
  }

  /// Joins an existing household using an invite code.
  Future<({Household household, Profile profile})> joinHousehold({
    required String inviteCode,
    required String profileName,
  }) async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    final household = await _service.getHouseholdByInviteCode(inviteCode);
    if (household == null) {
      throw Exception('No household found for that invite code.');
    }

    final profileData = await _client
        .from(SupabaseTables.profiles)
        .insert({
          'household_id': household.id,
          'auth_user_id': user.id,
          'name': profileName,
          'age_group': AgeGroup.adult.value,
          'style_persona': <String>[],
          'fit_preferences': <String, dynamic>{},
        })
        .select()
        .single();

    final profile = Profile.fromJson(profileData);
    return (household: household, profile: profile);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
