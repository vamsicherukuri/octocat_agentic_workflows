import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5137,
    host: '0.0.0.0',
    strictPort: true,
  },
  preview: {
    port: 8080,
    host: '0.0.0.0',
    allowedHosts: ['localhost', '127.0.0.1', 'octocat-supply-frontend.azurewebsites.net'],
  },
  define: {
    'process.env.CODESPACE_NAME': JSON.stringify(process.env.CODESPACE_NAME),
  },
});
