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

  /// Returns all profiles that belong to the given household,
  /// with avatar URLs replaced by 1-hour signed URLs.
  Future<List<Profile>> getHouseholdProfiles(String householdId) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('household_id', householdId)
        .order('created_at');

    final profiles = (data as List).map((e) => Profile.fromJson(e)).toList();

    // Batch-sign avatar URLs (buckets are private).
    final avatarPaths = profiles
        .where((p) => p.avatarUrl != null)
        .map((p) => _normalizePath(p.avatarUrl!, SupabaseBuckets.avatars))
        .toList();

    if (avatarPaths.isEmpty) return profiles;

    final signedMap =
        await createSignedUrls(SupabaseBuckets.avatars, avatarPaths);

    return profiles.map((p) {
      if (p.avatarUrl == null) return p;
      final path = _normalizePath(p.avatarUrl!, SupabaseBuckets.avatars);
      final signed = signedMap[path];
      return signed != null ? p.copyWith(avatarUrl: signed) : p;
    }).toList();
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

  /// Fetches all household_memberships for the current user, including nested
  /// household data and admin status per household.
  /// Returns empty result on any error — never throws.
  Future<({List<Household> households, Set<String> adminIds})>
      fetchHouseholdMemberships() async {
    try {
      final data = await _client
          .from('household_memberships')
          .select('is_admin, households(*)');
      final list = data as List;
      final households = list
          .map((row) =>
              Household.fromJson(row['households'] as Map<String, dynamic>))
          .toList();
      final adminIds = list
          .where((row) => (row['is_admin'] as bool?) == true)
          .map((row) =>
              (row['households'] as Map<String, dynamic>)['id'] as String)
          .toSet();
      return (households: households, adminIds: adminIds);
    } catch (_) {
      return (households: <Household>[], adminIds: <String>{});
    }
  }

  /// Convenience wrapper — returns just the household list.
  Future<List<Household>> getAllHouseholds() async =>
      (await fetchHouseholdMemberships()).households;

  /// Returns the profile for [householdId] belonging to the current user, or null.
  /// Requires the `profiles_select_own` RLS policy to be applied (see DB migration).
  Future<Profile?> getProfileForHousehold(String householdId) async {
    final user = getCurrentUser();
    if (user == null) return null;
    final data = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('auth_user_id', user.id)
        .eq('household_id', householdId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Returns the user's currently active household ID from `user_preferences`, or null.
  Future<String?> getActiveHouseholdId(String userId) async {
    try {
      final data = await _client
          .from('user_preferences')
          .select('active_household_id')
          .eq('user_id', userId)
          .maybeSingle();
      return data?['active_household_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Persists the user's active household choice in `user_preferences`.
  /// This drives `current_household_id()` so RLS reflects the selected household.
  /// Pass [householdId] = null to clear the preference (e.g. after leaving).
  Future<void> upsertActiveHousehold(String userId, String? householdId) async {
    await _client.from('user_preferences').upsert({
      'user_id': userId,
      'active_household_id': householdId, // null clears the preference
    });
  }

  Future<Household?> getHouseholdByInviteCode(String code) async {
    // Uses a SECURITY DEFINER RPC instead of direct table access.
    // The households table SELECT policy is now scoped to the caller's own
    // memberships; this RPC is the only path for pre-join invite-code lookup.
    final rows = await _client.rpc(
      'lookup_household_by_invite_code',
      params: {'p_code': code},
    ) as List<dynamic>;

    if (rows.isEmpty) return null;
    return Household.fromJson(rows.first as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Storage helpers
  // ---------------------------------------------------------------------------

  /// Uploads [bytes] to [bucket]/[path] and returns the **storage path**
  /// (not a public URL — buckets are private; use [createSignedUrl] to display).
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
    return path;
  }

  /// Returns a signed URL for [path] in [bucket], valid for [expiresIn] seconds.
  /// Returns null on error (best-effort).
  Future<String?> createSignedUrl(
    String bucket,
    String path, {
    int expiresIn = 3600,
  }) async {
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(_normalizePath(path, bucket), expiresIn);
    } catch (_) {
      return null;
    }
  }

  /// Batch-signs multiple [paths] in [bucket]. Returns a map of path → signed URL.
  /// Paths not successfully signed are omitted from the result.
  Future<Map<String, String>> createSignedUrls(
    String bucket,
    List<String> paths, {
    int expiresIn = 3600,
  }) async {
    if (paths.isEmpty) return {};
    try {
      final normalised = paths.map((p) => _normalizePath(p, bucket)).toList();
      final results = await _client.storage
          .from(bucket)
          .createSignedUrls(normalised, expiresIn);
      final map = <String, String>{};
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        if (r.signedUrl.isNotEmpty) {
          // Key by normalised path (what the API echoes back) AND original
          // input so callers can look up by either form.
          map[r.path] = r.signedUrl;
          map[paths[i]] = r.signedUrl; // original input (may be full URL)
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Extracts the storage path from either a plain path or a full public URL.
  /// e.g. `https://.../object/public/wardrobe-images/wardrobe/x/y.jpg`
  ///      → `wardrobe/x/y.jpg`
  static String _normalizePath(String urlOrPath, String bucket) {
    if (!urlOrPath.startsWith('http')) return urlOrPath;
    final marker = '/object/public/$bucket/';
    final idx = urlOrPath.indexOf(marker);
    return idx >= 0 ? urlOrPath.substring(idx + marker.length) : urlOrPath;
  }
}
