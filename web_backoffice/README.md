# VibeVault Backoffice (Web Only)

Admin workspace for the VibeVault app. Isolated from mobile/backend runtime so it can be enabled/disabled independently.

## Scope
- Entity browser: households, profiles, wardrobe items, outfits, calendar events, app config
- Tier management (upgrade/downgrade households)
- Read-only views: usage quotas, device tokens

## Auth
- Login via Supabase email/password
- Only emails listed in `VITE_ADMIN_EMAILS` are granted access

## Setup
```bash
npm install
cp .env.example .env   # fill in values
npm run dev
```

## Directory Shape
- `src/app` — shell, router
- `src/features/auth` — login, session
- `src/features/entities` — entity browser (config, API, page)
- `src/features/dashboard` — placeholder dashboard
- `src/lib` — Supabase client
- `src/styles` — design tokens/theme
