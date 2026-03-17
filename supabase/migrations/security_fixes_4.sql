-- security_fixes_4.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Fix 1: Add UNIQUE constraint on profiles(auth_user_id, household_id) so
--         join_household_with_invite retries don't create duplicate rows.
--         Regular UNIQUE (not partial): NULLs are never equal in SQL, so
--         multiple child profiles (auth_user_id IS NULL) remain allowed.
--         ON CONFLICT ON CONSTRAINT requires ALTER TABLE ADD CONSTRAINT,
--         not CREATE UNIQUE INDEX.
--
-- Fix 2: Update join_household_with_invite to use ON CONFLICT ON CONSTRAINT,
--         making the profile insert fully retry-safe.
--
-- Fix 3: Add process_verified_payment() SECURITY DEFINER RPC that atomically
--         inserts the payment record AND upgrades the tier in one DB transaction.
--         Eliminates the partial-failure window and closes the replay-attack
--         regression introduced by the previous "check tier and fall through" fix.
--         Restricted to service_role — not callable by authenticated users.

-- ── Fix 1: unique constraint on profiles ─────────────────────────────────────
-- Pre-check: if duplicate (auth_user_id, household_id) rows already exist the
-- ALTER TABLE would abort with a cryptic error. Fail fast with a clear message
-- instead so the issue can be investigated before data is touched.
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE auth_user_id IS NOT NULL
    GROUP BY auth_user_id, household_id
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Cannot add unique constraint: duplicate (auth_user_id, household_id) rows exist in profiles. '
      'Investigate and deduplicate manually, then re-run this migration.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_auth_user_household_uniq') THEN
    ALTER TABLE profiles ADD CONSTRAINT profiles_auth_user_household_uniq
      UNIQUE (auth_user_id, household_id);
  END IF;
END $$;

-- ── Fix 2: retry-safe profile insert in join_household_with_invite ────────────
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

  -- Insert profile. ON CONFLICT ON CONSTRAINT makes retries safe — if the profile
  -- already exists from a previous attempt, skip silently and continue.
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

-- ── Fix 3: atomic payment processing RPC ─────────────────────────────────────
-- Inserts the payment record AND updates the household tier in one transaction.
-- Returns TRUE = newly processed, FALSE = already processed (idempotent success).
-- Restricted to service_role — p_user_id comes from the Edge Function's verified
-- JWT, never from the request body.
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
    -- Already processed — idempotent success.
    RETURN FALSE;
  END IF;

  UPDATE households
  SET tier = p_tier, tier_expires_at = p_expires_at
  WHERE id = p_household_id;

  RETURN TRUE;
END;
$$;

-- Service-role only — never expose to authenticated users directly.
-- REVOKE strips PUBLIC (includes anon + authenticated).
-- Explicit GRANT to service_role is required: service_role is not a superuser
-- in Supabase and does not bypass GRANT/REVOKE privilege checks.
REVOKE ALL ON FUNCTION process_verified_payment(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION process_verified_payment(UUID, UUID, TEXT, TEXT, TEXT, INTEGER, TIMESTAMPTZ) TO service_role;
