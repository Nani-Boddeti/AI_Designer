// check-tier-expiry/index.ts
// Scheduled Edge Function — triggered daily via cron-job.org HTTP POST.
// Finds all households whose paid tier has expired and downgrades them to 'free'.
//
// This endpoint is NOT browser-facing — no CORS headers needed.
//
// cron-job.org setup:
//   URL:    https://<PROJECT_REF>.supabase.co/functions/v1/check-tier-expiry
//   Method: POST
//   Header: Authorization: Bearer <SERVICE_ROLE_KEY>
//   Schedule: 00:05 UTC daily

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const JSON_HEADERS = { 'Content-Type': 'application/json' };

Deno.serve(async (req) => {
  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Server misconfiguration' }),
        { status: 500, headers: JSON_HEADERS },
      );
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (token !== serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: JSON_HEADERS },
      );
    }

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, serviceRoleKey);

    const { data, error } = await supabase
      .from('households')
      .update({ tier: 'free', tier_expires_at: null })
      .neq('tier', 'free')
      .lt('tier_expires_at', new Date().toISOString())
      .select('id');

    if (error) throw error;

    const count = data?.length ?? 0;
    console.log(`[check-tier-expiry] Downgraded ${count} household(s) to free tier.`);

    return new Response(
      JSON.stringify({ downgraded: count, checkedAt: new Date().toISOString() }),
      { status: 200, headers: JSON_HEADERS },
    );
  } catch (err) {
    console.error('[check-tier-expiry] Error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: JSON_HEADERS },
    );
  }
});
