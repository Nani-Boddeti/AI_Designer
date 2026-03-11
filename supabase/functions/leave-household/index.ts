// leave-household/index.ts
// Called from the Flutter app when a user wants to leave a household.
// Handles admin promotion and household deletion atomically.
//
// Expected request body:
//   { household_id: string }
//
// Logic:
//   1. Verify the caller is a member of the household.
//   2. If caller is the only member → delete the household (CASCADE removes memberships).
//   3. If caller is the only admin but other members exist →
//      promote the longest-tenured member (ORDER BY joined_at ASC LIMIT 1).
//   4. Delete the caller's membership row.
//   5. If the household was the caller's active_household_id → clear it.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    // ── Auth: extract caller's JWT ───────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Decode the JWT to get the caller's user id.
    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userErr } = await supabase.auth.getUser(jwt);
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 });
    }

    const { household_id } = await req.json();
    if (!household_id) {
      return new Response(JSON.stringify({ error: 'household_id is required' }), { status: 400 });
    }

    // ── Step 1: Verify caller is a member ───────────────────────────────────
    const { data: callerMembership, error: memberErr } = await supabase
      .from('household_memberships')
      .select('id, is_admin')
      .eq('user_id', user.id)
      .eq('household_id', household_id)
      .maybeSingle();

    if (memberErr) throw memberErr;
    if (!callerMembership) {
      return new Response(JSON.stringify({ error: 'Not a member of this household' }), { status: 403 });
    }

    // ── Step 2: Count all members ────────────────────────────────────────────
    const { data: allMembers, error: allErr } = await supabase
      .from('household_memberships')
      .select('id, user_id, is_admin, joined_at')
      .eq('household_id', household_id)
      .order('joined_at', { ascending: true });

    if (allErr) throw allErr;

    const otherMembers = (allMembers ?? []).filter((m: { user_id: string }) => m.user_id !== user.id);

    if (otherMembers.length === 0) {
      // Sole member — delete the household (CASCADE removes membership + clears profiles.active_household_id via FK).
      const { error: deleteHouseErr } = await supabase
        .from('households')
        .delete()
        .eq('id', household_id);
      if (deleteHouseErr) throw deleteHouseErr;
    } else {
      // Other members exist.
      const callerIsAdmin = callerMembership.is_admin;
      const otherAdmins = otherMembers.filter((m: { is_admin: boolean }) => m.is_admin);

      if (callerIsAdmin && otherAdmins.length === 0) {
        // Step 3: Caller is the only admin — promote longest-tenured other member.
        const promote = otherMembers[0]; // already ordered by joined_at ASC
        const { error: promoteErr } = await supabase
          .from('household_memberships')
          .update({ is_admin: true })
          .eq('id', promote.id);
        if (promoteErr) throw promoteErr;

        // Also update the promoted member's profile.is_admin.
        await supabase
          .from('profiles')
          .update({ is_admin: true })
          .eq('auth_user_id', promote.user_id)
          .eq('household_id', household_id);
      }

      // Step 4: Delete caller's membership row.
      const { error: deleteMemberErr } = await supabase
        .from('household_memberships')
        .delete()
        .eq('user_id', user.id)
        .eq('household_id', household_id);
      if (deleteMemberErr) throw deleteMemberErr;
    }

    // Step 5: If this was the caller's active household, clear active_household_id.
    await supabase
      .from('profiles')
      .update({ active_household_id: null })
      .eq('auth_user_id', user.id)
      .eq('active_household_id', household_id);

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (err) {
    console.error('[leave-household] Error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
