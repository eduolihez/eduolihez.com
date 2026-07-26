// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  // IMPORTANTE: cambia esto por tu dominio real. Se usa para generar
  // las URLs canonicas, el sitemap y las etiquetas Open Graph (LinkedIn).
  site: 'https://eduolihez.com',

  // Salida 100% estatica -> genera HTML/CSS/JS en la carpeta dist/
  // que subiras por FTP a CDMON. NO necesita Node en produccion.
  output: 'static',

  // i18n nativo de Astro: espanol en "/", ingles en "/en/", catalan en "/ca/".
  i18n: {
    defaultLocale: 'es',
    locales: ['es', 'en', 'ca'],
    routing: {
      // No anade "/es" a la URL del idioma por defecto (queda mas limpio).
      prefixDefaultLocale: false,
    },
  },

  // Tailwind se engancha por PostCSS (ver postcss.config.mjs), no por una
  // integracion: @astrojs/tailwind se quedo en Astro 5 y rompia npm install.

  // CSP estricta: Astro calcula automaticamente los hashes de los scripts
  // (en linea y externos) en cada build y genera la <meta> CSP. Asi tenemos
  // script-src sin 'unsafe-inline' sin mantener hashes a mano (S6).
  security: {
    csp: {
      directives: [
        "default-src 'self'",
        "img-src 'self' data: https:",
        "font-src 'self'",
        "connect-src 'self' https://formspree.io",
        "form-action 'self' https://formspree.io",
        "base-uri 'self'",
        "object-src 'none'",
      ],
      styleDirective: {
        // Tailwind/estilos: permitimos estilos en linea (no ejecutan codigo).
        resources: ["'self'", "'unsafe-inline'"],
      },
    },
  },

  build: {
    // Genera /experiencia/index.html en vez de /experiencia.html.
    // Mas compatible con Apache/cPanel.
    format: 'directory',
  },

  // Optimizaciones para hosting compartido.
  compressHTML: true,
});
