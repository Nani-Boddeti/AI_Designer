// notify-member-joined/index.ts
// Called from the Flutter app when a user successfully joins a household.
// Sends a push notification to all existing household members (excluding the
// new member who just joined).
//
// Required Supabase secrets:
//   FIREBASE_SERVICE_ACCOUNT  — full service account JSON string
//
// Expected request body:
//   { household_id: string, new_user_id: string }
//
// new_member_name is intentionally NOT accepted from the client — it is
// fetched from the database after JWT verification to prevent notification
// body injection.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getAccessToken, sendFcmBatch } from '../_shared/fcm.ts';

Deno.serve(async (req) => {
  try {
    // ── JWT auth: caller must be a signed-in Supabase user ───────────────────
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

    const { household_id, new_user_id } = await req.json();

    if (!household_id || !new_user_id) {
      return new Response(
        JSON.stringify({ error: 'household_id and new_user_id are required' }),
        { status: 400 },
      );
    }

    // ── Caller must be the user who just joined ───────────────────────────────
    if (user.id !== new_user_id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403 });
    }

    // ── Fetch member name from DB — never trust client-supplied name ──────────
    const { data: profile, error: profileErr } = await supabase
      .from('profiles')
      .select('name')
      .eq('auth_user_id', new_user_id)
      .eq('household_id', household_id)
      .maybeSingle();

    if (profileErr) throw profileErr;
    const memberName = profile?.name ?? 'A new member';

    // ── FCM setup ─────────────────────────────────────────────────────────────
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saJson) throw new Error('FIREBASE_SERVICE_ACCOUNT secret not set');
    const sa = JSON.parse(saJson);
    const accessToken = await getAccessToken(sa);

    // ── Get tokens for all existing members via household_memberships ─────────
    const { data: memberships, error: membershipsErr } = await supabase
      .from('household_memberships')
      .select('user_id')
      .eq('household_id', household_id)
      .neq('user_id', new_user_id);

    if (membershipsErr) throw membershipsErr;
    if (!memberships || memberships.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const memberUserIds = memberships.map((m: { user_id: string }) => m.user_id);

    const { data: tokens, error: tokensErr } = await supabase
      .from('device_tokens')
      .select('token')
      .in('user_id', memberUserIds);

    if (tokensErr) throw tokensErr;

    const tokenList = (tokens ?? []).map((r: { token: string }) => r.token);
    if (tokenList.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    await sendFcmBatch(
      accessToken,
      sa.project_id,
      tokenList,
      '👋 New member joined',
      `${memberName} just joined your household!`,
      { type: 'member_joined' },
    );

    return new Response(JSON.stringify({ sent: tokenList.length }), { status: 200 });
  } catch (err) {
    console.error('[notify-member-joined] Error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 });
  }
});
