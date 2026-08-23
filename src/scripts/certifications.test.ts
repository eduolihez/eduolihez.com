import { describe, it, expect, vi, afterEach } from 'vitest';
import { initCerts, safeUrl, issuerColor } from './certifications';

function setupGrid() {
  document.body.innerHTML = `
    <section id="certificaciones"></section>
    <div id="certs-counter" data-target="0">0</div>
    <div id="certs-status" class="hidden">
      <span id="certs-status-text"></span>
      <button class="status-retry">Reintentar</button>
    </div>
    <input id="certs-search" />
    <div id="certs-filter-container">
      <button type="button" class="cert-filter-btn is-active" data-filter="all">Todas</button>
      <button type="button" class="cert-filter-btn" data-filter="cyber">Ciberseguridad</button>
    </div>
    <div id="certs-breadcrumb" class="hidden">
      <button id="certs-back-btn"></button>
      <span id="certs-breadcrumb-current"></span>
    </div>
    <div
      id="certs-grid"
      data-api="/api/certifications.php"
      data-labels='{"loading":"Cargando","error":"Error","empty":"Sin certificaciones","credentials":"credenciales","credential":"credencial","back":"Todas","viewIssuer":"Ver certificaciones de"}'
    ></div>
    <div id="certs-load-more-container" class="hidden">
      <button id="certs-load-more-btn"></button>
    </div>
  `;
  return document.getElementById('certs-grid') as HTMLElement;
}

function mockFetchOnce(response: { ok: boolean; json?: () => Promise<unknown> }) {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValueOnce({ ok: response.ok, json: response.json ?? (() => Promise.resolve([])) }),
  );
}

const sampleCert = {
  name: 'Fortinet NSE',
  issuer: 'Fortinet',
  category: 'Cybersecurity',
  issue_date: '2026-01',
};

describe('initCerts()', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    document.body.innerHTML = '';
  });

  it('no hace nada si #certs-grid no existe', () => {
    document.body.innerHTML = '';
    expect(() => initCerts()).not.toThrow();
  });

  it('no vuelve a pedir datos si el grid ya esta cargado', () => {
    const grid = setupGrid();
    grid.dataset.loaded = '1';
    mockFetchOnce({ ok: true, json: () => Promise.resolve([sampleCert]) });

    initCerts();

    expect(fetch).not.toHaveBeenCalled();
  });

  it('agrupa por emisor en la vista "Todas" cuando hay certificaciones', async () => {
    const grid = setupGrid();
    mockFetchOnce({
      ok: true,
      json: () =>
        Promise.resolve([sampleCert, { ...sampleCert, name: 'Fortinet NSE 2' }, { ...sampleCert, issuer: 'Microsoft', name: 'Azure AI' }]),
    });

    initCerts();
    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

    expect(grid.dataset.loaded).toBe('1');
    // Vista resumen: una tarjeta-boton por emisor, no una por certificacion.
    expect(grid.querySelectorAll('button').length).toBe(2);
    expect(grid.textContent).toContain('Fortinet');
    expect(grid.textContent).toContain('Microsoft');
  });

  it('muestra el estado vacio cuando la API devuelve un array vacio', async () => {
    setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([]) });

    initCerts();

    const status = document.getElementById('certs-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('empty'), { timeout: 3000 });
    expect(document.getElementById('certs-status-text')?.textContent).toBe('Sin certificaciones');
  });

  it('el filtro de busqueda sale del detalle de un emisor y aplica el termino', async () => {
    const grid = setupGrid();
    mockFetchOnce({
      ok: true,
      json: () => Promise.resolve([sampleCert, { ...sampleCert, issuer: 'Microsoft', name: 'Azure AI' }]),
    });

    initCerts();
    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

    const search = document.getElementById('certs-search') as HTMLInputElement;
    search.value = 'fortinet';
    search.dispatchEvent(new Event('input'));

    // Con busqueda activa se sale de la vista-resumen y se listan
    // certificaciones sueltas que coincidan, no tarjetas de emisor.
    expect(grid.textContent).toContain('Fortinet NSE');
    expect(grid.textContent).not.toContain('Azure AI');
  });

  it('el boton de reintento vuelve a pedir los datos', async () => {
    vi.useFakeTimers();
    try {
      setupGrid();
      // mockResolvedValue (no *Once): la cascada de reintentos de
      // fetchWithRetry llama a fetch varias veces antes de agotarse.
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false }));
      initCerts();
      await vi.runAllTimersAsync();

      const status = document.getElementById('certs-status') as HTMLElement;
      expect(status.getAttribute('data-state')).toBe('error');

      vi.stubGlobal('fetch', vi.fn().mockResolvedValueOnce({ ok: true, json: () => Promise.resolve([sampleCert]) }));
      status.querySelector<HTMLButtonElement>('.status-retry')?.click();
      await vi.runAllTimersAsync();

      expect(status.getAttribute('data-state')).not.toBe('error');
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('safeUrl() (Certifications)', () => {
  it('permite http(s), rutas relativas y mailto', () => {
    expect(safeUrl('https://credly.com/badges/x')).toBe('https://credly.com/badges/x');
    expect(safeUrl('mailto:hola@example.com')).toBe('mailto:hola@example.com');
  });

  it('bloquea esquemas ejecutables', () => {
    expect(safeUrl('javascript:alert(1)')).toBe('');
  });
});

describe('issuerColor()', () => {
  it('es deterministico: el mismo nombre siempre da el mismo color', () => {
    expect(issuerColor('Fortinet')).toBe(issuerColor('Fortinet'));
  });

  it('devuelve uno de los 4 tokens de la paleta del sistema', () => {
    const palette = ['var(--color-accent)', 'var(--color-accent-cyan)', 'var(--color-violet)', 'var(--color-closed)'];
    expect(palette).toContain(issuerColor('Microsoft'));
    expect(palette).toContain(issuerColor('Trend Micro'));
  });
});
