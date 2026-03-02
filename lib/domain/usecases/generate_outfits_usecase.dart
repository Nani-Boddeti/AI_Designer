import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/models/wardrobe_item.dart';
import '../../data/repositories/outfit_repository.dart';
import '../../data/repositories/wardrobe_repository.dart';
import '../../data/services/weather_service.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final generateOutfitsUseCaseProvider = Provider<GenerateOutfitsUseCase>((ref) {
  return GenerateOutfitsUseCase(
    outfitRepository: ref.watch(outfitRepositoryProvider),
    wardrobeRepository: ref.watch(wardrobeRepositoryProvider),
    weatherService: ref.watch(weatherServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// Use case
// ---------------------------------------------------------------------------

/// Orchestrates generating coordinated family outfits:
///  1. Loads each profile's wardrobe.
///  2. Optionally fetches weather for the event date.
///  3. Calls [OutfitRepository.generateOutfits] (which calls Gemini).
class GenerateOutfitsUseCase {
  GenerateOutfitsUseCase({
    required this.outfitRepository,
    required this.wardrobeRepository,
    required this.weatherService,
  });

  final OutfitRepository outfitRepository;
  final WardrobeRepository wardrobeRepository;
  final WeatherService weatherService;

  Future<List<GeneratedOutfit>> execute({
    required List<Profile> profiles,
    required String occasion,
    required DateTime eventDate,
    double? latitude,
    double? longitude,
  }) async {
    // 1. Load wardrobes for all selected profiles in parallel.
    final wardrobeResults = await Future.wait(
      profiles.map(
        (p) => wardrobeRepository
            .getItemsForProfile(p.id)
            .then((items) => MapEntry(p.id, items)),
      ),
    );

    final wardrobeByProfile = Map<String, List<WardrobeItem>>.fromEntries(
      wardrobeResults,
    );

    // Convert to plain maps for the Gemini prompt.
    final wardrobeMapByProfile = wardrobeByProfile.map(
      (id, items) => MapEntry(
        id,
        items.map((item) => item.toJson()).toList(),
      ),
    );

    // 2. Fetch weather if location provided.
    Map<String, dynamic> weatherData = {};
    if (latitude != null && longitude != null) {
      try {
        weatherData = await weatherService.getWeather(
          lat: latitude,
          lon: longitude,
          date: eventDate,
        );
      } catch (_) {
        // Non-fatal – continue without weather.
      }
    }

    // 3. Generate outfits via Gemini.
    return outfitRepository.generateOutfits(
      profiles: profiles,
      occasion: occasion,
      weatherData: weatherData,
      wardrobeByProfile: wardrobeMapByProfile,
    );
  }
}
