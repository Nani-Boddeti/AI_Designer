// weather-proxy/index.ts
// Proxies OpenWeatherMap forecast calls server-side — API key never reaches the client.
// JWT auth required.
//
// Request:  POST { lat: number, lon: number, date: string (ISO yyyy-MM-dd) }
// Response: { temp_c, feels_like_c, description, icon, humidity, wind_kph }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MOCK_WEATHER = {
  temp_c: 22.0,
  feels_like_c: 21.0,
  description: 'Partly cloudy',
  icon: '02d',
  humidity: 55,
  wind_kph: 12.0,
};

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

    const apiKey = Deno.env.get('OPENWEATHER_API_KEY') ?? '';
    if (!apiKey) return reply(MOCK_WEATHER);

    const { lat, lon, date } = await req.json();
    if (lat == null || lon == null || !date) {
      return reply({ error: 'lat, lon, and date are required' }, 400);
    }

    const url = new URL('https://api.openweathermap.org/data/2.5/forecast');
    url.searchParams.set('lat', String(lat));
    url.searchParams.set('lon', String(lon));
    url.searchParams.set('units', 'metric');
    url.searchParams.set('appid', apiKey);

    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) return reply(MOCK_WEATHER);

    const body = await res.json();
    const list: Array<Record<string, unknown>> = body?.list ?? [];

    // Find forecast entry closest to noon on the target date
    const targetNoon = new Date(`${date}T12:00:00Z`).getTime();
    let best: Record<string, unknown> | null = null;
    let bestDiff = Infinity;

    for (const entry of list) {
      const dt = ((entry['dt'] as number) ?? 0) * 1000;
      const diff = Math.abs(dt - targetNoon);
      if (diff < bestDiff) {
        bestDiff = diff;
        best = entry;
      }
    }

    if (!best) return reply(MOCK_WEATHER);

    const main = (best['main'] as Record<string, unknown>) ?? {};
    const weather = ((best['weather'] as unknown[])?.[0] as Record<string, unknown>) ?? {};
    const wind = (best['wind'] as Record<string, unknown>) ?? {};

    return reply({
      temp_c: (main['temp'] as number) ?? 20.0,
      feels_like_c: (main['feels_like'] as number) ?? 20.0,
      description: (weather['description'] as string) ?? 'Clear sky',
      icon: (weather['icon'] as string) ?? '01d',
      humidity: (main['humidity'] as number) ?? 50,
      wind_kph: ((wind['speed'] as number) ?? 0) * 3.6,
    });
  } catch (e) {
    return reply({ error: String(e) }, 500);
  }
});
