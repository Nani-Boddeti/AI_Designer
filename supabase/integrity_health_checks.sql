-- ---------------------------------------------------------------------------
-- Integrity Health Checks (read-only)
-- ---------------------------------------------------------------------------
-- Purpose:
--   Lightweight diagnostics to detect data consistency drift without schema
--   changes. Safe to run anytime in Supabase SQL Editor.
--
-- Output:
--   One row per check with:
--     - check_name
--     - severity
--     - status (OK | ALERT)
--     - anomaly_count
--     - sample (up to 10 IDs/rows)
--   Plus summary columns repeated on each row:
--     - failing_checks
--     - total_checks
--
-- Usage:
--   1) Open Supabase Dashboard -> SQL Editor
--   2) Paste this file and run
--   3) Investigate rows where status = 'ALERT'
-- ---------------------------------------------------------------------------

WITH anomalies AS (
  -- -------------------------------------------------------------------------
  -- Null critical FKs
  -- -------------------------------------------------------------------------
  SELECT
    'profiles_null_household_id'::text AS check_name,
    'high'::text AS severity,
    2 AS severity_rank,
    COUNT(*)::bigint AS anomaly_count,
    COALESCE(jsonb_agg(id) FILTER (WHERE rn <= 10), '[]'::jsonb) AS sample
  FROM (
    SELECT id, row_number() OVER (ORDER BY created_at DESC NULLS LAST, id) rn
    FROM profiles
    WHERE household_id IS NULL
  ) q

  UNION ALL

  SELECT
    'wardrobe_items_null_profile_id',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(jsonb_agg(id) FILTER (WHERE rn <= 10), '[]'::jsonb)
  FROM (
    SELECT id, row_number() OVER (ORDER BY created_at DESC NULLS LAST, id) rn
    FROM wardrobe_items
    WHERE profile_id IS NULL
  ) q

  UNION ALL

  SELECT
    'outfits_null_profile_id',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(jsonb_agg(id) FILTER (WHERE rn <= 10), '[]'::jsonb)
  FROM (
    SELECT id, row_number() OVER (ORDER BY created_at DESC NULLS LAST, id) rn
    FROM outfits
    WHERE profile_id IS NULL
  ) q

  UNION ALL

  SELECT
    'calendar_events_null_household_id',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(jsonb_agg(id) FILTER (WHERE rn <= 10), '[]'::jsonb)
  FROM (
    SELECT id, row_number() OVER (ORDER BY created_at DESC NULLS LAST, id) rn
    FROM calendar_events
    WHERE household_id IS NULL
  ) q

  -- -------------------------------------------------------------------------
  -- Orphan FK targets
  -- -------------------------------------------------------------------------
  UNION ALL

  SELECT
    'profiles_orphan_household_fk',
    'critical',
    1,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('profile_id', id, 'household_id', household_id)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      p.id,
      p.household_id,
      row_number() OVER (ORDER BY p.created_at DESC NULLS LAST, p.id) rn
    FROM profiles p
    LEFT JOIN households h ON h.id = p.household_id
    WHERE p.household_id IS NOT NULL
      AND h.id IS NULL
  ) q

  UNION ALL

  SELECT
    'wardrobe_items_orphan_profile_fk',
    'critical',
    1,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('item_id', id, 'profile_id', profile_id)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      wi.id,
      wi.profile_id,
      row_number() OVER (ORDER BY wi.created_at DESC NULLS LAST, wi.id) rn
    FROM wardrobe_items wi
    LEFT JOIN profiles p ON p.id = wi.profile_id
    WHERE wi.profile_id IS NOT NULL
      AND p.id IS NULL
  ) q

  UNION ALL

  SELECT
    'outfits_orphan_profile_fk',
    'critical',
    1,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('outfit_id', id, 'profile_id', profile_id)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      o.id,
      o.profile_id,
      row_number() OVER (ORDER BY o.created_at DESC NULLS LAST, o.id) rn
    FROM outfits o
    LEFT JOIN profiles p ON p.id = o.profile_id
    WHERE o.profile_id IS NOT NULL
      AND p.id IS NULL
  ) q

  UNION ALL

  SELECT
    'calendar_events_orphan_household_fk',
    'critical',
    1,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('event_id', id, 'household_id', household_id)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      ce.id,
      ce.household_id,
      row_number() OVER (ORDER BY ce.created_at DESC NULLS LAST, ce.id) rn
    FROM calendar_events ce
    LEFT JOIN households h ON h.id = ce.household_id
    WHERE ce.household_id IS NOT NULL
      AND h.id IS NULL
  ) q

  -- -------------------------------------------------------------------------
  -- Membership/profile consistency
  -- -------------------------------------------------------------------------
  UNION ALL

  SELECT
    'auth_profiles_missing_membership',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'profile_id', id,
          'auth_user_id', auth_user_id,
          'household_id', household_id
        )
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      p.id,
      p.auth_user_id,
      p.household_id,
      row_number() OVER (ORDER BY p.created_at DESC NULLS LAST, p.id) rn
    FROM profiles p
    WHERE p.auth_user_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM household_memberships hm
        WHERE hm.user_id = p.auth_user_id
          AND hm.household_id = p.household_id
      )
  ) q

  UNION ALL

  SELECT
    'memberships_missing_auth_profile',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('user_id', user_id, 'household_id', household_id)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      hm.user_id,
      hm.household_id,
      row_number() OVER (ORDER BY hm.joined_at DESC NULLS LAST, hm.id) rn
    FROM household_memberships hm
    WHERE NOT EXISTS (
      SELECT 1
      FROM profiles p
      WHERE p.auth_user_id = hm.user_id
        AND p.household_id = hm.household_id
    )
  ) q

  UNION ALL

  SELECT
    'duplicate_auth_profile_per_household',
    'critical',
    1,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'auth_user_id', auth_user_id,
          'household_id', household_id,
          'rows', row_count
        )
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      auth_user_id,
      household_id,
      COUNT(*) AS row_count,
      row_number() OVER (ORDER BY COUNT(*) DESC, auth_user_id, household_id) rn
    FROM profiles
    WHERE auth_user_id IS NOT NULL
    GROUP BY auth_user_id, household_id
    HAVING COUNT(*) > 1
  ) q

  -- -------------------------------------------------------------------------
  -- Outfits JSON integrity
  -- -------------------------------------------------------------------------
  UNION ALL

  SELECT
    'outfits_item_ids_not_array',
    'medium',
    3,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('outfit_id', id, 'item_ids_type', item_ids_type)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      o.id,
      jsonb_typeof(o.item_ids) AS item_ids_type,
      row_number() OVER (ORDER BY o.created_at DESC NULLS LAST, o.id) rn
    FROM outfits o
    WHERE o.item_ids IS NULL
       OR jsonb_typeof(o.item_ids) <> 'array'
  ) q

  UNION ALL

  SELECT
    'outfits_reference_missing_wardrobe_item',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('outfit_id', outfit_id, 'missing_item_id', item_id)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      o.id AS outfit_id,
      e.item_id,
      row_number() OVER (ORDER BY o.created_at DESC NULLS LAST, o.id) rn
    FROM outfits o
    CROSS JOIN LATERAL (
      SELECT value AS item_id
      FROM jsonb_array_elements_text(
        CASE WHEN jsonb_typeof(o.item_ids) = 'array' THEN o.item_ids ELSE '[]'::jsonb END
      )
    ) e
    LEFT JOIN wardrobe_items wi ON wi.id::text = e.item_id
    WHERE wi.id IS NULL
  ) q

  UNION ALL

  SELECT
    'outfits_reference_item_from_other_profile',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'outfit_id', outfit_id,
          'outfit_profile_id', outfit_profile_id,
          'item_id', item_id,
          'item_profile_id', item_profile_id
        )
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      o.id AS outfit_id,
      o.profile_id AS outfit_profile_id,
      wi.id::text AS item_id,
      wi.profile_id AS item_profile_id,
      row_number() OVER (ORDER BY o.created_at DESC NULLS LAST, o.id) rn
    FROM outfits o
    CROSS JOIN LATERAL (
      SELECT value AS item_id
      FROM jsonb_array_elements_text(
        CASE WHEN jsonb_typeof(o.item_ids) = 'array' THEN o.item_ids ELSE '[]'::jsonb END
      )
    ) e
    JOIN wardrobe_items wi ON wi.id::text = e.item_id
    WHERE wi.profile_id IS DISTINCT FROM o.profile_id
  ) q

  -- -------------------------------------------------------------------------
  -- Calendar assignment JSON integrity
  -- -------------------------------------------------------------------------
  UNION ALL

  SELECT
    'calendar_outfit_assignments_not_object',
    'medium',
    3,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object('event_id', id, 'type', assign_type)
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      ce.id,
      jsonb_typeof(ce.outfit_assignments) AS assign_type,
      row_number() OVER (ORDER BY ce.created_at DESC NULLS LAST, ce.id) rn
    FROM calendar_events ce
    WHERE ce.outfit_assignments IS NULL
       OR jsonb_typeof(ce.outfit_assignments) <> 'object'
  ) q

  UNION ALL

  SELECT
    'calendar_assignment_profile_not_in_household',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'event_id', event_id,
          'household_id', household_id,
          'profile_id', profile_id
        )
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      ce.id AS event_id,
      ce.household_id,
      kv.key AS profile_id,
      row_number() OVER (ORDER BY ce.created_at DESC NULLS LAST, ce.id) rn
    FROM calendar_events ce
    CROSS JOIN LATERAL jsonb_each_text(
      CASE WHEN jsonb_typeof(ce.outfit_assignments) = 'object'
           THEN ce.outfit_assignments ELSE '{}'::jsonb END
    ) kv
    LEFT JOIN profiles p
      ON p.id::text = kv.key
     AND p.household_id = ce.household_id
    WHERE p.id IS NULL
  ) q

  UNION ALL

  SELECT
    'calendar_assignment_outfit_missing_or_mismatch',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'event_id', event_id,
          'profile_id', profile_id,
          'outfit_id', outfit_id
        )
      ) FILTER (WHERE rn <= 10),
      '[]'::jsonb
    )
  FROM (
    SELECT
      ce.id AS event_id,
      kv.key AS profile_id,
      kv.value AS outfit_id,
      row_number() OVER (ORDER BY ce.created_at DESC NULLS LAST, ce.id) rn
    FROM calendar_events ce
    CROSS JOIN LATERAL jsonb_each_text(
      CASE WHEN jsonb_typeof(ce.outfit_assignments) = 'object'
           THEN ce.outfit_assignments ELSE '{}'::jsonb END
    ) kv
    LEFT JOIN outfits o ON o.id::text = kv.value
    LEFT JOIN profiles po ON po.id = o.profile_id
    WHERE o.id IS NULL
       OR o.profile_id::text <> kv.key
       OR po.household_id IS DISTINCT FROM ce.household_id
  ) q

  -- -------------------------------------------------------------------------
  -- Storage path consistency (best-effort)
  -- -------------------------------------------------------------------------
  UNION ALL

  SELECT
    'storage_wardrobe_object_missing_item_row',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(jsonb_agg(name) FILTER (WHERE rn <= 10), '[]'::jsonb)
  FROM (
    SELECT
      so.name,
      row_number() OVER (ORDER BY so.created_at DESC NULLS LAST, so.name) rn
    FROM storage.objects so
    LEFT JOIN wardrobe_items wi ON wi.id::text = split_part(so.name, '/', 3)
    WHERE so.bucket_id = 'wardrobe-images'
      AND so.name LIKE 'wardrobe/%/%/%'
      AND wi.id IS NULL
  ) q

  UNION ALL

  SELECT
    'storage_processed_object_missing_item_row',
    'high',
    2,
    COUNT(*)::bigint,
    COALESCE(jsonb_agg(name) FILTER (WHERE rn <= 10), '[]'::jsonb)
  FROM (
    SELECT
      so.name,
      row_number() OVER (ORDER BY so.created_at DESC NULLS LAST, so.name) rn
    FROM storage.objects so
    LEFT JOIN wardrobe_items wi ON wi.id::text = split_part(so.name, '/', 3)
    WHERE so.bucket_id = 'processed-images'
      AND so.name LIKE 'wardrobe/%/%/%'
      AND wi.id IS NULL
  ) q
)
SELECT
  check_name,
  severity,
  CASE WHEN anomaly_count > 0 THEN 'ALERT' ELSE 'OK' END AS status,
  anomaly_count,
  sample,
  SUM((anomaly_count > 0)::int) OVER () AS failing_checks,
  COUNT(*) OVER () AS total_checks
FROM anomalies
ORDER BY severity_rank, check_name;
