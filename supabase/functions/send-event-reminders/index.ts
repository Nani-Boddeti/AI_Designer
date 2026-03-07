// send-event-reminders/index.ts
// Scheduled Edge Function — triggered daily by pg_cron (see SQL below).
// Finds events happening tomorrow, collects device tokens for each household,
// and sends a FCM reminder to every member.
//
// Required Supabase secrets:
//   FIREBASE_SERVICE_ACCOUNT  — full service account JSON string
//
// pg_cron setup (run once in Supabase SQL editor):
// ---------------------------------------------------------------------------
// select cron.schedule(
//   'send-event-reminders',
//   '0 9 * * *',    -- 09:00 UTC every day
//   $$
//   select net.http_post(
//     url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-event-reminders',
//     headers := jsonb_build_object(
//       'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
//       'Content-Type',  'application/json'
//     ),
//     body    := '{}'::jsonb
//   );
//   $$
// );
// ---------------------------------------------------------------------------

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getAccessToken, sendFcmBatch } from '../_shared/fcm.ts';

Deno.serve(async (_req) => {
  try {
    // ── Supabase admin client (bypasses RLS) ────────────────────────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // ── FCM setup ───────────────────────────────────────────────────────────
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saJson) throw new Error('FIREBASE_SERVICE_ACCOUNT secret not set');
    const sa = JSON.parse(saJson);
    const accessToken = await getAccessToken(sa);

    // ── Find events happening tomorrow (UTC date) ───────────────────────────
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    const tomorrowDate = tomorrow.toISOString().split('T')[0]; // 'YYYY-MM-DD'

    const { data: events, error: eventsErr } = await supabase
      .from('calendar_events')
      .select('id, title, household_id, occasion')
      .eq('event_date', tomorrowDate);

    if (eventsErr) throw eventsErr;
    if (!events || events.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    let totalSent = 0;

    for (const event of events) {
      // Get all device tokens for this household via profiles → device_tokens.
      const { data: tokens, error: tokensErr } = await supabase
        .from('device_tokens')
        .select('token')
        .in(
          'user_id',
          supabase
            .from('profiles')
            .select('user_id')
            .eq('household_id', event.household_id)
        );

      if (tokensErr) {
        console.error(`[reminders] Token fetch error for household ${event.household_id}:`, tokensErr);
        continue;
      }

      const tokenList = (tokens ?? []).map((r: { token: string }) => r.token);
      if (tokenList.length === 0) continue;

      const title = '📅 Outfit reminder';
      const body = event.occasion
        ? `"${event.title}" (${event.occasion}) is tomorrow — make sure your outfit is ready!`
        : `"${event.title}" is tomorrow — make sure your outfit is ready!`;

      await sendFcmBatch(accessToken, sa.project_id, tokenList, title, body, {
        type: 'event_reminder',
        event_id: event.id,
      });

      totalSent += tokenList.length;
    }

    return new Response(JSON.stringify({ sent: totalSent }), { status: 200 });
  } catch (err) {
    console.error('[send-event-reminders] Error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
