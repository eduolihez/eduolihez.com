/**
 * /sitemap.xml — mapa del sitio generado en cada compilacion.
 * ---------------------------------------------------------------------------
 * Se genera solo con la fecha del build, asi que nunca se queda obsoleto.
 *
 * Contiene DOS tipos de pagina, que se tratan distinto a proposito:
 *
 *  1. PAGINAS TRADUCIDAS (portfolio y "sobre esta web"). Cada una declara sus
 *     hermanas con <xhtml:link hreflang>. Sin eso, Google puede tomar las
 *     versiones ES/EN/CA por contenido duplicado en vez de por traducciones.
 *
 *  2. PAGINAS DE PROYECTO (/projects/...). Existen en UN solo idioma, asi que
 *     no llevan alternos: declarar un hreflang que no existe es un error que
 *     Search Console reporta.
 *
 * Aqui SOLO van URLs indexables (200 + sin noindex). Incluir una pagina
 * noindex en el sitemap es contradictorio y Search Console lo marca como
 * "URL enviada marcada como noindex".
 */
import type { APIRoute } from 'astro';
import { SITE } from '../config';

export const prerender = true;

/** Grupos de paginas traducidas: las tres versiones son la misma pagina. */
const translatedGroups: { paths: Record<'es' | 'en' | 'ca', string>; priority: string }[] = [
  {
    // Portfolio principal.
    paths: { es: '/', en: '/en/', ca: '/ca/' },
    priority: '1.0',
  },
  {
    // "Sobre esta web": faltaba por completo en el sitemap anterior.
    paths: {
      es: '/sobre-esta-web/',
      en: '/en/about-this-website/',
      ca: '/ca/sobre-aquesta-web/',
    },
    priority: '0.5',
  },
];

/**
 * Paginas de proyecto publicadas bajo /projects/.
 *
 * SOLO van URLs canonicas e indexables. Quedan fuera a proposito
 * uninstall.html y las plantillas de demostracion de Zeora, marcadas noindex.
 *
 * BadaVeu y Mes Badalona se retiraron del sitio: sus URLs responden 410 Gone
 * desde el .htaccess.
 */
const projectPages: { path: string; priority: string }[] = [
  // Indice de proyectos: concentrador de enlaces hacia los seis.
  { path: '/projects/', priority: '0.7' },
  { path: '/projects/fluence/', priority: '0.8' },
  { path: '/projects/fluence/privacy.html', priority: '0.3' },
  { path: '/projects/fluence/terms.html', priority: '0.3' },
  { path: '/projects/fluence/disclaimer.html', priority: '0.3' },
  { path: '/projects/followguard/', priority: '0.8' },
  { path: '/projects/passwdcentinel/', priority: '0.8' },
  { path: '/projects/passwdcentinel/politica.html', priority: '0.3' },
  { path: '/projects/promptmaster/', priority: '0.8' },
  { path: '/projects/promptmaster/privacy.html', priority: '0.3' },
  { path: '/projects/zeora/', priority: '0.8' },
];

export const GET: APIRoute = () => {
  const lastmod = new Date().toISOString().slice(0, 10);
  const url = (p: string) => new URL(p, SITE.domain).href;

  const entry = (loc: string, priority: string, changefreq: string, alternates = '') =>
    [
      '  <url>',
      `    <loc>${loc}</loc>`,
      ...(alternates ? [alternates] : []),
      `    <lastmod>${lastmod}</lastmod>`,
      `    <changefreq>${changefreq}</changefreq>`,
      `    <priority>${priority}</priority>`,
      '  </url>',
    ].join('\n');

  // --- 1. Paginas traducidas -------------------------------------------------
  const translated = translatedGroups.flatMap((group) => {
    // El protocolo exige que cada pagina declare a TODAS sus hermanas,
    // incluida ella misma, y un x-default.
    const alternates = (['es', 'en', 'ca'] as const)
      .map(
        (l) =>
          `    <xhtml:link rel="alternate" hreflang="${l}" href="${url(group.paths[l])}"/>`
      )
      .concat(`    <xhtml:link rel="alternate" hreflang="x-default" href="${url(group.paths.es)}"/>`)
      .join('\n');

    return (['es', 'en', 'ca'] as const).map((l) =>
      entry(url(group.paths[l]), l === 'es' ? group.priority : '0.9', 'weekly', alternates)
    );
  });

  // --- 2. Paginas de proyecto (un solo idioma, sin alternos) ------------------
  const projects = projectPages.map((p) => entry(url(p.path), p.priority, 'monthly'));

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
${[...translated, ...projects].join('\n')}
</urlset>
`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
