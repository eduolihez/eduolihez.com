/**
 * /blog/covers/<slug>.png — portada generada del articulo, en build-time.
 * ---------------------------------------------------------------------------
 * Ver src/lib/cover.ts para el diseno (por que SVG a mano y no una imagen de
 * IA generica). Este archivo solo hace tres cosas: pedir los articulos,
 * construir el SVG por cada uno con los datos reales, y convertirlo a PNG
 * con resvg -- los lectores de redes sociales (LinkedIn, Twitter/X) no
 * renderizan SVG en og:image, asi que hace falta el paso a PNG aunque el
 * propio SVG ya sea valido para <img> en el sitio.
 *
 * Se usa como FALLBACK: solo genera portada para los articulos sin
 * cover_url propio en la base de datos. Si en algun momento subes una
 * imagen real desde /admin, esa gana (ver post.astro y BlogPostBody.astro).
 */
import type { APIRoute } from 'astro';
import { Resvg } from '@resvg/resvg-js';
import { fetchAllPostSummaries } from '../../../lib/posts';
import { formatDate } from '../../../scripts/blog';
import { buildCoverSvg } from '../../../lib/cover';

export const prerender = true;

export async function getStaticPaths() {
  const posts = await fetchAllPostSummaries('es');
  return posts
    .filter((post) => !post.cover_url)
    .map((post) => ({ params: { slug: post.slug }, props: { post } }));
}

interface Props {
  post: Awaited<ReturnType<typeof fetchAllPostSummaries>>[number];
}

export const GET: APIRoute = ({ props }) => {
  const { post } = props as Props;

  const svg = buildCoverSvg({
    title: post.title,
    kicker: 'eduolihez.com / blog',
    meta: formatDate(post.published_at, 'es', true),
    tags: post.tags || [],
  });

  const resvg = new Resvg(svg, {
    font: { loadSystemFonts: true },
    fitTo: { mode: 'width', value: 1200 },
  });
  const png = resvg.render().asPng();

  return new Response(new Uint8Array(png), {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
};
