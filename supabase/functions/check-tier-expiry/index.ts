// check-tier-expiry/index.ts
// Scheduled Edge Function — triggered daily via cron-job.org HTTP POST.
// Finds all households whose paid tier has expired and downgrades them to 'free'.
//
// cron-job.org setup:
//   URL:    https://<PROJECT_REF>.supabase.co/functions/v1/check-tier-expiry
//   Method: POST
//   Header: Authorization: Bearer <SERVICE_ROLE_KEY>
//   Schedule: 00:05 UTC daily

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Server misconfiguration: missing service role key' }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (token !== serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
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
      { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[check-tier-expiry] Error:', err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }
});
