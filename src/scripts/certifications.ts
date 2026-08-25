/**
 * certifications.ts - Logica de la isla dinamica de Certificaciones
 * (Certifications.astro). Extraido del <script> inline por la misma razon que
 * projects.ts: Astro no permite importar/testear codigo dentro de un bloque
 * <script> de un .astro.
 */

import { safeUrl, setStatusPanel, fetchWithRetry } from './shared';

// Re-exportado por compatibilidad: los tests importan safeUrl desde './certifications'.
export { safeUrl };

interface CertLabels {
  loading: string;
  error: string;
  empty: string;
  countLabel: string;
  credentials: string;
  credential: string;
  back: string;
  viewIssuer: string;
}

interface Certification {
  name?: string;
  issuer?: string;
  category?: string;
  logo_url?: string;
  credential_url?: string;
  issue_date?: string;
}

// Solo tokens del sistema. Antes eran siete tonos, dos de ellos fuera de la
// paleta documentada. Cuatro hues bastan para distinguir emisores de un vistazo.
const PALETTE = ['var(--color-accent)', 'var(--color-accent-cyan)', 'var(--color-violet)', 'var(--color-closed)'];

/** Color estable por emisor (mismo nombre -> mismo color siempre). */
export function issuerColor(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return PALETTE[h % PALETTE.length];
}

export function initCerts(): void {
  const grid = document.getElementById('certs-grid');
  const status = document.getElementById('certs-status');
  const statusText = document.getElementById('certs-status-text');
  const counter = document.getElementById('certs-counter');
  const searchInput = document.getElementById('certs-search') as HTMLInputElement | null;
  const filterButtons = document.querySelectorAll<HTMLButtonElement>('.cert-filter-btn');
  const breadcrumb = document.getElementById('certs-breadcrumb');
  const breadcrumbCurrent = document.getElementById('certs-breadcrumb-current');
  const backBtn = document.getElementById('certs-back-btn');
  const loadMoreContainer = document.getElementById('certs-load-more-container');
  const loadMoreBtn = document.getElementById('certs-load-more-btn');
  if (!grid || grid.dataset.loaded) return;

  const apiUrl = grid.dataset.api || '';
  const labels: CertLabels = JSON.parse(grid.dataset.labels || '{}');

  let allCerts: Certification[] = [];
  let activeFilter = 'all';
  let activeIssuer: string | null = null;
  let searchQuery = '';
  let animationFrameId: number | null = null;
  let hasAnimatedOnce = false;
  const DEFAULT_LIMIT = 12; // multiplo de 2 y 3: no parte la ultima fila del grid
  let limit = DEFAULT_LIMIT;

  /**
   * Sube la vista a la cabecera de la seccion al entrar o salir de un emisor.
   * Respeta a quien pide menos animacion en el sistema.
   */
  function revealSection(): void {
    const section = document.getElementById('certificaciones');
    if (!section) return;
    const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    section.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' });
  }

  /** Sello de credencial en SVG (mismo icono que el contador de la seccion). */
  function sealIcon(color: string, size: string): SVGSVGElement {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('class', size);
    svg.setAttribute('aria-hidden', 'true');
    svg.style.color = color;
    const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    p.setAttribute('fill', 'currentColor');
    p.setAttribute(
      'd',
      'M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V22l-4-2-4 2v-7.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7m0 2a5 5 0 0 0-5 5 5 5 0 0 0 5 5 5 5 0 0 0 5-5 5 5 0 0 0-5-5Z',
    );
    svg.appendChild(p);
    return svg;
  }

  /** Recuadro del logo: imagen real si la hay, si no el sello coloreado. */
  function logoBox(logoUrl: string | undefined, altText: string, color: string): HTMLDivElement {
    const box = document.createElement('div');
    box.className = 'flex h-11 w-11 shrink-0 items-center justify-center overflow-hidden rounded-md border border-bg-border';
    const logo = safeUrl(logoUrl);
    if (logo) {
      box.classList.add('bg-bg-soft');
      const img = document.createElement('img');
      img.src = logo;
      img.alt = altText || '';
      img.loading = 'lazy';
      img.decoding = 'async';
      img.className = 'h-full w-full object-contain p-1.5';
      box.appendChild(img);
    } else {
      box.style.backgroundColor = color + '1a';
      box.style.borderColor = color + '33';
      box.appendChild(sealIcon(color, 'h-5 w-5'));
    }
    return box;
  }

  function animateCounter(target: number): void {
    if (!counter) return;
    if (animationFrameId) cancelAnimationFrame(animationFrameId);

    const run = () => {
      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        counter.textContent = String(target);
        return;
      }
      const dur = 800;
      const start = performance.now();
      const startVal = parseInt(counter.textContent || '0') || 0;
      const diff = target - startVal;
      function tick(now: number) {
        const p = Math.min((now - start) / dur, 1);
        const eased = 1 - Math.pow(1 - p, 3);
        counter!.textContent = String(Math.round(startVal + eased * diff));
        animationFrameId = p < 1 ? requestAnimationFrame(tick) : null;
      }
      animationFrameId = requestAnimationFrame(tick);
    };

    if (!hasAnimatedOnce && 'IntersectionObserver' in window) {
      const obs = new IntersectionObserver(
        (entries) => {
          entries.forEach((e) => {
            if (e.isIntersecting) {
              hasAnimatedOnce = true;
              run();
              obs.disconnect();
            }
          });
        },
        { threshold: 0.4 },
      );
      obs.observe(counter);
    } else {
      run();
    }
  }

  /** Aplica busqueda + filtro de categoria + emisor abierto. */
  function getFiltered(): Certification[] {
    return allCerts.filter((c) => {
      if (searchQuery) {
        const term = searchQuery.toLowerCase();
        const hay = [c.name, c.issuer, c.category].map((v) => (v || '').toLowerCase());
        if (!hay.some((v) => v.includes(term))) return false;
      }

      if (activeIssuer) {
        return (c.issuer || 'Otros').trim() === activeIssuer;
      }

      if (activeFilter === 'all') return true;

      const cat = (c.category || '').toLowerCase();
      const issuer = (c.issuer || '').toLowerCase();
      if (activeFilter === 'cyber') {
        return (
          cat.includes('security') ||
          cat.includes('secops') ||
          cat.includes('intel') ||
          cat.includes('cyber') ||
          issuer.includes('tryhackme')
        );
      }
      if (activeFilter === 'ai-cloud') return cat.includes('ai') || cat.includes('cloud');
      if (activeFilter === 'cisco') return issuer.includes('cisco');
      if (activeFilter === 'tryhackme') return issuer.includes('tryhackme');
      if (activeFilter === 'sys-dev') {
        return cat.includes('sistemas') || cat.includes('desarrollo') || cat.includes('system') || cat.includes('dev');
      }
      return false;
    });
  }

  /**
   * Mantiene la barra de categorias en sintonia con lo que se esta viendo.
   * Al abrir un emisor NO hay ninguna categoria activa: se esta filtrando por
   * emisor, no por tema.
   */
  function syncFilterButtons(): void {
    filterButtons.forEach((b) => {
      const on = !activeIssuer && b.dataset.filter === activeFilter;
      b.classList.toggle('is-active', on);
      if (on) {
        b.setAttribute('aria-pressed', 'true');
      } else {
        b.removeAttribute('aria-pressed');
      }
    });
  }

  function render(): void {
    if (!grid) return;
    grid.innerHTML = '';
    const filtered = getFiltered();
    animateCounter(filtered.length);

    syncFilterButtons();

    if (breadcrumb) {
      breadcrumb.classList.toggle('hidden', !activeIssuer);
      breadcrumb.classList.toggle('flex', !!activeIssuer);
      if (activeIssuer && breadcrumbCurrent) breadcrumbCurrent.textContent = activeIssuer;
    }

    if (!filtered.length) {
      hideLoadMore();
      return message(labels.empty);
    }

    // Vista "Todas" sin busqueda: resumen por emisor, no la lista completa.
    const summaryView = activeFilter === 'all' && !activeIssuer && !searchQuery;
    const items = summaryView ? buildIssuerCards(filtered) : filtered.map(makeCertCard);

    const pageSize = summaryView ? items.length : limit;
    items.slice(0, pageSize).forEach((el) => grid.appendChild(el));

    if (items.length > pageSize) {
      loadMoreContainer?.classList.remove('hidden');
      loadMoreContainer?.classList.add('flex');
    } else {
      hideLoadMore();
    }
  }

  function hideLoadMore(): void {
    loadMoreContainer?.classList.remove('flex');
    loadMoreContainer?.classList.add('hidden');
  }

  /** Una tarjeta por emisor: nombre + numero de credenciales. */
  function buildIssuerCards(certs: Certification[]): HTMLElement[] {
    const order: string[] = [];
    const groups: Record<string, Certification[]> = {};
    certs.forEach((c) => {
      const key = (c.issuer || 'Otros').trim();
      if (!groups[key]) {
        groups[key] = [];
        order.push(key);
      }
      groups[key].push(c);
    });
    order.sort((a, b) => groups[b].length - groups[a].length);
    return order.map((issuer) => makeIssuerCard(issuer, groups[issuer]));
  }

  function makeIssuerCard(issuer: string, certs: Certification[]): HTMLButtonElement {
    const color = issuerColor(issuer);
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className =
      'reveal is-visible group flex w-full cursor-pointer items-center gap-3 rounded-lg border border-bg-border bg-bg-card p-4 text-left transition hover:border-accent/40 hover:bg-bg-soft/40 focus:outline-hidden focus-visible:ring-2 focus-visible:ring-accent';
    btn.setAttribute('aria-label', `${labels.viewIssuer} ${issuer} (${certs.length})`);

    let logo = '';
    for (const c of certs) {
      const l = safeUrl(c.logo_url);
      if (l) {
        logo = l;
        break;
      }
    }
    btn.appendChild(logoBox(logo, issuer, color));

    const info = document.createElement('div');
    info.className = 'min-w-0 flex-1';

    const name = document.createElement('p');
    name.className = 'truncate text-sm font-semibold text-text';
    name.textContent = issuer;
    info.appendChild(name);

    const sub = document.createElement('p');
    sub.className = 'mt-0.5 text-xs text-text-muted';
    sub.textContent = `${certs.length} ${certs.length === 1 ? labels.credential : labels.credentials}`;
    info.appendChild(sub);
    btn.appendChild(info);

    const count = document.createElement('span');
    count.className = 'shrink-0 rounded-full px-2 py-0.5 font-mono text-sm font-bold tabular-nums';
    count.style.color = color;
    count.style.backgroundColor = color + '1a';
    count.textContent = String(certs.length);
    btn.appendChild(count);

    btn.addEventListener('click', () => {
      activeIssuer = issuer;
      limit = DEFAULT_LIMIT;
      render();
      revealSection();
      grid?.querySelector<HTMLElement>('a, button')?.focus({ preventScroll: true });
    });

    return btn;
  }

  /** Tarjeta de UNA certificacion. */
  function makeCertCard(c: Certification): HTMLElement {
    const href = safeUrl(c.credential_url);
    const wrap = document.createElement(href ? 'a' : 'div') as HTMLAnchorElement | HTMLDivElement;
    wrap.className = 'reveal is-visible group flex items-center gap-3 rounded-lg border border-bg-border bg-bg-card p-4 transition hover:border-text-faint/40';
    if (href) {
      (wrap as HTMLAnchorElement).href = href;
      (wrap as HTMLAnchorElement).target = '_blank';
      (wrap as HTMLAnchorElement).rel = 'noopener noreferrer';
    }

    wrap.appendChild(logoBox(c.logo_url, c.issuer || c.name || '', issuerColor((c.issuer || c.name || '?').trim())));

    const info = document.createElement('div');
    info.className = 'min-w-0 flex-1';
    const name = document.createElement('p');
    name.className = 'line-clamp-2 text-sm font-medium text-text';
    name.textContent = c.name || '';
    info.appendChild(name);
    const meta = document.createElement('p');
    meta.className = 'mt-0.5 truncate text-xs text-text-muted';
    meta.textContent = [c.issuer, c.issue_date].filter(Boolean).join(' · ');
    info.appendChild(meta);
    wrap.appendChild(info);

    if (href) {
      const a = document.createElement('span');
      a.className = 'shrink-0 text-text-faint transition group-hover:text-accent';
      a.setAttribute('aria-hidden', 'true');
      a.textContent = '↗';
      wrap.appendChild(a);
    }
    return wrap;
  }

  function message(text: string): void {
    if (!grid) return;
    const p = document.createElement('p');
    p.className = 'col-span-full text-sm text-text-muted';
    p.textContent = text;
    grid.appendChild(p);
  }

  function setState(state: 'loading' | 'empty' | 'error', text: string): void {
    setStatusPanel(status, statusText, state, text);
  }

  function loadData(): void {
    setState('loading', labels.loading);
    if (grid) grid.innerHTML = '';

    fetchWithRetry(apiUrl, { headers: { Accept: 'application/json' } })
      .then((data) => {
        if (!grid) return;
        grid.dataset.loaded = '1';
        allCerts = Array.isArray(data) ? data : (data as { items?: Certification[] })?.items || [];
        if (!allCerts.length) return setState('empty', labels.empty);
        status?.classList.add('hidden');
        render();
      })
      .catch(() => setState('error', labels.error));
  }

  status?.querySelector<HTMLButtonElement>('.status-retry')?.addEventListener('click', loadData);

  searchInput?.addEventListener('input', (e) => {
    searchQuery = (e.target as HTMLInputElement).value;
    activeIssuer = null; // buscar sale del detalle de un emisor
    limit = DEFAULT_LIMIT;
    render();
  });

  filterButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      activeFilter = btn.dataset.filter || 'all';
      activeIssuer = null;
      limit = DEFAULT_LIMIT;
      render();
    });
  });

  backBtn?.addEventListener('click', () => {
    activeIssuer = null;
    limit = DEFAULT_LIMIT;
    render();
    revealSection();
  });

  loadMoreBtn?.addEventListener('click', () => {
    limit = Infinity;
    render();
  });

  loadData();
}
