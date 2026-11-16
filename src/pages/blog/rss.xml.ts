/**
 * /blog/rss.xml - Feed RSS del blog en espanol, generado en build-time con los
 * mismos articulos que las paginas estaticas (src/lib/posts.ts).
 */
import type { APIRoute } from 'astro';
import { SITE } from '../../config';
import { fetchAllPostSummaries } from '../../lib/posts';
import { buildRss } from '../../lib/rss';

export const prerender = true;

export const GET: APIRoute = async () => {
  const posts = await fetchAllPostSummaries('es');
  const body = buildRss(posts, {
    domain: SITE.domain,
    title: `Blog de ${SITE.name}`,
    description: 'Ciberseguridad, SOC, cloud e IA: notas de trabajo de un analista.',
  });
  return new Response(body, {
    headers: { 'Content-Type': 'application/rss+xml; charset=utf-8', 'Cache-Control': 'public, max-age=3600' },
  });
};
