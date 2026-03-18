import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final geminiServiceProvider = Provider<GeminiService>(
  (ref) => GeminiService(),
);

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Wraps Gemini AI calls proxied through the gemini-proxy Edge Function.
/// API key never reaches the client — all calls are JWT-authenticated.
class GeminiService {
  final _functions = Supabase.instance.client.functions;

  // ---------------------------------------------------------------------------
  // 1. Tag a wardrobe item from image bytes
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> tagWardrobeItem(Uint8List imageBytes) async {
    final res = await _functions.invoke(
      'gemini-proxy',
      body: {
        'action': 'tag_item',
        'image_base64': base64Encode(imageBytes),
        'mime_type': 'image/jpeg',
      },
    );
    return (res.data as Map<String, dynamic>?) ?? {};
  }

  // ---------------------------------------------------------------------------
  // 2. Generate coordinated family outfits
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> generateOutfits({
    required List<Profile> profiles,
    required String occasion,
    required Map<String, dynamic> weatherData,
    required Map<String, List<Map<String, dynamic>>> wardrobeByProfile,
  }) async {
    final weatherDesc = weatherData.isNotEmpty
        ? 'Temperature: ${weatherData['temp_c']}°C, ${weatherData['description']}'
        : 'No weather data available';

    // Pseudonymize names — never send real names to third-party AI services.
    final profilesJson = profiles.asMap().entries.map((entry) {
      final p = entry.value;
      final wardrobe = wardrobeByProfile[p.id] ?? [];
      return {
        'profile_id': p.id,
        'profile_name': 'Member ${entry.key + 1}',
        'age_group': p.ageGroup.displayName,
        'gender': p.gender.displayName,
        if (p.skinTone != null) 'complexion': p.skinTone!.displayName,
        'style_personas': p.stylePersona,
        'fit_preferences': p.fitPreferences,
        'wardrobe_items': wardrobe
            .map((item) => {
                  'id': item['id'],
                  'category': item['category'],
                  'colors': item['colors'],
                  'style_tags': item['style_tags'],
                })
            .toList(),
      };
    }).toList();

    final res = await _functions.invoke(
      'gemini-proxy',
      body: {
        'action': 'generate_outfits',
        'profiles_json': profilesJson,
        'occasion': occasion,
        'weather_desc': weatherDesc,
      },
    );
    final data = res.data;
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  // ---------------------------------------------------------------------------
  // 3. Analyse wardrobe gaps
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> analyzeWardrobeGaps({
    required Profile profile,
    required List<Map<String, dynamic>> items,
  }) async {
    final profileJson = {
      'age_group': profile.ageGroup.displayName,
      'style_personas': profile.stylePersona,
      'fit_preferences': profile.fitPreferences,
    };

    final itemsJson = items
        .map((i) => {
              'name': i['name'],
              'category': i['category'],
              'colors': i['color_names'],
              'style_tags': i['style_tags'],
            })
        .toList();

    final res = await _functions.invoke(
      'gemini-proxy',
      body: {
        'action': 'analyze_gaps',
        'profile_json': profileJson,
        'items_json': itemsJson,
      },
    );
    final data = res.data;
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return [];
  }
}
