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
      <button type="button" class="cert-filter-btn" data-filter="ai-cloud">IA &amp; Cloud</button>
      <button type="button" class="cert-filter-btn" data-filter="cisco">Cisco</button>
      <button type="button" class="cert-filter-btn" data-filter="tryhackme">TryHackMe</button>
      <button type="button" class="cert-filter-btn" data-filter="sys-dev">Sistemas &amp; Dev</button>
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

  it('muestra el estado de error si fetch rechaza (sin red), no solo cuando responde !ok', async () => {
    vi.useFakeTimers();
    try {
      setupGrid();
      vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network down')));
      initCerts();
      await vi.runAllTimersAsync();

      const status = document.getElementById('certs-status') as HTMLElement;
      expect(status.getAttribute('data-state')).toBe('error');
    } finally {
      vi.useRealTimers();
    }
  });

  describe('filtro por categoria', () => {
    const mixed = [
      { ...sampleCert, name: 'Fortinet NSE', issuer: 'Fortinet', category: 'Network Security' },
      { ...sampleCert, name: 'Azure AI', issuer: 'Microsoft', category: 'AI / Cloud' },
      { ...sampleCert, name: 'Intro Ciberseguridad', issuer: 'Cisco Networking Academy', category: 'Cybersecurity' },
      { ...sampleCert, name: 'Pre-Security', issuer: 'TryHackMe', category: 'Cybersecurity' },
      { ...sampleCert, name: 'IT Specialist', issuer: 'Certiport', category: 'Desarrollo' },
    ];

    async function loadMixed() {
      const grid = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve(mixed) });
      initCerts();
      await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));
      return grid;
    }

    it('"cyber" filtra por categoria (security/secops/intel/cyber) o por emisor TryHackMe', async () => {
      // La condicion mas compleja de las 5 (5 checks con OR): category
      // "Network Security" case por "security", "Cybersecurity" case por
      // "cyber", y TryHackMe caeria aunque su categoria no dijera nada de
      // seguridad, solo por venir de ese emisor.
      const grid = await loadMixed();
      document.querySelector<HTMLButtonElement>('[data-filter="cyber"]')!.click();

      expect(grid.textContent).toContain('Fortinet NSE'); // categoria "Network Security"
      expect(grid.textContent).toContain('Intro Ciberseguridad'); // categoria "Cybersecurity"
      expect(grid.textContent).toContain('Pre-Security'); // categoria "Cybersecurity" + emisor TryHackMe
      expect(grid.textContent).not.toContain('Azure AI'); // "AI / Cloud", no matchea nada de cyber
      expect(grid.textContent).not.toContain('IT Specialist'); // "Desarrollo"
    });

    it('"ai-cloud" filtra por categoria que contiene "ai" o "cloud"', async () => {
      const grid = await loadMixed();
      document.querySelector<HTMLButtonElement>('[data-filter="ai-cloud"]')!.click();
      expect(grid.textContent).toContain('Azure AI');
      expect(grid.textContent).not.toContain('Fortinet NSE');
    });

    it('"cisco" filtra por emisor, no por categoria', async () => {
      const grid = await loadMixed();
      document.querySelector<HTMLButtonElement>('[data-filter="cisco"]')!.click();
      expect(grid.textContent).toContain('Intro Ciberseguridad');
      expect(grid.textContent).not.toContain('Azure AI');
    });

    it('"tryhackme" filtra por emisor', async () => {
      const grid = await loadMixed();
      document.querySelector<HTMLButtonElement>('[data-filter="tryhackme"]')!.click();
      expect(grid.textContent).toContain('Pre-Security');
      expect(grid.textContent).not.toContain('Intro Ciberseguridad');
    });

    it('"sys-dev" filtra por categoria "desarrollo"/"sistemas"', async () => {
      const grid = await loadMixed();
      document.querySelector<HTMLButtonElement>('[data-filter="sys-dev"]')!.click();
      expect(grid.textContent).toContain('IT Specialist');
      expect(grid.textContent).not.toContain('Azure AI');
    });

    it('marca is-active solo en el boton del filtro elegido', async () => {
      await loadMixed();
      const ciscoBtn = document.querySelector<HTMLButtonElement>('[data-filter="cisco"]')!;
      const allBtn = document.querySelector<HTMLButtonElement>('[data-filter="all"]')!;
      ciscoBtn.click();
      expect(ciscoBtn.classList.contains('is-active')).toBe(true);
      expect(allBtn.classList.contains('is-active')).toBe(false);
    });
  });

  describe('drill-down de emisor', () => {
    it('al pulsar la tarjeta de un emisor, muestra sus certificaciones sueltas y las migas de pan', async () => {
      const grid = setupGrid();
      mockFetchOnce({
        ok: true,
        json: () =>
          Promise.resolve([
            sampleCert,
            { ...sampleCert, name: 'Fortinet NSE 2' },
            { ...sampleCert, issuer: 'Microsoft', name: 'Azure AI' },
          ]),
      });

      initCerts();
      await vi.waitFor(() => expect(grid.querySelectorAll('button').length).toBe(2)); // 2 emisores

      const fortinetCard = Array.from(grid.querySelectorAll('button')).find((b) =>
        b.textContent?.includes('Fortinet'),
      )!;
      fortinetCard.click();

      // Ahora se listan certificaciones sueltas de Fortinet, no tarjetas de emisor.
      expect(grid.textContent).toContain('Fortinet NSE 2');
      expect(grid.textContent).not.toContain('Azure AI');

      const breadcrumb = document.getElementById('certs-breadcrumb') as HTMLElement;
      expect(breadcrumb.classList.contains('hidden')).toBe(false);
      expect(document.getElementById('certs-breadcrumb-current')?.textContent).toBe('Fortinet');
    });

    it('el boton "Todas" de las migas vuelve a la vista resumen por emisor', async () => {
      const grid = setupGrid();
      mockFetchOnce({
        ok: true,
        json: () =>
          Promise.resolve([sampleCert, { ...sampleCert, issuer: 'Microsoft', name: 'Azure AI' }]),
      });

      initCerts();
      await vi.waitFor(() => expect(grid.querySelectorAll('button').length).toBe(2));

      Array.from(grid.querySelectorAll('button'))
        .find((b) => b.textContent?.includes('Fortinet'))!
        .click();
      expect(document.getElementById('certs-breadcrumb')?.classList.contains('hidden')).toBe(false);

      document.getElementById('certs-back-btn')?.click();

      expect(document.getElementById('certs-breadcrumb')?.classList.contains('hidden')).toBe(true);
      // De vuelta a la vista resumen: tarjetas de emisor otra vez.
      expect(grid.querySelectorAll('button').length).toBe(2);
      expect(grid.textContent).toContain('Fortinet');
      expect(grid.textContent).toContain('Microsoft');
    });
  });

  describe('paginacion ("cargar mas")', () => {
    // DEFAULT_LIMIT en certifications.ts es 12. Con busqueda o un filtro
    // activo se sale de la vista-resumen y se listan certificaciones sueltas,
    // que es donde aplica el limite.
    const many = Array.from({ length: 15 }, (_, i) => ({
      ...sampleCert,
      name: `Cert ${i + 1}`,
    }));

    it('con mas elementos que el limite, muestra el boton "cargar mas" y solo pinta 12', async () => {
      const grid = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve(many) });

      initCerts();
      await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

      // Buscar algo que case con las 15 para salir de la vista-resumen
      // (agrupada por emisor) y listar certificaciones sueltas paginadas.
      const search = document.getElementById('certs-search') as HTMLInputElement;
      search.value = 'Cert';
      search.dispatchEvent(new Event('input'));

      const loadMoreContainer = document.getElementById('certs-load-more-container') as HTMLElement;
      expect(loadMoreContainer.classList.contains('hidden')).toBe(false);
      expect(grid.children.length).toBe(12);
    });

    it('"cargar mas" pinta el resto y oculta el boton', async () => {
      const grid = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve(many) });

      initCerts();
      await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

      const search = document.getElementById('certs-search') as HTMLInputElement;
      search.value = 'Cert';
      search.dispatchEvent(new Event('input'));
      expect(grid.children.length).toBe(12);

      document.getElementById('certs-load-more-btn')?.click();

      expect(grid.children.length).toBe(15);
      const loadMoreContainer = document.getElementById('certs-load-more-container') as HTMLElement;
      expect(loadMoreContainer.classList.contains('hidden')).toBe(true);
    });
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
