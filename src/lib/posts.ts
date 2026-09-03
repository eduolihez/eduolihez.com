/**
 * posts.ts - Trae los articulos del blog desde /api/*.php EN BUILD TIME.
 * ---------------------------------------------------------------------------
 * Antes, el detalle de un articulo (/blog/post/?slug=X) era un solo molde de
 * HTML que src/scripts/blog.ts rellenaba en el navegador tras un fetch. Para
 * un rastreador que no ejecuta JS -- o al que un WAF le bloquea el fetch, o
 * que respeta el robots.txt de /api/ -- los 8 articulos eran indistinguibles:
 * mismo <title>, misma descripcion, y sobre todo el mismo <link
 * rel="canonical"> sin slug. Google trataba las 8 URLs del sitemap como
 * duplicados de una pagina vacia.
 *
 * Este modulo corre SOLO durante `astro build` (dentro de getStaticPaths()),
 * nunca en el navegador: genera una pagina estatica real por cada slug, con
 * su titulo, su canonical y su BlogPosting propios ya en el HTML servido.
 *
 * Falla la build a proposito si la API no responde. Servir un blog vacio o
 * con contenido viejo en silencio es peor que un CI en rojo que avisa a
 * alguien. La contrapartida: `npm run build` ahora depende de que
 * eduolihez.com/api/*.php este vivo en el momento de compilar (antes no
 * dependia de nada externo). Si el build falla por esto, es la API la que
 * hay que mirar primero, no el codigo.
 */
import { SITE } from '../config';
import type { Lang } from '../i18n/ui';

export interface PostSummary {
  id: number;
  title: string;
  slug: string;
  summary: string;
  cover_url: string | null;
  tags: string[];
  lang: string;
  published_at: string;
}

export interface PostDetail extends PostSummary {
  content: string;
  updated_at: string;
  read_minutes: number;
}

/**
 * La API en produccion ha devuelto 500 de forma intermitente en peticiones
 * hechas con fetch() de Node (no con curl, no con el navegador) -- muy
 * probablemente el mismo Cloudflare Bot Management que la auditoria GEO
 * encontro sobreescribiendo el robots.txt propio del sitio: parece puntuar
 * distinto a un cliente HTTP sin huella de navegador. Tres reintentos con
 * backoff absorben ese ruido sin ocultar un fallo real y persistente.
 */
async function fetchJson<T>(url: string, attempt = 1): Promise<T> {
  const res = await fetch(url, { headers: { 'User-Agent': 'eduolihez.com-build/1.0' } });
  if (!res.ok) {
    if (attempt < 3) {
      await new Promise((r) => setTimeout(r, attempt * 1000));
      return fetchJson<T>(url, attempt + 1);
    }
    throw new Error(`[src/lib/posts.ts] GET ${url} -> HTTP ${res.status} (tras ${attempt} intentos). ` +
      'El build de Astro necesita la API en produccion respondiendo para generar el blog. Reintenta el build.');
  }
  return res.json() as Promise<T>;
}

/**
 * Todos los articulos publicados de un idioma, con su contenido completo.
 * Vacio (no error) si ese idioma todavia no tiene articulos -- EN y CA no
 * tienen ninguno a fecha de escribir esto, y eso es un estado valido.
 */
export async function fetchAllPostDetails(lang: Lang): Promise<PostDetail[]> {
  const list = await fetchJson<PostSummary[]>(`${SITE.domain}/api/posts.php?lang=${lang}`);
  // Secuencial, no Promise.all: el hosting compartido es el mismo que sirve
  // /admin y las visitas reales, y son pocos articulos -- no hay necesidad
  // de lanzarle N peticiones simultaneas solo porque el build pueda.
  const details: PostDetail[] = [];
  for (const item of list) {
    details.push(await fetchJson<PostDetail>(`${SITE.domain}/api/post.php?slug=${encodeURIComponent(item.slug)}`));
  }
  return details;
}

/** Fecha en ISO 8601 para datePublished/dateModified. */
export function isoDate(raw: string): string {
  if (!raw) return '';
  const d = new Date(raw.replace(' ', 'T'));
  return Number.isNaN(d.getTime()) ? '' : d.toISOString();
}
