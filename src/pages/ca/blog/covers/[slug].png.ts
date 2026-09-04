/**
 * /ca/blog/covers/<slug>.png — variant catalana de la portada.
 * Vegeu src/pages/blog/covers/[slug].png.ts per al raonament complet;
 * mateixa logica, nomes canvia l'idioma. Ara mateix es un no-op en build:
 * el blog en catala encara no te articles (ver src/lib/posts.ts), asi que
 * getStaticPaths retorna un array buit fins que en tingui.
 */
import type { APIRoute } from 'astro';
import { Resvg } from '@resvg/resvg-js';
import { fetchAllPostSummaries } from '../../../../lib/posts';
import { formatDate } from '../../../../scripts/blog';
import { buildCoverSvg } from '../../../../lib/cover';

export const prerender = true;

export async function getStaticPaths() {
  const posts = await fetchAllPostSummaries('ca');
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
    meta: formatDate(post.published_at, 'ca', true),
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
