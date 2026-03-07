# Architecture Reference

Supplementary reference for Claude Code. See CLAUDE.md for critical patterns and rules.

## Structure

Flutter Android app (**VibeVault**) for family outfit coordination. Flutter SDK `^3.11.0`. Clean Architecture:

```
lib/
├── core/           # App-wide constants, theme, utilities (no business logic)
├── data/           # Models, repositories, services (Supabase + Gemini + external APIs)
├── domain/         # Use cases (pure orchestration, no Flutter imports)
├── presentation/   # Riverpod providers + screens (UI layer)
└── router/         # GoRouter configuration
```

## State Management — Riverpod 3

Provider types in use:
- `AsyncNotifierProvider` — async state with loading/error (`authProvider`, `wardrobeProvider`)
- `AsyncNotifierProvider.autoDispose` — auto-disposed async state
- `NotifierProvider.family` — scoped sync state per key (`_WardrobeCategoryFilter`)
- `NotifierProvider` — sync in-memory state (`generatedOutfitsProvider`)

Providers defined at the bottom of each file. Repositories receive `SupabaseService` via `ref.watch(supabaseServiceProvider)`.

## Auth & Navigation Flow

GoRouter (`lib/router/app_router.dart`) drives navigation via `_AuthStateListenable` — a `ChangeNotifier` wrapping `authProvider` **and** `versionCheckProvider`. Redirect logic:
1. Version check fails (below `min_version`) → `/force-update` (blocking, non-dismissable)
2. Unauthenticated → `/auth`
3. First launch → `/onboarding`
4. Authenticated, no household → `/household-setup`
5. Authenticated + household → `/home`

`AuthState` held by `AuthNotifier` containing `User?`, `Profile?`, `Household?`, `isLoading`, `error`.

Deep link scheme: `io.supabase.aidesignerassist://login-callback` — PKCE for email confirmation, magic links, Google OAuth.

## Data Layer

**SupabaseService** (`lib/data/services/supabase_service.dart`) — thin wrapper around `SupabaseClient`. All repositories depend on it, never on `Supabase.instance` directly.

**WardrobeRepository.addItem** — 5-step pipeline with progress callbacks:
1. Compress image (quality 85, min 800×800)
2. Remove background via remove.bg API (optional — errors swallowed)
3. AI tag via Gemini vision (optional — errors swallowed)
4. Upload `original.jpg` → `wardrobe-images`, `processed.png` → `processed-images`
5. INSERT row into `wardrobe_items`

Storage paths: `wardrobe/{profileId}/{itemId}/original.jpg` and `wardrobe/{profileId}/{itemId}/processed.png`.

**WardrobeNotifier** (infinite scroll):
- 20 items/page (`_pageSize = 20`); `build()` fetches first page only
- `loadMore()` appends to state; guarded by `_hasMore`/`_isLoadingMore`
- `getItemsForProfile(limit, offset)` uses `.range(offset, offset+limit-1)`

**Batch upload** (`lib/presentation/screens/wardrobe/add_item_screen.dart`):
- Gallery: `pickMultiImage` — 1 image → single flow; 2+ → `_processBatch`
- `_processBatch` shows non-dismissable `_BatchProgressSheet` (ValueNotifier-driven), calls `notifier.addItem()` sequentially
- Camera stays single-pick

**GeminiService** (`lib/data/services/gemini_service.dart`) — model `gemini-2.5-flash`:
1. `tagWardrobeItem(imageBytes)` — vision → structured clothing tags
2. `generateOutfits(...)` — wardrobe JSON → coordinated family outfits (2 variants/profile)
3. `analyzeWardrobeGaps(...)` — shopping recommendations

**GeneratedOutfit**:
- `variantNumber` (int, 1 or 2) — 2 distinct variants per profile
- `outfit_result_screen.dart` groups by `profileId` → `_ProfileSection` renders profile header + 2 `_OutfitCard`s ("Option A" / "Option B")
- `_MatchScorePill` shows `harmonyScore` as "X% Match" (green ≥70%, amber ≥50%, red <50%)
- `_OutfitCard` is `ConsumerStatefulWidget` with `_saved`/`_saving` — prevents duplicate saves

**Use cases** (`lib/domain/usecases/`) — `GenerateOutfitsUseCase` supports manual item selection: pinned items skip the auto-pick filter.

**AuthRepository.deleteAccount**: deletes all storage files (wardrobe + processed + avatar) for every profile of the auth user (best-effort), then calls `delete_account` RPC.

## App Constants (`lib/core/constants/app_constants.dart`)

- `SupabaseTables` / `SupabaseBuckets` — table/bucket name strings
- `WardrobeCategory` / `AgeGroup` — enums with `.value` and `.fromString()` (case-insensitive fallback)
- `Gender` — `male`/`female`/`other`; `.fromString(String?)` defaults to `other`
- `SkinTone` — `fair`/`light`/`medium`/`olive`/`brown`/`dark`; `.swatchColor` (ARGB int); `.fromString(String?)` returns nullable
- `StylePersonas.all` (15), `FitConstraints.all` (14), `OccasionOptions.all` (17), `SeasonOptions.all` (5)
- `AppSizes` — `paddingSm/Md/Lg`, `radiusSm/Md/Lg/Xl`, `avatarSmall/Medium/Large`
- `TierLimits` — per-female/per-male counts, min floors, price per suggestion in paisa

## Route Constants (`lib/router/app_router.dart`)

`AppRoutes` helpers:
- `AppRoutes.wardrobePath(profileId)` → `/wardrobe/$profileId`
- `AppRoutes.addItemPath(profileId)` → `/wardrobe/$profileId/add`
- `AppRoutes.itemDetailPath(profileId, itemId)` → `/wardrobe/$profileId/item/$itemId`
- `AppRoutes.profileEditPath(profileId)` → `/profiles/$profileId/edit`
- `AppRoutes.savedOutfits` → `/saved-outfits/:profileId`
- Flat constants: `manualItemSelection`, `virtualLineup`, `gapFiller`, `calendar`, `subscription`, `contactUs`, `privacyPolicy`, `onboarding`

## Supabase Schema

Eight tables: `households`, `profiles`, `wardrobe_items`, `outfits`, `calendar_events`, `household_usage`, `app_config`, `device_tokens`. All RLS enabled.

`profiles` notable columns: `age_group`, `gender`, `skin_tone` (nullable), `style_persona` (JSONB `[]`), `fit_preferences` (JSONB `{}`), `auth_user_id` (null for child profiles), `is_admin` (bool).

`households` notable columns: `tier`, `tier_expires_at`, `dynamic_pricing` (bool), `hemisphere`.

`calendar_events` notable columns: `outfit_assignments` (JSONB `{}` — profileId → outfitId map).

`household_usage` — monthly counter (`household_id`, `year_month` 'YYYY-MM', `outfit_count`). `UsageService` reads/increments via upsert-on-conflict.

`app_config` — force-update control. Row `id='android'` with `min_version TEXT`, `latest_version TEXT`, `store_url TEXT`. RLS: public SELECT. Bump `min_version` to block older builds.

```sql
CREATE TABLE app_config (
  id TEXT PRIMARY KEY,
  min_version TEXT NOT NULL DEFAULT '1.0.0',
  latest_version TEXT NOT NULL DEFAULT '1.0.0',
  store_url TEXT DEFAULT 'https://play.google.com/store/apps/details?id=com.vibevault'
);
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read" ON app_config FOR SELECT USING (true);
INSERT INTO app_config (id, min_version, latest_version) VALUES ('android', '1.0.0', '1.0.0');
```

`device_tokens` — FCM push token per user per platform. UNIQUE(`user_id`, `platform`) — one active token per platform. RLS: users manage own rows; service_role reads all (for Edge Functions).

```sql
CREATE TABLE device_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, platform)
);
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own tokens" ON device_tokens FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

Storage buckets: `wardrobe-images`, `processed-images`, `avatars` (all private — serve via signed URLs).

## Theming

`flex_color_scheme` → `FlexThemeData.light/dark(...)` — never override with raw `ThemeData(...)`. `shimmer` for skeleton loading states.

## Local Storage (Hive)

`hive_flutter` — onboarding-seen flag and lightweight non-sensitive prefs. Never store auth tokens or PII in Hive.

## Branding

Display name **VibeVault**; package `ai_designer_assist` and `applicationId` unchanged (breaks imports + deep links).

SVG assets via `AppAssets` (`lib/core/constants/app_assets.dart`):
- `AppAssets.hero` — splash + auth header
- `AppAssets.appIcon` — compact in-UI, AppBar
- `AppAssets.monoBlack` — dark backgrounds
- `AppAssets.monoWhite` — light backgrounds

`VaultLogoVariant.adaptive` auto-picks mono variant by brightness.

## External Services

| Service | Purpose | Notes |
|---|---|---|
| Gemini 2.5 Flash | Clothing tagging, outfit generation, gap analysis | `gemini-2.5-flash` |
| remove.bg | Background removal | 50 credits/month — cached in `processed-images` |
| OpenWeather | 5-day forecast for outfit weather-matching | 1000 calls/day free |
| Supabase | Auth, Postgres DB, Storage, Edge Functions | Free project |
| Razorpay | In-app subscriptions (pro/prime) | Switch to live keys before publish |
| Firebase Crashlytics | Crash reporting | `google-services.json` gitignored |
| Firebase Messaging | Push notifications (FCM HTTP v1) | Secret `FIREBASE_SERVICE_ACCOUNT` in Supabase |

## Edge Functions

| Function | Trigger | Purpose |
|---|---|---|
| `delete-account` | Client call | Atomic auth + DB + storage deletion |
| `create-razorpay-order` | Client call | Create Razorpay payment order |
| `verify-razorpay-payment` | Client call | Verify + update household tier |
| `send-event-reminders` | Daily cron (9 AM UTC) | FCM reminder for tomorrow's calendar events |
| `notify-member-joined` | Client call (joinHousehold) | FCM alert to existing household members |

All Edge Functions require `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Notification functions also require `FIREBASE_SERVICE_ACCOUNT` (full service account JSON).

Schedule `send-event-reminders` via cron-job.org (POST to `/functions/v1/send-event-reminders` with `Authorization: Bearer <SERVICE_ROLE_KEY>`) or pg_cron + pg_net.
