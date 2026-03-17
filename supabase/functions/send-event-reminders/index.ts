// send-event-reminders/index.ts
// Scheduled Edge Function — triggered daily by pg_cron or cron-job.org.
// Finds events happening tomorrow, collects device tokens for each household,
// and sends FCM reminders to every member.
//
// Required Supabase secrets:
//   FIREBASE_SERVICE_ACCOUNT  — full service account JSON string
//   SUPABASE_SERVICE_ROLE_KEY — auto-provided in Edge Function runtime
//
// Auth: caller must send Authorization: Bearer <SERVICE_ROLE_KEY>
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

const MAX_EVENTS = 500; // guard against timeouts at scale

Deno.serve(async (req) => {
  try {
    // ── Auth: service role key required (called by cron, not end users) ───────
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Server misconfiguration' }), { status: 500 });
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (token !== serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
    }

    // ── Supabase admin client (bypasses RLS) ──────────────────────────────────
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, serviceRoleKey);

    // ── FCM setup ─────────────────────────────────────────────────────────────
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saJson) throw new Error('FIREBASE_SERVICE_ACCOUNT secret not set');
    const sa = JSON.parse(saJson);
    const accessToken = await getAccessToken(sa);

    // ── Find events happening tomorrow — capped to avoid timeouts ─────────────
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    const tomorrowDate = tomorrow.toISOString().split('T')[0]; // 'YYYY-MM-DD'

    const { data: events, error: eventsErr } = await supabase
      .from('calendar_events')
      .select('id, title, household_id, occasion')
      .eq('event_date', tomorrowDate)
      .limit(MAX_EVENTS);

    if (eventsErr) throw eventsErr;
    if (!events || events.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    // ── Batch-fetch all memberships + tokens in 2 queries (not N queries) ─────
    const householdIds = [...new Set(events.map((e: { household_id: string }) => e.household_id))];

    const { data: memberships, error: membershipsErr } = await supabase
      .from('household_memberships')
      .select('household_id, user_id')
      .in('household_id', householdIds);

    if (membershipsErr) throw membershipsErr;

    const memberUserIds = [...new Set((memberships ?? []).map((m: { user_id: string }) => m.user_id))];

    const { data: tokenRows, error: tokensErr } = await supabase
      .from('device_tokens')
      .select('user_id, token')
      .in('user_id', memberUserIds);

    if (tokensErr) throw tokensErr;

    // Build lookup maps for O(1) access
    const tokenByUser = new Map<string, string>();
    for (const row of tokenRows ?? []) tokenByUser.set(row.user_id, row.token);

    const tokensByHousehold = new Map<string, string[]>();
    for (const m of memberships ?? []) {
      const tok = tokenByUser.get(m.user_id);
      if (!tok) continue;
      const list = tokensByHousehold.get(m.household_id) ?? [];
      list.push(tok);
      tokensByHousehold.set(m.household_id, list);
    }

    // ── Send notifications in parallel ────────────────────────────────────────
    let totalSent = 0;

    await Promise.allSettled(
      events.map(async (event: { id: string; title: string; household_id: string; occasion: string | null }) => {
        const tokenList = tokensByHousehold.get(event.household_id) ?? [];
        if (tokenList.length === 0) return;

        const body = event.occasion
          ? `"${event.title}" (${event.occasion}) is tomorrow — make sure your outfit is ready!`
          : `"${event.title}" is tomorrow — make sure your outfit is ready!`;

        await sendFcmBatch(accessToken, sa.project_id, tokenList, '📅 Outfit reminder', body, {
          type: 'event_reminder',
          event_id: event.id,
        });

        totalSent += tokenList.length;
      }),
    );

    return new Response(JSON.stringify({ sent: totalSent }), { status: 200 });
  } catch (err) {
    console.error('[send-event-reminders] Error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 });
  }
});
