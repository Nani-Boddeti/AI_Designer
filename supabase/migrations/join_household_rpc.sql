-- join_household_rpc.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Closes the invite-code bypass: the old memberships_insert RLS policy only
-- checked user_id = auth.uid(), so anyone who knew a household UUID could
-- insert themselves as a member without an invite code.
--
-- Fix:
--   1. Create join_household_with_invite() SECURITY DEFINER RPC — validates
--      invite code before inserting the membership row.
--   2. Tighten memberships_insert to first-member-only (createHousehold flow).
--      All subsequent joins must go through the RPC.

-- ── 1. SECURITY DEFINER RPC ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION join_household_with_invite(
  p_household_id UUID,
  p_invite_code  TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate invite code matches the household.
  IF NOT EXISTS (
    SELECT 1 FROM households
    WHERE id = p_household_id AND invite_code = p_invite_code
  ) THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  -- Insert membership; ON CONFLICT DO NOTHING is idempotent (retry-safe).
  INSERT INTO household_memberships (user_id, household_id, is_admin)
  VALUES (auth.uid(), p_household_id, false)
  ON CONFLICT (user_id, household_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION join_household_with_invite(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION join_household_with_invite(UUID, TEXT) TO authenticated;

-- ── 2. Tighten memberships_insert ────────────────────────────────────────────
-- Allow direct insert only when no membership rows exist yet for that household
-- (i.e., the creator inserting the very first row in createHousehold flow).
-- join_household_with_invite() SECURITY DEFINER bypasses this for all other joins.
DROP POLICY IF EXISTS "memberships_insert" ON household_memberships;

CREATE POLICY "memberships_insert" ON household_memberships
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM household_memberships existing
      WHERE existing.household_id = household_memberships.household_id
    )
  );
