import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock supabase before importing proxy_api (which imports supabase at module level).
vi.mock('../supabase', () => ({
  supabase: {
    auth: {
      getSession: vi.fn(),
    },
  },
}));

import { proxyList, proxyUpdate, proxyDelete } from '../proxy_api';
import { supabase } from '../supabase';

const mockGetSession = vi.mocked(supabase.auth.getSession);

beforeEach(() => {
  mockGetSession.mockResolvedValue({
    data: { session: { access_token: 'test-jwt' } },
    error: null,
  } as Awaited<ReturnType<typeof supabase.auth.getSession>>);
});

describe('proxyList', () => {
  it('returns the data array on success', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ data: [{ id: '1', name: 'Test' }] }),
    } as unknown as Response);

    const result = await proxyList('households', '');
    expect(result).toEqual([{ id: '1', name: 'Test' }]);
  });

  it('sends Authorization header with JWT', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ data: [] }),
    } as unknown as Response);
    global.fetch = fetchMock;

    await proxyList('households', '');

    const [, options] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect((options.headers as Record<string, string>)['Authorization']).toBe('Bearer test-jwt');
  });

  it('throws with server error message on non-ok response', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: () => Promise.resolve({ error: 'Forbidden' }),
    } as unknown as Response);

    await expect(proxyList('households', '')).rejects.toThrow('Forbidden');
  });

  it('throws generic message when server returns no error field', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      json: () => Promise.resolve({}),
    } as unknown as Response);

    await expect(proxyList('households', '')).rejects.toThrow('Request failed: 500');
  });
});

describe('proxyUpdate', () => {
  it('resolves on success', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ success: true }),
    } as unknown as Response);

    await expect(proxyUpdate('households', 'id-1', { name: 'Updated' })).resolves.toBeUndefined();
  });

  it('throws on error response', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: () => Promise.resolve({ error: 'Not allowed' }),
    } as unknown as Response);

    await expect(proxyUpdate('households', 'id-1', {})).rejects.toThrow('Not allowed');
  });
});

describe('proxyDelete', () => {
  it('resolves on success', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ success: true }),
    } as unknown as Response);

    await expect(proxyDelete('households', 'id-1')).resolves.toBeUndefined();
  });

  it('throws on error response', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: () => Promise.resolve({ error: 'Not allowed' }),
    } as unknown as Response);

    await expect(proxyDelete('households', 'id-1')).rejects.toThrow('Not allowed');
  });
});
