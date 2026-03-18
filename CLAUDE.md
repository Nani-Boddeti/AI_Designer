# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See `ARCHITECTURE.md` for architecture overview, data layer details, schema, constants, and external services.

## Commands

All Flutter commands require `ANDROID_SDK_ROOT` to be set:

```bash
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter run

./build_apk.sh [debug|release]

ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter analyze
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter pub get
ANDROID_SDK_ROOT="/Users/nani/Library/Android/sdk" flutter test test/path/to/test.dart
```

API keys are stored as Supabase secrets and never reach the client. All external API calls
(Gemini, background removal, OpenWeather) are proxied through JWT-authenticated Edge Functions.

## Critical Patterns

### Auth guard — household operations
`createHousehold` and `joinHousehold` must **never** use `AsyncValue.guard`. If they throw and set `AsyncError`, `authProvider.value == null` → router redirects to `/auth` even though the user is authenticated. Always keep `state = AsyncData(...)` and surface errors via `AuthState.error`:

```dart
final prev = state.value ?? const AuthState();
state = AsyncData(prev.copyWith(isLoading: true, error: null));
try {
  state = AsyncData(AuthState(user: ..., profile: ..., household: ...));
} catch (e) {
  state = AsyncData(prev.copyWith(isLoading: false, error: e.toString()));
}
```

### Supabase INSERT
Never chain `.select()` on INSERT — generate UUID client-side, INSERT, then SELECT separately.
Never include `null` values in INSERT maps — use `if (x != null) 'key': x`.
Remove `created_at` before upsert — let the DB set it (`OutfitRepository.saveOutfit` uses upsert).

### Riverpod 3
- `StateProvider` gone → `NotifierProvider` with explicit method
- External `.notifier.state = x` banned — expose a method
- `FamilyAsyncNotifier`/`FamilyNotifier` gone — use plain `AsyncNotifier<S>` with constructor arg
- `.valueOrNull` → `.value`
- Always pass explicit type on AsyncData: `AsyncData<List<T>>(items)`

### Gemini
- Model: `gemini-2.5-flash`, `responseMimeType: 'application/json'`
- Strip markdown fences before JSON parse
- **Never** use `Schema.enumString` for category — constrained decoding defaults to first enum value. Use free-form string + `WardrobeCategory.fromString`
- Tag lists: never `.cast<String>()` — use `_toStringList(dynamic)` which checks `is List`
- Returns 2 variants per profile (`variantNumber` 1 or 2), temperature 0.7

### Tiers & pricing
- Use `.isProActive`, `.isPrimeActive`, `.isSubscribed` — never compare `.tier` directly (ignores expiry)
- Always use effective tier: `household.isSubscribed ? household.tier : 'free'`
- `TierCalculator.monthlyLimit/pricePaisa` — always pass `dynamicPricing: household.dynamicPricing`
- Tier change: call `update_household_tier(p_tier, p_expires_at)` RPC, then invalidate `authProvider` + `usageNotifierProvider`
- Admin can toggle `dynamic_pricing` post-creation from home screen settings

### Calendar outfit assignment
- `CalendarNotifier.assignOutfit/removeOutfitAssignment` — update `outfitAssignments` map in DB then replace event in local state
- `outfitCoverUrlProvider` — `FutureProvider.autoDispose.family` keyed by `({String profileId, String outfitId})` record; fetches first item's image URL for `_OutfitMiniThumb` (32px circle on event tile)

### Admin role
- `Profile.isAdmin` — set `true` on `createHousehold`, `false` on `joinHousehold`
- Guard edit button, Add Member FAB, and profile edit screen: `currentProfile.isAdmin || profile.id == currentProfile.id`

### CopyWith sentinels
- `AuthState.copyWith`: `_kKeepError` sentinel — pass `error: null` to clear, omit to keep
- `Profile.copyWith`: `_kSkinToneSentinel` — pass `skinTone: null` to clear, omit to keep
- `Household.copyWith`: `_kSentinel` for `tierExpiresAt` — same pattern

### Branding & routing
- Always use `VaultLogo(size, variant)` widget — never `SvgPicture.asset` directly
- Always use `AppRoutes` helpers — never construct route strings inline
- SVG paths in `AppAssets`; `VaultLogoVariant.adaptive` auto-picks mono variant by brightness

### share_plus v12
```dart
await SharePlus.instance.share(ShareParams(files: [...], subject: '...'));
// Not: Share.shareXFiles(...)
```

### In-app review
- `ReviewService.requestIfEligible()` — one-shot (SharedPreferences key `review_requested`); called after first successful "Save All" in `OutfitResultScreen`

### Screenshot / share outfit
```dart
// Capture widget to bytes, then share via share_plus
final image = await screenshotController.capture();
await SharePlus.instance.share(ShareParams(files: [XFile.fromData(image!)], subject: '...'));
```

### Other conventions
- **List spreads**: `<Type>[...(list ?? <Type>[])]` — avoid `List<dynamic>` inference
- **Calendar DATE**: `.toIso8601String().split('T').first`
- **Auth stream**: `ref.onDispose(subscription.cancel)` after `.listen()`
- **`currentProfileIdProvider`** (non-autoDispose): reset to `null` on user change to prevent stale profile
- `DropdownButtonFormField.value` deprecation: suppress inline with `// ignore: deprecated_member_use`
- Weather permission: requested in `StyleSessionScreen.initState()` via `postFrameCallback`; `deniedForever` → snackbar + `openAppSettings` + NYC default
- Storage paths: `wardrobe/{profileId}/{itemId}/original.jpg` and `wardrobe/{profileId}/{itemId}/processed.png`
- Deep link scheme: `io.supabase.aidesignerassist://login-callback`
- `devBypassLimitsProvider` (`lib/core/config/dev_config.dart`) skips usage limits in debug only
- Razorpay test-mode "Something went wrong" after payment is a test artifact — tier updates correctly
