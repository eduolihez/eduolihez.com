/**
 * /en/blog/covers/<slug>.png — English cover image variant.
 * See src/pages/blog/covers/[slug].png.ts for the full rationale; identical
 * logic, only the language changes. Currently a no-op at build time: the
 * English blog has no posts yet (see src/lib/posts.ts), so getStaticPaths
 * returns an empty array until that changes.
 */
import type { APIRoute } from 'astro';
import { Resvg } from '@resvg/resvg-js';
import { fetchAllPostSummaries } from '../../../../lib/posts';
import { formatDate } from '../../../../scripts/blog';
import { buildCoverSvg } from '../../../../lib/cover';

export const prerender = true;

export async function getStaticPaths() {
  const posts = await fetchAllPostSummaries('en');
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
    meta: formatDate(post.published_at, 'en', true),
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
