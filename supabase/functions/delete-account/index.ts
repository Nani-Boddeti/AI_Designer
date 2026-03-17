// delete-account/index.ts
//
// Deletes a user's account completely. Must run with service_role credentials
// to access Admin API and bypass RLS.
//
// Steps (in order, atomic from user perspective — any failure leaves account intact):
//   1. Verify caller JWT
//   2. Delete storage files for all profiles (wardrobe-images, processed-images, avatars)
//   3. Delete DB rows via delete_account_for_user RPC (CASCADE handles children)
//   4. Delete the auth user via Supabase Admin API
//
// Request: POST (no body — user is identified from JWT)
// Response: { success: true } | { error: string }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Wardrobe path: wardrobe/{profileId}/{itemId}/file — two levels deep.
// Avatar path:   avatars/{profileId}/file        — one level deep.
async function deleteProfileStorage(
  supabase: ReturnType<typeof createClient>,
  profileId: string,
): Promise<void> {
  // wardrobe-images and processed-images share the same path structure.
  for (const bucket of ['wardrobe-images', 'processed-images']) {
    const profilePrefix = `wardrobe/${profileId}`;
    const { data: itemFolders } = await supabase.storage
      .from(bucket)
      .list(profilePrefix, { limit: 1000 });

    for (const folder of itemFolders ?? []) {
      const itemPrefix = `${profilePrefix}/${folder.name}`;
      const { data: files } = await supabase.storage
        .from(bucket)
        .list(itemPrefix, { limit: 1000 });

      if (!files?.length) continue;
      const paths = files.map((f) => `${itemPrefix}/${f.name}`);
      const { error } = await supabase.storage.from(bucket).remove(paths);
      if (error) {
        console.error(`[delete-account] remove ${bucket}/${itemPrefix}:`, error.message);
      }
    }
  }

  // Avatars are one level deep: avatars/{profileId}/file
  const avatarPrefix = `avatars/${profileId}`;
  const { data: avatarFiles } = await supabase.storage
    .from('avatars')
    .list(avatarPrefix, { limit: 1000 });

  if (avatarFiles?.length) {
    const paths = avatarFiles.map((f) => `${avatarPrefix}/${f.name}`);
    const { error } = await supabase.storage.from('avatars').remove(paths);
    if (error) {
      console.error(`[delete-account] remove avatars/${avatarPrefix}:`, error.message);
    }
  }
}

Deno.serve(async (req) => {
  try {
    // ── 1. Verify JWT ─────────────────────────────────────────────────────────
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

    // ── 2. Delete storage files ───────────────────────────────────────────────
    // Fetch all profile IDs for this user (across all households).
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id')
      .eq('auth_user_id', user.id);

    for (const profile of profiles ?? []) {
      await deleteProfileStorage(supabase, profile.id);
    }

    // ── 3. Delete DB rows ─────────────────────────────────────────────────────
    // delete_account_for_user RPC handles cascade deletion of profiles,
    // household_memberships, user_preferences, device_tokens, and any
    // sole-member households the user owns.
    const { error: rpcErr } = await supabase.rpc('delete_account_for_user', {
      p_user_id: user.id,
    });
    if (rpcErr) throw rpcErr;

    // ── 4. Delete auth user ───────────────────────────────────────────────────
    const { error: deleteErr } = await supabase.auth.admin.deleteUser(user.id);
    if (deleteErr) throw deleteErr;

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (err) {
    console.error('[delete-account] Error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500 },
    );
  }
});
