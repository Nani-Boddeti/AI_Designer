-- create_household_rpc.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Fixes two bugs:
--
-- 1. RLS infinite recursion (42P17):
--    memberships_insert and memberships_select_admin both subquery
--    household_memberships from within policies ON household_memberships,
--    causing PostgreSQL to detect recursion and raise 42P17.
--    Fix: SECURITY DEFINER helper functions bypass RLS for the subquery,
--    breaking the recursion (same pattern as get_profile_is_admin in
--    integrity_fixes.sql).
--
-- 2. Orphaned rows:
--    auth_repository.dart performed 4 sequential uncommitted inserts.
--    A failure at step 3 (memberships insert) left committed household +
--    profile rows with no membership row — orphans.
--    Fix: create_household() SECURITY DEFINER RPC executes all 4 steps
--    in a single transaction. PostgREST rolls back everything on failure.

-- ── Part A: SECURITY DEFINER helpers ─────────────────────────────────────────

-- Returns true if the given household already has at least one member.
-- Used by memberships_insert to enforce the first-member-only guard
-- without querying household_memberships recursively from within the policy.
CREATE OR REPLACE FUNCTION household_has_members(p_household_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM household_memberships
    WHERE household_id = p_household_id
  );
$$;

REVOKE ALL ON FUNCTION household_has_members(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION household_has_members(UUID) TO authenticated;

-- Returns the set of household_ids where p_user_id is an admin.
-- Used by memberships_select_admin without querying household_memberships
-- recursively from within the policy.
CREATE OR REPLACE FUNCTION get_admin_household_ids(p_user_id UUID)
RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT household_id
  FROM household_memberships
  WHERE user_id = p_user_id AND is_admin = true;
$$;

REVOKE ALL ON FUNCTION get_admin_household_ids(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_admin_household_ids(UUID) TO authenticated;

-- ── Part B: Rewrite self-referencing policies ─────────────────────────────────

-- memberships_insert: allow direct insert only for the very first membership
-- row of a household (createHousehold flow). All subsequent joins use
-- join_household_with_invite() SECURITY DEFINER which bypasses this policy.
DROP POLICY IF EXISTS "memberships_insert" ON household_memberships;
CREATE POLICY "memberships_insert" ON household_memberships
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND NOT household_has_members(household_memberships.household_id)
  );

-- memberships_select_admin: admins can see all membership rows in their
-- households (for member management UI).
DROP POLICY IF EXISTS "memberships_select_admin" ON household_memberships;
CREATE POLICY "memberships_select_admin" ON household_memberships
  FOR SELECT USING (
    household_id IN (SELECT get_admin_household_ids(auth.uid()))
  );

-- ── Part C: Atomic create_household RPC ──────────────────────────────────────
-- Replaces 4 sequential client-side inserts with a single atomic transaction.
-- SECURITY DEFINER runs as function owner (postgres) → bypasses all RLS
-- internally, so no policy recursion possible inside this function.
-- PostgREST wraps every rpc() call in a transaction → full rollback on any
-- unhandled exception → no orphaned households or profiles possible.

CREATE OR REPLACE FUNCTION create_household(
  p_household_id    UUID,
  p_name            TEXT,
  p_invite_code     TEXT,
  p_hemisphere      TEXT,
  p_dynamic_pricing BOOLEAN,
  p_profile_name    TEXT,
  p_gender          TEXT,
  p_skin_tone       TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_household JSONB;
  v_profile   JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Step 1: Insert household.
  INSERT INTO households (id, name, invite_code, hemisphere, dynamic_pricing)
  VALUES (p_household_id, p_name, p_invite_code, p_hemisphere, p_dynamic_pricing);

  -- Step 2: Insert profile for the creating user (always adult, admin).
  INSERT INTO profiles (
    household_id, auth_user_id, name, age_group, gender,
    skin_tone, style_persona, fit_preferences, is_admin
  )
  VALUES (
    p_household_id, v_uid, p_profile_name, 'adult', p_gender,
    p_skin_tone, '[]', '{}', true
  );

  -- Step 3: Insert membership row (creator is always admin).
  INSERT INTO household_memberships (user_id, household_id, is_admin)
  VALUES (v_uid, p_household_id, true);

  -- Step 4: Set active household in user_preferences so current_household_id()
  -- starts returning this household immediately for all subsequent RLS checks.
  INSERT INTO user_preferences (user_id, active_household_id)
  VALUES (v_uid, p_household_id)
  ON CONFLICT (user_id) DO UPDATE
    SET active_household_id = EXCLUDED.active_household_id;

  -- Step 5: Fetch and return full household + profile rows so the Flutter
  -- client can hydrate its models without an extra round-trip.
  -- Runs as postgres (SECURITY DEFINER) so no RLS filter needed.
  SELECT to_jsonb(h) INTO v_household
  FROM households h WHERE h.id = p_household_id;

  SELECT to_jsonb(p) INTO v_profile
  FROM profiles p
  WHERE p.auth_user_id = v_uid AND p.household_id = p_household_id;

  RETURN jsonb_build_object('household', v_household, 'profile', v_profile);
END;
$$;

REVOKE ALL ON FUNCTION create_household(UUID, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_household(UUID, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT, TEXT) TO authenticated;

-- ── Part D: One-time orphan cleanup ──────────────────────────────────────────
-- Run this ONCE separately after the above is deployed to remove households
-- that were created before this fix but have no membership row.
-- profiles.household_id has ON DELETE CASCADE → profiles are deleted too.
--
-- DELETE FROM households
-- WHERE id NOT IN (SELECT DISTINCT household_id FROM household_memberships);
