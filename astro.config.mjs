// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

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

  // Tailwind 4 entra como plugin de Vite (no como integracion de Astro y no
  // por PostCSS). @astrojs/tailwind se quedo en Astro 5 y rompia npm install;
  // el plugin oficial no depende de la version de Astro y ademas compila con
  // el motor Oxide, que es bastante mas rapido que el pipeline de PostCSS.
  // El tema vive ahora en src/styles/global.css (@theme), no en un JS aparte.
  vite: {
    plugins: [tailwindcss()],
  },

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
    // El CSS del sitio son ~12KB (todo Tailwind incluido) -- por encima del
    // umbral que el modo 'auto' de Astro inlinea, asi que se serviria como
    // <link> externo que bloquea el primer render (100-300ms medidos en
    // PageSpeed Insights). 'always' lo mete directo en un <style> del HTML:
    // sin peticion extra, sin bloqueo. El sitio es pequeno (una decena de
    // paginas), asi que perder el cacheo entre paginas de un CSS compartido
    // pesa menos que el round-trip que se ahorra en cada una.
    inlineStylesheets: 'always',
  },

  // Optimizaciones para hosting compartido.
  compressHTML: true,
});
