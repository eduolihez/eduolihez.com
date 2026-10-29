/**
 * /blog/translations.json — mapa slug ES -> slug CA de los articulos.
 * ---------------------------------------------------------------------------
 * La fuente de verdad es src/lib/postTranslations.ts. Este archivo solo lo
 * publica para que server/lib/sitemap.php (PHP, sin acceso al codigo TS)
 * pueda poner los hreflang de /sitemap-posts.xml sin duplicar el mapa.
 */
import type { APIRoute } from 'astro';
import { POST_TRANSLATIONS_CA } from '../../lib/postTranslations';

export const prerender = true;

export const GET: APIRoute = () =>
  new Response(JSON.stringify(POST_TRANSLATIONS_CA), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
