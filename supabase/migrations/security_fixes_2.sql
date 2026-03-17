-- security_fixes_2.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Fix 1: household_update policy was open to any member, including non-admins,
--         and did not block billing fields (tier, tier_expires_at, invite_code).
--
-- Fix 2: current_household_id() profile fallback did not check membership.
--         After leaving a household the profile row remains (intentional — wardrobe
--         data stays for other household members), but the fallback could still
--         return the old household_id, granting the ex-member read/write access.
--
-- Fix 3: payment_transactions had no uniqueness guard on razorpay_order_id /
--         razorpay_payment_id, allowing the same payment to be replayed to
--         reset the tier expiry.
--
-- Fix 4: memberships_delete policy let users delete their own membership row
--         directly, bypassing the leave_household() RPC which handles admin
--         promotion and sole-member household cleanup.

-- ── Fix 1: household_update — admin-only, billing fields immutable via RLS ────
DROP POLICY IF EXISTS "household_update" ON households;

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
    -- tier, tier_expires_at, invite_code are managed exclusively by Edge Functions
    -- (service role, bypasses RLS). Admins may change name, hemisphere, dynamic_pricing.
    tier            IS NOT DISTINCT FROM (SELECT h.tier            FROM households h WHERE h.id = id) AND
    tier_expires_at IS NOT DISTINCT FROM (SELECT h.tier_expires_at FROM households h WHERE h.id = id) AND
    invite_code     IS NOT DISTINCT FROM (SELECT h.invite_code     FROM households h WHERE h.id = id)
  );

-- ── Fix 2: current_household_id() — validate membership in profile fallback ───
CREATE OR REPLACE FUNCTION current_household_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    -- Primary: user_preferences.active_household_id, validated against membership.
    (
      SELECT up.active_household_id
      FROM user_preferences up
      JOIN household_memberships hm
        ON hm.household_id = up.active_household_id
       AND hm.user_id      = auth.uid()
      WHERE up.user_id = auth.uid()
    ),
    -- Fallback: first profile row, also validated against membership.
    -- Without this check, ex-members whose profile row remains would still
    -- get access via the fallback after leaving a household.
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

-- ── Fix 3: unique constraints to prevent payment replay ───────────────────────
ALTER TABLE payment_transactions
  ADD CONSTRAINT payment_transactions_order_id_uniq   UNIQUE (razorpay_order_id),
  ADD CONSTRAINT payment_transactions_payment_id_uniq UNIQUE (razorpay_payment_id);

-- ── Fix 4: remove direct membership delete — all exits go through RPC ─────────
-- leave_household() SECURITY DEFINER handles admin promotion, sole-member
-- household cleanup, and user_preferences clearing. Direct deletes bypass all of that.
DROP POLICY IF EXISTS "memberships_delete" ON household_memberships;
