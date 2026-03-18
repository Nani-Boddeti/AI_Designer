import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// gemini-proxy/index.ts
// Proxies all Gemini AI calls server-side — API key never reaches the client.
// JWT auth required.
//
// Supported actions (POST body): tag_item | generate_outfits | analyze_gaps
//
// Gemini REST API notes:
//   - Image parts use camelCase: inlineData.mimeType (not inline_data.mime_type)
//   - Response: candidates[0].content.parts[0].text  (always a string)
//   - responseMimeType:'application/json' constrains output but text is still a string
//   - candidates[] can be empty on SAFETY blocks — handle explicitly


const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

// ---------------------------------------------------------------------------
// Gemini REST caller
// ---------------------------------------------------------------------------

type GeminiPart = { text?: string; thought?: boolean };
type GeminiResponse = {
  candidates?: Array<{
    content?: { parts?: GeminiPart[] };
    finishReason?: string;
  }>;
  promptFeedback?: { blockReason?: string };
};

async function callGemini(
  apiKey: string,
  contents: unknown[],
  temperature = 0.7,
): Promise<string> {
  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    // API key in header — not query string
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      contents,
      generationConfig: {
        responseMimeType: 'application/json',
        temperature,
      },
    }),
    signal: AbortSignal.timeout(50_000),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini API ${res.status}: ${err}`);
  }

  const data = (await res.json()) as GeminiResponse;

  // Handle safety blocks or empty candidates
  const candidates = data?.candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) {
    const blockReason = data?.promptFeedback?.blockReason ?? 'unknown';
    throw new Error(`Gemini blocked: ${blockReason}`);
  }

  const candidate = candidates[0];
  if (candidate?.finishReason === 'SAFETY') {
    throw new Error('Gemini response blocked by safety filters');
  }

  // gemini-2.5-flash is a thinking model — parts[] contains thought parts
  // (thought: true) alongside the actual answer. Skip thoughts, take the
  // first non-thought part. Fall back to last part if all are thoughts.
  const parts = candidate?.content?.parts ?? [];
  const textPart = parts.find((p) => !p.thought) ?? parts[parts.length - 1];
  const text = textPart?.text ?? '';

  if (!text) throw new Error('Empty response from Gemini');

  // Strip markdown fences defensively (model may still wrap despite responseMimeType)
  return text.replace(/```(?:json)?\s*/g, '').replace(/```\s*$/g, '').trim();
}

// ---------------------------------------------------------------------------
// Prompt builders
// ---------------------------------------------------------------------------

const TAG_PROMPT = `
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

SAREE RULE: A draped Saree on a person = "fullSet". A folded/undraped Saree fabric alone = "fullSet".
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
`.trim();

function buildOutfitPrompt(
  occasion: string,
  weatherDesc: string,
  profilesJson: unknown,
): string {
  return `
You are an expert Indian family fashion coordinator who deeply understands Indian ethnic and fusion wear.
Create a coordinated outfit for each family member for the given occasion.

OCCASION: ${occasion}
WEATHER: ${weatherDesc}

FAMILY MEMBERS AND THEIR WARDROBES:
${JSON.stringify(profilesJson)}

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
`.trim();
}

function buildGapPrompt(profileJson: unknown, itemsJson: unknown): string {
  const p = profileJson as Record<string, unknown>;
  const items = itemsJson as unknown[];
  return `
You are a personal Indian fashion stylist. Analyse this wardrobe and identify the most impactful missing items for an Indian wardrobe.

PERSON:
- Age group: ${p.age_group}
- Style personas: ${JSON.stringify(p.style_personas)}
- Fit preferences: ${JSON.stringify(p.fit_preferences)}

CURRENT WARDROBE (${items.length} items):
${JSON.stringify(items)}

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
`.trim();
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const reply = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return reply({ error: 'Unauthorized' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { data: { user }, error } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );
    if (error || !user) return reply({ error: 'Invalid token' }, 401);

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) return reply({ error: 'Server misconfiguration' }, 500);

    const body = await req.json();
    const { action } = body;

    // ── tag_item ──────────────────────────────────────────────────────────────
    if (action === 'tag_item') {
      const { image_base64, mime_type = 'image/jpeg' } = body;
      // REST API uses camelCase: inlineData.mimeType
      const contents = [{
        parts: [
          { inlineData: { mimeType: mime_type, data: image_base64 } },
          { text: TAG_PROMPT },
        ],
      }];
      const text = await callGemini(apiKey, contents);
      return reply(JSON.parse(text));
    }

    // ── generate_outfits ──────────────────────────────────────────────────────
    if (action === 'generate_outfits') {
      const { profiles_json, occasion, weather_desc } = body;
      const prompt = buildOutfitPrompt(occasion, weather_desc, profiles_json);
      const text = await callGemini(apiKey, [{ parts: [{ text: prompt }] }]);
      return reply(JSON.parse(text));
    }

    // ── analyze_gaps ──────────────────────────────────────────────────────────
    if (action === 'analyze_gaps') {
      const { profile_json, items_json } = body;
      const prompt = buildGapPrompt(profile_json, items_json);
      const text = await callGemini(apiKey, [{ parts: [{ text: prompt }] }]);
      return reply(JSON.parse(text));
    }

    return reply({ error: 'Unknown action' }, 400);
  } catch (e) {
    return reply({ error: String(e) }, 500);
  }
});
