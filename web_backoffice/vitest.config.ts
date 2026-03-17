import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    env: {
      VITE_BACKOFFICE_PROXY_URL: 'http://localhost/proxy',
      VITE_SUPABASE_URL: 'http://localhost',
      VITE_SUPABASE_ANON_KEY: 'anon-key-stub',
    },
  },
});
