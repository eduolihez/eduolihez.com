import { getViteConfig } from 'astro/config';

// Reutiliza el vite.config real del proyecto (plugins, alias) via el helper
// oficial de Astro, en vez de duplicar configuracion en un archivo aparte.
//
// environment: 'jsdom' porque los scripts de cliente (blog.ts, y en el futuro
// la logica de Projects.astro/Certifications.astro si se extrae a modulos
// .ts) usan document.getElementById/fetch/DOM real. jsdom es superconjunto
// de 'node' para los tests que no tocan el DOM, asi que no hace falta un
// environment distinto por archivo.
export default getViteConfig({
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.ts'],
    setupFiles: ['src/test/setup.ts'],
  },
});
