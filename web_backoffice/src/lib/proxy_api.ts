import { supabase } from './supabase';

const PROXY_URL = import.meta.env.VITE_BACKOFFICE_PROXY_URL as string;

async function proxyRequest<T>(body: object): Promise<T> {
  const { data: sessionData } = await supabase.auth.getSession();
  const jwt = sessionData.session?.access_token;

  const res = await fetch(PROXY_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(jwt ? { Authorization: `Bearer ${jwt}` } : {}),
    },
    body: JSON.stringify(body),
  });

  const json = await res.json();
  if (!res.ok) throw new Error(json.error ?? `Request failed: ${res.status}`);
  return json as T;
}

export async function proxyList(entityKey: string, search: string): Promise<Record<string, unknown>[]> {
  const result = await proxyRequest<{ data: Record<string, unknown>[] }>({ action: 'list', entityKey, search });
  return result.data;
}

export async function proxyUpdate(entityKey: string, id: string, patch: Record<string, unknown>): Promise<void> {
  await proxyRequest<{ success: true }>({ action: 'update', entityKey, id, patch });
}

export async function proxyDelete(entityKey: string, id: string): Promise<void> {
  await proxyRequest<{ success: true }>({ action: 'delete', entityKey, id });
}
