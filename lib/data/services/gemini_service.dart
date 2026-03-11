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
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.7,
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
You are a professional Indian fashion stylist and clothing analyst specialising in Indian ethnic and fusion wear.
Carefully examine the image and identify the clothing item or the most prominent clothing item shown.

CATEGORY DEFINITIONS — pick the single best match:
  "top"       → Kurta, Kurti, Tunic, Shirt, Blouse, Saree Blouse, Crop Top, Sherwani Top, T-Shirt, Sweatshirt, any upper-body garment
  "bottom"    → Salwar, Churidar, Palazzo, Lehenga Skirt, Dhoti Pants, Trousers, Jeans, Skirt, Shorts, any lower-body garment
  "fullSet"   → Saree (with or without blouse), Lehenga Set (skirt+blouse+dupatta), Salwar Suit (3-piece), Anarkali, Co-ord Set, Jumpsuit, Sherwani Set, Sharara Set, Gharara Set — i.e. a COMPLETE outfit sold/worn as one unit
  "dress"     → Western one-piece dress, romper, mini/midi/maxi dress
  "outerwear" → Jacket, Shrug, Blazer, Nehru Jacket, Cape, Coat, Hoodie
  "shoes"     → Juttis, Kolhapuri, Mojari, Heels, Flats, Sneakers, Sandals, Boots, any footwear
  "accessory" → Dupatta, Stole, Bangles, Necklace, Maang Tikka, Earrings, Clutch, Belt, Watch, Sunglasses, Scarf, any accessory
  "swimwear"  → Swimsuit, Bikini, Cover-up, Swim trunks

SAREE RULE: A draped Saree on a person = "fullSet". A folded/undrped Saree fabric alone = "fullSet".
DUPATTA RULE: A standalone Dupatta or stole = "accessory". When part of a Salwar Suit = "fullSet".

FULL-OUTFIT PHOTOS: If the image shows a complete outfit on a person or mannequin,
identify the SINGLE item that visually dominates the frame (largest area, most detailed).

Return a JSON object with exactly these fields (no markdown fences):
{
  "name": "<concise Indian item name, e.g. 'Chikankari Embroidered Kurti' or 'Banarasi Silk Saree'>",
  "category": "<exactly one lowercase value from the list above>",
  "colors": ["<dominant hex color e.g. #1A2B3C>", "<secondary hex if clearly present>"],
  "color_names": ["<human color name>", "<second color name if any>"],
  "style_tags": ["<tag1>", "<tag2>", "<tag3>"],
  "season_tags": ["<one or more of: Spring, Summer, Fall, Winter, All-Season>"],
  "brand": "<brand name if a logo or label is clearly visible, else null>",
  "description": "<2-sentence styling description highlighting the Indian craft, fabric, or occasion suitability>"
}

Rules:
- category MUST be exactly one of the eight values defined above (use camelCase for fullSet).
- Recognise Indian embroidery/craft names: Chikankari, Zardozi, Phulkari, Bandhani, Block Print, Kantha, Kalamkari, Ikat, Banarasi, Kanjeevaram, Chanderi, Lucknowi.
- style_tags: 3–6 descriptors e.g. "ethnic wear", "embroidered yoke", "tunic length", "relaxed fit", "festival wear", "Chikankari embroidery".
- season_tags: Indian climate — prefer "Summer", "All-Season", "Winter" as applicable.
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
        'wardrobe_items': wardrobe.map((item) => {
              'id': item['id'],
              'category': item['category'],
              'colors': item['colors'],
              'style_tags': item['style_tags'],
            }).toList(),
      };
    }).toList();

    final prompt = '''
You are an expert Indian family fashion coordinator who deeply understands Indian ethnic and fusion wear.
Create a coordinated outfit for each family member for the given occasion.

OCCASION: $occasion
WEATHER: $weatherDesc

FAMILY MEMBERS AND THEIR WARDROBES:
${jsonEncode(profilesJson)}

Requirements:
- Each outfit must only use items from that member's own wardrobe (reference by "id").
- Outfits should be visually coordinated across the whole family (complementary or analogous colors).
- Respect age group, style personas, and fit preferences.
- Respect gender: suggest styles appropriate and flattering for that gender.
- If complexion is provided, prefer colours that complement that complexion.
- If weather data is given, choose weather-appropriate items.
- Write a short, friendly styling note for each person.

INDIAN GARMENT LAYERING RULES — strictly follow these:
1. Saree (fullSet) is complete on its own — pair with matching Blouse (top) from wardrobe if available. Do not add bottoms.
2. Kurta/Kurti (top) pairs with Salwar/Churidar/Palazzo (bottom). Add Dupatta (accessory) if available.
3. Lehenga Set (fullSet) is complete — do not add separate bottoms or tops.
4. Salwar Suit (fullSet) is complete on its own.
5. Anarkali (fullSet) is complete — may pair with a belt (accessory) optionally.
6. Sherwani Set (fullSet) for men — complete on its own, add Mojari/Jutti (shoes) if available.
7. Never combine fullSet + bottom (e.g., Saree + Jeans is culturally incorrect).
8. Dupatta should be suggested as an accessory when Kurta/Kurti is the top, especially for weddings, festivals, puja.
9. For Indian festivals (Diwali, Navratri, Eid, Wedding, Mehndi, Sangeet, Puja): strongly prefer ethnic wear over western.
10. For casual/office: fusion (Kurti + trousers/jeans) is acceptable.

OCCASION-SPECIFIC GUIDANCE:
- Wedding/Mehndi/Sangeet/Eid/Navratri/Diwali/Puja → Saree, Lehenga, Anarkali, Salwar Suit preferred
- Office/Work → Kurti + Palazzo/Churidar, or fusion Kurti + trousers
- Casual/Everyday → Kurti, casual Kurta, or western wear
- Family Function/Birthday → Ethnic or smart fusion

Return a JSON array — TWO objects per family member (variant 1 and variant 2) — with this shape:
[
  {
    "profile_id": "<id>",
    "profile_name": "<name>",
    "variant_number": 1,
    "item_ids": ["<wardrobe item id>", ...],
    "styling_note": "<short, warm styling note mentioning the Indian garment and occasion>",
    "harmony_score": <0.0-1.0 float>
  }
]

Variant 1 = best coordinated ethnic/occasion-appropriate pick.
Variant 2 = a distinctly different color/silhouette combination (or fusion alternative if ethnic not available).
Never repeat the same item_id combination between variants for the same profile.
Total objects = number of profiles × 2.

HARMONY SCORE RULES:
- Reflect ACTUAL color compatibility between the selected items, not just general outfit quality.
- Scores above 0.92 are RARE — reserve for truly perfect complementary color combinations.
- A typical good outfit scores 0.70–0.85; an excellent outfit 0.85–0.92.
- Variant 1 should generally score higher than Variant 2.
- Score below 0.60 if colors clash significantly.
- Never give both variants the same score for the same profile.

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
You are a personal Indian fashion stylist. Analyse this wardrobe and identify the most impactful missing items for an Indian wardrobe.

PERSON:
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

Task: Identify 4–6 wardrobe gaps and suggest specific Indian or fusion items to purchase.

INDIAN WARDROBE ESSENTIALS TO CHECK FOR:
- At least one Dupatta/Stole (accessory) — essential for completing ethnic looks
- At least one ethnic footwear (Juttis, Kolhapuri, or Mojari for Indian occasions)
- A versatile Kurti or Salwar Suit for office/casual use
- A festive piece (Anarkali, Lehenga, or Banarasi Saree) for weddings/festivals
- A Nehru Jacket or ethnic Shrug for layering at formal events (especially men)
- Neutral/earth-toned Palazzo or Churidar to pair with multiple Kurtis

Return a JSON array with this shape (Indian-focused search queries for Myntra/Ajio/Nykaa Fashion):
[
  {
    "item_name": "<specific Indian item name, e.g. 'Chanderi Silk Kurti'>",
    "category": "<top|bottom|fullSet|shoes|accessory|outerwear|dress|swimwear>",
    "colors": ["<recommended hex color>"],
    "color_names": ["<color name>"],
    "reason": "<1-2 sentence explanation of why this fills a gap>",
    "search_query": "<Indian shopping search query e.g. 'Chikankari cotton kurti women' or 'men Nehru jacket silk'>"
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
        // Eager filter — avoids lazy cast throwing outside the try/catch.
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }
}
