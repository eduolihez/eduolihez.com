/**
 * /og/<lang>.png — tarjeta Open Graph del perfil, una por idioma, en build-time.
 * ---------------------------------------------------------------------------
 * Es la og:image de la portada y de toda pagina sin imagen propia (ver
 * Seo.astro). El diseno vive en src/lib/cover.ts (buildProfileCoverSvg); aqui
 * solo se le dan los textos de cada idioma y se pasa a PNG con resvg, porque
 * LinkedIn, WhatsApp y X no renderizan SVG en og:image. Mismo motor y mismas
 * fuentes del sistema que las portadas del blog (blog/covers/[slug].png.ts).
 */
import type { APIRoute } from 'astro';
import { Resvg } from '@resvg/resvg-js';
import { SITE } from '../../config';
import { ui, type Lang } from '../../i18n/ui';
import { buildProfileCoverSvg } from '../../lib/cover';

export const prerender = true;

const LOCATION: Record<Lang, string> = {
  es: 'Barcelona, España',
  en: 'Barcelona, Spain',
  ca: 'Barcelona, Espanya',
};

// Nombres tecnicos: no se traducen (igual que en src/data/skills.ts).
const TAGS = ['Cloud Security', 'IAM', 'Email & Collaboration', 'SOC'];

export function getStaticPaths() {
  return (Object.keys(ui) as Lang[]).map((lang) => ({ params: { lang } }));
}

export const GET: APIRoute = ({ params }) => {
  const lang = params.lang as Lang;

  const svg = buildProfileCoverSvg({
    name: SITE.name,
    role: ui[lang]['hero.role'],
    location: LOCATION[lang],
    tags: TAGS,
  });

  const png = new Resvg(svg, {
    font: { loadSystemFonts: true },
    fitTo: { mode: 'width', value: 1200 },
  })
    .render()
    .asPng();

  return new Response(new Uint8Array(png), {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=86400',
    },
  });
};
