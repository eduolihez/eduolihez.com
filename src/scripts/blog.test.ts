import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { initBlogList, initStaticBlogFilters, escapeHtml, safeUrl, formatDate } from './blog';

function setupGrid(overrides: Partial<Record<string, string>> = {}) {
  document.body.innerHTML = `
    <div id="blog-status" data-state="loading" class="hidden">
      <span id="blog-status-text"></span>
      <button class="status-retry">Reintentar</button>
    </div>
    <div
      id="blog-grid"
      data-api="/api/posts.php"
      data-loading="Cargando"
      data-empty="No hay articulos"
      data-error="Error al cargar"
      data-readmore="Leer mas"
      data-lang="es"
      data-detail="/blog/post/"
    ></div>
  `;
  const grid = document.getElementById('blog-grid') as HTMLElement;
  for (const [key, value] of Object.entries(overrides)) {
    grid.dataset[key] = value;
  }
  return grid;
}

function mockFetchOnce(response: { ok: boolean; json?: () => Promise<unknown> }) {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValueOnce({
      ok: response.ok,
      json: response.json ?? (() => Promise.resolve([])),
    }),
  );
}

const samplePost = {
  id: 1,
  title: 'Deteccion de phishing con Python',
  slug: 'deteccion-phishing-python',
  summary: 'Como automatizar el triage de correos sospechosos.',
  lang: 'es',
  published_at: '2026-01-15 10:00:00',
};

describe('initBlogList()', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    document.body.innerHTML = '';
  });

  it('no hace nada si #blog-grid no existe en la pagina', () => {
    document.body.innerHTML = '';
    expect(() => initBlogList()).not.toThrow();
  });

  it('no vuelve a pedir datos si el grid ya esta cargado (guardia anti-doble-init)', () => {
    const grid = setupGrid({ loaded: '1' });
    mockFetchOnce({ ok: true, json: () => Promise.resolve([samplePost]) });

    initBlogList();

    expect(fetch).not.toHaveBeenCalled();
    expect(grid.children.length).toBe(0);
  });

  it('pinta las tarjetas cuando la API devuelve articulos', async () => {
    const grid = setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([samplePost]) });

    initBlogList();
    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

    expect(grid.dataset.loaded).toBe('1');
    expect(grid.querySelector('article')).not.toBeNull();
    expect(grid.classList.contains('hidden')).toBe(false);
    const status = document.getElementById('blog-status');
    expect(status?.classList.contains('hidden')).toBe(true);
  });

  it('muestra el estado vacio cuando la API devuelve un array vacio', async () => {
    setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([]) });

    initBlogList();

    const status = document.getElementById('blog-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('empty'));

    expect(document.getElementById('blog-status-text')?.textContent).toBe('No hay articulos');
    expect(status.classList.contains('hidden')).toBe(false);
  });

  it('muestra el estado de error si la respuesta HTTP no es ok', async () => {
    setupGrid();
    mockFetchOnce({ ok: false });

    initBlogList();

    const status = document.getElementById('blog-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('error'));

    expect(document.getElementById('blog-status-text')?.textContent).toBe('Error al cargar');
  });

  it('muestra el estado de error si fetch rechaza (sin red)', async () => {
    setupGrid();
    vi.stubGlobal('fetch', vi.fn().mockRejectedValueOnce(new Error('network down')));

    initBlogList();

    const status = document.getElementById('blog-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('error'));
  });

  it('el boton de reintento vuelve a pedir los datos sin duplicar el listener', async () => {
    const grid = setupGrid();
    // Primera carga: falla.
    mockFetchOnce({ ok: false });
    initBlogList();

    const status = document.getElementById('blog-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('error'));

    // Reintento: ahora la API responde bien.
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValueOnce({ ok: true, json: () => Promise.resolve([samplePost]) }),
    );
    status.querySelector<HTMLButtonElement>('.status-retry')?.click();

    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));
    // Un solo click == una sola llamada a fetch en este segundo mock: si el
    // listener se hubiera registrado dos veces, fetch se habria llamado dos
    // veces con el mismo mockResolvedValueOnce y la segunda habria fallado
    // por falta de valor (mock agotado), rompiendo el test.
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('el reintento vuelve a mostrar el estado de carga en vez de quedarse en error (regresion)', async () => {
    const grid = setupGrid();
    mockFetchOnce({ ok: false });
    initBlogList();

    const status = document.getElementById('blog-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('error'));

    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValueOnce({ ok: true, json: () => Promise.resolve([samplePost]) }),
    );
    status.querySelector<HTMLButtonElement>('.status-retry')?.click();

    // setState('loading', ...) se ejecuta de forma sincrona al inicio de
    // loadPosts(), antes de esperar la respuesta de fetch.
    expect(status.getAttribute('data-state')).toBe('loading');
    expect(document.getElementById('blog-status-text')?.textContent).toBe('Cargando');

    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));
    expect(status.classList.contains('hidden')).toBe(true);
  });
});

describe('initStaticBlogFilters()', () => {
  function setupStaticGrid() {
    document.body.innerHTML = `
      <div id="blog-filters">
        <button type="button" class="blog-filter-btn border-accent bg-accent text-bg" data-filter="all">Todos</button>
        <button type="button" class="blog-filter-btn border-bg-border/60" data-filter="python">python</button>
        <button type="button" class="blog-filter-btn border-bg-border/60" data-filter="soc">soc</button>
      </div>
      <div id="blog-grid">
        <article data-tags="python,soc"><h2>A</h2></article>
        <article data-tags="python"><h2>B</h2></article>
        <article data-tags="soc"><h2>C</h2></article>
      </div>
    `;
  }

  it('no lanza si faltan los contenedores', () => {
    document.body.innerHTML = '';
    expect(() => initStaticBlogFilters()).not.toThrow();
  });

  it('oculta las tarjetas que no tienen la etiqueta seleccionada', () => {
    setupStaticGrid();
    initStaticBlogFilters();

    document.querySelector<HTMLButtonElement>('[data-filter="python"]')?.click();

    const articles = [...document.querySelectorAll<HTMLElement>('#blog-grid article')];
    expect(articles.map((a) => a.classList.contains('hidden'))).toEqual([false, false, true]);
  });

  it('vuelve a mostrar todas las tarjetas al elegir "Todos"', () => {
    setupStaticGrid();
    initStaticBlogFilters();

    document.querySelector<HTMLButtonElement>('[data-filter="soc"]')?.click();
    document.querySelector<HTMLButtonElement>('[data-filter="all"]')?.click();

    const articles = [...document.querySelectorAll<HTMLElement>('#blog-grid article')];
    expect(articles.every((a) => !a.classList.contains('hidden'))).toBe(true);
  });

  it('marca como activo solo el boton pulsado', () => {
    setupStaticGrid();
    initStaticBlogFilters();

    const pythonBtn = document.querySelector<HTMLButtonElement>('[data-filter="python"]')!;
    pythonBtn.click();

    expect(pythonBtn.className).toContain('bg-accent');
    const allBtn = document.querySelector<HTMLButtonElement>('[data-filter="all"]')!;
    expect(allBtn.className).not.toContain('bg-accent');
  });

  it('ignora clicks fuera de un boton de filtro', () => {
    setupStaticGrid();
    initStaticBlogFilters();
    const filters = document.getElementById('blog-filters')!;

    expect(() => filters.click()).not.toThrow();
  });
});

describe('escapeHtml()', () => {
  it('escapa las entidades HTML peligrosas', () => {
    expect(escapeHtml('<script>alert(1)</script>')).toBe(
      '&lt;script&gt;alert(1)&lt;/script&gt;',
    );
    expect(escapeHtml(`"' & <>`)).toBe('&quot;&#39; &amp; &lt;&gt;');
  });

  it('convierte null/undefined en cadena vacia en vez de "null"/"undefined"', () => {
    expect(escapeHtml(null)).toBe('');
    expect(escapeHtml(undefined)).toBe('');
  });
});

describe('safeUrl()', () => {
  it('permite http(s) y rutas relativas', () => {
    expect(safeUrl('https://example.com/img.png')).toBe('https://example.com/img.png');
    expect(safeUrl('/img.png')).toBe('/img.png');
  });

  it('bloquea esquemas ejecutables', () => {
    expect(safeUrl('javascript:alert(1)')).toBe('');
    expect(safeUrl('data:text/html,<script>alert(1)</script>')).toBe('');
    expect(safeUrl('vbscript:msgbox(1)')).toBe('');
  });

  it('devuelve cadena vacia si no es un string', () => {
    expect(safeUrl(null)).toBe('');
    expect(safeUrl(undefined)).toBe('');
  });
});

describe('formatDate()', () => {
  it('devuelve cadena vacia si no hay fecha', () => {
    expect(formatDate('', 'es')).toBe('');
  });

  it('devuelve la cadena original si la fecha no es valida', () => {
    expect(formatDate('no-es-una-fecha', 'es')).toBe('no-es-una-fecha');
  });

  it('formatea una fecha valida sin lanzar', () => {
    const result = formatDate('2026-01-15 10:00:00', 'es');
    expect(result).not.toBe('');
    expect(result).not.toBe('2026-01-15 10:00:00');
  });
});
