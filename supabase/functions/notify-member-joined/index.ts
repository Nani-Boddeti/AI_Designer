// notify-member-joined/index.ts
// Called from the Flutter app when a user successfully joins a household.
// Sends a push notification to all existing household members (excluding the
// new member who just joined).
//
// Required Supabase secrets:
//   FIREBASE_SERVICE_ACCOUNT  — full service account JSON string
//
// Expected request body:
//   { household_id: string, new_member_name: string, new_user_id: string }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getAccessToken, sendFcmBatch } from '../_shared/fcm.ts';

Deno.serve(async (req) => {
  try {
    const { household_id, new_member_name, new_user_id } = await req.json();

    if (!household_id || !new_member_name || !new_user_id) {
      return new Response(
        JSON.stringify({ error: 'household_id, new_member_name and new_user_id are required' }),
        { status: 400 }
      );
    }

    // ── Supabase admin client ────────────────────────────────────────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // ── FCM setup ────────────────────────────────────────────────────────────
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saJson) throw new Error('FIREBASE_SERVICE_ACCOUNT secret not set');
    const sa = JSON.parse(saJson);
    const accessToken = await getAccessToken(sa);

    // ── Get tokens for all existing members (excluding the new one) ──────────
    const { data: tokens, error: tokensErr } = await supabase
      .from('device_tokens')
      .select('token')
      .in(
        'user_id',
        supabase
          .from('profiles')
          .select('user_id')
          .eq('household_id', household_id)
          .neq('user_id', new_user_id) // exclude the new member
      );

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
      `${new_member_name} just joined your household!`,
      { type: 'member_joined', new_member_name }
    );

    return new Response(JSON.stringify({ sent: tokenList.length }), { status: 200 });
  } catch (err) {
    console.error('[notify-member-joined] Error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
