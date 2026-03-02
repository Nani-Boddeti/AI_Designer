import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/household.dart';
import '../models/profile.dart';
import '../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Thin wrapper around the Supabase client that exposes commonly used queries
/// and centralises error handling.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  // ---------------------------------------------------------------------------
  // Auth helpers
  // ---------------------------------------------------------------------------

  User? getCurrentUser() => _client.auth.currentUser;

  Session? getCurrentSession() => _client.auth.currentSession;

  bool get isAuthenticated => getCurrentUser() != null;

  // ---------------------------------------------------------------------------
  // Profile helpers
  // ---------------------------------------------------------------------------

  /// Returns the [Profile] associated with the currently authenticated user,
  /// or null if none exists yet.
  Future<Profile?> getCurrentProfile() async {
    final user = getCurrentUser();
    if (user == null) return null;

    final data = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Returns all profiles that belong to the given household.
  Future<List<Profile>> getHouseholdProfiles(String householdId) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('household_id', householdId)
        .order('created_at');

    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }

  // ---------------------------------------------------------------------------
  // Household helpers
  // ---------------------------------------------------------------------------

  /// Returns the [Household] for the given profile, or null.
  Future<Household?> getHousehold(String householdId) async {
    final data = await _client
        .from(SupabaseTables.households)
        .select()
        .eq('id', householdId)
        .maybeSingle();

    if (data == null) return null;
    return Household.fromJson(data);
  }

  Future<Household?> getHouseholdByInviteCode(String code) async {
    final data = await _client
        .from(SupabaseTables.households)
        .select()
        .eq('invite_code', code)
        .maybeSingle();

    if (data == null) return null;
    return Household.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Storage helpers
  // ---------------------------------------------------------------------------

  /// Uploads [bytes] to [bucket]/[path] and returns the public URL.
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String contentType = 'image/jpeg',
  }) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    final url = _client.storage.from(bucket).getPublicUrl(path);
    return url;
  }
}
