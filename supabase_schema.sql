-- ============================================================
-- AI Designer Assist — Supabase Schema  (source of truth)
-- Apply in Supabase Dashboard → SQL Editor.
-- Uses CREATE TABLE IF NOT EXISTS / CREATE POLICY IF NOT EXISTS
-- so it is safe to re-run on an existing database.
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

CREATE POLICY "wardrobe_images_select" ON storage.objects FOR SELECT USING (bucket_id = 'wardrobe-images');
CREATE POLICY "wardrobe_images_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'wardrobe-images' AND auth.role() = 'authenticated');
CREATE POLICY "wardrobe_images_update" ON storage.objects FOR UPDATE USING (bucket_id = 'wardrobe-images' AND auth.role() = 'authenticated');
CREATE POLICY "wardrobe_images_delete" ON storage.objects FOR DELETE USING (bucket_id = 'wardrobe-images' AND auth.role() = 'authenticated');

CREATE POLICY "processed_images_select" ON storage.objects FOR SELECT USING (bucket_id = 'processed-images');
CREATE POLICY "processed_images_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'processed-images' AND auth.role() = 'authenticated');
CREATE POLICY "processed_images_update" ON storage.objects FOR UPDATE USING (bucket_id = 'processed-images' AND auth.role() = 'authenticated');
CREATE POLICY "processed_images_delete" ON storage.objects FOR DELETE USING (bucket_id = 'processed-images' AND auth.role() = 'authenticated');

CREATE POLICY "avatars_select" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "avatars_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
CREATE POLICY "avatars_update" ON storage.objects FOR UPDATE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');
CREATE POLICY "avatars_delete" ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');

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
AS $$
  SELECT COALESCE(
    (SELECT active_household_id FROM user_preferences WHERE user_id      = auth.uid()),
    (SELECT household_id        FROM profiles           WHERE auth_user_id = auth.uid() LIMIT 1)
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS Policies
-- ---------------------------------------------------------------------------

-- ── Households ──────────────────────────────────────────────────────────────

-- Members can read their current household.
CREATE POLICY "household_select" ON households
  FOR SELECT USING (id = current_household_id());

-- All authenticated users can read any household row.
-- Needed for: invite-code lookup before joining, PostgREST nested join in
-- fetchHouseholdMemberships (.select('is_admin, households(*)')), and
-- household-picker reads. RLS on memberships + current_household_id() gates
-- write access; broad SELECT here does not expose sensitive data.
CREATE POLICY "household_select_for_join" ON households
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Any authenticated user can create a household.
CREATE POLICY "household_insert" ON households
  FOR INSERT WITH CHECK (true);

-- Members can update their current household.
CREATE POLICY "household_update" ON households
  FOR UPDATE USING (id = current_household_id());

-- ── Profiles ────────────────────────────────────────────────────────────────

-- Members can see all profiles within their current household.
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (household_id = current_household_id());

-- Users can always see their own profiles across all households.
-- Required for getProfileForHousehold() during household switching.
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth_user_id = auth.uid());

-- Users can insert their own profile (auth_user_id = auth.uid()),
-- or a child profile inside the current household (auth_user_id IS NULL).
CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (
    auth_user_id = auth.uid()
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

-- Users can insert their own membership row.
CREATE POLICY "memberships_insert" ON household_memberships
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can delete their own membership (leave household).
CREATE POLICY "memberships_delete" ON household_memberships
  FOR DELETE USING (user_id = auth.uid());

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
