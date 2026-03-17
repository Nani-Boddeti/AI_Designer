-- storage_rls_fix.sql
-- Run in Supabase dashboard → SQL Editor.
--
-- Fixes overly permissive storage SELECT policies.
-- Previous policies only checked bucket_id — any authenticated user could
-- generate signed URLs for objects belonging to other households.
--
-- New policies scope access to profiles in the caller's current household,
-- using the profileId embedded in the storage path at position 2:
--   wardrobe-images  → wardrobe/{profileId}/{itemId}/original.jpg
--   processed-images → wardrobe/{profileId}/{itemId}/processed.png
--   avatars          → avatars/{profileId}/avatar.jpg

-- ── Drop old permissive policies ──────────────────────────────────────────────
DROP POLICY IF EXISTS "wardrobe_images_select"   ON storage.objects;
DROP POLICY IF EXISTS "wardrobe_images_insert"   ON storage.objects;
DROP POLICY IF EXISTS "wardrobe_images_update"   ON storage.objects;
DROP POLICY IF EXISTS "wardrobe_images_delete"   ON storage.objects;

DROP POLICY IF EXISTS "processed_images_select"  ON storage.objects;
DROP POLICY IF EXISTS "processed_images_insert"  ON storage.objects;
DROP POLICY IF EXISTS "processed_images_update"  ON storage.objects;
DROP POLICY IF EXISTS "processed_images_delete"  ON storage.objects;

DROP POLICY IF EXISTS "avatars_select"           ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert"           ON storage.objects;
DROP POLICY IF EXISTS "avatars_update"           ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete"           ON storage.objects;

-- ── wardrobe-images ───────────────────────────────────────────────────────────
CREATE POLICY "wardrobe_images_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'wardrobe-images'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "wardrobe_images_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'wardrobe-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "wardrobe_images_update" ON storage.objects FOR UPDATE USING (
  bucket_id = 'wardrobe-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "wardrobe_images_delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'wardrobe-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);

-- ── processed-images ──────────────────────────────────────────────────────────
CREATE POLICY "processed_images_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'processed-images'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "processed_images_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'processed-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "processed_images_update" ON storage.objects FOR UPDATE USING (
  bucket_id = 'processed-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "processed_images_delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'processed-images'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);

-- ── avatars ───────────────────────────────────────────────────────────────────
CREATE POLICY "avatars_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'avatars'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "avatars_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'avatars'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "avatars_update" ON storage.objects FOR UPDATE USING (
  bucket_id = 'avatars'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
CREATE POLICY "avatars_delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'avatars'
  AND auth.role() = 'authenticated'
  AND split_part(name, '/', 2)::uuid IN (
    SELECT id FROM profiles WHERE household_id = current_household_id()
  )
);
