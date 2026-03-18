import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// remove-background/index.ts
// Proxies image background removal server-side — API keys never reach the client.
// JWT auth required.
//
// Request:  POST { image_base64: string, mime_type?: string }
// Response: { image_base64: string }  (PNG)
//
// Tries REMBG_API_KEY first, falls back to REMOVE_BG_API_KEY.

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const reply = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return reply({ error: 'Unauthorized' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { data: { user }, error } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );
    if (error || !user) return reply({ error: 'Invalid token' }, 401);

    const { image_base64, mime_type = 'image/jpeg' } = await req.json();
    if (!image_base64) return reply({ error: 'image_base64 is required' }, 400);

    const imageBytes = Uint8Array.from(atob(image_base64), (c) => c.charCodeAt(0));
    const blob = new Blob([imageBytes], { type: mime_type });

    const rembgKey = Deno.env.get('REMBG_API_KEY') ?? '';
    const removeBgKey = Deno.env.get('REMOVE_BG_API_KEY') ?? '';

    let resultBuffer: ArrayBuffer | null = null;

    // Try rembg first
    if (rembgKey) {
      const form = new FormData();
      form.append('image', blob, 'upload.jpg');
      form.append('format', 'png');
      form.append('expand', 'true');

      const res = await fetch('https://api.rembg.com/rmbg', {
        method: 'POST',
        headers: { 'x-api-key': rembgKey },
        body: form,
        signal: AbortSignal.timeout(30_000),
      });
      if (res.ok) resultBuffer = await res.arrayBuffer();
    }

    // Fall back to remove.bg
    if (!resultBuffer && removeBgKey) {
      const form = new FormData();
      form.append('image_file', blob, 'upload.jpg');
      form.append('size', 'auto');

      const res = await fetch('https://api.remove.bg/v1.0/removebg', {
        method: 'POST',
        headers: { 'X-Api-Key': removeBgKey },
        body: form,
        signal: AbortSignal.timeout(30_000),
      });
      if (res.ok) resultBuffer = await res.arrayBuffer();
    }

    if (!resultBuffer) {
      return reply({ error: 'Background removal failed' }, 502);
    }

    return reply({ image_base64: arrayBufferToBase64(resultBuffer) });
  } catch (e) {
    return reply({ error: String(e) }, 500);
  }
});
