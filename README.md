# AI Designer Assist

AI-powered family outfit coordination app built with Flutter, Supabase, and Google Gemini.

---

## Features

### 1. Family Hub & Multi-Profile Management
Create a household and add every family member — adults, teens, and toddlers — as individual profiles. Each profile stores a name, avatar, age group, style persona (e.g. Business Casual, Sporty, Playful), and sensory/fit preferences (tag-less, loose fit, no jeans, etc.). One account owner manages the household; child profiles can be added without separate login credentials. Family members can also join an existing household using a shared invite code.

### 2. AI Wardrobe Digitization
Photograph any clothing item with the camera or pick from the gallery. The app automatically:
- Compresses the image for fast upload
- Removes the background using the remove.bg API so items appear on a clean transparent canvas
- Sends the processed image to Google Gemini Vision, which identifies the item name, category, dominant colors (with hex codes), style tags (casual, formal, sporty…), and season suitability
- Saves everything to your personal wardrobe grid, filterable by category

No manual tagging required — Gemini does it all in seconds.

### 3. Visual Harmony Engine
A built-in color theory engine scores outfit combinations before they reach Gemini. It parses hex color codes from wardrobe items, computes complementary (180° hue offset), analogous (<30°), and triadic (120°) relationships, and produces a 0–1 harmony score. This score is shown as a badge on each generated outfit card so you can see at a glance how well the family coordinates.

### 4. AI Outfit Generation
Select an occasion (birthday party, school run, wedding, etc.), a date, and which family members to dress. The app:
- Fetches the weather forecast for that date automatically
- Collects each profile's wardrobe, style persona, and fit constraints
- Sends a single structured prompt to Gemini asking for coordinated but non-matching outfits
- Presents per-profile outfit cards with item images, harmony score, and a short styling note from the AI
- Offers a one-tap **Regenerate** button for fresh combinations

### 5. Virtual Lineup
Side-by-side preview of the whole family's outfit. Each column shows one family member's items stacked vertically (accessory → top → bottom → shoes) using the transparent-background processed images, creating a clean mannequin-stack look. A screenshot button lets you share the full lineup as an image via any installed share app.

### 6. Smart Gap Filler Shopping
Select a family member and tap **Analyse Wardrobe**. Gemini reviews the entire wardrobe inventory against the profile's style persona and returns 3–5 recommended missing pieces — each with a description, suggested color palette, and three direct shopping links (Amazon, Google Shopping, Zara). Tapping a link opens the browser directly to a pre-filled search.

### 7. Shared Style Calendar
A household-wide calendar powered by TableCalendar. Days with scheduled outfit events are marked with a dot. Tap any day to see event details or add a new event. Each event stores the occasion, weather snapshot, and outfit assignments per family member. Outfits can be newly generated on the spot or picked from previously saved looks.

### 8. Magic Link Authentication
Sign in with a one-tap email link — no password required. Enter your email, receive the link, tap it, and you're in. Ideal for family members who share devices or dislike passwords. Traditional email/password sign-up is also supported alongside the magic link flow.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.41 (Android) |
| State management | Riverpod 2 (AsyncNotifier) |
| Navigation | go_router |
| Backend / Auth / DB | Supabase |
| AI — tagging | Gemini 1.5 Flash (multimodal) |
| AI — outfit generation | Gemini 1.5 Flash |
| Background removal | remove.bg API |
| Weather | OpenWeatherMap 5-day forecast |
| Local cache | Hive |
| Image loading | cached_network_image |
| Calendar UI | table_calendar |
| Theme | FlexColorScheme Material 3 |

---

## Project Structure

```
lib/
├── core/
│   ├── constants/        # Enums, table names, option lists
│   ├── theme/            # Material 3 deep-purple theme
│   └── utils/
│       ├── color_harmony.dart    # Complementary / analogous scoring
│       └── shopping_links.dart   # Amazon / Google / Zara URL builders
├── data/
│   ├── models/           # Household, Profile, WardrobeItem, Outfit, CalendarEvent
│   ├── repositories/     # Auth, Wardrobe, Outfit, Calendar
│   └── services/         # Supabase, Gemini, remove.bg, Weather
├── domain/
│   └── usecases/         # GenerateOutfitsUseCase, AnalyzeGapsUseCase
├── presentation/
│   ├── providers/        # 5 Riverpod providers
│   └── screens/          # 14 screens across all features
├── router/               # go_router with auth-gated routes
└── main.dart
```

---

## Setup

### 1. Clone & install dependencies
```bash
git clone https://github.com/Nani-Boddeti/AI_Designer.git
cd AI_Designer
flutter pub get
```

### 2. Configure environment
Create a `.env` file in the project root:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-gemini-key
REMOVE_BG_API_KEY=your-remove-bg-key
OPENWEATHER_API_KEY=your-openweather-key
```

### 3. Set up Supabase
- Run `supabase_schema.sql` in your Supabase SQL Editor
- Create two **public** Storage buckets: `wardrobe` and `avatars`
- Enable the **Email** provider under Authentication → Providers (Magic Link is included)

### 4. Run
```bash
flutter run
```

---

## API Keys

| Service | Free tier | Where to get |
|---|---|---|
| Supabase | Generous free tier | [supabase.com](https://supabase.com) |
| Google Gemini | 15 req/min free | [aistudio.google.com](https://aistudio.google.com) |
| remove.bg | 50 credits/month | [remove.bg](https://www.remove.bg) |
| OpenWeatherMap | 1000 calls/day free | [openweathermap.org](https://openweathermap.org) |

> **Note:** Processed wardrobe images are cached in Supabase Storage so remove.bg credits are only consumed once per item.

---

## Database Schema

Five tables with Row Level Security — household members can only access their own household's data:

- `households` — family group with invite code
- `profiles` — individual family members with style preferences
- `wardrobe_items` — clothing items with AI-generated tags
- `outfits` — saved outfit combinations
- `calendar_events` — scheduled outfit events with weather snapshot

Full schema: [`supabase_schema.sql`](./supabase_schema.sql)

---

## License

MIT
