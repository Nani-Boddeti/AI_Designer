-- delete_account_rpc.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Creates the delete_account_for_user() RPC required by the delete-account
-- Edge Function. Without this, account deletion fails at step 3 of the
-- Edge Function flow.

CREATE OR REPLACE FUNCTION delete_account_for_user(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Prevent a user from deleting another user's account.
  -- Service role callers have auth.uid() = NULL — allowed.
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Cannot delete another user''s account';
  END IF;

  -- 1. Delete households where this user is the sole member.
  --    CASCADE removes calendar_events, household_usage, payment_transactions.
  DELETE FROM households
  WHERE id IN (
    SELECT m.household_id
    FROM household_memberships m
    WHERE m.user_id = p_user_id
      AND NOT EXISTS (
        SELECT 1 FROM household_memberships other
        WHERE other.household_id = m.household_id
          AND other.user_id <> p_user_id
      )
  );

  -- 2. Delete profiles. CASCADE removes wardrobe_items and outfits.
  DELETE FROM profiles WHERE auth_user_id = p_user_id;

  -- 3. Delete remaining membership rows (user was not sole member above).
  DELETE FROM household_memberships WHERE user_id = p_user_id;

  -- 4. Delete user preferences.
  DELETE FROM user_preferences WHERE user_id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION delete_account_for_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_account_for_user(UUID) TO authenticated;
