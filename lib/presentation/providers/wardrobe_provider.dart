import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/wardrobe_item.dart';
import '../../data/repositories/wardrobe_repository.dart';

// ---------------------------------------------------------------------------
// Active category filter (per profile)
// ---------------------------------------------------------------------------

final wardrobeCategoryFilterProvider =
    StateProvider.family<WardrobeCategory?, String>(
  (ref, profileId) => null, // null = All
);

// ---------------------------------------------------------------------------
// Wardrobe items notifier (per profile)
// ---------------------------------------------------------------------------

class WardrobeNotifier extends AutoDisposeFamilyAsyncNotifier<List<WardrobeItem>, String> {
  @override
  Future<List<WardrobeItem>> build(String arg) async {
    return ref
        .watch(wardrobeRepositoryProvider)
        .getItemsForProfile(arg);
  }

  // ---------------------------------------------------------------------------
  // Add item pipeline
  // ---------------------------------------------------------------------------

  /// Tracks the current upload step for UI feedback.
  String _currentStep = '';
  String get currentStep => _currentStep;

  Future<WardrobeItem> addItem(Uint8List imageBytes) async {
    final previous = state;
    final repo = ref.read(wardrobeRepositoryProvider);
    final profileId = arg;

    _currentStep = 'Starting…';

    try {
      final item = await repo.addItem(
        profileId: profileId,
        imageBytes: imageBytes,
        onStep: (step) => _currentStep = step,
      );
      state = AsyncData<List<WardrobeItem>>([item, ...(state.value ?? <WardrobeItem>[])]);
      return item;
    } catch (e, st) {
      state = AsyncError<List<WardrobeItem>>(e, st);
      await Future.delayed(Duration.zero);
      state = previous;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Update / delete
  // ---------------------------------------------------------------------------

  Future<void> updateItem(WardrobeItem item) async {
    final previous = state;
    try {
      final repo = ref.read(wardrobeRepositoryProvider);
      final updated = await repo.updateItem(item);
      final items = <WardrobeItem>[...(state.value ?? <WardrobeItem>[])];
      final idx = items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) items[idx] = updated;
      state = AsyncData<List<WardrobeItem>>(items);
    } catch (e, st) {
      state = AsyncError<List<WardrobeItem>>(e, st);
      await Future.delayed(Duration.zero);
      state = previous;
    }
  }

  Future<void> deleteItem(String itemId) async {
    final previous = state;
    try {
      final repo = ref.read(wardrobeRepositoryProvider);
      await repo.deleteItem(itemId);
      final items = <WardrobeItem>[...(state.value ?? <WardrobeItem>[])]
        ..removeWhere((i) => i.id == itemId);
      state = AsyncData<List<WardrobeItem>>(items);
    } catch (e, st) {
      state = AsyncError<List<WardrobeItem>>(e, st);
      await Future.delayed(Duration.zero);
      state = previous;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

final wardrobeProvider = AutoDisposeAsyncNotifierProviderFamily<
    WardrobeNotifier, List<WardrobeItem>, String>(
  WardrobeNotifier.new,
);

/// Filtered view of wardrobe items by category.
final filteredWardrobeProvider =
    Provider.autoDispose.family<List<WardrobeItem>, String>((ref, profileId) {
  final items = ref.watch(wardrobeProvider(profileId)).value ?? [];
  final filter = ref.watch(wardrobeCategoryFilterProvider(profileId));
  if (filter == null) return items;
  return items.where((i) => i.category == filter).toList();
});
