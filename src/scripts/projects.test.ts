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
