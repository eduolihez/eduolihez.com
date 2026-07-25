/**
 * Configuracion de Tailwind para la web de PromptMaster.
 * ---------------------------------------------------------------------------
 * PromptMaster es HTML plano dentro de /public, asi que no pasa por el
 * pipeline de Astro: su CSS se compila aparte, una sola vez, con este archivo.
 *
 * Antes la pagina cargaba https://cdn.tailwindcss.com, que compila en el
 * navegador del visitante ejecutando JavaScript de un tercero. Esto lo
 * sustituye por una hoja estatica servida desde el propio dominio.
 *
 * Regenerar (desde la raiz del repo):
 *     npm run css:promptmaster
 *
 * Vive FUERA de /public a proposito: es una herramienta de compilacion y no
 * debe acabar publicada en el servidor.
 */
module.exports = {
  content: ['./public/projects/promptmaster/index.html'],
  theme: {
    extend: {
      // Estos colores estaban en un bloque `tailwind.config` en linea dentro
      // del <head>. Al dejar de usar el CDN, viven aqui.
      colors: {
        darkBase: '#09090b',
        glassBg: 'rgba(255, 255, 255, 0.03)',
        glassBorder: 'rgba(139, 92, 246, 0.2)',
        primary: '#8b5cf6',
        secondary: '#3b82f6',
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'hero-glow':
          'conic-gradient(from 180deg at 50% 50%, #2a8af6 0deg, #a853ba 180deg, #e92a67 360deg)',
      },
    },
  },
};
