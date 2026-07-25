/**
 * /sitemap.xml — mapa del sitio generado en cada compilacion.
 * ---------------------------------------------------------------------------
 * Antes era un archivo estatico en /public que habia que editar a mano (y que
 * no tenia <lastmod>, asi que Google no sabia si algo habia cambiado). Ahora
 * se genera solo con la fecha del build y las tres versiones de idioma
 * correctamente enlazadas entre si con hreflang.
 *
 * Esto es importante para el SEO multiidioma: sin los enlaces alternos,
 * Google puede tomar las versiones ES/EN/CA por contenido duplicado en vez de
 * por traducciones de la misma pagina.
 */
import type { APIRoute } from 'astro';
import { SITE } from '../config';

export const prerender = true;

// Rutas del sitio con su prioridad. La home en espanol es la principal.
const pages = [
  { path: '/', priority: '1.0', hreflang: 'es' },
  { path: '/en/', priority: '0.9', hreflang: 'en' },
  { path: '/ca/', priority: '0.9', hreflang: 'ca' },
];

export const GET: APIRoute = () => {
  const lastmod = new Date().toISOString().slice(0, 10);
  const url = (p: string) => new URL(p, SITE.domain).href;

  // Los mismos enlaces alternos se repiten en cada <url>: es lo que exige el
  // protocolo (cada pagina debe declarar a todas sus hermanas, incluida ella).
  const alternates = pages
    .map((p) => `    <xhtml:link rel="alternate" hreflang="${p.hreflang}" href="${url(p.path)}"/>`)
    .concat(`    <xhtml:link rel="alternate" hreflang="x-default" href="${url('/')}"/>`)
    .join('\n');

  const entries = pages
    .map((p) =>
      [
        '  <url>',
        `    <loc>${url(p.path)}</loc>`,
        alternates,
        `    <lastmod>${lastmod}</lastmod>`,
        '    <changefreq>weekly</changefreq>',
        `    <priority>${p.priority}</priority>`,
        '  </url>',
      ].join('\n')
    )
    .join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
${entries}
</urlset>
`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
