import { supabase } from '../../lib/supabase';
import type { EntityDef } from './EntityConfig';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function listInstances(entity: EntityDef, search: string): Promise<any[]> {
  let q = supabase
    .from(entity.table)
    .select('*')
    .order(entity.orderBy, { ascending: false })
    .limit(200);

  if (search.trim()) {
    q = q.ilike(entity.searchColumn, `%${search.trim()}%`);
  }

  const { data, error } = await q;
  if (error) throw error;
  return data ?? [];
}

export async function updateInstance(
  entity: EntityDef,
  id: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const { error } = await supabase.from(entity.table).update(patch).eq('id', id);
  if (error) throw error;
}

export async function deleteInstance(entity: EntityDef, id: string): Promise<void> {
  const { error } = await supabase.from(entity.table).delete().eq('id', id);
  if (error) throw error;
}
