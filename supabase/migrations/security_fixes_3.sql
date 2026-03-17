-- security_fixes_3.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Fix 1: profiles_insert was open to any household_id the caller knows.
--         Now restricted to:
--           a) Brand-new household (no members yet) — createHousehold flow.
--           b) Child profile (auth_user_id IS NULL) in the current household.
--         joinHousehold profile insert is now handled inside
--         join_household_with_invite() SECURITY DEFINER (see Fix below).
--
-- Fix 2: join_household_with_invite() extended to insert the profile atomically
--         alongside the membership. Flutter no longer inserts the profile directly.
--
-- Fix 3: backfill_membership_if_missing() RPC for legacy backfill path.
--         Direct insert now blocked by first-member policy.
--
-- Fix 4: Unique constraints on payment_transactions wrapped in exception
--         handler so schema is safely re-runnable.

-- ── Fix 1: tighten profiles_insert ───────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_insert" ON profiles;

CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (
    -- Own profile into a brand-new household (createHousehold — no members yet).
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

-- ── Fix 2: extend join_household_with_invite to insert profile atomically ────
-- Dropping old signature first (parameter list changed).
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

  -- Insert profile (SECURITY DEFINER bypasses profiles_insert RLS which
  -- would otherwise block inserts into households that already have members).
  INSERT INTO profiles (
    household_id, auth_user_id, name, age_group, gender, skin_tone,
    style_persona, fit_preferences
  )
  VALUES (
    p_household_id, auth.uid(), p_profile_name, 'adult', p_gender, p_skin_tone,
    '[]', '{}'
  );

  -- Insert membership. ON CONFLICT DO NOTHING is retry-safe.
  INSERT INTO household_memberships (user_id, household_id, is_admin)
  VALUES (auth.uid(), p_household_id, false)
  ON CONFLICT (user_id, household_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION join_household_with_invite(UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION join_household_with_invite(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ── Fix 3: drop backfill_membership_if_missing RPC ────────────────────────────
-- Removed: profile-existence check is insufficient because profiles are NOT
-- deleted on leave_household — ex-members retained their profile row and could
-- call this RPC to rejoin without an invite (or escalate to is_admin=true).
-- The one-time SQL migration already created membership rows for all legacy
-- users. Any user genuinely missing a row must rejoin via invite code.
DROP FUNCTION IF EXISTS backfill_membership_if_missing(UUID, BOOLEAN);

-- ── Fix 4: idempotent unique constraints ──────────────────────────────────────
-- UNIQUE constraints create an underlying index — PostgreSQL raises 42P07
-- (duplicate relation), not 42710 (duplicate object). Use pg_constraint guard.
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
