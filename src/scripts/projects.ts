/**
 * projects.ts - Logica de la isla dinamica de Proyectos (Projects.astro).
 * ---------------------------------------------------------------------------
 * Extraido del <script> inline de Projects.astro para poder testear la carga,
 * el estado vacio/error, el reintento y el modal con Vitest + jsdom. Astro no
 * permite importar y testear codigo que vive dentro de un bloque <script> de
 * un .astro, asi que este modulo es la fuente de verdad y Projects.astro solo
 * lo invoca.
 */

interface ProjectLabels {
  loading: string;
  empty: string;
  error: string;
  featured: string;
  details: string;
  demo: string;
  repo: string;
  badgeOpenSource?: string;
  badgeInDevelopment?: string;
  badgePrivateCode?: string;
}

interface Project {
  title?: string;
  description?: string;
  summary?: string;
  image_url?: string;
  badges?: string[];
  stack?: string[];
  demo_url?: string;
  repo_url?: string;
  featured?: number | string;
}

const githubSvg = `<svg class="h-3.5 w-3.5 fill-current" viewBox="0 0 24 24" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><path d="M12 2A10 10 0 0 0 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.9-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.9 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0 0 12 2Z"/></svg>`;
const externalSvg = `<svg class="h-3.5 w-3.5 stroke-current" fill="none" stroke-width="2.5" viewBox="0 0 24 24" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 0 0 3 8.25v10.5A2.25 2.25 0 0 0 5.25 21h10.5A2.25 2.25 0 0 0 18 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/></svg>`;
const eyeSvg = `<svg class="h-3.5 w-3.5 stroke-current" fill="none" stroke-width="2.5" viewBox="0 0 24 24" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>`;

// --- Seguridad (S3): solo se aceptan URLs de esquema seguro ---
export function safeUrl(url: unknown): string {
  if (typeof url !== 'string') return '';
  const u = url.trim();
  if (/^(https?:\/\/|mailto:|\/)/i.test(u)) return u;
  return '';
}

function badgeMeta(b: string, labels: ProjectLabels): { className: string; text: string } | null {
  if (b === 'open-source') {
    return { className: 'bg-oss/10 text-oss border-oss/20', text: labels.badgeOpenSource || 'Open Source' };
  }
  if (b === 'in-development') {
    return { className: 'bg-wip/10 text-wip border-wip/20', text: labels.badgeInDevelopment || 'En Desarrollo' };
  }
  if (b === 'private-code') {
    return { className: 'bg-closed/10 text-closed border-closed/20', text: labels.badgePrivateCode || 'Código Privado' };
  }
  return null;
}

export function initProjects(): void {
  const grid = document.getElementById('projects-grid');
  const status = document.getElementById('projects-status');
  const statusText = document.getElementById('projects-status-text');
  if (!grid || grid.dataset.loaded) return;

  const apiUrl = grid.dataset.api || '';
  const labels: ProjectLabels = JSON.parse(grid.dataset.labels || '{}');

  // --- Modal ---
  const modal = document.getElementById('project-modal') as HTMLElement | null;
  const pmImage = document.getElementById('pm-image') as HTMLImageElement | null;
  const pmTitle = document.getElementById('pm-title');
  const pmDesc = document.getElementById('pm-desc');
  const pmStack = document.getElementById('pm-stack');
  const pmLinks = document.getElementById('pm-links');
  const pmClose = document.getElementById('pm-close');
  let lastFocus: (Element & { focus?: () => void }) | null = null;

  function linkEl(href: string | undefined, text: string, iconSvg: string, isPrimary = false): HTMLAnchorElement | null {
    const safe = safeUrl(href);
    if (!safe) return null;
    const a = document.createElement('a');
    a.href = safe;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';

    const spanText = document.createElement('span');
    spanText.textContent = text;

    a.innerHTML = iconSvg || '';
    a.appendChild(spanText);

    a.className = isPrimary
      ? 'inline-flex items-center gap-1.5 rounded-lg border border-accent bg-accent/10 hover:bg-accent hover:text-bg px-3 py-1.5 text-xs font-semibold text-accent transition duration-200 shadow-xs hover:no-underline'
      : 'inline-flex items-center gap-1.5 rounded-lg border border-bg-border bg-bg-soft/40 hover:bg-bg-card hover:border-text-faint/40 px-3 py-1.5 text-xs font-semibold text-text-muted hover:text-text transition duration-200 shadow-xs hover:no-underline';
    return a;
  }

  function openModal(p: Project): void {
    if (!modal || !pmTitle || !pmDesc || !pmStack || !pmLinks || !pmImage) return;
    lastFocus = document.activeElement as Element | null;
    pmTitle.textContent = p.title || '';
    pmDesc.textContent = p.description || p.summary || '';
    const img = safeUrl(p.image_url);
    if (img) {
      pmImage.src = img;
      pmImage.alt = p.title || '';
      pmImage.classList.remove('hidden');
    } else {
      pmImage.classList.add('hidden');
      pmImage.removeAttribute('src');
    }

    pmStack.innerHTML = '';
    (Array.isArray(p.badges) ? p.badges : []).forEach((b) => {
      const meta = badgeMeta(b, labels);
      if (!meta) return;
      const li = document.createElement('li');
      li.className = `badge ${meta.className} font-semibold`;
      li.textContent = meta.text;
      pmStack.appendChild(li);
    });

    (Array.isArray(p.stack) ? p.stack : []).forEach((s) => {
      const li = document.createElement('li');
      li.className = 'badge';
      li.textContent = s;
      pmStack.appendChild(li);
    });

    pmLinks.innerHTML = '';
    if (p.demo_url) {
      const el = linkEl(p.demo_url, labels.demo, externalSvg, true);
      if (el) pmLinks.appendChild(el);
    }
    if (p.repo_url) {
      const el = linkEl(p.repo_url, labels.repo, githubSvg, false);
      if (el) pmLinks.appendChild(el);
    }
    modal.hidden = false;
    requestAnimationFrame(() => modal.classList.add('open'));
    pmClose?.focus();
  }

  function closeModal(): void {
    if (!modal) return;
    modal.classList.remove('open');
    setTimeout(() => {
      modal.hidden = true;
    }, 180);
    if (lastFocus?.focus) lastFocus.focus();
  }

  if (modal) {
    pmClose?.addEventListener('click', closeModal);
    modal.addEventListener('click', (e) => {
      if (e.target === modal) closeModal();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !modal.hidden) closeModal();
    });
  }

  // --- Tarjeta ---
  function makeCard(p: Project): HTMLElement {
    const card = document.createElement('article');
    card.className =
      'reveal is-visible group flex flex-col overflow-hidden rounded-lg border border-bg-border bg-bg-card transition hover:border-text-faint/40 shadow-xs';

    card.setAttribute('data-badges', Array.isArray(p.badges) && p.badges.length ? p.badges.join(',') : '');

    const img = safeUrl(p.image_url);
    if (img) {
      const wrap = document.createElement('div');
      wrap.className = 'relative aspect-video overflow-hidden bg-bg-soft';
      const im = document.createElement('img');
      im.src = img;
      im.alt = p.title || '';
      im.loading = 'lazy';
      im.decoding = 'async';
      im.className = 'h-full w-full object-cover';
      wrap.appendChild(im);
      if (Number(p.featured) === 1) {
        const b = document.createElement('span');
        b.className = 'absolute left-2 top-2 rounded-sm bg-accent px-1.5 py-0.5 text-[11px] font-semibold text-bg';
        b.textContent = labels.featured;
        wrap.appendChild(b);
      }
      card.appendChild(wrap);
    }

    const body = document.createElement('div');
    body.className = 'flex flex-1 flex-col p-5';

    const h = document.createElement('h3');
    h.className = 'text-base font-semibold text-text';
    h.textContent = p.title || '';
    body.appendChild(h);

    if (Array.isArray(p.badges) && p.badges.length) {
      const badgeContainer = document.createElement('div');
      badgeContainer.className = 'flex flex-wrap gap-1.5 mt-1.5 mb-0.5';
      p.badges.forEach((b) => {
        const meta = badgeMeta(b, labels);
        if (!meta) return;
        const badgeSpan = document.createElement('span');
        badgeSpan.className = `rounded-sm ${meta.className} px-2 py-0.5 text-[10px] font-semibold border`;
        badgeSpan.textContent = meta.text;
        badgeContainer.appendChild(badgeSpan);
      });
      body.appendChild(badgeContainer);
    }

    const sum = document.createElement('p');
    sum.className = 'mt-2 text-sm leading-relaxed text-text-muted';
    sum.textContent = p.summary || '';
    body.appendChild(sum);

    if (Array.isArray(p.stack) && p.stack.length) {
      const st = document.createElement('ul');
      st.className = 'mt-4 flex flex-wrap gap-1.5';
      p.stack.forEach((s) => {
        const li = document.createElement('li');
        li.className = 'rounded-sm border border-bg-border px-1.5 py-0.5 font-mono text-[11px] text-text-muted bg-bg-soft/20';
        li.textContent = s;
        st.appendChild(li);
      });
      body.appendChild(st);
    }

    const links = document.createElement('div');
    links.className = 'mt-auto pt-5 flex flex-wrap items-center gap-2 border-t border-bg-border/40';
    const hasDetail = (p.description && p.description.trim()) || img;
    if (hasDetail) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.innerHTML = eyeSvg + `<span>${labels.details}</span>`;
      btn.className =
        'inline-flex items-center gap-1.5 rounded-lg border border-bg-border bg-bg-soft/40 hover:bg-bg-card hover:border-text-faint/40 px-3 py-1.5 text-xs font-semibold text-text-muted hover:text-text transition duration-200 shadow-xs cursor-pointer';
      btn.addEventListener('click', () => openModal(p));
      links.appendChild(btn);
    }

    if (p.demo_url) {
      const el = linkEl(p.demo_url, labels.demo, externalSvg, true);
      if (el) links.appendChild(el);
    }
    if (p.repo_url) {
      const el = linkEl(p.repo_url, labels.repo, githubSvg, false);
      if (el) links.appendChild(el);
    }

    if (links.childElementCount) body.appendChild(links);

    card.appendChild(body);
    return card;
  }

  // El panel de estado se controla con data-state; el CSS decide el icono y
  // si sale el boton de reintento (ver StatusPanel.astro).
  function setState(state: 'loading' | 'empty' | 'error', text: string): void {
    if (statusText) statusText.textContent = text;
    if (status) {
      status.setAttribute('data-state', state);
      status.classList.remove('hidden');
    }
  }

  function message(text: string): void {
    setState('empty', text);
  }

  function fetchWithRetry(url: string, options: RequestInit = {}, retries = 3, delay = 500): Promise<unknown> {
    return fetch(url, options)
      .then((res) => {
        if (!res.ok) {
          if (retries > 0) {
            return new Promise((resolve) => setTimeout(resolve, delay)).then(() =>
              fetchWithRetry(url, options, retries - 1, delay * 1.5),
            );
          }
          throw new Error('HTTP ' + res.status);
        }
        return res.json();
      })
      .catch((err) => {
        if (retries > 0) {
          return new Promise((resolve) => setTimeout(resolve, delay)).then(() =>
            fetchWithRetry(url, options, retries - 1, delay * 1.5),
          );
        }
        throw err;
      });
  }

  function loadProjects(): void {
    setState('loading', labels.loading);
    grid.innerHTML = '';
    fetchWithRetry(apiUrl, { headers: { Accept: 'application/json' } })
      .then((data) => {
        grid.dataset.loaded = '1';
        const items: Project[] = Array.isArray(data) ? data : (data as { items?: Project[] })?.items || [];
        if (status) status.classList.add('hidden');
        if (!items.length) return message(labels.empty);

        const filtersContainer = document.getElementById('projects-filters');
        if (filtersContainer) filtersContainer.classList.remove('hidden');

        items.forEach((p) => grid.appendChild(makeCard(p)));

        const filterButtons = document.querySelectorAll<HTMLButtonElement>('.project-filter-btn');
        filterButtons.forEach((btn) => {
          btn.addEventListener('click', () => {
            filterButtons.forEach((b) => {
              b.classList.remove('bg-accent', 'text-bg', 'border-accent');
              b.classList.add('bg-bg-soft/40', 'text-text-muted', 'border-bg-border/60');
            });
            btn.classList.add('bg-accent', 'text-bg', 'border-accent');
            btn.classList.remove('bg-bg-soft/40', 'text-text-muted', 'border-bg-border/60');

            const filterValue = btn.getAttribute('data-filter');
            const cards = grid.querySelectorAll('article');
            cards.forEach((card) => {
              const badgesAttr = card.getAttribute('data-badges') || '';
              const badges = badgesAttr ? badgesAttr.split(',') : [];
              if (filterValue === 'all' || badges.includes(filterValue || '')) {
                card.classList.remove('hidden');
              } else {
                card.classList.add('hidden');
              }
            });
          });
        });
      })
      .catch(() => setState('error', labels.error));
  }

  status?.querySelector('.status-retry')?.addEventListener('click', loadProjects);
  loadProjects();
}
