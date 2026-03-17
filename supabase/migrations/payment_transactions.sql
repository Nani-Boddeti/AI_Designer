-- Run this in Supabase dashboard → SQL Editor
-- Creates the payment_transactions table for logging successful Razorpay payments.

CREATE TABLE IF NOT EXISTS payment_transactions (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id         UUID        NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id              UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  razorpay_order_id    TEXT        NOT NULL,
  razorpay_payment_id  TEXT        NOT NULL,
  tier                 TEXT        NOT NULL CHECK (tier IN ('pro', 'prime')),
  amount_paise         INTEGER,
  expires_at           TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for backoffice queries
CREATE INDEX IF NOT EXISTS idx_payment_transactions_household ON payment_transactions(household_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created   ON payment_transactions(created_at DESC);

-- RLS: service role (backoffice + edge functions) bypasses this automatically.
-- Regular users have no access.
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;

-- ── View: joins household name + payer's profile name for backoffice display ──
CREATE OR REPLACE VIEW payment_transactions_view AS
SELECT
  pt.id,
  pt.household_id,
  h.name                AS household_name,
  pt.user_id,
  p.name                AS user_name,
  pt.razorpay_order_id,
  pt.razorpay_payment_id,
  pt.tier,
  pt.amount_paise,
  pt.expires_at,
  pt.created_at
FROM payment_transactions pt
LEFT JOIN households h ON h.id = pt.household_id
LEFT JOIN profiles p   ON p.auth_user_id = pt.user_id;
