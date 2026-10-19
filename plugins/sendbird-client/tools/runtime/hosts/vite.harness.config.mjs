// Vite config the runtime harness uses for a React project that has none (the e2e fixtures
// type-check only). Serves RT_APP_ROOT with the React plugin; the project's own files are unchanged.
import react from '@vitejs/plugin-react';

export default {
  root: process.env.RT_APP_ROOT,
  plugins: [react()],
  clearScreen: false,
  server: { hmr: false },
};
