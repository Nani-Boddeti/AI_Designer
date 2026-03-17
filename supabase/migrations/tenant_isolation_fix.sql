-- tenant_isolation_fix.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Fix 1: current_household_id() trusted user_preferences.active_household_id
-- without validating membership. A user who writes an arbitrary UUID into their
-- own active_household_id row could bypass tenant isolation on every RLS policy
-- that calls current_household_id() (wardrobe, profiles, outfits, calendar, etc.).
--
-- Fix: JOIN to household_memberships inside the function so only UUIDs the
-- caller is actually a member of are returned. Unrecognised UUIDs silently fall
-- through to the profiles-based fallback, preserving legacy behaviour.
--
-- Fix 2: Legacy backfill path in the Flutter app reads households directly via
-- .from('households').select() which broke when household_select_for_join was
-- replaced by the membership-scoped household_select_own policy.
-- A new SECURITY DEFINER RPC validates backfill scope via the profiles table
-- (auth_user_id = auth.uid()) — the same trust anchor used by profiles_select_own.

-- ── Fix 1: validate membership in current_household_id() ─────────────────────
CREATE OR REPLACE FUNCTION current_household_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    -- Only return active_household_id if the caller is actually a member.
    (
      SELECT up.active_household_id
      FROM user_preferences up
      JOIN household_memberships hm
        ON hm.household_id = up.active_household_id
       AND hm.user_id      = auth.uid()
      WHERE up.user_id = auth.uid()
    ),
    -- Legacy fallback: first profile row (single-household era).
    (SELECT household_id FROM profiles WHERE auth_user_id = auth.uid() LIMIT 1)
  );
$$;

-- ── Fix 2: backfill RPC scoped to caller's own profiles ──────────────────────
-- Returns household rows for the given IDs, but only for households where the
-- caller has a profile row (auth_user_id = auth.uid()). This is the same trust
-- anchor as profiles_select_own — no new privilege is granted.
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
      -- Scope to households where the caller has a profile — same trust as
      -- profiles_select_own. Prevents using this RPC to read arbitrary households.
      AND h.id IN (
        SELECT household_id FROM profiles WHERE auth_user_id = auth.uid()
      );
END;
$$;

REVOKE ALL ON FUNCTION get_households_by_ids_for_backfill(UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_households_by_ids_for_backfill(UUID[]) TO authenticated;
