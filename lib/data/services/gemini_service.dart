import 'dart:convert';
import 'dart:typed_data';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/profile.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
  return GeminiService(apiKey);
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Wraps Google Generative AI calls for the app's three core AI features:
///  1. Wardrobe item tagging
///  2. Family outfit generation
///  3. Wardrobe gap analysis
class GeminiService {
  GeminiService(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.4,
          ),
        );

  final GenerativeModel _model;

  // ---------------------------------------------------------------------------
  // 1. Tag a wardrobe item from image bytes
  // ---------------------------------------------------------------------------

  /// Sends the image to Gemini and returns a structured tagging result.
  ///
  /// Returns a [Map] with keys:
  ///   name, category, colors (List), color_names (List),
  ///   style_tags (List), season_tags (List), brand, description
  Future<Map<String, dynamic>> tagWardrobeItem(Uint8List imageBytes) async {
    const prompt = '''
You are a professional fashion stylist and clothing analyst.
Analyse the clothing item in the image and return a JSON object with exactly these fields:

{
  "name": "<short descriptive name, e.g. 'Floral Wrap Dress'>",
  "category": "<one of: top, bottom, shoes, accessory, outerwear, dress, swimwear>",
  "colors": ["<hex color 1 e.g. #FF5733>", "<hex color 2 if any>"],
  "color_names": ["<human color name 1>", "<human color name 2 if any>"],
  "style_tags": ["<tag1>", "<tag2>", "<tag3>"],
  "season_tags": ["<one or more of: Spring, Summer, Fall, Winter, All-Season>"],
  "brand": "<brand name if visible, else null>",
  "description": "<2-sentence AI styling description>"
}

Rules:
- category must be exactly one of the enum values listed.
- colors list must contain valid hex strings with leading #.
- style_tags: 3–6 descriptive fashion tags (e.g. "casual", "floral", "midi length").
- season_tags: at least one season.
- Return ONLY the JSON object, no markdown fences.
''';

    final content = [
      Content.multi([
        DataPart('image/jpeg', imageBytes),
        TextPart(prompt),
      ]),
    ];

    final response = await _model.generateContent(content);
    final text = response.text ?? '{}';
    return _parseJson(text);
  }

  // ---------------------------------------------------------------------------
  // 2. Generate coordinated family outfits
  // ---------------------------------------------------------------------------

  /// Generates outfit suggestions for multiple family members.
  ///
  /// Returns a list of outfit maps, one per profile, each containing:
  ///   profile_id, profile_name, item_ids (List), styling_note, harmony_score
  Future<List<Map<String, dynamic>>> generateOutfits({
    required List<Profile> profiles,
    required String occasion,
    required Map<String, dynamic> weatherData,
    required Map<String, List<Map<String, dynamic>>> wardrobeByProfile,
  }) async {
    final weatherDesc = weatherData.isNotEmpty
        ? 'Temperature: ${weatherData['temp_c']}°C, '
            '${weatherData['description']}'
        : 'No weather data available';

    final profilesJson = profiles.map((p) {
      final wardrobe = wardrobeByProfile[p.id] ?? [];
      return {
        'profile_id': p.id,
        'profile_name': p.name,
        'age_group': p.ageGroup.displayName,
        'style_personas': p.stylePersona,
        'fit_preferences': p.fitPreferences,
        'wardrobe_items': wardrobe.map((item) => {
              'id': item['id'],
              'category': item['category'],
              'colors': item['colors'],
              'style_tags': item['style_tags'],
            }).toList(),
      };
    }).toList();

    final prompt = '''
You are an expert family fashion coordinator. Create a coordinated outfit for each family member for the given occasion.

OCCASION: $occasion
WEATHER: $weatherDesc

FAMILY MEMBERS AND THEIR WARDROBES:
${jsonEncode(profilesJson)}

Requirements:
- Each outfit must only use items from that member's own wardrobe (reference by "id").
- Outfits should be visually coordinated across the whole family (complementary or analogous colors).
- Respect age group, style personas, and fit preferences.
- If weather data is given, choose weather-appropriate items.
- Write a short, friendly styling note for each person.

Return a JSON array — one object per family member — with this shape:
[
  {
    "profile_id": "<id>",
    "profile_name": "<name>",
    "item_ids": ["<wardrobe item id>", ...],
    "styling_note": "<short note>",
    "harmony_score": <0.0-1.0 float>
  }
]

Return ONLY the JSON array, no markdown fences.
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '[]';
    final parsed = _parseJsonList(text);
    return parsed;
  }

  // ---------------------------------------------------------------------------
  // 3. Analyse wardrobe gaps
  // ---------------------------------------------------------------------------

  /// Analyses gaps in a profile's wardrobe and suggests items to buy.
  ///
  /// Returns a list of recommendation maps:
  ///   item_name, category, colors (List), reason, search_query
  Future<List<Map<String, dynamic>>> analyzeWardrobeGaps({
    required Profile profile,
    required List<Map<String, dynamic>> items,
  }) async {
    final prompt = '''
You are a personal stylist. Analyse this wardrobe and identify the most impactful missing items.

PERSON:
- Name: ${profile.name}
- Age group: ${profile.ageGroup.displayName}
- Style personas: ${profile.stylePersona.join(', ')}
- Fit preferences: ${jsonEncode(profile.fitPreferences)}

CURRENT WARDROBE (${items.length} items):
${jsonEncode(items.map((i) => {
          'name': i['name'],
          'category': i['category'],
          'colors': i['color_names'],
          'style_tags': i['style_tags'],
        }).toList())}

Task: Identify 4–6 wardrobe gaps and suggest specific items to purchase.

Return a JSON array with this shape:
[
  {
    "item_name": "<specific item name>",
    "category": "<top|bottom|shoes|accessory|outerwear|dress|swimwear>",
    "colors": ["<recommended hex color>"],
    "color_names": ["<color name>"],
    "reason": "<1-2 sentence explanation>",
    "search_query": "<optimised shopping search query>"
  }
]

Return ONLY the JSON array, no markdown fences.
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '[]';
    return _parseJsonList(text);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _parseJson(String text) {
    try {
      // Strip possible markdown code fences.
      final clean = text.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  List<Map<String, dynamic>> _parseJsonList(String text) {
    try {
      final clean = text.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      final decoded = jsonDecode(clean);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}
