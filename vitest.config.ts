import { getViteConfig } from 'astro/config';

// Reutiliza el vite.config real del proyecto (plugins, alias) via el helper
// oficial de Astro, en vez de duplicar configuracion en un archivo aparte.
export default getViteConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});
