// verify-razorpay-payment/index.ts
//
// Verifies a completed Razorpay payment before upgrading the household tier.
//
// Security checks (in order):
//   1. Valid Supabase JWT (caller is authenticated)
//   2. HMAC-SHA256 signature verification (proves payment occurred)
//   3. Razorpay Orders API fetch — order.notes.tier === claimed tier
//      (prevents tier-substitution: reusing a valid pro signature to claim prime)
//   4. Caller is a member of the target household
//   5. Tier is a valid paid tier ('pro' | 'prime')
//
// Request body: { payment_id, order_id, signature, tier, household_id, amount_paise? }
// Response:     { success: true, tier, expires_at }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── HMAC-SHA256 using Web Crypto API (built into Deno) ────────────────────────
async function verifyRazorpaySignature(
  orderId: string,
  paymentId: string,
  signature: string,
  keySecret: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(keySecret);
  const message = encoder.encode(`${orderId}|${paymentId}`);

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sigBuffer = await crypto.subtle.sign('HMAC', cryptoKey, message);
  const expectedSignature = Array.from(new Uint8Array(sigBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  // Constant-time comparison to prevent timing attacks
  if (expectedSignature.length !== signature.length) return false;
  let mismatch = 0;
  for (let i = 0; i < expectedSignature.length; i++) {
    mismatch |= expectedSignature.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return mismatch === 0;
}

// ── Fetch canonical order from Razorpay to bind tier to the order ─────────────
// Returns null on any non-200 — caller must fail closed (reject, not grant tier).
interface RazorpayOrder {
  id: string;
  amount: number;
  status: string;
  notes: { tier?: string; household_id?: string; user_id?: string };
}

async function fetchRazorpayOrder(
  orderId: string,
  keyId: string,
  keySecret: string,
): Promise<RazorpayOrder | null> {
  const credentials = btoa(`${keyId}:${keySecret}`);
  const res = await fetch(`https://api.razorpay.com/v1/orders/${orderId}`, {
    headers: { Authorization: `Basic ${credentials}` },
  });
  if (!res.ok) return null;
  return res.json() as Promise<RazorpayOrder>;
}

// ── Verify the order matches the claimed tier, household, and user ────────────
// Prevents two replay attacks:
//   1. Tier-substitution: reuse a valid pro HMAC to claim prime
//   2. Household-replay: use a paid order for household A to upgrade household B
//      (possible when caller is a member of both)
function verifyOrderBinding(
  order: RazorpayOrder,
  claimedTier: string,
  householdId: string,
  userId: string,
): boolean {
  return (
    order.notes?.tier         === claimedTier &&
    order.notes?.household_id === householdId &&
    order.notes?.user_id      === userId
  );
}

// ── Handler ───────────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  try {
    // Auth
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userErr } = await supabase.auth.getUser(jwt);
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 });
    }

    const { payment_id, order_id, signature, tier, household_id, amount_paise } = await req.json();

    if (!payment_id || !order_id || !signature || !tier || !household_id) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400 });
    }

    if (!['pro', 'prime'].includes(tier)) {
      return new Response(JSON.stringify({ error: 'Invalid tier' }), { status: 400 });
    }

    // ── 2. HMAC-SHA256 signature verification ─────────────────────────────────
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')!;
    const isValid = await verifyRazorpaySignature(order_id, payment_id, signature, keySecret);

    if (!isValid) {
      console.error(`[verify-razorpay-payment] Signature mismatch for order ${order_id.slice(0, 8)}`);
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid payment signature' }),
        { status: 400 },
      );
    }

    // ── 3. Cross-check order binding against Razorpay's canonical record ──────
    // Prevents tier-substitution AND household-replay attacks.
    // Fail closed: if Razorpay API is unreachable, reject rather than grant tier.
    const keyId = Deno.env.get('RAZORPAY_KEY_ID')!;
    const razorpayOrder = await fetchRazorpayOrder(order_id, keyId, keySecret);

    if (razorpayOrder === null) {
      console.error(`[verify-razorpay-payment] Could not fetch order ${order_id.slice(0, 8)} from Razorpay`);
      return new Response(
        JSON.stringify({ success: false, error: 'Could not verify order with payment provider. Please try again.' }),
        { status: 502 },
      );
    }

    if (!verifyOrderBinding(razorpayOrder, tier, household_id, user.id)) {
      console.error(
        `[verify-razorpay-payment] Order binding mismatch: order ${order_id.slice(0, 8)} ` +
        `notes=${JSON.stringify(razorpayOrder.notes)} claimed tier=${tier} household=${household_id.slice(0, 8)}`,
      );
      return new Response(
        JSON.stringify({ success: false, error: 'Payment verification failed' }),
        { status: 400 },
      );
    }

    // ── 4. Verify caller is a member of the household ─────────────────────────
    const { data: membership, error: memberErr } = await supabase
      .from('household_memberships')
      .select('user_id')
      .eq('user_id', user.id)
      .eq('household_id', household_id)
      .maybeSingle();

    if (memberErr) throw memberErr;
    if (!membership) {
      return new Response(
        JSON.stringify({ success: false, error: 'Not a member of this household' }),
        { status: 403 },
      );
    }

    // ── 5. Atomic insert + tier upgrade via SECURITY DEFINER RPC ─────────────
    // process_verified_payment runs both the payment_transactions INSERT and the
    // households UPDATE in a single DB transaction — partial failure is impossible.
    // Returns true = newly processed, false = already processed (idempotent success).
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { data: isNew, error: processErr } = await supabase.rpc('process_verified_payment', {
      p_household_id: household_id,
      p_user_id: user.id,
      p_order_id: order_id,
      p_payment_id: payment_id,
      p_tier: tier,
      p_amount_paise: amount_paise ?? null,
      p_expires_at: expiresAt,
    });

    if (processErr) throw processErr;

    console.log(
      `[verify-razorpay-payment] household=${household_id.slice(0, 8)} tier=${tier} new=${isNew}`,
    );

    return new Response(
      JSON.stringify({ success: true, tier, expires_at: expiresAt }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[verify-razorpay-payment] Error:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500 },
    );
  }
});
