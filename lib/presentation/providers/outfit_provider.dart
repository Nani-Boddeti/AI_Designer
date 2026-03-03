import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/outfit.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/outfit_repository.dart';
import '../../domain/usecases/generate_outfits_usecase.dart';
import '../providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Generated outfits holder (in-memory for current session)
// ---------------------------------------------------------------------------

class GeneratedOutfitsNotifier extends Notifier<List<GeneratedOutfit>> {
  @override
  List<GeneratedOutfit> build() => [];

  Future<void> generate({
    required List<Profile> profiles,
    required String occasion,
    required DateTime eventDate,
    double? latitude,
    double? longitude,
  }) async {
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
    );
    state = results;
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

class OutfitNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Outfit>, String> {
  @override
  Future<List<Outfit>> build(String arg) async {
    return ref.watch(outfitRepositoryProvider).getOutfitsForProfile(arg);
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
    state = await AsyncValue.guard(() => build(arg));
  }
}

final outfitProvider = AutoDisposeAsyncNotifierProviderFamily<OutfitNotifier,
    List<Outfit>, String>(
  OutfitNotifier.new,
);
