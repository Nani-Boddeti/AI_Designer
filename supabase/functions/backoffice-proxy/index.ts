// backoffice-proxy/index.ts
//
// Server-side proxy for the VibeVault web backoffice.
// The browser holds only the anon key + user JWT — the service role key
// never leaves this function, so it cannot be extracted from the JS bundle.
//
// Auth flow:
//   1. Browser signs in via supabase.auth (anon key) → gets a user JWT
//   2. Browser POSTs to this function with Authorization: Bearer <jwt>
//   3. Function verifies JWT server-side
//   4. Function checks user email against BACKOFFICE_ADMIN_EMAILS (Deno secret)
//   5. Function executes the DB operation with service role key
//
// Required Deno secrets (supabase secrets set):
//   BACKOFFICE_ADMIN_EMAILS  — comma-separated admin email allowlist
//   BACKOFFICE_ORIGIN        — deployed backoffice URL for CORS (optional, defaults to *)
//   SUPABASE_URL             — auto-injected by Supabase runtime
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected by Supabase runtime
//
// API: POST /functions/v1/backoffice-proxy
// Body: { action: 'list'|'update'|'delete', entityKey: string, ...params }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Table allowlist — entityKey sent by browser maps to real table name ───────
// The browser never sends a raw table name, only an entityKey.
// Any entityKey not in this map returns 400 — prevents arbitrary table access.
const ENTITY_TABLE_MAP: Record<string, {
  table: string;
  orderBy: string;
  searchColumn: string;
  readOnly?: boolean;
}> = {
  'households':           { table: 'households',                orderBy: 'created_at', searchColumn: 'name' },
  'profiles':             { table: 'profiles',                  orderBy: 'created_at', searchColumn: 'name' },
  'wardrobe-items':       { table: 'wardrobe_items',            orderBy: 'created_at', searchColumn: 'name' },
  'outfits':              { table: 'outfits',                   orderBy: 'created_at', searchColumn: 'name' },
  'calendar-events':      { table: 'calendar_events',           orderBy: 'event_date', searchColumn: 'title' },
  'app-config':           { table: 'app_config',                orderBy: 'id',         searchColumn: 'id' },
  'usage':                { table: 'household_usage',           orderBy: 'year_month', searchColumn: 'household_id', readOnly: true },
  'payment-transactions': { table: 'payment_transactions_view', orderBy: 'created_at', searchColumn: 'household_name', readOnly: true },
  'device-tokens':        { table: 'device_tokens',             orderBy: 'user_id',    searchColumn: 'user_id', readOnly: true },
};

// ── CORS — locked to deployed backoffice origin, * only in dev ────────────────
function corsHeaders(req: Request): Record<string, string> {
  const allowedOrigin = Deno.env.get('BACKOFFICE_ORIGIN') ?? '*';
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type',
  };
}

Deno.serve(async (req) => {
  const cors = corsHeaders(req);

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  try {
    // ── 1. JWT verification ───────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userErr } = await supabase.auth.getUser(jwt);
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    // ── 2. Admin allowlist check (server-side only — never sent to browser) ───
    const adminEmails = (Deno.env.get('BACKOFFICE_ADMIN_EMAILS') ?? '')
      .split(',')
      .map((e) => e.trim())
      .filter(Boolean);

    if (!adminEmails.includes(user.email ?? '')) {
      return new Response(JSON.stringify({ error: 'Forbidden: not an admin' }), {
        status: 403,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    // ── 3. Parse and validate request ─────────────────────────────────────────
    const body = await req.json();
    const { action, entityKey } = body;

    const entityMeta = ENTITY_TABLE_MAP[entityKey as string];
    if (!entityMeta) {
      return new Response(JSON.stringify({ error: `Unknown entityKey: ${entityKey}` }), {
        status: 400,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    // ── 4. Dispatch action ────────────────────────────────────────────────────
    if (action === 'list') {
      const search = (body.search as string | undefined)?.trim() ?? '';
      let q = supabase
        .from(entityMeta.table)
        .select('*')
        .order(entityMeta.orderBy, { ascending: false })
        .limit(200);

      if (search) {
        q = q.ilike(entityMeta.searchColumn, `%${search}%`);
      }

      const { data, error } = await q;
      if (error) throw error;

      return new Response(JSON.stringify({ data: data ?? [] }), {
        status: 200,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    if (action === 'update') {
      if (entityMeta.readOnly) {
        return new Response(JSON.stringify({ error: 'Entity is read-only' }), {
          status: 400,
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }

      const { id, patch } = body as { id: string; patch: Record<string, unknown> };
      if (!id || !patch) {
        return new Response(JSON.stringify({ error: 'id and patch are required for update' }), {
          status: 400,
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }

      const { error } = await supabase.from(entityMeta.table).update(patch).eq('id', id);
      if (error) throw error;

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    if (action === 'delete') {
      if (entityMeta.readOnly) {
        return new Response(JSON.stringify({ error: 'Entity is read-only' }), {
          status: 400,
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }

      const { id } = body as { id: string };
      if (!id) {
        return new Response(JSON.stringify({ error: 'id is required for delete' }), {
          status: 400,
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }

      const { error } = await supabase.from(entityMeta.table).delete().eq('id', id);
      if (error) throw error;

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
      status: 400,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('[backoffice-proxy] Error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
