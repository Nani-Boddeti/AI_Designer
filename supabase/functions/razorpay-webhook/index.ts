// razorpay-webhook/index.ts
//
// Handles Razorpay server-initiated webhook events. Acts as a reliable
// fallback for the client-side verify-razorpay-payment flow — covering the
// case where the client crashes or loses network after Razorpay collects
// payment but before verify-razorpay-payment is called.
//
// Events handled:
//   order.paid        → upgrade household tier (idempotent)
//   payment.captured  → upgrade household tier (idempotent)
//   payment.failed    → record in payment_events for audit
//   refund.processed  → record in payment_events for audit
//
// Security:
//   - X-Razorpay-Signature verified with HMAC-SHA256 + RAZORPAY_WEBHOOK_SECRET
//   - No JWT required — Razorpay calls this endpoint directly
//   - All data sourced from Razorpay payload (not client-supplied)
//   - process_verified_payment is idempotent — safe to call after client flow
//
// Response:
//   - 401: Invalid signature (reject unknown callers, Razorpay will retry)
//   - 200: Event processed or permanently unprocessable (acknowledged)
//   - 500: Transient error (DB down etc.) — Razorpay will retry

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Webhook signature verification ───────────────────────────────────────────
// Razorpay signs the raw request body with HMAC-SHA256 using the webhook secret
// configured in the Razorpay dashboard (different from the API key_secret).
async function verifyWebhookSignature(
  rawBody: string,
  signature: string,
  webhookSecret: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(webhookSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sigBuffer = await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(rawBody));
  const expectedSig = Array.from(new Uint8Array(sigBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  // Constant-time comparison — prevents timing attacks
  if (expectedSig.length !== signature.length) return false;
  let mismatch = 0;
  for (let i = 0; i < expectedSig.length; i++) {
    mismatch |= expectedSig.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return mismatch === 0;
}

// ── Type helpers ──────────────────────────────────────────────────────────────
interface OrderNotes {
  tier?: string;
  household_id?: string;
  user_id?: string;
}

interface RazorpayPaymentEntity {
  id: string;
  order_id?: string;
  amount: number;
  status: string;
  notes?: OrderNotes;
  error_code?: string;
  error_description?: string;
}

interface RazorpayOrderEntity {
  id: string;
  amount: number;
  status: string;
  notes?: OrderNotes;
}

interface RazorpayRefundEntity {
  id: string;
  payment_id: string;
  amount: number;
}

// ── Extract notes from order or payment entity (notes live on the order) ──────
function extractNotes(
  orderEntity?: RazorpayOrderEntity,
  paymentEntity?: RazorpayPaymentEntity,
): OrderNotes {
  return orderEntity?.notes ?? paymentEntity?.notes ?? {};
}

// ── Supabase client (service_role — bypasses RLS) ────────────────────────────
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// ── Handler: order.paid / payment.captured ────────────────────────────────────
// Calls the same process_verified_payment RPC used by verify-razorpay-payment.
// Fully idempotent — ON CONFLICT DO NOTHING prevents duplicate tier upgrades.
async function handlePaymentSuccess(
  payload: Record<string, unknown>,
  eventType: string,
): Promise<void> {
  const orderEntity = (payload.order as { entity: RazorpayOrderEntity } | undefined)?.entity;
  const paymentEntity = (payload.payment as { entity: RazorpayPaymentEntity } | undefined)?.entity;

  if (!paymentEntity) {
    console.error(`[razorpay-webhook] ${eventType}: missing payment entity`);
    return;
  }

  const orderId    = orderEntity?.id ?? paymentEntity.order_id ?? '';
  const paymentId  = paymentEntity.id;
  const amount     = paymentEntity.amount ?? orderEntity?.amount ?? 0;
  const notes      = extractNotes(orderEntity, paymentEntity);
  const { tier, household_id, user_id } = notes;

  if (!orderId || !paymentId || !tier || !household_id || !user_id) {
    console.error(
      `[razorpay-webhook] ${eventType}: incomplete notes — ` +
      `order=${orderId.slice(0, 8)} tier=${tier} household=${String(household_id).slice(0, 8)}`,
    );
    // Permanently unprocessable — ack to stop retries, log for investigation.
    return;
  }

  if (!['pro', 'prime'].includes(tier)) {
    console.error(`[razorpay-webhook] ${eventType}: invalid tier="${tier}"`);
    return;
  }

  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  const { data: isNew, error } = await supabase.rpc('process_verified_payment', {
    p_household_id: household_id,
    p_user_id:      user_id,
    p_order_id:     orderId,
    p_payment_id:   paymentId,
    p_tier:         tier,
    p_amount_paise: amount,
    p_expires_at:   expiresAt,
  });

  if (error) throw error; // Transient — let Razorpay retry

  console.log(
    `[razorpay-webhook] ${eventType}: household=${String(household_id).slice(0, 8)} ` +
    `tier=${tier} new=${isNew}`,
  );
}

// ── Handler: payment.failed ───────────────────────────────────────────────────
async function handlePaymentFailed(payload: Record<string, unknown>): Promise<void> {
  const paymentEntity = (payload.payment as { entity: RazorpayPaymentEntity } | undefined)?.entity;
  if (!paymentEntity) return;

  const notes = paymentEntity.notes ?? {};

  const { error } = await supabase.rpc('record_payment_event', {
    p_event_type:          'payment.failed',
    p_razorpay_order_id:   paymentEntity.order_id ?? null,
    p_razorpay_payment_id: paymentEntity.id,
    p_household_id:        notes.household_id ?? null,
    p_user_id:             notes.user_id ?? null,
    p_tier:                notes.tier ?? null,
    p_amount_paise:        paymentEntity.amount,
    p_error_code:          paymentEntity.error_code ?? null,
    p_error_description:   paymentEntity.error_description ?? null,
    p_raw_payload:         payload,
  });

  if (error) throw error;

  console.log(
    `[razorpay-webhook] payment.failed: ` +
    `order=${String(paymentEntity.order_id).slice(0, 8)} ` +
    `error=${paymentEntity.error_code}`,
  );
}

// ── Handler: refund.processed ─────────────────────────────────────────────────
async function handleRefundProcessed(payload: Record<string, unknown>): Promise<void> {
  const refundEntity  = (payload.refund  as { entity: RazorpayRefundEntity  } | undefined)?.entity;
  const paymentEntity = (payload.payment as { entity: RazorpayPaymentEntity } | undefined)?.entity;

  if (!refundEntity) return;

  const notes = paymentEntity?.notes ?? {};

  const { error } = await supabase.rpc('record_payment_event', {
    p_event_type:          'refund.processed',
    p_razorpay_order_id:   paymentEntity?.order_id ?? null,
    p_razorpay_payment_id: refundEntity.payment_id,
    p_razorpay_refund_id:  refundEntity.id,
    p_household_id:        notes.household_id ?? null,
    p_user_id:             notes.user_id ?? null,
    p_tier:                notes.tier ?? null,
    p_amount_paise:        refundEntity.amount,
    p_raw_payload:         payload,
  });

  if (error) throw error;

  console.log(
    `[razorpay-webhook] refund.processed: ` +
    `refund=${refundEntity.id.slice(0, 8)} ` +
    `payment=${refundEntity.payment_id.slice(0, 8)} ` +
    `amount=${refundEntity.amount}`,
  );
}

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  // Read raw body first — must be read before any other parsing.
  const rawBody = await req.text();

  // ── 1. Verify webhook signature ───────────────────────────────────────────
  const signature     = req.headers.get('X-Razorpay-Signature') ?? '';
  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET');

  if (!webhookSecret) {
    console.error('[razorpay-webhook] RAZORPAY_WEBHOOK_SECRET secret not set');
    return new Response('Internal configuration error', { status: 500 });
  }

  const isValid = await verifyWebhookSignature(rawBody, signature, webhookSecret);
  if (!isValid) {
    console.error('[razorpay-webhook] Signature verification failed — rejecting request');
    return new Response('Unauthorized', { status: 401 });
  }

  // ── 2. Parse event ────────────────────────────────────────────────────────
  let event: Record<string, unknown>;
  try {
    event = JSON.parse(rawBody);
  } catch {
    console.error('[razorpay-webhook] Failed to parse JSON body');
    return new Response('Bad request', { status: 400 });
  }

  const eventType = event.event as string;
  const payload   = (event.payload ?? {}) as Record<string, unknown>;

  console.log(`[razorpay-webhook] Received event: ${eventType}`);

  // ── 3. Dispatch ───────────────────────────────────────────────────────────
  try {
    switch (eventType) {
      case 'order.paid':
      case 'payment.captured':
        await handlePaymentSuccess(payload, eventType);
        break;

      case 'payment.failed':
        await handlePaymentFailed(payload);
        break;

      case 'refund.processed':
        await handleRefundProcessed(payload);
        break;

      default:
        console.log(`[razorpay-webhook] Unhandled event type: ${eventType} — acknowledging`);
    }
  } catch (err) {
    // Transient error (e.g. DB down) — return 500 so Razorpay retries later.
    // process_verified_payment and record_payment_event are both idempotent,
    // so retries are completely safe.
    console.error(`[razorpay-webhook] Transient error for event ${eventType}:`, err);
    return new Response('Internal server error', { status: 500 });
  }

  // ── 4. Acknowledge ────────────────────────────────────────────────────────
  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
