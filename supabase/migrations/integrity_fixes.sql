-- ---------------------------------------------------------------------------
-- Integrity Fixes Migration
-- Safe to re-run (idempotent).
-- Run in Supabase SQL editor: Dashboard → SQL Editor → paste and run.
-- ---------------------------------------------------------------------------

-- ── 1. wardrobe_items: add is_private column ──────────────────────────────
-- All existing items default to false (not private) — no behaviour change.
ALTER TABLE wardrobe_items
  ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;

-- ── 2. household_usage: format + non-negative constraints ─────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'household_usage_year_month_fmt'
  ) THEN
    ALTER TABLE household_usage
      ADD CONSTRAINT household_usage_year_month_fmt
      CHECK (year_month ~ '^\d{4}-\d{2}$');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'household_usage_count_nonneg'
  ) THEN
    ALTER TABLE household_usage
      ADD CONSTRAINT household_usage_count_nonneg
      CHECK (outfit_count >= 0);
  END IF;
END $$;

-- ── 3. profiles_update WITH CHECK: fix RLS recursion bug ──────────────────
-- The old WITH CHECK used a self-referencing subquery on profiles, which
-- triggered Postgres RLS recursion protection and returned NULL.
-- For non-admin users: false = NULL evaluates to NULL (not true) → update blocked.
-- Fix: SECURITY DEFINER function bypasses RLS for the is_admin lookup.

CREATE OR REPLACE FUNCTION get_profile_is_admin(p_profile_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE id = p_profile_id), false);
$$;

DROP POLICY IF EXISTS "profiles_update" ON profiles;
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
    -- Non-recursive: SECURITY DEFINER function reads current is_admin without RLS
    is_admin = get_profile_is_admin(id)
    OR EXISTS (
      SELECT 1 FROM household_memberships
      WHERE user_id = auth.uid()
        AND household_id = current_household_id()
        AND is_admin = true
    )
  );

-- ── 4. wardrobe_select: enforce is_private ────────────────────────────────
-- Private items are only visible to the profile owner.
-- Household members see only non-private items from other profiles.
-- Existing items all have is_private=false → no change in visible data.

DROP POLICY IF EXISTS "wardrobe_select" ON wardrobe_items;
CREATE POLICY "wardrobe_select" ON wardrobe_items
  FOR SELECT USING (
    profile_id IN (SELECT id FROM profiles WHERE household_id = current_household_id())
    AND (
      NOT is_private
      OR profile_id = (
        SELECT id FROM profiles
        WHERE auth_user_id = auth.uid()
          AND household_id = current_household_id()
      )
    )
  );

-- ── 5. Storage SELECT: enforce is_private ────────────────────────────────
-- Path format: wardrobe/{profileId}/{itemId}/filename
-- Position 2 = profileId, position 3 = itemId
-- Own-profile images: always readable.
-- Other-profile images: readable only if item is not private.

DROP POLICY IF EXISTS "wardrobe_images_select" ON storage.objects;
CREATE POLICY "wardrobe_images_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'wardrobe-images'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
  AND (
    split_part(name, '/', 2)::uuid IN (
      SELECT id FROM profiles
      WHERE auth_user_id = auth.uid() AND household_id = current_household_id()
    )
    OR NOT EXISTS (
      SELECT 1 FROM wardrobe_items wi
      WHERE wi.id = split_part(name, '/', 3)::uuid
        AND wi.is_private = true
    )
  )
);

DROP POLICY IF EXISTS "processed_images_select" ON storage.objects;
CREATE POLICY "processed_images_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'processed-images'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
  AND (
    split_part(name, '/', 2)::uuid IN (
      SELECT id FROM profiles
      WHERE auth_user_id = auth.uid() AND household_id = current_household_id()
    )
    OR NOT EXISTS (
      SELECT 1 FROM wardrobe_items wi
      WHERE wi.id = split_part(name, '/', 3)::uuid
        AND wi.is_private = true
    )
  )
);

-- ── 6. Calendar outfit assignment — atomic RPCs ───────────────────────────
-- Replaces read-modify-write (SELECT → merge → UPDATE) with a single atomic
-- UPDATE using JSONB operators. Eliminates concurrent-overwrite race condition.
-- Runs in caller security context so calendar_update RLS applies automatically.

CREATE OR REPLACE FUNCTION assign_outfit_to_event(
  p_event_id   UUID,
  p_profile_id TEXT,
  p_outfit_id  TEXT
) RETURNS SETOF calendar_events LANGUAGE sql AS $$
  UPDATE calendar_events
  SET outfit_assignments = outfit_assignments || jsonb_build_object(p_profile_id, p_outfit_id)
  WHERE id = p_event_id
  RETURNING *;
$$;

CREATE OR REPLACE FUNCTION remove_outfit_from_event(
  p_event_id   UUID,
  p_profile_id TEXT
) RETURNS SETOF calendar_events LANGUAGE sql AS $$
  UPDATE calendar_events
  SET outfit_assignments = outfit_assignments - p_profile_id
  WHERE id = p_event_id
  RETURNING *;
$$;
