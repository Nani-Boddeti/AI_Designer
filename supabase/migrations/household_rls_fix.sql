-- household_rls_fix.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Fixes the over-broad household SELECT policy that allowed any authenticated
-- user to read every household row.
--
-- Root cause: "household_select_for_join" used `auth.uid() IS NOT NULL` —
-- any logged-in user could enumerate all household names, tiers, invite codes.
--
-- Fix:
--   1. Drop the broad policy.
--   2. Create a membership-scoped policy (members read their own households).
--   3. Add a SECURITY DEFINER RPC for the one legitimate pre-join use case
--      (invite-code lookup), so only one household is ever returned and
--      only when the caller knows the invite code (acts as a secret token).

-- ── 1. Drop old policies ──────────────────────────────────────────────────────
-- household_select: was scoped to current_household_id() only (too narrow for
--   multi-household picker and backfill use cases).
-- household_select_for_join: was open to any authenticated user (too broad).
-- Both are replaced by household_select_own below.
DROP POLICY IF EXISTS "household_select"          ON households;
DROP POLICY IF EXISTS "household_select_for_join" ON households;
DROP POLICY IF EXISTS "household_select_own"      ON households;

-- ── 2. Membership-scoped SELECT policy ───────────────────────────────────────
-- Users can only read households they belong to. Covers:
--   - PostgREST nested join: .select('is_admin, households(*)') from
--     household_memberships rows the caller already owns (JOIN stays in scope).
--   - Multi-household backfill: IDs are fetched from the caller's own
--     membership rows before filtering households — always a subset the
--     policy allows.
CREATE POLICY "household_select_own" ON households
  FOR SELECT USING (
    id IN (
      SELECT household_id
      FROM household_memberships
      WHERE user_id = auth.uid()
    )
  );

-- ── 3. Invite-code lookup RPC (SECURITY DEFINER) ─────────────────────────────
-- Called before the user is a member. Returns full household row for one
-- household whose invite_code matches p_code. Invite code acts as the
-- access token — no enumeration possible (one code → at most one row).
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

-- Allow authenticated users (and only authenticated users) to call it.
REVOKE ALL ON FUNCTION lookup_household_by_invite_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lookup_household_by_invite_code(TEXT) TO authenticated;
