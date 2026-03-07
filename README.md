# VibeVault

AI-powered family outfit coordination app built with Flutter, Supabase, and Google Gemini.

---

## Features

### 1. Family Hub & Multi-Profile Management
Create a household and add every family member — adults, teens, and toddlers — as individual profiles. Each profile stores a name, avatar, age group, gender, skin tone, style persona (e.g. Business Casual, Sporty, Playful), and sensory/fit preferences (tag-less, loose fit, no jeans, etc.). The household creator becomes the admin; child profiles can be added without separate login credentials. Family members can also join an existing household using a shared invite code.

### 2. AI Wardrobe Digitization
Photograph any clothing item with the camera or pick from the gallery (single or batch). The app automatically:
- Compresses the image for fast upload
- Removes the background using the remove.bg API so items appear on a clean transparent canvas
- Sends the processed image to Google Gemini Vision, which identifies the item name, category, dominant colors (with hex codes), style tags (casual, formal, sporty…), and season suitability
- Saves everything to your personal wardrobe grid, filterable by category with infinite scroll pagination

No manual tagging required — Gemini does it all in seconds.

### 3. Visual Harmony Engine
A built-in color theory engine scores outfit combinations before they reach Gemini. It parses hex color codes from wardrobe items, computes complementary (180° hue offset), analogous (<30°), and triadic (120°) relationships, and produces a 0–1 harmony score. This score is shown as a prominent "X% Match" pill on each outfit card so you can see at a glance how well the family coordinates.

### 4. AI Outfit Generation
Select an occasion, a date, and which family members to dress. The app:
- Fetches the weather forecast for that date automatically
- Collects each profile's wardrobe, style persona, fit constraints, gender, and skin tone
- Supports manual item pinning — pre-select specific items to lock into the generation
- Sends a structured prompt to Gemini asking for 2 distinct coordinated outfit variants per profile
- Presents per-profile outfit cards (Option A / Option B) with item images, harmony score pill, and a styling note
- Offers one-tap **Regenerate** and **Save All** actions

### 5. Virtual Lineup
Side-by-side preview of the whole family's outfits. Each column shows one family member's items stacked vertically using transparent-background processed images, creating a clean mannequin-stack look. A share button lets you export the full lineup as an image.

### 6. Smart Gap Filler Shopping
Select a family member and tap **Analyse Wardrobe**. Gemini reviews the wardrobe inventory against the profile's style persona and returns 3–5 recommended missing pieces — each with a description, suggested color palette, and direct shopping links (Amazon, Google Shopping, Zara, H&M, Target).

### 7. Shared Style Calendar
A household-wide calendar. Days with scheduled outfit events are marked with a mini outfit thumbnail. Tap any day to see event details or add a new event. Each event stores the occasion, weather snapshot, and outfit assignments per family member.

### 8. Subscription Tiers
Three tiers — **Free**, **Pro**, and **Prime** — with per-household monthly outfit generation limits and optional dynamic pricing. Payments via Razorpay (Indian market). Tier upgrades verified server-side via Supabase Edge Functions.

### 9. Push Notifications
- **Event reminders** — FCM notification the day before a scheduled calendar event
- **Member joined** — instant notification to household members when someone new joins

### 10. Force Update Gate
On launch, the app checks the `app_config` table in Supabase. If the installed version is below `min_version`, a non-dismissable update screen blocks the app and directs the user to the Play Store.

### 11. In-App Review
After successfully saving AI-generated outfits for the first time, the native Google Play in-app review dialog is triggered (one-shot, never repeats).

### 12. Magic Link & Password Authentication
Sign in with a one-tap email magic link or traditional email/password. Google OAuth supported via PKCE deep link (`io.supabase.aidesignerassist://login-callback`).

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.x (Android) |
| State management | Riverpod 3 (AsyncNotifierProvider) |
| Navigation | go_router |
| Backend / Auth / DB | Supabase (Postgres + RLS + Edge Functions) |
| AI — tagging & generation | Gemini 2.5 Flash (multimodal) |
| Background removal | remove.bg API |
| Weather | OpenWeatherMap 5-day forecast |
| Payments | Razorpay |
| Push notifications | Firebase Messaging (FCM HTTP v1) |
| Crash reporting | Firebase Crashlytics |
| Local cache | Hive |
| Image loading | cached_network_image |
| Calendar UI | table_calendar |
| Theme | FlexColorScheme Material 3 |

---

## Project Structure

```
lib/
├── core/
│   ├── config/           # Dev bypass flags
│   ├── constants/        # Enums, table names, option lists, assets
│   ├── services/         # NotificationService, ReviewService
│   ├── theme/            # Material 3 theme
│   └── utils/            # ColorHarmony, ShoppingLinks, TierCalculator, VersionUtils
├── data/
│   ├── models/           # Household, Profile, WardrobeItem, Outfit, CalendarEvent
│   ├── repositories/     # Auth, Wardrobe, Outfit, Calendar, Config
│   └── services/         # Supabase, Gemini, Weather
├── domain/
│   └── usecases/         # GenerateOutfitsUseCase, AnalyzeGapsUseCase
├── presentation/
│   ├── providers/        # Auth, Wardrobe, Outfit, Calendar, Usage, VersionCheck
│   └── screens/          # All screens across features + force update
├── router/               # go_router with auth + version-gated routes
└── main.dart
```

---

## Setup

### 1. Clone & install dependencies
```bash
git clone https://github.com/Nani-Boddeti/AI_Designer.git
cd AI_Designer
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter pub get
```

### 2. Configure environment
Keys are never bundled — passed via `--dart-define` at build/run time:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-gemini-key
REMOVE_BG_API_KEY=your-remove-bg-key
OPENWEATHER_API_KEY=your-openweather-key
RAZORPAY_KEY_ID=your-razorpay-key-id
```

### 3. Set up Firebase
- Create a Firebase project, add an Android app
- Download `google-services.json` → place in `android/app/`
- Enable **Firebase Messaging** and **Firebase Crashlytics**
- Add `FIREBASE_SERVICE_ACCOUNT` (full service account JSON) as a Supabase Edge Function secret

### 4. Set up Supabase
- Run `supabase_schema.sql` in the Supabase SQL Editor (Dashboard → SQL Editor)
- Storage buckets `wardrobe-images`, `processed-images`, `avatars` are created by the schema (private, served via signed URLs)
- Enable the **Email** provider under Authentication → Providers (Magic Link included)
- Add your site URL and `io.supabase.aidesignerassist://login-callback` as a redirect URL
- Deploy Edge Functions (Dashboard → Edge Functions):
  - `delete-account`
  - `create-razorpay-order`
  - `verify-razorpay-payment`
  - `send-event-reminders`
  - `notify-member-joined`
- Schedule `send-event-reminders` daily via [cron-job.org](https://cron-job.org) — POST to `https://your-project.supabase.co/functions/v1/send-event-reminders` with `Authorization: Bearer <SERVICE_ROLE_KEY>`

### 5. Run on device / emulator
```bash
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter run \
  --dart-define=SUPABASE_URL="your-url" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key" \
  --dart-define=GEMINI_API_KEY="your-gemini-key" \
  --dart-define=REMOVE_BG_API_KEY="your-remove-bg-key" \
  --dart-define=OPENWEATHER_API_KEY="your-openweather-key" \
  --dart-define=RAZORPAY_KEY_ID="your-razorpay-key"
```

---

## Commands Reference

### Install / update dependencies
```bash
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter pub get
```

### Build APK
```bash
./build_apk.sh debug
./build_apk.sh release
```

Output: `build/app/outputs/flutter-apk/app-debug.apk` or `app-release.apk`

### Static analysis
```bash
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter analyze
```

### Run tests
```bash
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter test
```

---

## API Keys

| Service | Free tier | Where to get |
|---|---|---|
| Supabase | Generous free tier | [supabase.com](https://supabase.com) |
| Google Gemini | 15 req/min free | [aistudio.google.com](https://aistudio.google.com) |
| remove.bg | 50 credits/month | [remove.bg](https://www.remove.bg) |
| OpenWeatherMap | 1000 calls/day free | [openweathermap.org](https://openweathermap.org) |
| Razorpay | Free (test mode) | [razorpay.com](https://razorpay.com) |
| Firebase | Free Spark plan | [firebase.google.com](https://firebase.google.com) |

> Processed wardrobe images are cached in Supabase Storage — remove.bg credits are consumed only once per item.

---

## Database Schema

Eight tables with Row Level Security — household members can only access their own household's data:

| Table | Purpose |
|---|---|
| `households` | Family group with invite code, tier, and hemisphere |
| `profiles` | Individual members with style preferences, skin tone, admin flag |
| `wardrobe_items` | Clothing items with AI-generated tags and image URLs |
| `outfits` | Saved outfit combinations |
| `calendar_events` | Scheduled outfit events with weather snapshot |
| `household_usage` | Monthly outfit generation counter per household |
| `app_config` | Force-update version gate (min_version, store_url) |
| `device_tokens` | FCM push tokens per user per platform |

Full schema: [`supabase_schema.sql`](./supabase_schema.sql)

---

## License

MIT
