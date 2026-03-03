import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/outfit.dart';
import '../models/profile.dart';
import '../services/gemini_service.dart';
import '../services/supabase_service.dart';
import '../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final outfitRepositoryProvider = Provider<OutfitRepository>((ref) {
  return OutfitRepository(
    supabaseService: ref.watch(supabaseServiceProvider),
    geminiService: ref.watch(geminiServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class OutfitRepository {
  OutfitRepository({
    required this.supabaseService,
    required this.geminiService,
  });

  final SupabaseService supabaseService;
  final GeminiService geminiService;

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<List<Outfit>> getOutfitsForProfile(String profileId) async {
    final data = await supabaseService.client
        .from(SupabaseTables.outfits)
        .select()
        .eq('profile_id', profileId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Outfit.fromJson(e)).toList();
  }

  Future<Outfit> saveOutfit(Outfit outfit) async {
    final json = outfit.toJson();
    // Remove created_at so DB sets it.
    json.remove('created_at');

    final data = await supabaseService.client
        .from(SupabaseTables.outfits)
        .upsert(json)
        .select()
        .single();

    return Outfit.fromJson(data);
  }

  Future<void> deleteOutfit(String outfitId) async {
    await supabaseService.client
        .from(SupabaseTables.outfits)
        .delete()
        .eq('id', outfitId);
  }

  // ---------------------------------------------------------------------------
  // AI generation
  // ---------------------------------------------------------------------------

  /// Calls GeminiService to generate outfits, then wraps results in [Outfit] objects.
  Future<List<GeneratedOutfit>> generateOutfits({
    required List<Profile> profiles,
    required String occasion,
    required Map<String, dynamic> weatherData,
    required Map<String, List<Map<String, dynamic>>> wardrobeByProfile,
  }) async {
    final rawList = await geminiService.generateOutfits(
      profiles: profiles,
      occasion: occasion,
      weatherData: weatherData,
      wardrobeByProfile: wardrobeByProfile,
    );

    return rawList.map((raw) {
      final profileId = raw['profile_id'] as String? ?? '';
      final profileName = raw['profile_name'] as String? ?? '';
      final rawItemIds = raw['item_ids'];
      final itemIds = rawItemIds is List
          ? rawItemIds.map((e) => e.toString()).toList()
          : <String>[];
      final note = raw['styling_note'] as String? ?? '';
      final harmonyScore =
          (raw['harmony_score'] as num?)?.toDouble() ?? 0.75;

      final outfit = Outfit(
        id: const Uuid().v4(),
        profileId: profileId,
        name: '$profileName\'s $occasion Outfit',
        occasion: occasion,
        itemIds: itemIds,
        notes: note,
        isAiGenerated: true,
        createdAt: DateTime.now(),
      );

      return GeneratedOutfit(
        outfit: outfit,
        profileName: profileName,
        stylingNote: note,
        harmonyScore: harmonyScore,
      );
    }).toList();
  }
}

/// Combines an [Outfit] with additional AI metadata returned by Gemini.
class GeneratedOutfit {
  const GeneratedOutfit({
    required this.outfit,
    required this.profileName,
    required this.stylingNote,
    required this.harmonyScore,
  });

  final Outfit outfit;
  final String profileName;
  final String stylingNote;
  final double harmonyScore;
}
