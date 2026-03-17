import { createClient } from '@supabase/supabase-js';

// Anon key only — safe to expose in browser bundle.
// All DB operations go through backoffice-proxy Edge Function (service role stays server-side).
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL as string,
  import.meta.env.VITE_SUPABASE_ANON_KEY as string,
);
