// create-razorpay-order/index.ts
//
// Creates a Razorpay order server-side so the amount and tier are never
// trusted from the client. The client only receives the opaque order_id.
//
// Request body: { tier: 'pro' | 'prime', household_id: string }
// Response:     { key_id, order_id, amount, currency }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Pricing (mirrors TierCalculator.dart — keep in sync) ─────────────────────
// Per-member suggestion quotas by gender
const PRO_PER_FEMALE  = 15;
const PRO_PER_OTHER   = 10;
const PRIME_PER_FEMALE = 55;
const PRIME_PER_OTHER  = 50;
const PRICE_PER_SUGGESTION_PAISA = 500; // ₹5
const PRO_MIN_SUGGESTIONS   = 50;
const PRIME_MIN_SUGGESTIONS = 200;
const PRO_MIN_PAISA   = 25000;  // ₹250
const PRIME_MIN_PAISA = 100000; // ₹1000

function calcMonthlyLimit(
  tier: string,
  profiles: { gender: string }[],
  dynamicPricing: boolean,
): number {
  if (!dynamicPricing) {
    if (tier === 'pro')   return PRO_MIN_SUGGESTIONS;
    if (tier === 'prime') return PRIME_MIN_SUGGESTIONS;
    return 15;
  }
  if (tier === 'prime') {
    const raw = profiles.reduce(
      (s, p) => s + (p.gender === 'female' ? PRIME_PER_FEMALE : PRIME_PER_OTHER),
      0,
    );
    return Math.max(raw, PRIME_MIN_SUGGESTIONS);
  }
  if (tier === 'pro') {
    const raw = profiles.reduce(
      (s, p) => s + (p.gender === 'female' ? PRO_PER_FEMALE : PRO_PER_OTHER),
      0,
    );
    return Math.max(raw, PRO_MIN_SUGGESTIONS);
  }
  return 15;
}

function calcPricePaisa(
  tier: string,
  profiles: { gender: string }[],
  dynamicPricing: boolean,
): number {
  const limit = calcMonthlyLimit(tier, profiles, dynamicPricing);
  const raw   = limit * PRICE_PER_SUGGESTION_PAISA;
  if (tier === 'prime') return Math.max(raw, PRIME_MIN_PAISA);
  if (tier === 'pro')   return Math.max(raw, PRO_MIN_PAISA);
  return raw;
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

    const { tier, household_id } = await req.json();

    // Validate inputs
    if (!['pro', 'prime'].includes(tier)) {
      return new Response(JSON.stringify({ error: 'Invalid tier' }), { status: 400 });
    }
    if (!household_id) {
      return new Response(JSON.stringify({ error: 'household_id is required' }), { status: 400 });
    }

    // Verify caller is a member of the household
    const { data: membership, error: memberErr } = await supabase
      .from('household_memberships')
      .select('user_id')
      .eq('user_id', user.id)
      .eq('household_id', household_id)
      .maybeSingle();

    if (memberErr) throw memberErr;
    if (!membership) {
      return new Response(JSON.stringify({ error: 'Not a member of this household' }), { status: 403 });
    }

    // Fetch household for dynamic_pricing flag
    const { data: household, error: hErr } = await supabase
      .from('households')
      .select('dynamic_pricing')
      .eq('id', household_id)
      .single();

    if (hErr || !household) throw new Error('Household not found');

    // Fetch profiles for this household (gender-aware pricing)
    const { data: profiles } = await supabase
      .from('profiles')
      .select('gender')
      .eq('household_id', household_id);

    const amount = calcPricePaisa(tier, profiles ?? [], household.dynamic_pricing ?? true);

    // Create Razorpay order server-side
    const keyId     = Deno.env.get('RAZORPAY_KEY_ID')!;
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')!;
    const credentials = btoa(`${keyId}:${keySecret}`);

    const orderRes = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount,
        currency: 'INR',
        // Short receipt for Razorpay dashboard traceability (≤40 chars)
        receipt: `${household_id.slice(0, 8)}-${tier}-${Date.now().toString().slice(-6)}`,
        // Notes stored in Razorpay for audit; tier binding used in verification
        notes: { tier, household_id, user_id: user.id },
      }),
    });

    if (!orderRes.ok) {
      const errText = await orderRes.text();
      console.error('[create-razorpay-order] Razorpay error:', errText);
      return new Response(
        JSON.stringify({ error: 'Failed to create order. Please try again.' }),
        { status: 502 },
      );
    }

    const order = await orderRes.json();

    return new Response(
      JSON.stringify({
        key_id:   keyId,          // client uses this to open Razorpay SDK
        order_id: order.id,
        amount:   order.amount,   // paisa, as set server-side
        currency: order.currency,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[create-razorpay-order] Error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500 },
    );
  }
});
