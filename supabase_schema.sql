-- ============================================================
-- AI Designer Assist — Supabase Schema  (source of truth)
-- Apply in Supabase Dashboard → SQL Editor.
-- Tables use CREATE TABLE IF NOT EXISTS (safe to re-run).
-- Policies use plain CREATE POLICY — NOT idempotent.
-- To re-apply policies on an existing DB, run the migration
-- files in supabase/migrations/ which DROP IF EXISTS first.
-- ============================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS households (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT        NOT NULL,
  hemisphere      TEXT        CHECK (hemisphere IN ('north','south')) DEFAULT 'north',
  invite_code     TEXT        UNIQUE DEFAULT substr(md5(random()::text), 1, 8),
  tier            TEXT        CHECK (tier IN ('free','pro','prime')) DEFAULT 'free',
  tier_expires_at TIMESTAMPTZ,
  dynamic_pricing BOOLEAN     DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS profiles (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id        UUID        REFERENCES households(id) ON DELETE CASCADE,
  auth_user_id        UUID        REFERENCES auth.users(id),  -- null for child profiles
  name                TEXT        NOT NULL,
  avatar_url          TEXT,
  age_group           TEXT        CHECK (age_group IN ('toddler','child','teen','adult')),
  gender              TEXT        CHECK (gender IN ('male','female','other')) DEFAULT 'other',
  skin_tone           TEXT        CHECK (skin_tone IN ('fair','light','medium','olive','brown','dark')),
  style_persona       JSONB       DEFAULT '[]',
  fit_preferences     JSONB       DEFAULT '{}',
  is_admin            BOOLEAN     DEFAULT false,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- One auth profile per household — prevents duplicate rows on join retries.
-- Regular UNIQUE constraint (not partial): NULLs are never equal in SQL so
-- multiple child profiles (auth_user_id IS NULL) in the same household are
-- still allowed. ON CONFLICT ON CONSTRAINT requires ALTER TABLE ADD CONSTRAINT,
-- not CREATE UNIQUE INDEX.
DO $$ BEGIN
  -- Pre-check: fail fast with a clear message if duplicates exist rather than
  -- letting ALTER TABLE abort with a cryptic constraint-violation error.
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE auth_user_id IS NOT NULL
    GROUP BY auth_user_id, household_id
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Cannot add unique constraint: duplicate (auth_user_id, household_id) rows exist in profiles. '
      'Investigate and deduplicate manually, then re-run.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_auth_user_household_uniq') THEN
    ALTER TABLE profiles ADD CONSTRAINT profiles_auth_user_household_uniq
      UNIQUE (auth_user_id, household_id);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Multi-household support
-- ---------------------------------------------------------------------------

-- Tracks which households a user belongs to, and their admin role per household.
CREATE TABLE IF NOT EXISTS household_memberships (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES auth.users(id)   ON DELETE CASCADE,
  household_id UUID        NOT NULL REFERENCES households(id)   ON DELETE CASCADE,
  is_admin     BOOLEAN     NOT NULL DEFAULT false,
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, household_id)
);

-- Stores each user's currently active household selection.
-- Drives current_household_id() so RLS always reflects the chosen household.
CREATE TABLE IF NOT EXISTS user_preferences (
  user_id             UUID PRIMARY KEY REFERENCES auth.users(id)  ON DELETE CASCADE,
  active_household_id UUID             REFERENCES households(id)  ON DELETE SET NULL
);

-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS wardrobe_items (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id          UUID        REFERENCES profiles(id) ON DELETE CASCADE,
  name                TEXT,
  category            TEXT,
  subcategory         TEXT,
  colors              JSONB,
  color_names         JSONB,
  style_tags          JSONB,
  season_tags         JSONB,
  image_url           TEXT,
  processed_image_url TEXT,
  brand               TEXT,
  size                TEXT,
  ai_description      TEXT,
  created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS outfits (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id      UUID        REFERENCES profiles(id) ON DELETE CASCADE,
  name            TEXT,
  occasion        TEXT,
  item_ids        JSONB,
  notes           TEXT,
  is_ai_generated BOOLEAN     DEFAULT true,
  harmony_score   FLOAT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS calendar_events (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id        UUID        REFERENCES households(id) ON DELETE CASCADE,
  title               TEXT        NOT NULL,
  event_date          DATE        NOT NULL,
  occasion            TEXT,
  outfit_assignments  JSONB       DEFAULT '{}',
  weather_snapshot    JSONB,
  notes               TEXT,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- Monthly outfit-generation counter per household.
CREATE TABLE IF NOT EXISTS household_usage (
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  year_month   TEXT NOT NULL,   -- 'YYYY-MM'
  outfit_count INT  NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, year_month)
);

-- Minimum required app version gate. Bump min_version to force-update clients.
CREATE TABLE IF NOT EXISTS app_config (
  id             TEXT PRIMARY KEY,
  min_version    TEXT NOT NULL DEFAULT '1.0.0',
  latest_version TEXT NOT NULL DEFAULT '1.0.0',
  store_url      TEXT DEFAULT 'https://play.google.com/store/apps/details?id=com.vibevault'
);

INSERT INTO app_config (id, min_version, latest_version)
  VALUES ('android', '1.0.0', '1.0.0')
  ON CONFLICT (id) DO NOTHING;

-- Payment transaction log — inserted by verify-razorpay-payment Edge Function.
CREATE TABLE IF NOT EXISTS payment_transactions (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id         UUID        NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id              UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  razorpay_order_id    TEXT        NOT NULL,
  razorpay_payment_id  TEXT        NOT NULL,
  tier                 TEXT        NOT NULL CHECK (tier IN ('pro', 'prime')),
  amount_paise         INTEGER,
  expires_at           TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_household ON payment_transactions(household_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created   ON payment_transactions(created_at DESC);
-- Unique constraints prevent replaying the same payment to reset tier expiry.
-- Guarded by pg_constraint check so the schema is safely re-runnable.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payment_transactions_order_id_uniq'
  ) THEN
    ALTER TABLE payment_transactions
      ADD CONSTRAINT payment_transactions_order_id_uniq UNIQUE (razorpay_order_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payment_transactions_payment_id_uniq'
  ) THEN
    ALTER TABLE payment_transactions
      ADD CONSTRAINT payment_transactions_payment_id_uniq UNIQUE (razorpay_payment_id);
  END IF;
END $$;

-- FCM device tokens — one token per user per platform.
CREATE TABLE IF NOT EXISTS device_tokens (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token      TEXT        NOT NULL,
  platform   TEXT        NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT device_tokens_user_platform_key UNIQUE (user_id, platform)
);

-- ---------------------------------------------------------------------------
-- Storage buckets
-- ---------------------------------------------------------------------------

-- Buckets are PRIVATE — images served via signed URLs only.
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('wardrobe-images',  'wardrobe-images',  false),
  ('processed-images', 'processed-images', false),
  ('avatars',          'avatars',          false)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- Storage paths embed the profileId at position 2 for all buckets:
--   wardrobe-images  → wardrobe/{profileId}/{itemId}/original.jpg
--   processed-images → wardrobe/{profileId}/{itemId}/processed.png
--   avatars          → avatars/{profileId}/avatar.jpg
--
-- Policies scope access to profiles belonging to the caller's current household.
-- This prevents cross-tenant reads: an authenticated user from Household A cannot
-- generate signed URLs for objects owned by Household B's profiles.
--
-- Any household member may read/write all non-private profiles in their household,
-- matching the wardrobe_items and profiles RLS policies.

-- ── wardrobe-images ───────────────────────────────────────────────────────────
CREATE POLICY "wardrobe_images_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'wardrobe-images'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "wardrobe_images_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'wardrobe-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "wardrobe_images_update" ON storage.objects FOR UPDATE USING (
  bucket_id = 'wardrobe-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "wardrobe_images_delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'wardrobe-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);

-- ── processed-images ──────────────────────────────────────────────────────────
CREATE POLICY "processed_images_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'processed-images'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "processed_images_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'processed-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "processed_images_update" ON storage.objects FOR UPDATE USING (
  bucket_id = 'processed-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "processed_images_delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'processed-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);

-- ── avatars ───────────────────────────────────────────────────────────────────
CREATE POLICY "avatars_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'avatars'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "avatars_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'avatars'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "avatars_update" ON storage.objects FOR UPDATE USING (
  bucket_id = 'avatars'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "avatars_delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'avatars'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);

-- ---------------------------------------------------------------------------
-- Enable Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE households          ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences    ENABLE ROW LEVEL SECURITY;
ALTER TABLE wardrobe_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE outfits             ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_usage     ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config              ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens           ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions    ENABLE ROW LEVEL SECURITY;
-- No user-facing RLS policies on payment_transactions — service role only.

-- ---------------------------------------------------------------------------
-- Helper function: current_household_id()
-- Returns the user's active household — drives all RLS policies below.
-- Prefers user_preferences.active_household_id (set when switching households),
-- falls back to the household_id on the user's first profile (legacy / single-household).
-- SECURITY DEFINER bypasses RLS when reading these tables (avoids recursion).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_household_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    -- Only return active_household_id if the caller is actually a member.
    -- Prevents tenant-isolation bypass via arbitrary UUID writes to user_preferences.
    (
      SELECT up.active_household_id
      FROM user_preferences up
      JOIN household_memberships hm
        ON hm.household_id = up.active_household_id
       AND hm.user_id      = auth.uid()
      WHERE up.user_id = auth.uid()
    ),
    -- Fallback: first profile row, also validated against membership.
    -- Without the JOIN, ex-members whose profile row remains (intentional —
    -- wardrobe data stays for other members) would still get access after leaving.
    (
      SELECT p.household_id
      FROM profiles p
      JOIN household_memberships hm
        ON hm.household_id = p.household_id
       AND hm.user_id      = auth.uid()
      WHERE p.auth_user_id = auth.uid()
      LIMIT 1
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS Policies
-- ---------------------------------------------------------------------------

-- ── Households ──────────────────────────────────────────────────────────────

-- Members can read any household they belong to (all households, not just active).
-- Covers: household picker, PostgREST nested join from household_memberships,
-- and multi-household backfill (IDs already scoped to caller's memberships).
-- household_select_for_join (old broad policy) is replaced by this.
CREATE POLICY "household_select_own" ON households
  FOR SELECT USING (
    id IN (
      SELECT household_id FROM household_memberships WHERE user_id = auth.uid()
    )
  );

-- Any authenticated user can create a household.
CREATE POLICY "household_insert" ON households
  FOR INSERT WITH CHECK (true);

-- Admins can update name, hemisphere, dynamic_pricing.
-- Billing fields (tier, tier_expires_at, invite_code) are immutable via RLS —
-- only Edge Functions (service role) may change them.
CREATE POLICY "household_update" ON households
  FOR UPDATE
  USING (
    id = current_household_id()
    AND EXISTS (
      SELECT 1 FROM household_memberships
      WHERE user_id    = auth.uid()
        AND household_id = id
        AND is_admin   = true
    )
  )
  WITH CHECK (
    tier            IS NOT DISTINCT FROM (SELECT h.tier            FROM households h WHERE h.id = id) AND
    tier_expires_at IS NOT DISTINCT FROM (SELECT h.tier_expires_at FROM households h WHERE h.id = id) AND
    invite_code     IS NOT DISTINCT FROM (SELECT h.invite_code     FROM households h WHERE h.id = id)
  );

-- ── Profiles ────────────────────────────────────────────────────────────────

-- Members can see all profiles within their current household.
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (household_id = current_household_id());

-- Users can always see their own profiles across all households.
-- Required for getProfileForHousehold() during household switching.
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth_user_id = auth.uid());

-- Own profile into a brand-new household (createHousehold — no members yet),
-- or a child profile (no auth_user_id) added by a current household member.
-- joinHousehold profile insert is handled inside join_household_with_invite()
-- SECURITY DEFINER so it bypasses this policy.
CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (
    -- Own profile into a memberless household (createHousehold flow).
    (
      auth_user_id = auth.uid()
      AND NOT EXISTS (
        SELECT 1 FROM household_memberships hm
        WHERE hm.household_id = household_id
      )
    )
    -- Child profile (no auth_user_id) added by a member of the current household.
    OR (auth_user_id IS NULL AND household_id = current_household_id())
  );

-- Users can edit their own profile; admins can edit any profile in the household.
-- is_admin cannot be changed through this policy — only Edge Functions (service role) can.
CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE USING (
    household_id = current_household_id()
    AND (
      auth_user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM household_memberships
        WHERE user_id = auth.uid()
          AND household_id = current_household_id()
          AND is_admin = true
      )
    )
  )
  WITH CHECK (
    is_admin = (SELECT is_admin FROM profiles p WHERE p.id = id)
    OR EXISTS (
      SELECT 1 FROM household_memberships
      WHERE user_id = auth.uid()
        AND household_id = current_household_id()
        AND is_admin = true
    )
  );

-- Only admins can delete profiles in the household.
CREATE POLICY "profiles_delete" ON profiles
  FOR DELETE USING (
    household_id = current_household_id()
    AND EXISTS (
      SELECT 1 FROM household_memberships
      WHERE user_id = auth.uid()
        AND household_id = current_household_id()
        AND is_admin = true
    )
  );

-- ── Household memberships ────────────────────────────────────────────────────

-- Members can see their own membership rows (for allHouseholds fetch).
CREATE POLICY "memberships_select_own" ON household_memberships
  FOR SELECT USING (user_id = auth.uid());

-- Admins can see all membership rows in their household (for member management).
CREATE POLICY "memberships_select_admin" ON household_memberships
  FOR SELECT USING (
    household_id IN (
      SELECT household_id FROM household_memberships
      WHERE user_id = auth.uid() AND is_admin = true
    )
  );

-- Direct insert allowed only for the first membership row (createHousehold flow).
-- All subsequent joins must use join_household_with_invite() RPC which validates
-- the invite code before inserting — prevents UUID-only bypass of invite flow.
CREATE POLICY "memberships_insert" ON household_memberships
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM household_memberships existing
      WHERE existing.household_id = household_memberships.household_id
    )
  );

-- Direct membership delete is NOT allowed via RLS.
-- All household exits go through leave_household() SECURITY DEFINER RPC,
-- which handles admin promotion, sole-member cleanup, and preference clearing.

-- ── User preferences ─────────────────────────────────────────────────────────

-- Users can read/write only their own preferences row.
CREATE POLICY "user_prefs_own" ON user_preferences
  FOR ALL USING (user_id = auth.uid());

-- ── Wardrobe items ───────────────────────────────────────────────────────────

CREATE POLICY "wardrobe_select" ON wardrobe_items
  FOR SELECT USING (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

CREATE POLICY "wardrobe_insert" ON wardrobe_items
  FOR INSERT WITH CHECK (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

CREATE POLICY "wardrobe_update" ON wardrobe_items
  FOR UPDATE USING (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

CREATE POLICY "wardrobe_delete" ON wardrobe_items
  FOR DELETE USING (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

-- ── Outfits ──────────────────────────────────────────────────────────────────

CREATE POLICY "outfits_select" ON outfits
  FOR SELECT USING (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

CREATE POLICY "outfits_insert" ON outfits
  FOR INSERT WITH CHECK (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

CREATE POLICY "outfits_update" ON outfits
  FOR UPDATE USING (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

CREATE POLICY "outfits_delete" ON outfits
  FOR DELETE USING (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
  );

-- ── Calendar events ──────────────────────────────────────────────────────────

CREATE POLICY "calendar_select" ON calendar_events
  FOR SELECT USING (household_id = current_household_id());

CREATE POLICY "calendar_insert" ON calendar_events
  FOR INSERT WITH CHECK (household_id = current_household_id());

CREATE POLICY "calendar_update" ON calendar_events
  FOR UPDATE USING (household_id = current_household_id());

CREATE POLICY "calendar_delete" ON calendar_events
  FOR DELETE USING (household_id = current_household_id());

-- ── Household usage ──────────────────────────────────────────────────────────

CREATE POLICY "usage_select" ON household_usage
  FOR SELECT USING (household_id = current_household_id());

CREATE POLICY "usage_insert" ON household_usage
  FOR INSERT WITH CHECK (household_id = current_household_id());

CREATE POLICY "usage_update" ON household_usage
  FOR UPDATE USING (household_id = current_household_id());

-- ── App config ───────────────────────────────────────────────────────────────

-- Public read — checked before auth, so anon key must be able to read it.
CREATE POLICY "app_config_public_read" ON app_config
  FOR SELECT USING (true);

-- ── Device tokens ────────────────────────────────────────────────────────────

CREATE POLICY "device_tokens_user_all" ON device_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Data repair migration (run once to backfill missing membership rows)
-- Safe to re-run: ON CONFLICT DO NOTHING.
-- ---------------------------------------------------------------------------

INSERT INTO household_memberships (user_id, household_id, is_admin)
SELECT DISTINCT p.auth_user_id, p.household_id, p.is_admin
FROM profiles p
WHERE p.auth_user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM household_memberships hm
    WHERE hm.user_id = p.auth_user_id
      AND hm.household_id = p.household_id
  )
ON CONFLICT (user_id, household_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Column migrations (safe to re-run on existing databases)
-- ---------------------------------------------------------------------------

ALTER TABLE wardrobe_items ADD COLUMN IF NOT EXISTS subcategory TEXT;
ALTER TABLE outfits        ADD COLUMN IF NOT EXISTS harmony_score FLOAT;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- Atomically increments the monthly outfit-generation counter.
-- Uses INSERT … ON CONFLICT DO UPDATE to avoid read-modify-write race conditions.
-- Returns the new count so the caller can update local state accurately.
CREATE OR REPLACE FUNCTION increment_household_usage(
  p_household_id UUID,
  p_year_month   TEXT
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  new_count INT;
BEGIN
  INSERT INTO household_usage (household_id, year_month, outfit_count)
  VALUES (p_household_id, p_year_month, 1)
  ON CONFLICT (household_id, year_month)
  DO UPDATE SET outfit_count = household_usage.outfit_count + 1
  RETURNING outfit_count INTO new_count;

  RETURN new_count;
END;
$$;

-- Safely updates the household tier after Razorpay payment verification.
-- SECURITY DEFINER: validates tier value before writing.
CREATE OR REPLACE FUNCTION update_household_tier(
  p_tier       TEXT,
  p_expires_at TIMESTAMPTZ
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  IF p_tier NOT IN ('pro', 'prime', 'free') THEN
    RAISE EXCEPTION 'Invalid tier: %', p_tier;
  END IF;

  UPDATE households
  SET tier            = p_tier,
      tier_expires_at = p_expires_at
  WHERE id = current_household_id();
END;
$$;

-- ---------------------------------------------------------------------------
-- leave_household RPC
-- Handles all leave-household edge cases atomically:
--   sole member       → deletes the household (CASCADE removes memberships)
--   last admin        → promotes longest-tenured other member first
--   regular member    → removes own membership row
-- Always clears user_preferences.active_household_id if it pointed here.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION leave_household(p_household_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_caller_id          UUID := auth.uid();
  v_caller_is_admin    BOOLEAN;
  v_other_count        INT;
  v_other_admin_count  INT;
  v_promote_id         UUID;
  v_promote_user_id    UUID;
BEGIN
  -- Verify caller is a member and capture is_admin flag.
  SELECT is_admin INTO v_caller_is_admin
  FROM household_memberships
  WHERE user_id = v_caller_id AND household_id = p_household_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not a member of this household';
  END IF;

  -- Count other members.
  SELECT COUNT(*) INTO v_other_count
  FROM household_memberships
  WHERE household_id = p_household_id AND user_id != v_caller_id;

  IF v_other_count = 0 THEN
    -- Sole member — delete household (CASCADE removes memberships).
    DELETE FROM households WHERE id = p_household_id;
  ELSE
    IF v_caller_is_admin THEN
      SELECT COUNT(*) INTO v_other_admin_count
      FROM household_memberships
      WHERE household_id = p_household_id
        AND user_id != v_caller_id
        AND is_admin = true;

      IF v_other_admin_count = 0 THEN
        -- Promote longest-tenured other member.
        SELECT id, user_id INTO v_promote_id, v_promote_user_id
        FROM household_memberships
        WHERE household_id = p_household_id AND user_id != v_caller_id
        ORDER BY joined_at ASC
        LIMIT 1;

        UPDATE household_memberships SET is_admin = true WHERE id = v_promote_id;
        UPDATE profiles SET is_admin = true
        WHERE auth_user_id = v_promote_user_id AND household_id = p_household_id;
      END IF;
    END IF;

    -- Remove caller's membership.
    DELETE FROM household_memberships
    WHERE user_id = v_caller_id AND household_id = p_household_id;
  END IF;

  -- Clear active_household_id in user_preferences if it pointed here.
  UPDATE user_preferences
  SET active_household_id = NULL
  WHERE user_id = v_caller_id AND active_household_id = p_household_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- lookup_household_by_invite_code RPC
-- ---------------------------------------------------------------------------
-- Called before the user is a member (join flow). Returns the household row
-- for the given invite code. Invite code acts as the access token — no
-- enumeration possible (one known code → at most one row returned).
-- SECURITY DEFINER bypasses the membership-scoped SELECT policy.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION lookup_household_by_invite_code(p_code TEXT)
RETURNS TABLE (
  id               UUID,
  name             TEXT,
  invite_code      TEXT,
  hemisphere       TEXT,
  tier             TEXT,
  tier_expires_at  TIMESTAMPTZ,
  created_at       TIMESTAMPTZ,
  dynamic_pricing  BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT
      h.id,
      h.name,
      h.invite_code,
      h.hemisphere,
      h.tier,
      h.tier_expires_at,
      h.created_at,
      h.dynamic_pricing
    FROM households h
    WHERE h.invite_code = p_code;
END;
$$;

REVOKE ALL ON FUNCTION lookup_household_by_invite_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lookup_household_by_invite_code(TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- get_households_by_ids_for_backfill RPC
-- ---------------------------------------------------------------------------
-- Used by the legacy-membership backfill path in the Flutter app.
-- Returns household rows for the given IDs, scoped to households where the
-- caller has a profile row (auth_user_id = auth.uid()) — the same trust anchor
-- as profiles_select_own. Replaces the old direct .from('households') query
-- which broke when household_select_for_join was replaced by household_select_own.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_households_by_ids_for_backfill(p_ids UUID[])
RETURNS TABLE (
  id               UUID,
  name             TEXT,
  invite_code      TEXT,
  hemisphere       TEXT,
  tier             TEXT,
  tier_expires_at  TIMESTAMPTZ,
  created_at       TIMESTAMPTZ,
  dynamic_pricing  BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT
      h.id,
      h.name,
      h.invite_code,
      h.hemisphere,
      h.tier,
      h.tier_expires_at,
      h.created_at,
      h.dynamic_pricing
    FROM households h
    WHERE h.id = ANY(p_ids)
      AND h.id IN (
        SELECT household_id FROM profiles WHERE auth_user_id = auth.uid()
      );
END;
$$;

REVOKE ALL ON FUNCTION get_households_by_ids_for_backfill(UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_households_by_ids_for_backfill(UUID[]) TO authenticated;

-- ---------------------------------------------------------------------------
-- join_household_with_invite RPC
-- ---------------------------------------------------------------------------
-- Validates invite code, inserts the profile, then inserts the membership row
-- atomically. SECURITY DEFINER bypasses:
--   - profiles_insert (which blocks inserts into households that already have members)
--   - memberships_insert (first-member-only policy)
-- ON CONFLICT DO NOTHING makes it retry-safe.
-- ---------------------------------------------------------------------------

-- Drop old 2-param signature if present (parameter list changed).
DROP FUNCTION IF EXISTS join_household_with_invite(UUID, TEXT);

CREATE OR REPLACE FUNCTION join_household_with_invite(
  p_household_id UUID,
  p_invite_code  TEXT,
  p_profile_name TEXT,
  p_gender       TEXT,
  p_skin_tone    TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate invite code.
  IF NOT EXISTS (
    SELECT 1 FROM households
    WHERE id = p_household_id AND invite_code = p_invite_code
  ) THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  -- Insert profile. SECURITY DEFINER bypasses profiles_insert RLS.
  -- ON CONFLICT DO NOTHING makes retries safe — if the profile already exists
  -- (from a previous attempt) we skip silently and continue to membership insert.
  INSERT INTO profiles (
    household_id, auth_user_id, name, age_group, gender, skin_tone,
    style_persona, fit_preferences
  )
  VALUES (
    p_household_id, auth.uid(), p_profile_name, 'adult', p_gender, p_skin_tone,
    '[]', '{}'
  )
  ON CONFLICT ON CONSTRAINT profiles_auth_user_household_uniq DO NOTHING;

  -- Insert membership. ON CONFLICT DO NOTHING is retry-safe.
  INSERT INTO household_memberships (user_id, household_id, is_admin)
  VALUES (auth.uid(), p_household_id, false)
  ON CONFLICT (user_id, household_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION join_household_with_invite(UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION join_household_with_invite(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- delete_account_for_user RPC
-- ---------------------------------------------------------------------------
-- Called by the delete-account Edge Function (service role) to remove all
-- user data before the auth user itself is deleted via the Admin API.
--
-- Steps:
--   1. Delete sole-member households → CASCADE removes calendar_events,
--      household_usage, payment_transactions (household_id FK).
--   2. Delete profiles → CASCADE removes wardrobe_items, outfits.
--   3. Delete remaining membership rows (multi-member households).
--   4. Delete user_preferences row.
--
-- After this RPC returns, the Edge Function deletes the auth user.
-- The auth.users ON DELETE CASCADE then cleans up household_memberships,
-- user_preferences, device_tokens, and payment_transactions (user_id FK)
-- — all no-ops since this RPC already deleted them.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION delete_account_for_user(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Prevent a user from deleting another user's account.
  -- Service role callers have auth.uid() = NULL — allowed.
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Cannot delete another user''s account';
  END IF;

  -- 1. Delete households where this user is the sole member.
  --    CASCADE removes calendar_events, household_usage, payment_transactions.
  DELETE FROM households
  WHERE id IN (
    SELECT m.household_id
    FROM household_memberships m
    WHERE m.user_id = p_user_id
      AND NOT EXISTS (
        SELECT 1 FROM household_memberships other
        WHERE other.household_id = m.household_id
          AND other.user_id <> p_user_id
      )
  );

  -- 2. Delete profiles. CASCADE removes wardrobe_items and outfits.
  DELETE FROM profiles WHERE auth_user_id = p_user_id;

  -- 3. Delete remaining membership rows (user was not sole member above).
  DELETE FROM household_memberships WHERE user_id = p_user_id;

  -- 4. Delete user preferences.
  DELETE FROM user_preferences WHERE user_id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION delete_account_for_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_account_for_user(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- process_verified_payment RPC
-- ---------------------------------------------------------------------------
-- Called by verify-razorpay-payment Edge Function (service role) AFTER all
-- HMAC + Razorpay order-binding checks pass.
--
-- Atomically: inserts the payment_transactions row AND updates the household
-- tier in one DB transaction. Partial failure is structurally impossible.
--
-- Returns TRUE  → newly processed (first time).
-- Returns FALSE → already processed (order_id constraint conflict) — caller
--                 should treat this as idempotent success, NOT 409.
--
-- Restricted to service_role — never callable by authenticated users directly
-- (takes p_user_id as a parameter; must be derived from verified JWT, not body).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION process_verified_payment(
  p_household_id UUID,
  p_user_id      UUID,
  p_order_id     TEXT,
  p_payment_id   TEXT,
  p_tier         TEXT,
  p_amount_paise INTEGER,
  p_expires_at   TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO payment_transactions (
    household_id, user_id, razorpay_order_id, razorpay_payment_id,
    tier, amount_paise, expires_at
  )
  VALUES (
    p_household_id, p_user_id, p_order_id, p_payment_id,
    p_tier, p_amount_paise, p_expires_at
  )
  ON CONFLICT (razorpay_order_id) DO NOTHING;

  IF NOT FOUND THEN
    -- Constraint conflict — already processed. Idempotent success.
    RETURN FALSE;
  END IF;

  UPDATE households
  SET tier = p_tier, tier_expires_at = p_expires_at
  WHERE id = p_household_id;

  RETURN TRUE;
END;
$$;

-- Service-role only — never expose to authenticated users directly.
-- service_role is not a superuser in Supabase; explicit GRANT is required.
REVOKE ALL ON FUNCTION process_verified_payment(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION process_verified_payment(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, TIMESTAMPTZ) TO service_role;

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------

-- Backoffice view: payment transactions joined with household name and payer name.
CREATE OR REPLACE VIEW payment_transactions_view AS
SELECT
  pt.id,
  pt.household_id,
  h.name                AS household_name,
  pt.user_id,
  p.name                AS user_name,
  pt.razorpay_order_id,
  pt.razorpay_payment_id,
  pt.tier,
  pt.amount_paise,
  pt.expires_at,
  pt.created_at
FROM payment_transactions pt
LEFT JOIN households h ON h.id = pt.household_id
LEFT JOIN profiles p   ON p.auth_user_id = pt.user_id;
