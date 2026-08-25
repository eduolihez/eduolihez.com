import { describe, it, expect, vi, afterEach } from 'vitest';
import { initProjects, safeUrl } from './projects';

function setupGrid() {
  document.body.innerHTML = `
    <div id="projects-filters" class="hidden"></div>
    <div id="projects-status" data-state="loading" class="hidden">
      <span id="projects-status-text"></span>
      <button class="status-retry">Reintentar</button>
    </div>
    <div
      id="projects-grid"
      data-api="/api/projects.php"
      data-labels='{"loading":"Cargando","empty":"Sin proyectos","error":"Error","details":"Ver detalles","demo":"Demo","repo":"Codigo","featured":"Destacado"}'
    ></div>
    <div id="project-modal" hidden>
      <img id="pm-image" class="hidden" />
      <h3 id="pm-title"></h3>
      <p id="pm-desc"></p>
      <ul id="pm-stack"></ul>
      <div id="pm-links"></div>
      <button id="pm-close"></button>
    </div>
  `;
  return document.getElementById('projects-grid') as HTMLElement;
}

/** Variante sin #project-modal en el DOM (paginas que listan proyectos sin modal de detalle). */
function setupGridWithoutModal() {
  document.body.innerHTML = `
    <div id="projects-filters" class="hidden"></div>
    <div id="projects-status" data-state="loading" class="hidden">
      <span id="projects-status-text"></span>
      <button class="status-retry">Reintentar</button>
    </div>
    <div
      id="projects-grid"
      data-api="/api/projects.php"
      data-labels='{"loading":"Cargando","empty":"Sin proyectos","error":"Error","details":"Ver detalles","demo":"Demo","repo":"Codigo","featured":"Destacado"}'
    ></div>
  `;
  return document.getElementById('projects-grid') as HTMLElement;
}

function mockFetchOnce(response: { ok: boolean; json?: () => Promise<unknown> }) {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValueOnce({ ok: response.ok, json: response.json ?? (() => Promise.resolve([])) }),
  );
}

const sampleProject = {
  title: 'FollowGuard',
  summary: 'Ciberinteligencia para redes sociales.',
  badges: ['open-source'],
  stack: ['Python'],
  repo_url: 'https://github.com/eduolihez/followguard',
};

describe('initProjects()', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    document.body.innerHTML = '';
  });

  it('no hace nada si #projects-grid no existe', () => {
    document.body.innerHTML = '';
    expect(() => initProjects()).not.toThrow();
  });

  it('no vuelve a pedir datos si el grid ya esta cargado', () => {
    const grid = setupGrid();
    grid.dataset.loaded = '1';
    mockFetchOnce({ ok: true, json: () => Promise.resolve([sampleProject]) });

    initProjects();

    expect(fetch).not.toHaveBeenCalled();
  });

  it('pinta las tarjetas y muestra los filtros cuando hay proyectos', async () => {
    const grid = setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([sampleProject]) });

    initProjects();
    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

    expect(grid.dataset.loaded).toBe('1');
    expect(grid.querySelector('article')).not.toBeNull();
    expect(document.getElementById('projects-filters')?.classList.contains('hidden')).toBe(false);
  });

  it('usa los tokens de badge oss/wip/closed, no clases Tailwind crudas', async () => {
    const grid = setupGrid();
    mockFetchOnce({
      ok: true,
      json: () =>
        Promise.resolve([
          { ...sampleProject, badges: ['open-source', 'in-development', 'private-code'] },
        ]),
    });

    initProjects();
    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

    const badgeSpans = Array.from(grid.querySelectorAll('span')).map((s) => s.className);
    expect(badgeSpans.some((c) => c.includes('bg-oss'))).toBe(true);
    expect(badgeSpans.some((c) => c.includes('bg-wip'))).toBe(true);
    expect(badgeSpans.some((c) => c.includes('bg-closed'))).toBe(true);
    expect(badgeSpans.some((c) => c.includes('bg-emerald') || c.includes('bg-amber') || c.includes('bg-blue'))).toBe(
      false,
    );
  });

  it('muestra el estado vacio cuando la API devuelve un array vacio', async () => {
    setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([]) });

    initProjects();

    const status = document.getElementById('projects-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('empty'), { timeout: 3000 });
    expect(document.getElementById('projects-status-text')?.textContent).toBe('Sin proyectos');
  });

  it('el boton de reintento vuelve a pedir los datos sin duplicar el listener', async () => {
    vi.useFakeTimers();
    try {
      const grid = setupGrid();
      // Todas las respuestas fallan -> fetchWithRetry agota sus reintentos.
      // Con temporizadores falsos, runAllTimersAsync() vacia esa cascada
      // entera de una vez en vez de esperar los delays reales (500/750/1125ms).
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false }));
      initProjects();
      await vi.runAllTimersAsync();

      const status = document.getElementById('projects-status') as HTMLElement;
      expect(status.getAttribute('data-state')).toBe('error');

      vi.stubGlobal(
        'fetch',
        vi.fn().mockResolvedValueOnce({ ok: true, json: () => Promise.resolve([sampleProject]) }),
      );
      status.querySelector<HTMLButtonElement>('.status-retry')?.click();
      await vi.runAllTimersAsync();

      expect(grid.children.length).toBeGreaterThan(0);
      // Un solo click == una sola llamada a fetch con el mock de arriba: si el
      // listener estuviera duplicado, la segunda llamada agotaria el
      // mockResolvedValueOnce y la carga habria fallado en vez de pintar tarjetas.
      expect(fetch).toHaveBeenCalledTimes(1);
    } finally {
      vi.useRealTimers();
    }
  });

  it('muestra el estado de error si fetch rechaza (sin red), no solo cuando responde !ok', async () => {
    vi.useFakeTimers();
    try {
      setupGrid();
      vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network down')));
      initProjects();
      await vi.runAllTimersAsync();

      const status = document.getElementById('projects-status') as HTMLElement;
      expect(status.getAttribute('data-state')).toBe('error');
    } finally {
      vi.useRealTimers();
    }
  });

  it('el filtro por badge muestra y oculta tarjetas segun data-badges', async () => {
    const grid = setupGrid();
    // El listener de cada boton de filtro se registra UNA vez, cuando
    // loadProjects() resuelve y hace el querySelectorAll('.project-filter-btn')
    // -- el boton tiene que existir en el DOM ANTES de esa resolucion.
    document.body.insertAdjacentHTML(
      'beforeend',
      '<button class="project-filter-btn" data-filter="open-source">OSS</button>',
    );
    mockFetchOnce({
      ok: true,
      json: () =>
        Promise.resolve([
          { ...sampleProject, title: 'OSS', badges: ['open-source'] },
          { ...sampleProject, title: 'Privado', badges: ['private-code'] },
        ]),
    });

    initProjects();
    await vi.waitFor(() => expect(grid.querySelectorAll('article').length).toBe(2));

    const filterBtn = document.querySelector<HTMLButtonElement>('.project-filter-btn[data-filter="open-source"]')!;
    filterBtn.click();

    const cards = Array.from(grid.querySelectorAll('article'));
    const visible = cards.filter((c) => !c.classList.contains('hidden'));
    expect(visible.length).toBe(1);
    expect(visible[0].textContent).toContain('OSS');
  });

  describe('modal de detalle', () => {
    it('se abre al pulsar "Ver detalles" y rellena titulo, descripcion y enlaces', async () => {
      const grid = setupGrid();
      mockFetchOnce({
        ok: true,
        json: () =>
          Promise.resolve([
            {
              ...sampleProject,
              title: 'FollowGuard',
              description: 'Descripcion larga del proyecto.',
              demo_url: 'https://followguard.example.com',
            },
          ]),
      });

      initProjects();
      await vi.waitFor(() => expect(grid.querySelector('article')).not.toBeNull());

      const detailBtn = Array.from(grid.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('Ver detalles'),
      )!;
      detailBtn.click();

      const modal = document.getElementById('project-modal') as HTMLElement;
      expect(modal.hidden).toBe(false);
      expect(document.getElementById('pm-title')?.textContent).toBe('FollowGuard');
      expect(document.getElementById('pm-desc')?.textContent).toBe('Descripcion larga del proyecto.');
      expect(document.getElementById('pm-links')?.querySelectorAll('a').length).toBe(2); // demo + repo
    });

    it('mueve el foco al boton de cerrar al abrir, y lo devuelve al disparador al cerrar', async () => {
      const grid = setupGrid();
      mockFetchOnce({
        ok: true,
        json: () => Promise.resolve([{ ...sampleProject, description: 'Descripcion.' }]),
      });

      initProjects();
      await vi.waitFor(() => expect(grid.querySelector('article')).not.toBeNull());

      const detailBtn = Array.from(grid.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('Ver detalles'),
      )!;
      detailBtn.focus();
      detailBtn.click();

      const pmClose = document.getElementById('pm-close');
      expect(document.activeElement).toBe(pmClose);

      pmClose?.click();
      vi.useFakeTimers();
      try {
        await vi.advanceTimersByTimeAsync(200); // closeModal() oculta el modal tras 180ms
      } finally {
        vi.useRealTimers();
      }
      expect(document.activeElement).toBe(detailBtn);
    });

    it('se cierra al hacer click en el backdrop (fuera del contenido)', async () => {
      const grid = setupGrid();
      mockFetchOnce({
        ok: true,
        json: () => Promise.resolve([{ ...sampleProject, description: 'Descripcion.' }]),
      });

      initProjects();
      await vi.waitFor(() => expect(grid.querySelector('article')).not.toBeNull());

      const detailBtn = Array.from(grid.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('Ver detalles'),
      )!;
      detailBtn.click();

      const modal = document.getElementById('project-modal') as HTMLElement;
      expect(modal.hidden).toBe(false);
      modal.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      // El listener del modal comprueba e.target === modal; jsdom entrega el
      // propio modal como target cuando se dispara directamente sobre el.
      expect(modal.classList.contains('open')).toBe(false);
    });

    it('se cierra con la tecla Escape', async () => {
      const grid = setupGrid();
      mockFetchOnce({
        ok: true,
        json: () => Promise.resolve([{ ...sampleProject, description: 'Descripcion.' }]),
      });

      initProjects();
      await vi.waitFor(() => expect(grid.querySelector('article')).not.toBeNull());

      const detailBtn = Array.from(grid.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('Ver detalles'),
      )!;
      detailBtn.click();

      const modal = document.getElementById('project-modal') as HTMLElement;
      expect(modal.hidden).toBe(false);

      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      expect(modal.classList.contains('open')).toBe(false);
    });

    it('solo registra UN listener de Escape en toda la pagina aunque initProjects() corra varias veces', async () => {
      // Regresion: antes cada llamada a initProjects() (p.ej. tras
      // astro:page-load en cada transicion cliente) anadia un nuevo
      // document.addEventListener('keydown', ...) sin quitar el anterior. El
      // guard vive en una variable de MODULO (escapeListenerBound), asi que
      // este test necesita una instancia de modulo fresca -- si reutilizara
      // el modulo ya importado arriba, el guard podria seguir en `true` por
      // culpa de un test anterior en este mismo archivo.
      vi.resetModules();
      const { initProjects: freshInitProjects } = await import('./projects');
      const addSpy = vi.spyOn(document, 'addEventListener');

      const withDetail = { ...sampleProject, description: 'Descripcion.' };

      const grid1 = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve([withDetail]) });
      freshInitProjects();
      await vi.waitFor(() => expect(grid1.querySelector('article')).not.toBeNull());

      // Segunda "pagina": grid nuevo, fresco (sin data-loaded), simulando
      // una transicion astro:page-load con un modal distinto en el DOM.
      const grid2 = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve([withDetail]) });
      freshInitProjects();
      await vi.waitFor(() => expect(grid2.querySelector('article')).not.toBeNull());

      const keydownCalls = addSpy.mock.calls.filter(([type]) => type === 'keydown');
      expect(keydownCalls.length).toBe(1);

      // Y el listener unico sigue funcionando sobre el modal MAS RECIENTE.
      const detailBtn = Array.from(grid2.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('Ver detalles'),
      )!;
      detailBtn.click();
      const modal = document.getElementById('project-modal') as HTMLElement;
      expect(modal.hidden).toBe(false);
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      expect(modal.classList.contains('open')).toBe(false);

      addSpy.mockRestore();
    });

    it('si una pagina posterior no tiene modal, Escape no lanza (el handler se queda con el ultimo modal conocido)', async () => {
      // Caso limite de la variable de modulo currentModalCloseHandler: si
      // initProjects() se re-ejecuta en una pagina SIN #project-modal, el
      // bloque `if (modal)` no reasigna el handler, que se queda apuntando
      // al modal (ya desmontado) de la pagina anterior. No debe lanzar.
      vi.resetModules();
      const { initProjects: freshInitProjects } = await import('./projects');

      const withDetail = { ...sampleProject, description: 'Descripcion.' };

      const grid1 = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve([withDetail]) });
      freshInitProjects();
      await vi.waitFor(() => expect(grid1.querySelector('article')).not.toBeNull());

      const detailBtn = Array.from(grid1.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('Ver detalles'),
      )!;
      detailBtn.click();
      expect((document.getElementById('project-modal') as HTMLElement).hidden).toBe(false);

      // Pagina siguiente: mismo grid-id, pero SIN #project-modal en el DOM.
      const grid2 = setupGridWithoutModal();
      mockFetchOnce({ ok: true, json: () => Promise.resolve([sampleProject]) });
      freshInitProjects();
      await vi.waitFor(() => expect(grid2.querySelector('article')).not.toBeNull());

      expect(document.getElementById('project-modal')).toBeNull();
      expect(() =>
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })),
      ).not.toThrow();
    });
  });

  it('el reintento vuelve a mostrar el estado de carga en vez de quedarse en error', async () => {
    vi.useFakeTimers();
    try {
      setupGrid();
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false }));
      initProjects();
      await vi.runAllTimersAsync();

      const status = document.getElementById('projects-status') as HTMLElement;
      expect(status.getAttribute('data-state')).toBe('error');

      vi.stubGlobal(
        'fetch',
        vi.fn().mockResolvedValueOnce({ ok: true, json: () => Promise.resolve([sampleProject]) }),
      );
      status.querySelector<HTMLButtonElement>('.status-retry')?.click();

      // setState('loading', ...) se ejecuta de forma sincrona al inicio de
      // loadProjects(), antes de esperar la respuesta de fetch.
      expect(status.getAttribute('data-state')).toBe('loading');

      // Al exito el panel se oculta (igual que certifications.ts); data-state
      // no se reescribe porque ya no es visible.
      await vi.runAllTimersAsync();
      expect(status.classList.contains('hidden')).toBe(true);
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('safeUrl() (Projects)', () => {
  it('permite http(s), rutas relativas y mailto', () => {
    expect(safeUrl('https://example.com')).toBe('https://example.com');
    expect(safeUrl('/img.png')).toBe('/img.png');
    expect(safeUrl('mailto:hola@example.com')).toBe('mailto:hola@example.com');
  });

  it('bloquea esquemas ejecutables', () => {
    expect(safeUrl('javascript:alert(1)')).toBe('');
    expect(safeUrl('data:text/html,<script>alert(1)</script>')).toBe('');
  });
});
