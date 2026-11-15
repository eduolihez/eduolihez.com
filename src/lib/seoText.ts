/**
 * Longitudes de <title> y meta description de los articulos del blog.
 *
 * Los titulos salian como "<titular> | Blog | Edu Olivares" (70-106
 * caracteres) y la descripcion era el resumen entero (hasta 305): Google
 * corta hacia los 60 y los 160, asi que el final se perdia o lo reescribia el
 * buscador. Aqui se recorta primero lo prescindible (la marca), nunca el
 * titular, y la descripcion se corta por palabra completa.
 */

export const TITLE_MAX = 60;
export const DESCRIPTION_MAX = 155;

export function postTitle(headline: string, siteName: string): string {
  const candidates = [`${headline} | Blog | ${siteName}`, `${headline} | ${siteName}`];
  return candidates.find((c) => c.length <= TITLE_MAX) ?? headline;
}

export function metaDescription(text: string, max: number = DESCRIPTION_MAX): string {
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= max) return clean;
  const room = clean.slice(0, max - 1);
  const lastSpace = room.lastIndexOf(' ');
  const cut = lastSpace > 0 ? room.slice(0, lastSpace) : room;
  return `${cut.replace(/[\s,;:.\-–—]+$/, '')}…`;
}

/**
 * Titulo y descripcion finales de un articulo: el override por slug (si existe)
 * manda; si no, se aplican las reglas automaticas de arriba.
 */
export function postSeo(
  post: { slug: string; title: string; summary: string },
  siteName: string,
  overrides: Record<string, { title?: string; description?: string }>,
): { title: string; description: string } {
  const o = overrides[post.slug];
  return {
    title: o?.title ?? postTitle(post.title, siteName),
    description: o?.description ?? metaDescription(post.summary),
  };
}
