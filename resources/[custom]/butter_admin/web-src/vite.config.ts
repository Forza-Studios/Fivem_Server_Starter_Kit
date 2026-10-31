import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: '../web',
    emptyOutDir: true,
  },
  server: {
    port: 3000,
    host: '0.0.0.0',
    // The browser mocks read the resource's locales/en.json.
    fs: { allow: ['..'] },
  },
});
