/**
 * Articulos relacionados, calculados en build: mas etiquetas en comun primero,
 * a igualdad el mas reciente. Siempre devuelve hasta `max` (si hay otros
 * articulos), para que ningun post quede sin enlaces salientes.
 */
export interface RelatedCandidate {
  slug: string;
  tags: string[];
  published_at: string;
}

export function relatedPosts<T extends RelatedCandidate>(current: T, all: T[], max = 3): T[] {
  const mine = new Set((current.tags ?? []).map((t) => t.toLowerCase()));
  return all
    .filter((p) => p.slug !== current.slug)
    .map((p) => ({ p, score: (p.tags ?? []).filter((t) => mine.has(t.toLowerCase())).length }))
    .sort((a, b) => b.score - a.score || (a.p.published_at < b.p.published_at ? 1 : -1))
    .slice(0, max)
    .map((x) => x.p);
}
