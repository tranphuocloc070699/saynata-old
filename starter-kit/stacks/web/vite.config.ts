/// <reference types="vitest/config" />
import react from '@vitejs/plugin-react'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  // In dev, /api goes to the backend, so the browser sees one origin (no CORS setup needed).
  server: { proxy: { '/api': 'http://localhost:8080' } },
  build: { sourcemap: 'hidden' }, // maps for Sentry upload, not served to users
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
  },
})
