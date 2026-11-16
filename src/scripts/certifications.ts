/**
 * certifications.ts - Logica de la isla dinamica de Certificaciones
 * (Certifications.astro). Extraido del <script> inline por la misma razon que
 * projects.ts: Astro no permite importar/testear codigo dentro de un bloque
 * <script> de un .astro.
 *
 * Vista "Expediente": lista densa de filas (insignia, nombre, emisor, ano). Las
 * primeras --en el orden de la API-- son las destacadas; "Ver todas" despliega
 * el resto. Cada fila con credential_url es un enlace de verificacion.
 */

import { safeUrl, setStatusPanel, fetchWithRetry } from './shared';

// Re-exportado por compatibilidad: los tests importan safeUrl desde './certifications'.
export { safeUrl };

interface CertLabels {
  loading: string;
  error: string;
  empty: string;
  countLabel: string;
  verify?: string;
}

interface Certification {
  name?: string;
  issuer?: string;
  category?: string;
  logo_url?: string;
  credential_url?: string;
  issue_date?: string;
}

/** Filas visibles antes de pulsar "Ver todas" (las destacadas). */
export const DEFAULT_LIMIT = 8;

/**
 * Monograma del emisor (1-2 iniciales en mayusculas) para las certificaciones
 * sin logo. Dos o mas palabras: iniciales de las dos primeras ("Trend Micro" ->
 * "TM"); una sola: sus dos primeras letras ("Cisco" -> "CI").
 */
const KNOWN_INITIALS: Record<string, string> = {
  fortinet: 'FN',
  linkedin: 'LI',
  tryhackme: 'TH',
  'trend micro': 'TM',
};

export function issuerInitials(issuer: string | undefined): string {
  const known = KNOWN_INITIALS[(issuer || '').trim().toLowerCase()];
  if (known) return known;
  const words = (issuer || '').match(/[\p{L}\p{N}]+/gu) || [];
  if (!words.length) return '·';
  const letters = words.length > 1 ? words[0][0] + words[1][0] : words[0].slice(0, 2);
  return letters.toUpperCase();
}

export function initCerts(): void {
  const grid = document.getElementById('certs-grid');
  const status = document.getElementById('certs-status');
  const statusText = document.getElementById('certs-status-text');
  const counter = document.getElementById('certs-counter');
  const searchInput = document.getElementById('certs-search') as HTMLInputElement | null;
  const filterButtons = document.querySelectorAll<HTMLButtonElement>('.cert-filter-btn');
  const loadMoreContainer = document.getElementById('certs-load-more-container');
  const loadMoreBtn = document.getElementById('certs-load-more-btn');
  if (!grid || grid.dataset.loaded) return;

  const apiUrl = grid.dataset.api || '';
  const labels: CertLabels = JSON.parse(grid.dataset.labels || '{}');
  // Version WebP de cada logo generada en el build (ver buildLogoMap).
  const logos: Record<string, string> = JSON.parse(grid.dataset.logos || '{}');

  let allCerts: Certification[] = [];
  let activeFilter = 'all';
  let searchQuery = '';
  let animationFrameId: number | null = null;
  let hasAnimatedOnce = false;
  let limit = DEFAULT_LIMIT;

  /**
   * Recuadro de insignia: la imagen real de Credly si existe, si no el
   * monograma del emisor -- nunca una imagen inventada para las certificaciones
   * que solo tienen PDF (Trend Micro, LinkedIn...). Mismo marcado que CertRow.astro.
   */
  function logoBox(logoUrl: string | undefined, issuer: string | undefined): HTMLSpanElement {
    const box = document.createElement('span');
    const logo = safeUrl(logoUrl);
    if (logo) {
      box.className = 'cert-badge';
      const img = document.createElement('img');
      img.src = logos[logo] ?? logo;
      img.alt = '';
      img.width = 56;
      img.height = 56;
      img.loading = 'lazy';
      img.decoding = 'async';
      img.className = 'cert-badge-img';
      box.appendChild(img);
    } else {
      box.className = 'cert-badge cert-badge--mono';
      box.setAttribute('aria-hidden', 'true');
      box.textContent = issuerInitials(issuer);
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

  /** Aplica busqueda + filtro de categoria. */
  function getFiltered(): Certification[] {
    return allCerts.filter((c) => {
      if (searchQuery) {
        const term = searchQuery.toLowerCase();
        const hay = [c.name, c.issuer, c.category].map((v) => (v || '').toLowerCase());
        if (!hay.some((v) => v.includes(term))) return false;
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

  /** Mantiene la barra de categorias en sintonia con lo que se esta viendo. */
  function syncFilterButtons(): void {
    filterButtons.forEach((b) => {
      const on = b.dataset.filter === activeFilter;
      b.classList.toggle('is-active', on);
      b.setAttribute('aria-pressed', String(on));
    });
  }

  function render(): void {
    if (!grid) return;
    grid.innerHTML = '';
    const filtered = getFiltered();
    animateCounter(filtered.length);

    syncFilterButtons();

    if (!filtered.length) {
      hideLoadMore();
      return message(labels.empty);
    }

    filtered.slice(0, limit).forEach((c) => grid.appendChild(makeCertRow(c)));

    if (filtered.length > limit) {
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

  /** Fila de UNA certificacion: insignia, nombre + emisor, ano. Enlace si hay credencial. */
  function makeCertRow(c: Certification): HTMLElement {
    const href = safeUrl(c.credential_url);
    const row = document.createElement(href ? 'a' : 'div') as HTMLAnchorElement | HTMLDivElement;
    row.className = 'cert-row';
    if (href) {
      (row as HTMLAnchorElement).href = href;
      (row as HTMLAnchorElement).target = '_blank';
      (row as HTMLAnchorElement).rel = 'noopener noreferrer';
    }

    row.appendChild(logoBox(c.logo_url, c.issuer));

    const text = document.createElement('span');
    text.className = 'min-w-0';
    const name = document.createElement('span');
    name.className = 'cert-name block text-sm font-semibold text-text-title';
    name.textContent = c.name || '';
    const issuer = document.createElement('span');
    issuer.className = 'block truncate text-xs text-text-muted';
    issuer.textContent = c.issuer || '';
    text.appendChild(name);
    text.appendChild(issuer);
    row.appendChild(text);

    const year = document.createElement('span');
    year.className = 'cert-year';
    year.textContent = c.issue_date || '';
    row.appendChild(year);
    return row;
  }

  function message(text: string): void {
    if (!grid) return;
    const p = document.createElement('p');
    p.className = 'px-3 py-4 text-sm text-text-muted';
    p.textContent = text;
    grid.appendChild(p);
  }

  function setState(state: 'loading' | 'empty' | 'error', text: string): void {
    setStatusPanel(status, statusText, state, text);
  }

  function loadData(): void {
    // Con filas ya pintadas en el build no se muestra "cargando" ni se vacia la
    // lista hasta tener datos: sin parpadeo ni salto de altura.
    if (!grid!.childElementCount) setState('loading', labels.loading);

    fetchWithRetry(apiUrl, { headers: { Accept: 'application/json' } })
      .then((data) => {
        if (!grid) return;
        grid.dataset.loaded = '1';
        allCerts = Array.isArray(data) ? data : (data as { items?: Certification[] })?.items || [];
        grid.innerHTML = '';
        if (!allCerts.length) return setState('empty', labels.empty);
        status?.classList.add('hidden');
        render();
      })
      .catch(() => setState('error', labels.error));
  }

  status?.querySelector<HTMLButtonElement>('.status-retry')?.addEventListener('click', loadData);

  searchInput?.addEventListener('input', (e) => {
    searchQuery = (e.target as HTMLInputElement).value;
    limit = DEFAULT_LIMIT;
    render();
  });

  filterButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      activeFilter = btn.dataset.filter || 'all';
      limit = DEFAULT_LIMIT;
      render();
    });
  });

  loadMoreBtn?.addEventListener('click', () => {
    limit = Infinity;
    render();
  });

  loadData();
}
