import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/profile.dart';
import '../../data/services/supabase_service.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Currently selected profile id (active family member being viewed)
// ---------------------------------------------------------------------------

final currentProfileIdProvider =
    NotifierProvider<_CurrentProfileNotifier, String?>(_CurrentProfileNotifier.new);

class _CurrentProfileNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

// ---------------------------------------------------------------------------
// Household profiles notifier
// ---------------------------------------------------------------------------

class ProfilesNotifier extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() async {
    final authState = await ref.watch(authProvider.future);
    final householdId = authState.household?.id;
    if (householdId == null) return [];

    final svc = ref.watch(supabaseServiceProvider);
    return svc.getHouseholdProfiles(householdId);
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<void> addProfile({
    required String name,
    required AgeGroup ageGroup,
    Gender gender = Gender.other,
    SkinTone? skinTone,
    List<String> stylePersona = const [],
    Map<String, dynamic> fitPreferences = const {},
  }) async {
    final authState = await ref.read(authProvider.future);
    final householdId = authState.household?.id;
    if (householdId == null) return;

    final svc = ref.read(supabaseServiceProvider);
    // Generate ID client-side so we can fetch the row separately without
    // chaining .select() — INSERT+RETURNING triggers the SELECT RLS policy
    // which may fail in edge cases where current_household_id() is evaluated
    // before the profile row is visible. See MEMORY.md RLS patterns.
    final id = const Uuid().v4();
    await svc.client.from(SupabaseTables.profiles).insert({
      'id': id,
      'household_id': householdId,
      'name': name,
      'age_group': ageGroup.value,
      'gender': gender.value,
      if (skinTone != null) 'skin_tone': skinTone.value,
      'style_persona': stylePersona,
      'fit_preferences': fitPreferences,
    });

    final data = await svc.client
        .from(SupabaseTables.profiles)
        .select()
        .eq('id', id)
        .single();

    final newProfile = Profile.fromJson(data);
    state = AsyncData<List<Profile>>([...(state.value ?? <Profile>[]), newProfile]);
  }

  Future<void> updateProfile(Profile profile) async {
    final svc = ref.read(supabaseServiceProvider);
    final json = profile.toJson()
      ..remove('id')
      ..remove('created_at');

    final data = await svc.client
        .from(SupabaseTables.profiles)
        .update(json)
        .eq('id', profile.id)
        .select()
        .single();

    final updated = Profile.fromJson(data);
    final profiles = <Profile>[...(state.value ?? <Profile>[])];
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) profiles[idx] = updated;
    state = AsyncData<List<Profile>>(profiles);
  }

  Future<void> updateAvatar({
    required String profileId,
    required List<int> imageBytes,
  }) async {
    final svc = ref.read(supabaseServiceProvider);
    final path = 'avatars/$profileId/avatar.jpg';
    final avatarUrl = await svc.uploadFile(
      bucket: SupabaseBuckets.avatars,
      path: path,
      bytes: imageBytes,
      contentType: 'image/jpeg',
    );

    if (avatarUrl.isEmpty) throw Exception('Avatar upload returned empty URL');

    final data = await svc.client
        .from(SupabaseTables.profiles)
        .update({'avatar_url': avatarUrl})
        .eq('id', profileId)
        .select()
        .single();

    final updated = Profile.fromJson(data);
    final profiles = <Profile>[...(state.value ?? <Profile>[])];
    final idx = profiles.indexWhere((p) => p.id == profileId);
    if (idx >= 0) profiles[idx] = updated;
    state = AsyncData<List<Profile>>(profiles);
  }

  Future<void> deleteProfile(String profileId) async {
    final current = state.value;
    if (current == null) throw StateError('profiles state is null');
    final profile = current.firstWhere(
      (p) => p.id == profileId,
      orElse: () => throw Exception('Profile not found'),
    );

    // Refuse to delete account-linked profiles — doing so would break
    // current_household_id() for all subsequent Supabase queries from
    // that user, making every RLS-protected table invisible.
    if (profile.authUserId != null) {
      throw Exception(
          'Cannot delete the account owner profile. Remove the household instead.');
    }

    final svc = ref.read(supabaseServiceProvider);
    await svc.client.from(SupabaseTables.profiles).delete().eq('id', profileId);
    final profiles = <Profile>[...(state.value ?? <Profile>[])]
      ..removeWhere((p) => p.id == profileId);
    state = AsyncData<List<Profile>>(profiles);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final profilesProvider =
    AsyncNotifierProvider<ProfilesNotifier, List<Profile>>(
  ProfilesNotifier.new,
);

/// Convenience provider for a single profile by id.
final profileByIdProvider = Provider.family<Profile?, String>((ref, id) {
  final profiles = ref.watch(profilesProvider).value ?? [];
  try {
    return profiles.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
});
