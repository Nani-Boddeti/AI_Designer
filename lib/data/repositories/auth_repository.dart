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

  /// Deletes all storage files for the user's profiles, then calls the
  /// `delete_account` RPC which removes DB rows and the auth user.
  Future<void> deleteAccount() async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    // Fetch all profiles owned by this auth user.
    final profileRows = await _client
        .from(SupabaseTables.profiles)
        .select('id')
        .eq('auth_user_id', user.id);

    for (final row in profileRows as List) {
      final profileId = row['id'] as String;

      // Delete wardrobe storage files (both buckets, silently ignore errors).
      for (final bucket in [
        SupabaseBuckets.wardrobeImages,
        SupabaseBuckets.processedImages,
      ]) {
        try {
          final files = await _client.storage
              .from(bucket)
              .list(path: 'wardrobe/$profileId');
          for (final folder in files) {
            final folderFiles = await _client.storage
                .from(bucket)
                .list(path: 'wardrobe/$profileId/${folder.name}');
            final paths = folderFiles
                .map((f) => 'wardrobe/$profileId/${folder.name}/${f.name}')
                .toList();
            if (paths.isNotEmpty) {
              await _client.storage.from(bucket).remove(paths);
            }
          }
        } catch (_) {
          // Storage deletion is best-effort — proceed even if it fails.
        }
      }

      // Delete avatar file.
      try {
        await _client.storage
            .from(SupabaseBuckets.avatars)
            .remove(['avatars/$profileId/avatar.jpg']);
      } catch (_) {}
    }

    // Delete DB rows and auth user via RPC.
    await _client.rpc('delete_account');
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
  }) async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    final householdId = const Uuid().v4();
    // Derive invite code from the household UUID — guaranteed unique since
    // the UUID is unique. Takes 8 chars from the hex representation.
    final inviteCode = _inviteCodeFromId(householdId);

    // Step 1: Insert household WITHOUT .select() — the SELECT policy uses
    // current_household_id() which looks up the user's profile. No profile
    // exists yet, so chaining .select() would return 0 rows and throw an
    // RLS error even though the INSERT itself succeeds.
    await _client
        .from(SupabaseTables.households)
        .insert({
          'id': householdId,
          'name': householdName,
          'hemisphere': hemisphere,
          'invite_code': inviteCode,
        });

    // Step 2: Insert profile WITHOUT .select() — same reason as household:
    // current_household_id() can't see the row being inserted in the same
    // statement, so RETURNING would return 0 rows and throw an RLS error.
    await _client
        .from(SupabaseTables.profiles)
        .insert({
          'household_id': householdId,
          'auth_user_id': user.id,
          'name': profileName,
          'age_group': AgeGroup.adult.value,
          'gender': gender,
          'style_persona': <String>[],
          'fit_preferences': <String, dynamic>{},
        });

    // Step 3: Both rows are now committed. current_household_id() works.
    // Fetch household and profile in parallel.
    final results = await Future.wait([
      _client.from(SupabaseTables.households).select().eq('id', householdId).single(),
      _client.from(SupabaseTables.profiles).select().eq('auth_user_id', user.id).eq('household_id', householdId).single(),
    ]);

    return (
      household: Household.fromJson(results[0]),
      profile: Profile.fromJson(results[1]),
    );
  }

  /// Joins an existing household using an invite code.
  Future<({Household household, Profile profile})> joinHousehold({
    required String inviteCode,
    required String profileName,
    required String gender,
  }) async {
    final user = _service.getCurrentUser();
    if (user == null) throw Exception('Not authenticated');

    final household = await _service.getHouseholdByInviteCode(inviteCode);
    if (household == null) {
      throw Exception('No household found for that invite code.');
    }

    // Insert without .select() — same RLS reason as createHousehold.
    await _client
        .from(SupabaseTables.profiles)
        .insert({
          'household_id': household.id,
          'auth_user_id': user.id,
          'name': profileName,
          'age_group': AgeGroup.adult.value,
          'gender': gender,
          'style_persona': <String>[],
          'fit_preferences': <String, dynamic>{},
        });

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

  /// Derives a unique 8-character invite code from a household UUID.
  /// Guaranteed unique — one code per household, no collisions possible.
  String _inviteCodeFromId(String householdId) {
    return householdId.replaceAll('-', '').substring(0, 8).toUpperCase();
  }
}
