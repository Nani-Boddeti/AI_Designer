import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/wardrobe_repository.dart';
import '../../data/services/gemini_service.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final analyzeGapsUseCaseProvider = Provider<AnalyzeGapsUseCase>((ref) {
  return AnalyzeGapsUseCase(
    wardrobeRepository: ref.watch(wardrobeRepositoryProvider),
    geminiService: ref.watch(geminiServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// Use case
// ---------------------------------------------------------------------------

/// Loads a profile's wardrobe and asks Gemini to identify missing items.
class AnalyzeGapsUseCase {
  AnalyzeGapsUseCase({
    required this.wardrobeRepository,
    required this.geminiService,
  });

  final WardrobeRepository wardrobeRepository;
  final GeminiService geminiService;

  /// Returns a list of gap recommendation maps with keys:
  ///   item_name, category, colors (List), color_names (List),
  ///   reason, search_query.
  Future<List<Map<String, dynamic>>> execute(Profile profile) async {
    final items = await wardrobeRepository.getItemsForProfile(profile.id);
    final itemMaps = items.map((i) => i.toJson()).toList();

    return geminiService.analyzeWardrobeGaps(
      profile: profile,
      items: itemMaps,
    );
  }
}
