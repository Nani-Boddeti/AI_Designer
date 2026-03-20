# ARCHITECTURE

## 1. PROJECT STRUCTURE

This repository is a monorepo with three runtime surfaces:
- Flutter Android client in `lib/` + `android/`
- Supabase backend in `supabase/` + `supabase_schema.sql`
- React/Vite admin backoffice in `web_backoffice/`

The tree below is the repository-owned source/configuration tree, grouped by architectural area. It excludes generated/vendor/local-only directories such as `web_backoffice/node_modules/`, `web_backoffice/dist/`, `.git/`, `.idea/`, `.vscode/`, `.claude/`, `.DS_Store`, and secret-bearing local files. Working-copy-only artifacts currently present but not part of the tracked source tree include `actual/`, `reference/`, `sublime texts/`, `build_apk.sh`, `supabase/.temp/`, and `supabase/migrations/create_household_rpc.sql`.

```text
.
├── .github
│   └── workflows
│       ├── cd.yml
│       └── ci.yml
├── android
│   ├── app
│   │   ├── src
│   │   │   ├── debug
│   │   │   │   └── AndroidManifest.xml
│   │   │   ├── main
│   │   │   │   ├── kotlin
│   │   │   │   │   └── com
│   │   │   │   │       └── aidesigner
│   │   │   │   │           └── ai_designer_assist
│   │   │   │   │               └── MainActivity.kt
│   │   │   │   ├── res
│   │   │   │   │   ├── drawable
│   │   │   │   │   │   └── launch_background.xml
│   │   │   │   │   ├── drawable-hdpi
│   │   │   │   │   │   └── ic_launcher_foreground.png
│   │   │   │   │   ├── drawable-mdpi
│   │   │   │   │   │   └── ic_launcher_foreground.png
│   │   │   │   │   ├── drawable-v21
│   │   │   │   │   │   └── launch_background.xml
│   │   │   │   │   ├── drawable-xhdpi
│   │   │   │   │   │   └── ic_launcher_foreground.png
│   │   │   │   │   ├── drawable-xxhdpi
│   │   │   │   │   │   └── ic_launcher_foreground.png
│   │   │   │   │   ├── drawable-xxxhdpi
│   │   │   │   │   │   └── ic_launcher_foreground.png
│   │   │   │   │   ├── mipmap-anydpi-v26
│   │   │   │   │   │   └── ic_launcher.xml
│   │   │   │   │   ├── mipmap-hdpi
│   │   │   │   │   │   └── ic_launcher.png
│   │   │   │   │   ├── mipmap-mdpi
│   │   │   │   │   │   └── ic_launcher.png
│   │   │   │   │   ├── mipmap-xhdpi
│   │   │   │   │   │   └── ic_launcher.png
│   │   │   │   │   ├── mipmap-xxhdpi
│   │   │   │   │   │   └── ic_launcher.png
│   │   │   │   │   ├── mipmap-xxxhdpi
│   │   │   │   │   │   └── ic_launcher.png
│   │   │   │   │   ├── values
│   │   │   │   │   │   ├── colors.xml
│   │   │   │   │   │   └── styles.xml
│   │   │   │   │   └── values-night
│   │   │   │   │       └── styles.xml
│   │   │   │   └── AndroidManifest.xml
│   │   │   └── profile
│   │   │       └── AndroidManifest.xml
│   │   └── build.gradle.kts
│   ├── gradle
│   │   └── wrapper
│   │       └── gradle-wrapper.properties
│   ├── .gitignore
│   ├── build.gradle.kts
│   ├── gradle.properties
│   └── settings.gradle.kts
├── assets
│   ├── images
│   │   ├── icon_1024.png
│   │   ├── logo.png
│   │   ├── vault-app-icon.svg
│   │   ├── vault-hero.svg
│   │   ├── vault-monochrome-black.svg
│   │   └── vault-monochrome-white.svg
│   └── marketing
│       └── playstore_feature_graphic.png
├── integration_test
│   └── app_test.dart
├── lib
│   ├── core
│   │   ├── constants
│   │   │   ├── app_assets.dart
│   │   │   └── app_constants.dart
│   │   ├── services
│   │   │   ├── notification_service.dart
│   │   │   └── review_service.dart
│   │   ├── theme
│   │   │   └── app_theme.dart
│   │   ├── utils
│   │   │   ├── color_harmony.dart
│   │   │   ├── error_utils.dart
│   │   │   ├── shopping_links.dart
│   │   │   ├── tier_calculator.dart
│   │   │   └── version_utils.dart
│   │   └── widgets
│   │       └── vault_logo.dart
│   ├── data
│   │   ├── models
│   │   │   ├── calendar_event.dart
│   │   │   ├── household.dart
│   │   │   ├── household_membership.dart
│   │   │   ├── outfit.dart
│   │   │   ├── profile.dart
│   │   │   └── wardrobe_item.dart
│   │   ├── repositories
│   │   │   ├── auth_repository.dart
│   │   │   ├── calendar_repository.dart
│   │   │   ├── config_repository.dart
│   │   │   ├── outfit_repository.dart
│   │   │   └── wardrobe_repository.dart
│   │   └── services
│   │       ├── background_removal_service.dart
│   │       ├── gemini_service.dart
│   │       ├── supabase_service.dart
│   │       ├── usage_service.dart
│   │       └── weather_service.dart
│   ├── domain
│   │   └── usecases
│   │       ├── analyze_gaps_usecase.dart
│   │       └── generate_outfits_usecase.dart
│   ├── presentation
│   │   ├── providers
│   │   │   ├── auth_provider.dart
│   │   │   ├── calendar_provider.dart
│   │   │   ├── onboarding_provider.dart
│   │   │   ├── outfit_provider.dart
│   │   │   ├── profile_provider.dart
│   │   │   ├── usage_provider.dart
│   │   │   ├── version_check_provider.dart
│   │   │   └── wardrobe_provider.dart
│   │   └── screens
│   │       ├── auth
│   │       │   ├── auth_screen.dart
│   │       │   ├── household_picker_screen.dart
│   │       │   └── household_setup_screen.dart
│   │       ├── calendar
│   │       │   └── style_calendar_screen.dart
│   │       ├── force_update
│   │       │   └── force_update_screen.dart
│   │       ├── home
│   │       │   └── home_screen.dart
│   │       ├── more
│   │       │   ├── contact_us_screen.dart
│   │       │   └── privacy_policy_screen.dart
│   │       ├── onboarding
│   │       │   └── onboarding_screen.dart
│   │       ├── outfit
│   │       │   ├── manual_item_selection_screen.dart
│   │       │   ├── outfit_result_screen.dart
│   │       │   ├── style_session_screen.dart
│   │       │   └── virtual_lineup_screen.dart
│   │       ├── profiles
│   │       │   ├── profile_edit_screen.dart
│   │       │   └── profile_list_screen.dart
│   │       ├── shopping
│   │       │   └── gap_filler_screen.dart
│   │       ├── splash
│   │       │   └── splash_screen.dart
│   │       ├── subscription
│   │       │   └── subscription_screen.dart
│   │       └── wardrobe
│   │           ├── add_item_screen.dart
│   │           ├── item_detail_screen.dart
│   │           ├── saved_outfits_screen.dart
│   │           └── wardrobe_screen.dart
│   ├── router
│   │   └── app_router.dart
│   └── main.dart
├── supabase
│   ├── functions
│   │   ├── _shared
│   │   │   └── fcm.ts
│   │   ├── backoffice-proxy
│   │   │   └── index.ts
│   │   ├── check-tier-expiry
│   │   │   └── index.ts
│   │   ├── create-razorpay-order
│   │   │   └── index.ts
│   │   ├── delete-account
│   │   │   └── index.ts
│   │   ├── gemini-proxy
│   │   │   └── index.ts
│   │   ├── leave-household
│   │   │   └── index.ts
│   │   ├── notify-member-joined
│   │   │   └── index.ts
│   │   ├── remove-background
│   │   │   └── index.ts
│   │   ├── send-event-reminders
│   │   │   └── index.ts
│   │   ├── verify-razorpay-payment
│   │   │   └── index.ts
│   │   └── weather-proxy
│   │       └── index.ts
│   ├── migrations
│   │   ├── delete_account_rpc.sql
│   │   ├── household_rls_fix.sql
│   │   ├── integrity_fixes.sql
│   │   ├── join_household_rpc.sql
│   │   ├── payment_transactions.sql
│   │   ├── security_fixes_2.sql
│   │   ├── security_fixes_3.sql
│   │   ├── security_fixes_4.sql
│   │   ├── storage_rls_fix.sql
│   │   └── tenant_isolation_fix.sql
│   └── integrity_health_checks.sql
├── tasks
│   ├── code-review-gender-monetisation.md
│   ├── code_review_correctness.md
│   ├── code_review_runtime_bugs.md
│   └── multi_household_plan.md
├── test
│   ├── widgets
│   │   ├── auth_screen_test.dart
│   │   └── force_update_screen_test.dart
│   ├── app_routes_test.dart
│   ├── auth_provider_test.dart
│   ├── calendar_event_model_test.dart
│   ├── calendar_events_map_test.dart
│   ├── color_harmony_test.dart
│   ├── enums_test.dart
│   ├── error_utils_test.dart
│   ├── generated_outfit_parsing_test.dart
│   ├── household_membership_model_test.dart
│   ├── household_model_test.dart
│   ├── outfit_model_test.dart
│   ├── profile_model_test.dart
│   ├── shopping_links_test.dart
│   ├── storage_path_test.dart
│   ├── tier_calculator_test.dart
│   ├── usage_state_test.dart
│   ├── validators_test.dart
│   ├── virtual_lineup_logic_test.dart
│   ├── wardrobe_item_model_test.dart
│   └── widget_test.dart
├── web_backoffice
│   ├── src
│   │   ├── app
│   │   │   ├── layout
│   │   │   │   └── AppShell.tsx
│   │   │   └── router.tsx
│   │   ├── features
│   │   │   ├── auth
│   │   │   │   ├── AuthContext.tsx
│   │   │   │   └── LoginPage.tsx
│   │   │   ├── dashboard
│   │   │   │   └── DashboardPage.tsx
│   │   │   └── entities
│   │   │       ├── __tests__
│   │   │       │   └── EntityConfig.test.ts
│   │   │       ├── EntityBrowserPage.tsx
│   │   │       ├── EntityConfig.ts
│   │   │       └── entity_api.ts
│   │   ├── lib
│   │   │   ├── __tests__
│   │   │   │   └── proxy_api.test.ts
│   │   │   ├── proxy_api.ts
│   │   │   └── supabase.ts
│   │   ├── styles
│   │   │   └── global.css
│   │   ├── main.tsx
│   │   └── vite-env.d.ts
│   ├── .env.example
│   ├── .gitignore
│   ├── README.md
│   ├── eslint.config.js
│   ├── index.html
│   ├── package-lock.json
│   ├── package.json
│   ├── tsconfig.json
│   ├── tsconfig.tsbuildinfo
│   ├── vite.config.ts
│   └── vitest.config.ts
├── .gitignore
├── .metadata
├── ARCHITECTURE.md
├── CLAUDE.md
├── README.md
├── analysis_options.yaml
├── logo.png
├── pubspec.lock
├── pubspec.yaml
└── supabase_schema.sql
```

## 2. HIGH-LEVEL SYSTEM DIAGRAM

```text
[Family end users] --------------------------+
                                             |
                                             v
                                  [Flutter Android app]
                                             |
                                             | Supabase client SDK
                                             v
[Internal admins] -> [React/Vite backoffice] -> [Supabase Edge Function: backoffice-proxy]
                                             |
                                             v
                                    [Supabase platform]
                                    - Auth
                                    - Postgres + RLS + RPCs
                                    - Storage buckets
                                    - Edge Functions
                                             |
        +--------------------+---------------+---------------------+----------------------+
        |                    |                                     |                      |
        v                    v                                     v                      v
 [Google Gemini API]   [remove.bg / rembg]               [OpenWeatherMap]         [Razorpay API]
        |                    |                                     |                      |
        +--------------------+----------------------+--------------+----------------------+
                                                   |
                                                   v
                                           [Supabase Postgres]
                                           [Supabase Storage]

Supporting services:
- Firebase Messaging (FCM) via Edge Functions for push notifications
- Firebase Crashlytics from the mobile app for crash reporting
- cron-job.org or optional Supabase pg_cron for scheduled reminder/expiry jobs
```

Architecturally, this is not a traditional custom backend server. The backend is split between:
- Supabase-managed primitives (Auth, Postgres, Storage)
- SQL-level RPCs and RLS policies for tenancy and atomic writes
- Deno-based Edge Functions for privileged integrations and secret-bearing calls

## 3. CORE COMPONENTS

| Component | Purpose | Technologies | Deployment method |
|---|---|---|---|
| Mobile frontend | End-user app for auth, households, wardrobes, outfit generation, shopping suggestions, calendar, subscriptions, notifications | Flutter, Riverpod, go_router, Hive, SharedPreferences, Firebase Messaging, Firebase Crashlytics, Razorpay Flutter SDK | Built as an Android APK. Local builds use Flutter/Gradle; tagged releases are built by GitHub Actions and published as draft GitHub Releases. |
| Web backoffice | Internal CRUD/admin UI for households, profiles, wardrobe items, outfits, calendar events, app config, usage, payments, and device tokens | React 18, TypeScript, Vite, React Router, Supabase JS, ESLint, Vitest | Static SPA build via `npm run build`. No hosting target is codified in-repo; deployment appears manual/inferred, with runtime env vars pointing at Supabase and `backoffice-proxy`. |
| Backend core | Primary system of record for auth, tenancy, data storage, object storage, SQL functions, and access control | Supabase Auth, Postgres, Row Level Security, SQL RPCs, Storage buckets | Managed Supabase project. Schema is defined in `supabase_schema.sql` plus migrations in `supabase/migrations/`. |
| AI/content proxy microservices | Keep third-party API keys off the client and normalize AI/image/weather calls | Supabase Edge Functions (Deno/TypeScript): `gemini-proxy`, `remove-background`, `weather-proxy` | Deployed as individual Supabase Edge Functions. |
| Billing microservices | Create Razorpay orders server-side, verify payments, and apply tier changes atomically | Supabase Edge Functions, Razorpay REST API, Postgres RPC `process_verified_payment` | Deployed as Supabase Edge Functions. |
| Notification microservices | Send reminder and household-join push notifications | Supabase Edge Functions, Firebase FCM HTTP v1, Google OAuth2 token exchange | Deployed as Supabase Edge Functions; triggered by app events or scheduled jobs. |
| Admin proxy microservice | Prevents the web backoffice from ever receiving the service-role key; enforces admin allowlist | Supabase Edge Function `backoffice-proxy`, Supabase Auth, service-role DB access | Deployed as a Supabase Edge Function. |
| Scheduled maintenance microservices | Time-based jobs for expiring tiers and reminder dispatch | Edge Functions `check-tier-expiry`, `send-event-reminders` | Triggered externally by cron-job.org, with comments indicating optional `pg_cron` support for reminders. |

Edge-function inventory:
- `gemini-proxy`: AI tagging, outfit generation, wardrobe-gap analysis
- `remove-background`: image background removal via rembg/remove.bg
- `weather-proxy`: OpenWeatherMap 5-day forecast proxy
- `create-razorpay-order`: server-side order pricing and creation
- `verify-razorpay-payment`: HMAC verification, order binding, atomic tier update
- `delete-account`: coordinated storage/data/auth cleanup
- `notify-member-joined`: FCM broadcast to household members
- `send-event-reminders`: scheduled FCM reminders
- `check-tier-expiry`: scheduled downgrade of expired paid households
- `backoffice-proxy`: admin-only DB access facade
- `leave-household`: deprecated compatibility endpoint returning `410 Gone`

## 4. DATA STORES

| Store | Type | Purpose | Key schemas / collections |
|---|---|---|---|
| Supabase Postgres | Relational database | System of record for auth-linked business data and tenancy-aware queries | `households`, `profiles`, `household_memberships`, `user_preferences`, `wardrobe_items`, `outfits`, `calendar_events`, `household_usage`, `app_config`, `payment_transactions`, `device_tokens`, plus view `payment_transactions_view` |
| Supabase Auth (`auth.users`) | Managed auth store | Stores end-user and admin identities, sessions, provider linkage | Managed by Supabase; referenced by foreign keys from `profiles`, `household_memberships`, `user_preferences`, `payment_transactions`, `device_tokens` |
| Supabase Storage | Private object storage | Stores original wardrobe images, processed transparent images, and avatars | Buckets: `wardrobe-images`, `processed-images`, `avatars`; all are private and served through signed URLs |
| Hive `app_settings` | On-device key-value store | Lightweight local app settings | Onboarding completion flag (`hasSeenOnboarding`) |
| Hive `weather_cache` | On-device cache | Memoizes weather responses by coarse lat/lon/date | Entries keyed by `lat,lon,date`, storing fetched timestamp plus weather payload |
| SharedPreferences | On-device key-value store | One-shot review flag and household-leave guard | `review_requested`, `left_household_ids` |
| Cached network image cache | On-device transient cache | Caches signed image fetches for UI performance | Managed by `cached_network_image`; no explicit schema in repo |
| Message queue | None observed | No Redis/Kafka/RabbitMQ/SQS equivalent is present | N/A |

Key relational schema notes:
- Tenancy is household-based, driven by `current_household_id()` and `user_preferences.active_household_id`.
- `household_memberships` is the authoritative membership/role table.
- `payment_transactions` is append-only and protected from client writes; billing updates flow through service-role RPCs.
- `calendar_events.outfit_assignments` and `weather_snapshot` are JSONB payloads.
- `profiles.style_persona`, `profiles.fit_preferences`, `wardrobe_items.colors`, `wardrobe_items.style_tags`, `wardrobe_items.season_tags`, and `outfits.item_ids` are stored as JSONB.

## 5. EXTERNAL INTEGRATIONS

| Service | Purpose | Integration method |
|---|---|---|
| Supabase | Auth, Postgres, Storage, Edge Functions | Flutter app uses `supabase_flutter`; backoffice uses `@supabase/supabase-js`; Edge Functions use service-role and JWT verification. |
| Google Gemini 2.5 Flash | Image tagging, outfit generation, wardrobe-gap analysis | Mobile app calls `gemini-proxy`; the Edge Function sends HTTPS requests to `generativelanguage.googleapis.com` with `GEMINI_API_KEY`. Names are pseudonymized before sending profile data. |
| remove.bg | Background removal fallback | `remove-background` Edge Function sends multipart HTTPS requests with `REMOVE_BG_API_KEY`. |
| rembg API | Preferred background removal provider | `remove-background` Edge Function tries `api.rembg.com` first using `REMBG_API_KEY`. |
| OpenWeatherMap | Weather forecast enrichment for style sessions | `weather-proxy` Edge Function queries the 5-day forecast API with `OPENWEATHER_API_KEY`; the app caches responses locally. |
| Razorpay | Subscription checkout and payment verification | Mobile app uses `razorpay_flutter` for client checkout; Edge Functions create orders and verify signatures/order binding via Razorpay REST API. |
| Firebase Cloud Messaging | Push notifications for reminders and household events | Device tokens are stored in `device_tokens`; Edge Functions mint Google OAuth tokens from a Firebase service account and call FCM HTTP v1. |
| Firebase Crashlytics | Crash reporting | Mobile app initializes Crashlytics in `main.dart` and forwards Flutter + async errors. |
| Google OAuth via Supabase | Social sign-in | Flutter app uses `signInWithOAuth(OAuthProvider.google)` with Supabase PKCE deep-link callback `io.supabase.aidesignerassist://login-callback`. |
| cron-job.org | Scheduled HTTP triggers | Used to invoke `send-event-reminders` and `check-tier-expiry` with the service-role bearer token. |
| Google Play in-app review / Play Store | Native review dialog and force-update destination | Mobile app uses `in_app_review`; force-update UI reads `store_url` from `app_config`. |
| Amazon / Google Shopping / Zara / H&M / Target | Shopping suggestion destinations | The app builds plain search URLs client-side; these are links, not authenticated APIs. |

## 6. DEPLOYMENT & INFRASTRUCTURE

- Primary managed backend platform: Supabase. This repo does not define EC2, Kubernetes, Terraform, Cloud Run, or Lambda resources; those patterns are not present.
- Mobile deployment: Android-only. `android/app/build.gradle.kts` configures the application package `com.aidesigner.ai_designer_assist`, Firebase plugins, and release signing. GitHub Actions `cd.yml` builds a release APK on tag pushes and creates a draft GitHub Release.
- Backend deployment: Supabase SQL is applied from `supabase_schema.sql` plus targeted migrations. Edge Functions are deployed separately to the Supabase project.
- Backoffice deployment: inferred static hosting model. The app builds with Vite and relies on `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_BACKOFFICE_PROXY_URL`. The actual static host/CDN is not specified in the repo.
- CI/CD pipeline:
  - Flutter job: `flutter pub get`, generate Firebase stub for CI, `flutter analyze --fatal-infos`, `flutter test --coverage`
  - Backoffice job: `npm ci`, `npm run typecheck`, `npm run lint`, `npm test`
  - Edge Functions job: `deno check supabase/functions/**/*.ts`
  - CD job: release APK build + artifact upload + draft GitHub release
- Monitoring/observability:
  - Firebase Crashlytics for mobile crashes
  - Supabase function logs / console logging for Edge Functions
  - No centralized metrics, tracing, or alerting stack is defined in code
- Scheduling:
  - `check-tier-expiry` is designed for daily cron-job.org POSTs
  - `send-event-reminders` supports cron-job.org and also includes `pg_cron` guidance in comments
- Required backend secrets/environment:
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `GEMINI_API_KEY`
  - `OPENWEATHER_API_KEY`
  - `REMOVE_BG_API_KEY` and/or `REMBG_API_KEY`
  - `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`
  - `FIREBASE_SERVICE_ACCOUNT`
  - `BACKOFFICE_ADMIN_EMAILS`
  - `BACKOFFICE_ORIGIN`

## 7. SECURITY CONSIDERATIONS

- Authentication:
  - End-user mobile auth supports email/password, magic links, and Google OAuth through Supabase Auth.
  - The mobile app is configured for PKCE deep-link callbacks using `io.supabase.aidesignerassist://login-callback`.
  - Backoffice auth uses Supabase email/password sessions.
- Authorization:
  - Postgres Row Level Security is the main authorization layer.
  - Household scoping is enforced by `current_household_id()` plus `user_preferences.active_household_id`.
  - Membership/admin role checks use `household_memberships`.
  - Backoffice writes are not direct browser-to-table calls; all operations go through `backoffice-proxy`, which validates the user JWT and checks `BACKOFFICE_ADMIN_EMAILS`.
- Secret handling:
  - Privileged secrets stay server-side in Supabase Edge Functions.
  - The mobile app contains a public Supabase anon key, which is expected in the Supabase model; data safety depends on RLS rather than key secrecy.
  - Third-party AI, weather, image, FCM, and billing keys are not exposed to the mobile/web clients.
- Data isolation:
  - Storage buckets are private.
  - Signed URLs are used for wardrobe and avatar access.
  - Storage policies embed `profileId` in object paths and cross-check household membership.
- Payment security:
  - Orders are created server-side with canonical pricing.
  - Verification uses Razorpay HMAC, canonical order lookup, household/user/tier binding checks, and idempotent transaction inserts.
- Notification security:
  - FCM device tokens are keyed per user/platform.
  - FCM access tokens are minted from a server-held Firebase service account.
- Data minimization:
  - Profile names are pseudonymized before Gemini outfit generation requests.
- Encryption:
  - TLS in transit is implied by HTTPS calls to Supabase and external APIs.
  - At-rest encryption is not configured in this repo directly; it is inferred from the use of managed platforms such as Supabase and Firebase.
  - Local caches are not encrypted, but the code intentionally uses them only for lightweight settings, weather cache entries, and non-secret flags.
- Security tooling:
  - Static quality gates include Flutter analyze/lints, TypeScript/ESLint, and Deno type checks.
  - No dedicated SAST/DAST, WAF, SIEM, or secret-scanning pipeline is defined in the repository.

## 8. DEVELOPMENT & TESTING

Local setup:
1. Mobile app
   - `flutter pub get`
   - Ensure Android Firebase config exists (`android/app/google-services.json`) and `lib/firebase_options.dart` is valid for Android
   - Run with `flutter run`
2. Backoffice
   - `cd web_backoffice`
   - `npm ci`
   - `cp .env.example .env`
   - `npm run dev`
3. Backend
   - Apply `supabase_schema.sql`
   - Apply incremental fixes from `supabase/migrations/` as needed
   - Deploy Edge Functions to Supabase
   - Configure required Supabase secrets

Testing/frameworks:
- Flutter unit/widget tests: `flutter_test`
- Flutter integration tests: `integration_test`
- Backoffice unit tests: `Vitest`
- Edge Function validation: `deno check`

Code quality tools:
- Flutter analyzer via `flutter analyze`
- `flutter_lints` from `analysis_options.yaml`
- ESLint 9 for the backoffice
- TypeScript compiler type-checks (`tsc --noEmit`)
- GitHub Actions CI enforcing all of the above

Current automated coverage areas:
- Flutter models, providers, routing, utility logic, widget screens, and a small integration suite
- Backoffice proxy/client config tests
- Edge Functions type-check only; no dedicated runtime/integration test suite for functions is present

Notable development reality from the current code:
- The README and CD workflow still mention Dart defines for some values, but the mobile app now hardcodes the Supabase URL/anon key and proxies third-party APIs through Edge Functions. That documentation/build configuration drift should be reconciled.

## 9. FUTURE CONSIDERATIONS

- Backoffice deployment is not automated in this repo. A production-grade static-host deploy pipeline, environment promotion, and origin management would reduce operational ambiguity.
- Observability is light. Crashlytics and function logs exist, but there is no metrics dashboard, alerting, tracing, or business telemetry layer.
- `DashboardPage.tsx` is explicitly a placeholder, so an operational metrics/alerts slice is planned but not yet implemented.
- Scheduled jobs currently depend on external cron-job.org unless `pg_cron` is enabled for reminders. Moving all schedules into platform-native scheduling would simplify ops.
- Configuration drift exists between source and docs/CI: the app runtime has moved toward server-side proxies and hardcoded public Supabase bootstrapping, while some setup instructions still describe older `--dart-define` usage.
- The repo shows continuing schema/security hardening through many migrations (`tenant_isolation_fix`, `storage_rls_fix`, `security_fixes_*`), which suggests backend rules are still evolving and should be treated as an actively maintained surface.
- `leave-household` remains deployed as a deprecated `410 Gone` compatibility endpoint. It should eventually be removed once no callers depend on it.
- The mobile app is effectively Android-first today. Firebase options and manifests are Android-only, and there is no equivalent iOS/web/mobile-client deployment path defined here.

## 10. GLOSSARY

| Term | Meaning in this project |
|---|---|
| VibeVault | Product/brand name of the app; package name remains `ai_designer_assist`. |
| Household | Top-level tenant grouping a family or shared style unit. |
| Profile | A household member, which may or may not map to a real auth user. |
| Household membership | Link between an authenticated user and a household, including admin role. |
| Active household | The currently selected household stored in `user_preferences.active_household_id`; it drives RLS scoping. |
| Wardrobe item | A clothing/accessory record with AI-derived metadata and storage-backed images. |
| Outfit | A saved combination of wardrobe items for a profile, optionally AI-generated. |
| Generated outfit | An outfit candidate returned by Gemini, including styling note, variant number, and harmony score. |
| Style persona | User-selected fashion identity tags stored on profiles and sent to AI prompts. |
| Fit preferences | Profile-specific clothing constraints/preferences, stored as JSON. |
| Gap filler | The shopping recommendation feature that identifies missing wardrobe pieces. |
| Virtual lineup | Family-wide visual preview of selected outfits side by side. |
| Dynamic pricing | Household billing model where limits/prices scale with household composition instead of using flat paid tiers. |
| Force update | Startup gate that blocks app usage when the installed version is lower than `app_config.min_version`. |
| RLS | Row Level Security; the main authorization mechanism in Postgres/Supabase. |
| Edge Function | Deno-based serverless function hosted by Supabase for privileged or secret-bearing workflows. |

## 11. PROJECT IDENTIFICATION

- Project name: VibeVault
- Package/application ID: `ai_designer_assist` / `com.aidesigner.ai_designer_assist`
- Repository URL: `https://github.com/Nani-Boddeti/AI_Designer` (inferred from local `origin`)
- Primary contact/team: not documented in-repo; inferred owner is GitHub user `Nani-Boddeti`
- Document last updated: 2026-03-20
- Latest repository commit visible in this local clone: 2026-03-19 (`ff35980e7921c83872adccd9e6cb2f0926b11428`)
