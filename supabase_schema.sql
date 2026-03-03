-- ============================================================
-- AI Designer Assist — Supabase Schema
-- Run this in the Supabase SQL Editor (Dashboard > SQL)
-- ============================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS households (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  hemisphere  TEXT CHECK (hemisphere IN ('north', 'south')) DEFAULT 'north',
  invite_code TEXT UNIQUE DEFAULT substr(md5(random()::text), 1, 8),
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Migration: add hemisphere to existing households tables
-- ALTER TABLE households ADD COLUMN IF NOT EXISTS hemisphere TEXT CHECK (hemisphere IN ('north', 'south')) DEFAULT 'north';

CREATE TABLE IF NOT EXISTS profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id    UUID REFERENCES households(id) ON DELETE CASCADE,
  auth_user_id    UUID REFERENCES auth.users(id),  -- null for child profiles
  name            TEXT NOT NULL,
  avatar_url      TEXT,
  age_group       TEXT CHECK (age_group IN ('toddler','child','teen','adult')),
  style_persona   JSONB DEFAULT '[]',
  fit_preferences JSONB DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS wardrobe_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id           UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name                 TEXT,
  category             TEXT,
  colors               JSONB,
  color_names          JSONB,
  style_tags           JSONB,
  season_tags          JSONB,
  image_url            TEXT,
  processed_image_url  TEXT,
  brand                TEXT,
  size                 TEXT,
  ai_description       TEXT,
  created_at           TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS outfits (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id       UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name             TEXT,
  occasion         TEXT,
  item_ids         JSONB,
  notes            TEXT,
  is_ai_generated  BOOLEAN DEFAULT true,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS calendar_events (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id        UUID REFERENCES households(id) ON DELETE CASCADE,
  title               TEXT NOT NULL,
  event_date          DATE NOT NULL,
  occasion            TEXT,
  outfit_assignments  JSONB DEFAULT '{}',
  weather_snapshot    JSONB,
  notes               TEXT,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Storage buckets + policies
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('wardrobe-images',  'wardrobe-images',  true),
  ('processed-images', 'processed-images', true),
  ('avatars',          'avatars',          true)
ON CONFLICT (id) DO NOTHING;

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
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE households     ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE wardrobe_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE outfits        ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

-- Helper: get the household_id for the current user via their profile.
-- SECURITY DEFINER bypasses RLS when querying profiles, breaking the
-- recursion that would otherwise cause max_stack_depth errors.
CREATE OR REPLACE FUNCTION current_household_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT household_id FROM profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

-- Households: members can read/update their own household
CREATE POLICY "household_select" ON households
  FOR SELECT USING (id = current_household_id());

-- Allows unauthenticated-profile users to look up a household by invite code.
-- current_household_id() returns NULL before a profile exists, so we need
-- a separate open SELECT policy for the join flow.
CREATE POLICY "household_select_for_join" ON households
  FOR SELECT USING (true);

CREATE POLICY "household_insert" ON households
  FOR INSERT WITH CHECK (true);  -- authenticated users can create

CREATE POLICY "household_update" ON households
  FOR UPDATE USING (id = current_household_id());

-- Profiles: members can see all profiles in their household
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (household_id = current_household_id());

-- Allow a user to insert a profile tied to their own auth UID.
-- Using current_household_id() here would recurse (no profile exists yet
-- during first-time household creation), so we check auth_user_id directly.
-- auth_user_id = auth.uid() covers account-linked profiles.
-- The IS NULL branch covers child profiles (no auth account).
CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (
    auth_user_id = auth.uid()
    OR (auth_user_id IS NULL AND household_id = current_household_id())
  );

CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE USING (household_id = current_household_id());

CREATE POLICY "profiles_delete" ON profiles
  FOR DELETE USING (household_id = current_household_id());

-- Wardrobe items: scoped to household via profile
CREATE POLICY "wardrobe_select" ON wardrobe_items
  FOR SELECT USING (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

CREATE POLICY "wardrobe_insert" ON wardrobe_items
  FOR INSERT WITH CHECK (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

CREATE POLICY "wardrobe_update" ON wardrobe_items
  FOR UPDATE USING (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

CREATE POLICY "wardrobe_delete" ON wardrobe_items
  FOR DELETE USING (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

-- Outfits: scoped to household via profile
CREATE POLICY "outfits_select" ON outfits
  FOR SELECT USING (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

CREATE POLICY "outfits_insert" ON outfits
  FOR INSERT WITH CHECK (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

CREATE POLICY "outfits_update" ON outfits
  FOR UPDATE USING (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

CREATE POLICY "outfits_delete" ON outfits
  FOR DELETE USING (
    profile_id IN (
      SELECT id FROM profiles WHERE household_id = current_household_id()
    )
  );

-- Calendar events: scoped directly to household
CREATE POLICY "calendar_select" ON calendar_events
  FOR SELECT USING (household_id = current_household_id());

CREATE POLICY "calendar_insert" ON calendar_events
  FOR INSERT WITH CHECK (household_id = current_household_id());

CREATE POLICY "calendar_update" ON calendar_events
  FOR UPDATE USING (household_id = current_household_id());

CREATE POLICY "calendar_delete" ON calendar_events
  FOR DELETE USING (household_id = current_household_id());
