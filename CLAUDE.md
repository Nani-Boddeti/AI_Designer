# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All Flutter commands require `ANDROID_SDK_ROOT` to be set:

```bash
# Run on connected device/emulator
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter run \
  --dart-define=SUPABASE_URL="..." \
  --dart-define=SUPABASE_ANON_KEY="..." \
  --dart-define=GEMINI_API_KEY="..." \
  --dart-define=REMOVE_BG_API_KEY="..." \
  --dart-define=OPENWEATHER_API_KEY="..."

# Build APK (reads keys from build_apk.sh)
./build_apk.sh [debug|release]

# Analyze (must pass clean before any PR)
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter analyze

# Get dependencies
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter pub get

# Run tests
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter test
# Run a single test file
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter test test/path/to/test.dart
```

**API keys are never in source code.** They are passed exclusively via `--dart-define` at build/run time and read in Dart via `String.fromEnvironment(...)`. The `.env` file holds the values for local reference; `build_apk.sh` passes them to the build.

## Architecture

This is a Flutter Android app for family outfit coordination. Clean Architecture with three layers:

```
lib/
├── core/           # App-wide constants, theme, utilities (no business logic)
├── data/           # Models, repositories, services (Supabase + Gemini + external APIs)
├── domain/         # Use cases (pure orchestration, no Flutter imports)
├── presentation/   # Riverpod providers + screens (UI layer)
└── router/         # GoRouter configuration
```

### State Management — Riverpod

Every piece of shared state is a Riverpod provider defined next to its repository/service:
- `AsyncNotifierProvider` — async state with loading/error (e.g., `authProvider`, `wardrobeProvider`)
- `NotifierProvider` — sync in-memory state (e.g., `generatedOutfitsProvider`)
- `AutoDisposeAsyncNotifierProviderFamily` — scoped per profile ID (e.g., `outfitProvider(profileId)`)

Providers are defined at the bottom of each file and injected via `ref.watch`/`ref.read`. Repositories receive their `SupabaseService` via `ref.watch(supabaseServiceProvider)`.

### Auth & Navigation Flow

GoRouter (`lib/router/app_router.dart`) drives all navigation. It bridges to Riverpod via `_AuthStateListenable` — a `ChangeNotifier` that wraps `authProvider`. The redirect logic enforces three states:
1. Unauthenticated → `/auth`
2. Authenticated, no household → `/household-setup`
3. Authenticated + household → `/home`

`AuthState` (not to be confused with Supabase's `AuthState`) is the app-level model held by `AuthNotifier` containing `User?`, `Profile?`, and `Household?`.

**Critical auth guard pattern**: `createHousehold` and `joinHousehold` must **never** use `AsyncValue.guard`. If they throw and set `AsyncError`, then `authProvider.valueOrNull == null`, which causes the router redirect to send the user back to `/auth` even though they are still authenticated. These methods instead keep `state = AsyncData(...)` at all times and surface errors via `AuthState.error`:

```dart
// CORRECT pattern for household operations:
final prev = state.value ?? const AuthState();
state = AsyncData(prev.copyWith(isLoading: true, error: null));
try {
  // ... do work ...
  state = AsyncData(AuthState(user: ..., profile: ..., household: ...));
} catch (e) {
  state = AsyncData(prev.copyWith(isLoading: false, error: e.toString()));
}
```

**Deep link scheme**: `io.supabase.aidesignerassist://login-callback` — used for email sign-up confirmation, magic links, and Google OAuth redirects. Auth is PKCE flow.

### Data Layer

**SupabaseService** (`lib/data/services/supabase_service.dart`) is a thin wrapper around `SupabaseClient`. All repositories depend on it, not directly on `Supabase.instance`.

**Repositories** contain all Supabase query logic. They return typed models, not raw maps.

**WardrobeRepository.addItem** runs a 5-step pipeline with progress callbacks:
1. Compress image (quality 85, min 800×800)
2. Remove background via remove.bg (optional — swallows errors; item is still saved without it)
3. AI tag via Gemini vision (optional — swallows errors)
4. Upload `original.jpg` to `wardrobe-images` and `processed.png` to `processed-images`
5. Insert row into `wardrobe_items`

Storage paths follow `wardrobe/{profileId}/{itemId}/original.jpg` and `wardrobe/{profileId}/{itemId}/processed.png`.

**GeminiService** (`lib/data/services/gemini_service.dart`) wraps three AI features:
1. `tagWardrobeItem(imageBytes)` — vision model classifies a clothing photo into structured tags
2. `generateOutfits(...)` — text prompt with wardrobe JSON returns coordinated family outfits
3. `analyzeWardrobeGaps(...)` — text prompt returns shopping recommendations

All Gemini calls use `gemini-2.0-flash` with `responseMimeType: 'application/json'`. Responses are stripped of markdown fences before parsing.

**Use cases** (`lib/domain/usecases/`) orchestrate multiple repositories. `GenerateOutfitsUseCase` loads wardrobes for all profiles in parallel, optionally fetches weather, then calls `OutfitRepository.generateOutfits`.

### App Constants (`lib/core/constants/app_constants.dart`)

- `SupabaseTables` — table name strings
- `SupabaseBuckets` — storage bucket name strings
- `WardrobeCategory` / `AgeGroup` — enums (see conventions below)
- `StylePersonas.all` — 15 style label strings used in profile setup
- `FitConstraints.all` — 14 fit preference strings
- `OccasionOptions.all` — 15 occasion strings for outfit generation
- `AppSizes` — spacing/radius constants (`paddingSm/Md/Lg`, `radiusSm/Md/Lg/Xl`, `avatarSmall/Medium/Large`)

### Route Constants (`lib/router/app_router.dart`)

`AppRoutes` exposes path constants and builder helpers:
- `AppRoutes.wardrobePath(profileId)` → `/wardrobe/$profileId`
- `AppRoutes.addItemPath(profileId)` → `/wardrobe/$profileId/add`
- `AppRoutes.itemDetailPath(profileId, itemId)` → `/wardrobe/$profileId/item/$itemId`
- `AppRoutes.profileEditPath(profileId)` → `/profiles/$profileId/edit`

Always use these helpers — never construct route strings inline.

### Supabase Schema

Five tables: `households`, `profiles`, `wardrobe_items`, `outfits`, `calendar_events`. All have RLS enabled. Access is scoped via `current_household_id()` — a SQL function that looks up the current user's household through `profiles.auth_user_id = auth.uid()`.

Child profiles have `auth_user_id = null` — they belong to a household but don't have their own auth user.

Storage buckets: `wardrobe-images`, `processed-images`, `avatars` (all public). Run `supabase_schema.sql` in the Supabase SQL editor to initialize.

### Key Conventions

- **List spreads**: always use explicit type `<Type>[...(list ?? <Type>[])]` to avoid `List<dynamic>` inference errors
- **AsyncData updates**: always pass explicit type parameter: `AsyncData<List<T>>(items)`
- **Null map entries in insert**: use `if (x != null) 'key': x` pattern rather than `'key': x` where x might be null
- **Wildcard parameters**: Dart 3 supports repeated `_` in callbacks — `(_, _, e)` is valid
- **Gemini tag lists**: never use `.cast<String>()` on Gemini responses — use `_toStringList(dynamic)` which checks `is List` before casting
- **Calendar DATE column**: serialize with `.toIso8601String().split('T').first` (DATE not TIMESTAMP)
- **`style_persona` column**: `JSONB DEFAULT '[]'` in schema; `fromJson` uses `is List` guard
- **Auth stream disposal**: always `ref.onDispose(subscription.cancel)` after `.listen()`
- `DropdownButtonFormField.value` deprecation is suppressed inline with `// ignore: deprecated_member_use`
- All enums (`WardrobeCategory`, `AgeGroup`) follow the same pattern: `.value` getter returns `name`, `.fromString()` factory with a safe fallback

### External Services

| Service | Purpose | Free tier |
|---|---|---|
| Gemini 1.5 Flash | Clothing tagging, outfit generation, gap analysis | Generous free tier |
| remove.bg | Background removal on wardrobe photos | 50 credits/month — cache results in `processed-images` bucket |
| OpenWeather | 5-day forecast for outfit weather-matching | Free 1000 calls/day |
| Supabase | Auth, Postgres DB, Storage | Free project |
