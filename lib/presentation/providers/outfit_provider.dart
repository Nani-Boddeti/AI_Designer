import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/outfit.dart';
import '../../data/models/profile.dart';
import '../../data/models/wardrobe_item.dart';
import '../../data/repositories/outfit_repository.dart';
import '../../data/repositories/wardrobe_repository.dart';
import '../../domain/usecases/generate_outfits_usecase.dart';
import '../providers/auth_provider.dart';
import '../providers/usage_provider.dart';

// ---------------------------------------------------------------------------
// Generated outfits holder (in-memory for current session)
// ---------------------------------------------------------------------------

class GeneratedOutfitsNotifier extends Notifier<List<GeneratedOutfit>> {
  @override
  List<GeneratedOutfit> build() => [];

  List<Profile> _lastProfiles = [];
  String _lastOccasion = '';
  DateTime _lastEventDate = DateTime.now();

  List<Profile> get lastProfiles => _lastProfiles;
  String get lastOccasion => _lastOccasion;
  DateTime get lastEventDate => _lastEventDate;

  Future<void> generate({
    required List<Profile> profiles,
    required String occasion,
    required DateTime eventDate,
    double? latitude,
    double? longitude,
    Map<String, List<WardrobeItem>>? pinnedItemsByProfile,
  }) async {
    _lastProfiles = profiles;
    _lastOccasion = occasion;
    _lastEventDate = eventDate;
    final hemisphere =
        ref.read(authProvider).value?.household?.hemisphere ?? 'north';
    final useCase = ref.read(generateOutfitsUseCaseProvider);
    final results = await useCase.execute(
      profiles: profiles,
      occasion: occasion,
      eventDate: eventDate,
      hemisphere: hemisphere,
      latitude: latitude,
      longitude: longitude,
      pinnedItemsByProfile: pinnedItemsByProfile,
    );
    state = results;
    // Increment usage counter — fire-and-forget, never fatal.
    try {
      await ref.read(usageNotifierProvider.notifier).increment();
    } catch (_) {}
  }

  void clear() => state = [];
}

final generatedOutfitsProvider =
    NotifierProvider<GeneratedOutfitsNotifier, List<GeneratedOutfit>>(
  GeneratedOutfitsNotifier.new,
);

// ---------------------------------------------------------------------------
// Saved outfits (per profile)
// ---------------------------------------------------------------------------

class OutfitNotifier extends AsyncNotifier<List<Outfit>> {
  OutfitNotifier(this._profileId);
  final String _profileId;

  @override
  Future<List<Outfit>> build() async {
    return ref.watch(outfitRepositoryProvider).getOutfitsForProfile(_profileId);
  }

  Future<void> saveOutfit(Outfit outfit) async {
    final repo = ref.read(outfitRepositoryProvider);
    final saved = await repo.saveOutfit(outfit);
    state = AsyncData<List<Outfit>>([saved, ...(state.value ?? <Outfit>[])]);
  }

  Future<void> deleteOutfit(String outfitId) async {
    final repo = ref.read(outfitRepositoryProvider);
    await repo.deleteOutfit(outfitId);
    final updated = <Outfit>[...(state.value ?? <Outfit>[])]
      ..removeWhere((o) => o.id == outfitId);
    state = AsyncData<List<Outfit>>(updated);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final outfitProvider = AsyncNotifierProvider.autoDispose
    .family<OutfitNotifier, List<Outfit>, String>(
  (arg) => OutfitNotifier(arg),
);

// ---------------------------------------------------------------------------
// All wardrobe items for a profile (for manual item selection — limit 200)
// ---------------------------------------------------------------------------

final allWardrobeItemsProvider = FutureProvider.autoDispose
    .family<List<WardrobeItem>, String>((ref, profileId) {
  return ref
      .read(wardrobeRepositoryProvider)
      .getItemsForProfile(profileId, limit: 200);
});
