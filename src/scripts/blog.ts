/**
 * blog.ts - Logica compartida del blog (indice y detalle de articulo).
 * ---------------------------------------------------------------------------
 * Las seis paginas del blog (/blog/, /en/blog/, /ca/blog/ y sus detalles) eran
 * seis copias del mismo JavaScript. Aqui esta una sola vez: lo que cambie se
 * arregla en los tres idiomas a la vez, y no puede volver a pasar que una
 * version se quede atras.
 *
 * Dos cosas que este archivo hace y las copias no hacian:
 *
 *  1. ESCAPAR EL HTML. El listado se construia interpolando el titulo y el
 *     resumen en una plantilla de texto que acababa en innerHTML. Cualquier
 *     "<" del contenido rompia la maqueta, y una etiqueta guardada desde el
 *     panel se ejecutaba como marcado. El resto de la web (Proyectos,
 *     Certificaciones) ya construia sus tarjetas con textContent; el blog era
 *     la excepcion. Ahora sigue la misma norma.
 *
 *  2. SEO POR ARTICULO. El detalle vive en una sola ruta (/blog/post/) y
 *     cambia de contenido segun ?slug=. Sin esto, los cien articulos
 *     compartirian titulo, descripcion y canonica: Google los tomaria por la
 *     misma pagina duplicada. Al cargar se reescriben <title>, la descripcion,
 *     la canonica, las etiquetas Open Graph y un bloque BlogPosting de
 *     Schema.org con los datos reales del articulo.
 */

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

/** Escapa texto para poder incrustarlo en HTML sin que se interprete. */
export function escapeHtml(value: unknown): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Deja pasar solo URLs que no pueden ejecutar codigo.
 * Bloquea javascript:, data: y vbscript: en atributos href/src.
 * Misma regla que usan Proyectos y Certificaciones.
 */
export function safeUrl(url: unknown): string {
  if (typeof url !== 'string') return '';
  const u = url.trim();
  return /^(https?:\/\/|\/)/i.test(u) ? u : '';
}

/** Fecha legible en el idioma de la pagina. */
export function formatDate(raw: string, lang: string, long = false): string {
  if (!raw) return '';
  try {
    const d = new Date(raw.replace(' ', 'T'));
    if (Number.isNaN(d.getTime())) return raw;
    const locale = lang === 'en' ? 'en-US' : lang === 'ca' ? 'ca-ES' : 'es-ES';
    return d.toLocaleDateString(locale, {
      day: 'numeric',
      month: long ? 'long' : 'short',
      year: 'numeric',
    });
  } catch {
    return raw;
  }
}

/** Fecha en formato ISO para los datos estructurados (datePublished). */
function isoDate(raw: string): string {
  if (!raw) return '';
  const d = new Date(raw.replace(' ', 'T'));
  return Number.isNaN(d.getTime()) ? '' : d.toISOString();
}

interface Post {
  id: number;
  title: string;
  slug: string;
  summary: string;
  content?: string;
  cover_url?: string | null;
  tags?: string[];
  lang: string;
  published_at: string;
  updated_at?: string;
  read_minutes?: number;
}

// ---------------------------------------------------------------------------
// 1. Indice de articulos  (/blog/, /en/blog/, /ca/blog/)
// ---------------------------------------------------------------------------

export function initBlogList(): void {
  const grid = document.getElementById('blog-grid');
  if (!grid) return;

  const status = document.getElementById('blog-status');
  const statusText = document.getElementById('blog-status-text');

  const apiUrl = grid.dataset.api || '';
  const emptyMsg = grid.dataset.empty || '';
  const errorMsg = grid.dataset.error || '';
  const readMore = grid.dataset.readmore || '';
  const lang = grid.dataset.lang || 'es';
  const detailBase = grid.dataset.detail || '/blog/post/';

  const fail = (msg: string) => {
    if (statusText) statusText.textContent = msg;
    status?.querySelector('.animate-spin')?.classList.add('hidden');
  };

  fetch(apiUrl)
    .then((res) => {
      if (!res.ok) throw new Error('http');
      return res.json();
    })
    .then((posts: Post[]) => {
      status?.classList.add('hidden');
      grid.classList.remove('hidden');

      if (!Array.isArray(posts) || posts.length === 0) {
        const p = document.createElement('div');
        p.className = 'col-span-full py-16 text-center text-text-muted italic';
        p.textContent = emptyMsg;
        grid.appendChild(p);
        return;
      }

      posts.forEach((post) => grid.appendChild(card(post, { lang, readMore, detailBase })));

      // Las tarjetas nacen despues de que initReveal() haya observado el DOM,
      // asi que se marcan visibles a mano en lugar de quedarse en opacidad 0.
      grid.querySelectorAll('.reveal').forEach((el) => el.classList.add('is-visible'));
    })
    .catch(() => fail(errorMsg));
}

/** Tarjeta de UN articulo. Construida con nodos, nunca con innerHTML. */
function card(
  post: Post,
  opts: { lang: string; readMore: string; detailBase: string },
): HTMLElement {
  const href = `${opts.detailBase}?slug=${encodeURIComponent(post.slug || '')}`;

  const article = document.createElement('article');
  article.className =
    'group reveal flex flex-col overflow-hidden rounded-xl border border-bg-border bg-bg-card shadow-xs transition hover:-translate-y-1 hover:border-bg-border-hover hover:shadow-md';

  // --- Portada ---
  const cover = safeUrl(post.cover_url);
  const coverLink = document.createElement('a');
  coverLink.href = href;
  coverLink.className = 'block overflow-hidden';
  coverLink.setAttribute('aria-hidden', 'true');
  coverLink.tabIndex = -1;

  if (cover) {
    const img = document.createElement('img');
    img.src = cover;
    img.alt = '';
    img.loading = 'lazy';
    img.decoding = 'async';
    img.className =
      'h-48 w-full object-cover transition-transform duration-500 group-hover:scale-105';
    coverLink.appendChild(img);
  } else {
    const ph = document.createElement('div');
    ph.className =
      'flex h-48 w-full items-center justify-center border-b border-bg-border bg-bg-soft font-mono text-xs text-text-faint';
    ph.textContent = '</>';
    coverLink.appendChild(ph);
  }
  article.appendChild(coverLink);

  // --- Cuerpo ---
  const body = document.createElement('div');
  body.className = 'flex flex-1 flex-col p-5';

  const meta = document.createElement('p');
  meta.className = 'mb-2 flex items-center gap-2 font-mono text-xs text-text-muted';

  const time = document.createElement('time');
  time.dateTime = isoDate(post.published_at).slice(0, 10);
  time.textContent = formatDate(post.published_at, opts.lang);
  meta.appendChild(time);

  if (post.read_minutes) {
    const sep = document.createElement('span');
    sep.setAttribute('aria-hidden', 'true');
    sep.textContent = '·';
    meta.appendChild(sep);
    const read = document.createElement('span');
    read.textContent = `${post.read_minutes} min`;
    meta.appendChild(read);
  }
  body.appendChild(meta);

  const h2 = document.createElement('h2');
  h2.className =
    'mb-3 text-lg font-bold leading-snug text-text-title transition group-hover:text-accent';
  const titleLink = document.createElement('a');
  titleLink.href = href;
  titleLink.textContent = post.title || '';
  h2.appendChild(titleLink);
  body.appendChild(h2);

  const summary = document.createElement('p');
  summary.className = 'mb-4 line-clamp-3 text-sm text-text-muted';
  summary.textContent = post.summary || '';
  body.appendChild(summary);

  if (post.tags?.length) {
    body.appendChild(tagList(post.tags, 3));
  }

  const footer = document.createElement('div');
  footer.className = 'mt-auto';
  const more = document.createElement('a');
  more.href = href;
  more.className =
    'inline-flex items-center gap-1 text-sm font-semibold text-accent transition hover:text-accent-hover';
  more.textContent = `${opts.readMore} →`;
  footer.appendChild(more);
  body.appendChild(footer);

  article.appendChild(body);
  return article;
}

/**
 * Lista de etiquetas. `limit` recorta en la tarjeta del listado, donde cinco
 * etiquetas parten la maqueta; en el detalle se muestran todas.
 */
function tagList(tags: string[], limit = 0): HTMLElement {
  const ul = document.createElement('ul');
  ul.className = 'mb-4 flex flex-wrap gap-1.5';
  const shown = limit > 0 ? tags.slice(0, limit) : tags;

  shown.forEach((tag) => {
    const li = document.createElement('li');
    li.className =
      'rounded-sm border border-bg-border px-1.5 py-0.5 font-mono text-[10px] text-text-faint';
    li.textContent = tag;
    ul.appendChild(li);
  });

  if (limit > 0 && tags.length > limit) {
    const li = document.createElement('li');
    li.className = 'px-1 py-0.5 font-mono text-[10px] text-text-faint';
    li.textContent = `+${tags.length - limit}`;
    ul.appendChild(li);
  }
  return ul;
}

// ---------------------------------------------------------------------------
// 2. Detalle de articulo  (/blog/post/, /en/blog/post/, /ca/blog/post/)
// ---------------------------------------------------------------------------

export function initBlogPost(): void {
  const wrapper = document.getElementById('post-detail-wrapper');
  if (!wrapper) return;

  const apiUrl = wrapper.dataset.api || '';
  const lang = wrapper.dataset.lang || 'es';
  const siteName = wrapper.dataset.site || '';
  const authorName = wrapper.dataset.author || '';
  const notFoundMsg = wrapper.dataset.notfound || '';
  const errorMsg = wrapper.dataset.error || '';
  const missingSlugMsg = wrapper.dataset.missingslug || '';

  const slug = new URLSearchParams(window.location.search).get('slug') || '';
  if (!slug) {
    noindex();
    return showError(missingSlugMsg);
  }

  fetch(`${apiUrl}?slug=${encodeURIComponent(slug)}`)
    .then((res) => {
      if (res.status === 404) throw new Error(notFoundMsg);
      if (!res.ok) throw new Error(errorMsg);
      return res.json();
    })
    .then((post: Post) => {
      render(post, lang);
      applySeo(post, { lang, siteName, authorName });
    })
    .catch((err: Error) => {
      // Un slug que no existe no debe quedarse indexado como articulo real.
      noindex();
      showError(err.message || errorMsg);
    });
}

/** Vuelca el articulo en la pagina. */
function render(post: Post, lang: string): void {
  const set = (id: string, text: string) => {
    const el = document.getElementById(id);
    if (el) el.textContent = text;
  };

  set('post-title', post.title || '');
  set('post-summary', post.summary || '');

  const dateEl = document.getElementById('post-date');
  if (dateEl && post.published_at) {
    dateEl.textContent = formatDate(post.published_at, lang, true);
    dateEl.setAttribute('datetime', isoDate(post.published_at).slice(0, 10));
  }

  const readEl = document.getElementById('post-read');
  if (readEl && post.read_minutes) {
    readEl.textContent = `${post.read_minutes} min`;
    readEl.classList.remove('hidden');
  }

  const tagsEl = document.getElementById('post-tags');
  if (tagsEl && post.tags?.length) {
    tagsEl.replaceChildren(tagList(post.tags));
    tagsEl.classList.remove('hidden');
  }

  const cover = safeUrl(post.cover_url);
  if (cover) {
    const img = document.getElementById('post-cover') as HTMLImageElement | null;
    if (img) {
      img.src = cover;
      img.alt = post.title || '';
    }
    document.getElementById('post-cover-wrapper')?.classList.remove('hidden');
  }

  // El cuerpo SI es HTML a proposito: se redacta desde el panel, que es una
  // zona autenticada. Por eso el articulo puede llevar <h2>, listas o <pre>.
  // La CSP del sitio (script-src 'self' con hashes, sin 'unsafe-inline')
  // impide que un <script> o un onclick= incrustado ahi llegue a ejecutarse.
  const body = document.getElementById('post-body');
  if (body) body.innerHTML = post.content || '';

  document.getElementById('post-status')?.classList.add('hidden');
  document.getElementById('post-content-container')?.classList.remove('hidden');
}

/**
 * Reescribe los metadatos de la pagina con los del articulo cargado.
 *
 * Sin esto, /blog/post/?slug=lo-que-sea devolveria siempre el mismo <title>
 * generico y la misma canonica: para un buscador serian todo la misma pagina.
 */
function applySeo(
  post: Post,
  opts: { lang: string; siteName: string; authorName: string },
): void {
  const title = `${post.title} | Blog | ${opts.siteName}`;
  const url = window.location.href;
  const image = safeUrl(post.cover_url);
  const absoluteImage = image ? new URL(image, window.location.origin).href : '';

  document.title = title;

  const meta = (selector: string, content: string) => {
    const el = document.querySelector(selector);
    if (el && content) el.setAttribute('content', content);
  };

  meta('meta[name="description"]', post.summary || '');
  meta('meta[property="og:title"]', title);
  meta('meta[property="og:description"]', post.summary || '');
  meta('meta[property="og:url"]', url);
  meta('meta[property="og:type"]', 'article');
  meta('meta[name="twitter:title"]', title);
  meta('meta[name="twitter:description"]', post.summary || '');
  if (absoluteImage) {
    meta('meta[property="og:image"]', absoluteImage);
    meta('meta[name="twitter:image"]', absoluteImage);
  }

  // La canonica debe incluir el ?slug=: es lo que distingue un articulo de otro.
  const canonical = document.querySelector('link[rel="canonical"]');
  if (canonical) canonical.setAttribute('href', url);

  // Datos estructurados del articulo.
  //
  // Se rellena un <script type="application/ld+json"> que YA viene en el HTML
  // en lugar de crear uno nuevo. La CSP solo se evalua cuando el elemento
  // entra en el documento, asi que cambiar su contenido despues es valido;
  // insertar un <script> nuevo desde JavaScript lo bloquearia por no tener
  // hash en la politica.
  const holder = document.getElementById('post-jsonld');
  if (holder) {
    const person = { '@type': 'Person', name: opts.authorName, url: window.location.origin };
    holder.textContent = JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'BlogPosting',
      headline: post.title,
      description: post.summary,
      inLanguage: post.lang || opts.lang,
      datePublished: isoDate(post.published_at),
      // dateModified separado: es lo que distingue un articulo que se revisa
      // de uno abandonado, y Google lo tiene en cuenta.
      dateModified: isoDate(post.updated_at || post.published_at),
      ...(post.tags?.length ? { keywords: post.tags.join(', ') } : {}),
      ...(post.read_minutes ? { timeRequired: `PT${post.read_minutes}M` } : {}),
      mainEntityOfPage: { '@type': 'WebPage', '@id': url },
      url,
      ...(absoluteImage ? { image: absoluteImage } : {}),
      author: person,
      publisher: person,
    });
  }
}

/** Marca la pagina como no indexable (slug inexistente o error de carga). */
function noindex(): void {
  const robots = document.querySelector('meta[name="robots"]');
  if (robots) robots.setAttribute('content', 'noindex, follow');
  document.querySelector('meta[name="googlebot"]')?.remove();
}

function showError(msg: string): void {
  const statusText = document.getElementById('post-status-text');
  if (statusText) statusText.textContent = msg;
  document.getElementById('post-status')?.querySelector('.animate-spin')?.classList.add('hidden');
}
