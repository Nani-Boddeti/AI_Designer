import { proxyDelete, proxyList, proxyUpdate } from '../../lib/proxy_api';
import type { EntityDef } from './EntityConfig';

// All operations go through the backoffice-proxy Edge Function.
// The browser never directly accesses Supabase tables — no service role key in bundle.

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function listInstances(entity: EntityDef, search: string): Promise<any[]> {
  return proxyList(entity.key, search);
}

export async function updateInstance(
  entity: EntityDef,
  id: string,
  patch: Record<string, unknown>,
): Promise<void> {
  return proxyUpdate(entity.key, id, patch);
}

export async function deleteInstance(entity: EntityDef, id: string): Promise<void> {
  return proxyDelete(entity.key, id);
}
