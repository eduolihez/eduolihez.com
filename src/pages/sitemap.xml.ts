/**
 * /sitemap.xml — mapa del sitio generado en cada compilacion.
 * ---------------------------------------------------------------------------
 * Contiene DOS tipos de pagina, que se tratan distinto a proposito:
 *
 *  1. PAGINAS TRADUCIDAS (portfolio y "sobre esta web"). Cada una declara sus
 *     hermanas con <xhtml:link hreflang>. Sin eso, Google puede tomar las
 *     versiones ES/EN/CA por contenido duplicado en vez de por traducciones.
 *
 *  2. PAGINAS DE UN SOLO IDIOMA (/projects/..., /blog/). No llevan alternos:
 *     declarar un hreflang que no existe es un error que Search Console
 *     reporta. El indice del blog vivio antes en el grupo 1 con hermanas en
 *     /en/blog/ y /ca/blog/, pero esas dos rutas ahora redirigen a la home de
 *     su idioma (server/.htaccess) al no tener articulos todavia -- declarar
 *     un hreflang que redirige en vez de servir contenido equivalente es
 *     exactamente el error que este comentario advierte, asi que /blog/ paso
 *     a este segundo grupo el dia que se anadio esa redireccion.
 *
 * Aqui SOLO van URLs indexables (200 + sin noindex). Incluir una pagina
 * noindex en el sitemap es contradictorio y Search Console lo marca como
 * "URL enviada marcada como noindex".
 *
 * `priority` y `changefreq` NO se emiten: Google los ignora desde hace anos
 * (confirmado por varios empleados de Search). `lastmod` si lo lee, asi que
 * se calcula con la fecha real del ultimo commit que toco los archivos de
 * cada pagina en vez de la fecha del build -- si no, cada URL "cambia" en
 * cada deploy aunque su contenido lleve meses igual, y ese ruido le resta
 * credibilidad a la senal justo cuando si cambia algo de verdad.
 */
import type { APIRoute } from 'astro';
import { execFileSync } from 'node:child_process';
import { SITE } from '../config';

export const prerender = true;

/** Fecha del ultimo commit que toco alguno de estos paths, formato YYYY-MM-DD. */
function gitLastMod(paths: string[]): string {
  try {
    const out = execFileSync(
      'git',
      ['log', '-1', '--format=%cI', '--', ...paths],
      { cwd: process.cwd(), encoding: 'utf-8' }
    ).trim();
    if (out) return out.slice(0, 10);
  } catch {
    // Sin .git (algunos entornos de deploy no lo incluyen) o git no
    // disponible: cae al build date de mas abajo, que sigue siendo una
    // fecha valida aunque no distinga cambios reales.
  }
  return buildDate;
}

const buildDate = new Date().toISOString().slice(0, 10);

/** Grupos de paginas traducidas: las tres versiones son la misma pagina. */
const translatedGroups: { paths: Record<'es' | 'en' | 'ca', string>; lastmod: string }[] = [
  {
    // Portfolio principal: agrega casi todos los componentes de contenido.
    paths: { es: '/', en: '/en/', ca: '/ca/' },
    lastmod: gitLastMod([
      'src/pages/index.astro',
      'src/pages/en/index.astro',
      'src/pages/ca/index.astro',
      'src/components/Hero.astro',
      'src/components/Experience.astro',
      'src/components/Skills.astro',
      'src/components/Projects.astro',
      'src/components/Certifications.astro',
      'src/components/BlogPreview.astro',
      'src/components/Faq.astro',
      'src/components/Contact.astro',
      'src/data/experience.ts',
      'src/data/skills.ts',
      'src/data/faq.ts',
    ]),
  },
  {
    // "Sobre esta web".
    paths: {
      es: '/sobre-esta-web/',
      en: '/en/about-this-website/',
      ca: '/ca/sobre-aquesta-web/',
    },
    lastmod: gitLastMod([
      'src/pages/sobre-esta-web.astro',
      'src/pages/en/about-this-website.astro',
      'src/pages/ca/sobre-aquesta-web.astro',
      'src/components/AboutTech.astro',
      'src/data/about-tech.ts',
    ]),
  },
];

/**
 * Paginas de un solo idioma: proyectos (HTML estatico bajo public/projects/)
 * y el indice del blog (ES, ver comentario de cabecera).
 *
 * SOLO van URLs canonicas e indexables. Quedan fuera a proposito
 * uninstall.html y las plantillas de demostracion de Zeora, marcadas noindex.
 *
 * BadaVeu y Mes Badalona se retiraron del sitio: sus URLs responden 410 Gone
 * desde el .htaccess.
 */
const singleLangPages: { path: string; lastmod: string }[] = [
  {
    path: '/blog/',
    lastmod: gitLastMod(['src/pages/blog/index.astro', 'src/scripts/blog.ts']),
  },
  {
    path: '/projects/',
    lastmod: gitLastMod(['src/pages/projects/index.astro']),
  },
  { path: '/projects/fluence/', lastmod: gitLastMod(['public/projects/fluence/index.html']) },
  {
    path: '/projects/fluence/privacy.html',
    lastmod: gitLastMod(['public/projects/fluence/privacy.html']),
  },
  {
    path: '/projects/fluence/terms.html',
    lastmod: gitLastMod(['public/projects/fluence/terms.html']),
  },
  {
    path: '/projects/fluence/disclaimer.html',
    lastmod: gitLastMod(['public/projects/fluence/disclaimer.html']),
  },
  {
    path: '/projects/followguard/',
    lastmod: gitLastMod(['public/projects/followguard/index.html']),
  },
  {
    path: '/projects/passwdcentinel/',
    lastmod: gitLastMod(['public/projects/passwdcentinel/index.html']),
  },
  {
    path: '/projects/passwdcentinel/politica.html',
    lastmod: gitLastMod(['public/projects/passwdcentinel/politica.html']),
  },
  {
    path: '/projects/promptmaster/',
    lastmod: gitLastMod(['public/projects/promptmaster/index.html']),
  },
  {
    path: '/projects/promptmaster/privacy.html',
    lastmod: gitLastMod(['public/projects/promptmaster/privacy.html']),
  },
  { path: '/projects/zeora/', lastmod: gitLastMod(['public/projects/zeora/index.html']) },
];

export const GET: APIRoute = () => {
  const url = (p: string) => new URL(p, SITE.domain).href;

  const entry = (loc: string, lastmod: string, alternates = '') =>
    ['  <url>', `    <loc>${loc}</loc>`, ...(alternates ? [alternates] : []), `    <lastmod>${lastmod}</lastmod>`, '  </url>'].join(
      '\n'
    );

  // --- 1. Paginas traducidas -------------------------------------------------
  const translated = translatedGroups.flatMap((group) => {
    // El protocolo exige que cada pagina declare a TODAS sus hermanas,
    // incluida ella misma, y un x-default.
    const alternates = (['es', 'en', 'ca'] as const)
      .map((l) => `    <xhtml:link rel="alternate" hreflang="${l}" href="${url(group.paths[l])}"/>`)
      .concat(`    <xhtml:link rel="alternate" hreflang="x-default" href="${url(group.paths.es)}"/>`)
      .join('\n');

    return (['es', 'en', 'ca'] as const).map((l) => entry(url(group.paths[l]), group.lastmod, alternates));
  });

  // --- 2. Paginas de un solo idioma -------------------------------------------
  const singleLang = singleLangPages.map((p) => entry(url(p.path), p.lastmod));

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
${[...translated, ...singleLang].join('\n')}
</urlset>
`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
