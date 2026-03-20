-- payment_events.sql
--
-- Audit table for non-successful payment lifecycle events captured via
-- the Razorpay webhook (payment.failed, refund.processed).
-- Successful payments are recorded in payment_transactions by process_verified_payment.
--
-- Run once in Supabase Dashboard → SQL Editor.

-- ---------------------------------------------------------------------------
-- payment_events table
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS payment_events (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type            TEXT        NOT NULL,            -- e.g. 'payment.failed', 'refund.processed'
  razorpay_order_id     TEXT,
  razorpay_payment_id   TEXT,
  razorpay_refund_id    TEXT,
  household_id          UUID        REFERENCES households(id) ON DELETE SET NULL,
  user_id               UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  tier                  TEXT,
  amount_paise          INTEGER,
  error_code            TEXT,                            -- Razorpay error code (payment.failed only)
  error_description     TEXT,                            -- Human-readable error (payment.failed only)
  raw_payload           JSONB,                           -- Full Razorpay event payload for debugging
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Idempotency: one row per (payment_id, event_type) pair.
-- Prevents duplicate webhook deliveries from inserting duplicate rows.
CREATE UNIQUE INDEX IF NOT EXISTS payment_events_payment_event_uniq
  ON payment_events(razorpay_payment_id, event_type)
  WHERE razorpay_payment_id IS NOT NULL;

-- Idempotency: one row per refund_id.
CREATE UNIQUE INDEX IF NOT EXISTS payment_events_refund_uniq
  ON payment_events(razorpay_refund_id)
  WHERE razorpay_refund_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payment_events_household
  ON payment_events(household_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_created
  ON payment_events(created_at DESC);

ALTER TABLE payment_events ENABLE ROW LEVEL SECURITY;
-- No user-facing RLS policies — service_role only (called exclusively by Edge Functions).

-- ---------------------------------------------------------------------------
-- record_payment_event RPC
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER so the Edge Function can insert without an authenticated
-- user context. Restricted to service_role — not callable by clients.

CREATE OR REPLACE FUNCTION record_payment_event(
  p_event_type            TEXT,
  p_razorpay_order_id     TEXT        DEFAULT NULL,
  p_razorpay_payment_id   TEXT        DEFAULT NULL,
  p_razorpay_refund_id    TEXT        DEFAULT NULL,
  p_household_id          UUID        DEFAULT NULL,
  p_user_id               UUID        DEFAULT NULL,
  p_tier                  TEXT        DEFAULT NULL,
  p_amount_paise          INTEGER     DEFAULT NULL,
  p_error_code            TEXT        DEFAULT NULL,
  p_error_description     TEXT        DEFAULT NULL,
  p_raw_payload           JSONB       DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO payment_events (
    event_type,
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_refund_id,
    household_id,
    user_id,
    tier,
    amount_paise,
    error_code,
    error_description,
    raw_payload
  )
  VALUES (
    p_event_type,
    p_razorpay_order_id,
    p_razorpay_payment_id,
    p_razorpay_refund_id,
    p_household_id,
    p_user_id,
    p_tier,
    p_amount_paise,
    p_error_code,
    p_error_description,
    p_raw_payload
  )
  ON CONFLICT DO NOTHING; -- unique indexes handle idempotency for duplicate webhook deliveries
END;
$$;

REVOKE ALL ON FUNCTION record_payment_event(
  TEXT, TEXT, TEXT, TEXT, UUID, UUID, TEXT, INTEGER, TEXT, TEXT, JSONB
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION record_payment_event(
  TEXT, TEXT, TEXT, TEXT, UUID, UUID, TEXT, INTEGER, TEXT, TEXT, JSONB
) TO service_role;
