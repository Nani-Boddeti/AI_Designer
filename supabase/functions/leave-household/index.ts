// leave-household/index.ts
//
// ⚠️  DEPRECATED — NOT IN USE. Flutter uses leave_household() Postgres RPC instead.
// This Edge Function had a bug: it wrote active_household_id to the profiles
// table but that column lives on user_preferences.
//
// Kept deployed to return 410 Gone for any accidental callers.

Deno.serve((_req) => {
  return new Response(
    JSON.stringify({ error: 'This endpoint is deprecated. Use the leave_household RPC.' }),
    { status: 410, headers: { 'Content-Type': 'application/json' } },
  );
});
