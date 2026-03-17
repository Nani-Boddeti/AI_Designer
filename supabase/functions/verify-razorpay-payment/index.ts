// verify-razorpay-payment/index.ts
//
// Verifies a completed Razorpay payment before upgrading the household tier.
//
// Security checks (in order):
//   1. Valid Supabase JWT (caller is authenticated)
//   2. HMAC-SHA256 signature verification using RAZORPAY_KEY_SECRET
//      → signature = HMAC-SHA256(order_id + '|' + payment_id, key_secret)
//   3. Caller is a member of the target household
//   4. Tier is a valid paid tier ('pro' | 'prime')
//
// Request body: { payment_id, order_id, signature, tier, household_id }
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

    // Validate all fields present
    if (!payment_id || !order_id || !signature || !tier || !household_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400 },
      );
    }

    // Validate tier
    if (!['pro', 'prime'].includes(tier)) {
      return new Response(JSON.stringify({ error: 'Invalid tier' }), { status: 400 });
    }

    // ── CRITICAL: HMAC-SHA256 signature verification ──────────────────────────
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')!;
    const isValid = await verifyRazorpaySignature(order_id, payment_id, signature, keySecret);

    if (!isValid) {
      // Log without leaking actual values — only the first 8 chars for tracing
      console.error(
        `[verify-razorpay-payment] Signature mismatch for order ${order_id.slice(0, 8)}`,
      );
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid payment signature' }),
        { status: 400 },
      );
    }

    // ── Verify caller is a member of the household ────────────────────────────
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

    // ── Upgrade the household tier ────────────────────────────────────────────
    // tier_expires_at: 30 days from now
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { error: updateErr } = await supabase
      .from('households')
      .update({ tier, tier_expires_at: expiresAt })
      .eq('id', household_id);

    if (updateErr) throw updateErr;

    // ── Log payment transaction (fire-and-forget — don't fail if logging fails) ─
    supabase.from('payment_transactions').insert({
      household_id,
      user_id: user.id,
      razorpay_order_id: order_id,
      razorpay_payment_id: payment_id,
      tier,
      amount_paise: amount_paise ?? null,
      expires_at: expiresAt,
    }).then(({ error }) => {
      if (error) console.error('[verify-razorpay-payment] Failed to log transaction:', error.message);
    });

    console.log(
      `[verify-razorpay-payment] Tier updated household=${household_id.slice(0, 8)} tier=${tier}`,
    );

    return new Response(
      JSON.stringify({ success: true, tier, expires_at: expiresAt }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[verify-razorpay-payment] Error:', err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500 },
    );
  }
});
