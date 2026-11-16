import { describe, it, expect, vi, afterEach } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { initCerts, safeUrl, issuerInitials, DEFAULT_LIMIT } from './certifications';

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
    <div
      id="certs-grid"
      data-api="/api/certifications.php"
      data-labels='{"loading":"Cargando","error":"Error","empty":"Sin certificaciones","countLabel":"certificaciones"}'
    ></div>
    <div id="certs-load-more-container" class="hidden">
      <button id="certs-load-more-btn"><span>Ver todas</span></button>
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

  it('pinta una fila por certificacion con nombre, emisor y ano', async () => {
    const grid = setupGrid();
    mockFetchOnce({
      ok: true,
      json: () =>
        Promise.resolve([sampleCert, { ...sampleCert, name: 'Fortinet NSE 2' }, { ...sampleCert, issuer: 'Microsoft', name: 'Azure AI' }]),
    });

    initCerts();
    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

    expect(grid.dataset.loaded).toBe('1');
    const rows = grid.querySelectorAll('.cert-row');
    expect(rows.length).toBe(3);
    expect(rows[0].querySelector('.cert-name')?.textContent).toBe('Fortinet NSE');
    expect(rows[0].textContent).toContain('Fortinet');
    expect(rows[0].querySelector('.cert-year')?.textContent).toBe('2026-01');
    expect(grid.querySelectorAll('button').length).toBe(0);
  });

  it('cintillo: emisor y ano comparten linea (.cert-meta) encima del nombre; sin emisor/ano queda vacio', async () => {
    const grid = setupGrid();
    mockFetchOnce({
      ok: true,
      json: () => Promise.resolve([sampleCert, { name: 'Solo nombre' }]),
    });

    initCerts();
    await vi.waitFor(() => expect(grid.children.length).toBe(2));

    const [full, bare] = Array.from(grid.querySelectorAll('.cert-row'));
    const meta = full.querySelector('.cert-meta')!;
    expect(meta.children[0].className).toBe('cert-issuer');
    expect(meta.children[0].textContent).toBe('Fortinet');
    expect(meta.children[1].className).toBe('cert-year');
    expect(meta.nextElementSibling?.className).toContain('cert-name');
    expect(bare.querySelector('.cert-issuer')?.textContent).toBe('');
    expect(bare.querySelector('.cert-year')?.textContent).toBe('');
  });

  it('usa la version optimizada del logo cuando el build la genero (data-logos)', async () => {
    const grid = setupGrid();
    const fortinetLogo = 'https://images.credly.com/images/f/fortinet.png';
    grid.dataset.logos = JSON.stringify({ [fortinetLogo]: '/_astro/fortinet.webp' });
    mockFetchOnce({
      ok: true,
      json: () =>
        Promise.resolve([
          { ...sampleCert, logo_url: fortinetLogo },
          { ...sampleCert, issuer: 'Microsoft', logo_url: 'https://x.test/ms.png' },
        ]),
    });

    initCerts();
    await vi.waitFor(() => expect(grid.querySelectorAll('img').length).toBe(2));

    const srcs = [...grid.querySelectorAll('img')].map((img) => img.getAttribute('src'));
    expect(srcs).toContain('/_astro/fortinet.webp');
    // Sin entrada en el mapa: se queda el original.
    expect(srcs).toContain('https://x.test/ms.png');
    // El nombre y el emisor ya son texto visible: el logo es decorativo.
    expect([...grid.querySelectorAll('img')].every((img) => img.alt === '')).toBe(true);
  });

  it('con logo: insignia 56x56 con img decorativa; sin logo: monograma del emisor (ambas ramas)', async () => {
    const grid = setupGrid();
    mockFetchOnce({
      ok: true,
      json: () =>
        Promise.resolve([
          { ...sampleCert, logo_url: 'https://x.test/a.png' },
          { ...sampleCert, issuer: 'Trend Micro', logo_url: '' },
          { ...sampleCert, issuer: 'Cisco', logo_url: 'javascript:alert(1)' },
        ]),
    });

    initCerts();
    await vi.waitFor(() => expect(grid.querySelectorAll('.cert-row').length).toBe(3));

    const [withLogo, mono, mono2] = Array.from(grid.querySelectorAll('.cert-row'));
    const img = withLogo.querySelector('.cert-badge img')!;
    expect(img.getAttribute('width')).toBe('56');
    expect(img.getAttribute('height')).toBe('56');
    expect((img as HTMLImageElement).loading).toBe('lazy');
    expect(img.getAttribute('alt')).toBe('');
    expect(withLogo.querySelector('.cert-badge--mono')).toBeNull();
    expect(mono.querySelector('img')).toBeNull();
    expect(mono.querySelector('.cert-badge--mono')?.textContent).toBe('TM');
    expect(mono.querySelector('.cert-badge--mono')?.getAttribute('aria-hidden')).toBe('true');
    expect(mono2.querySelector('.cert-badge--mono')?.textContent).toBe('CI');
  });

  it('issuerInitials: dos palabras, una palabra, vacio', () => {
    expect(issuerInitials('Trend Micro')).toBe('TM');
    expect(issuerInitials('Fortinet')).toBe('FN');
    expect(issuerInitials(' TryHackMe ')).toBe('TH');
    expect(issuerInitials('LinkedIn')).toBe('LI');
    expect(issuerInitials('Cisco')).toBe('CI');
    expect(issuerInitials('Palo Alto')).toBe('PA');
    expect(issuerInitials('X')).toBe('X');
    expect(issuerInitials('')).toBe('·');
    expect(issuerInitials(undefined)).toBe('·');
  });

  it('la fila es un enlace de verificacion solo si hay credential_url valida', async () => {
    const grid = setupGrid();
    mockFetchOnce({
      ok: true,
      json: () =>
        Promise.resolve([
          { ...sampleCert, credential_url: 'https://www.credly.com/badges/abc' },
          { ...sampleCert, name: 'Sin enlace' },
          { ...sampleCert, name: 'Enlace malo', credential_url: 'javascript:alert(1)' },
        ]),
    });

    initCerts();
    await vi.waitFor(() => expect(grid.querySelectorAll('.cert-row').length).toBe(3));

    const [linked, plain, bad] = Array.from(grid.querySelectorAll('.cert-row'));
    expect(linked.tagName).toBe('A');
    expect(linked.getAttribute('href')).toBe('https://www.credly.com/badges/abc');
    expect(linked.getAttribute('target')).toBe('_blank');
    expect(linked.getAttribute('rel')).toBe('noopener noreferrer');
    expect(plain.tagName).toBe('DIV');
    expect(bad.tagName).toBe('DIV');
  });

  it('sin logo en la API pinta el sello neutro, nunca una imagen inventada', async () => {
    const grid = setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([sampleCert]) });

    initCerts();
    await vi.waitFor(() => expect(grid.querySelector('.cert-row')).not.toBeNull());

    expect(grid.querySelector('img')).toBeNull();
    expect(grid.querySelector('.cert-badge--mono')).not.toBeNull();
  });

  it('con filas ya pintadas en el build no muestra "cargando" ni las borra hasta tener datos', async () => {
    const grid = setupGrid();
    grid.innerHTML = '<div class="cert-row">Fila del build</div>';
    const status = document.getElementById('certs-status') as HTMLElement;
    let resolve!: (v: unknown) => void;
    vi.stubGlobal('fetch', vi.fn().mockReturnValueOnce(new Promise((r) => (resolve = r))));

    initCerts();
    expect(status.hasAttribute('data-state')).toBe(false);
    expect(grid.textContent).toContain('Fila del build');

    resolve({ ok: true, json: () => Promise.resolve([sampleCert]) });
    await vi.waitFor(() => expect(grid.textContent).not.toContain('Fila del build'));
    expect(grid.textContent).toContain('Fortinet NSE');
  });

  it('sin filas del build muestra el estado "cargando" mientras espera', () => {
    setupGrid();
    const status = document.getElementById('certs-status') as HTMLElement;
    vi.stubGlobal('fetch', vi.fn().mockReturnValueOnce(new Promise(() => {})));

    initCerts();

    expect(status.getAttribute('data-state')).toBe('loading');
    expect(document.getElementById('certs-status-text')?.textContent).toBe('Cargando');
  });

  it('una busqueda sin resultados muestra el mensaje vacio dentro de la lista', async () => {
    const grid = setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([sampleCert]) });
    initCerts();
    await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

    const search = document.getElementById('certs-search') as HTMLInputElement;
    search.value = 'zzz';
    search.dispatchEvent(new Event('input'));

    expect(grid.querySelectorAll('.cert-row').length).toBe(0);
    expect(grid.textContent).toBe('Sin certificaciones');
  });

  it('muestra el estado vacio cuando la API devuelve un array vacio', async () => {
    setupGrid();
    mockFetchOnce({ ok: true, json: () => Promise.resolve([]) });

    initCerts();

    const status = document.getElementById('certs-status') as HTMLElement;
    await vi.waitFor(() => expect(status.getAttribute('data-state')).toBe('empty'), { timeout: 3000 });
    expect(document.getElementById('certs-status-text')?.textContent).toBe('Sin certificaciones');
  });

  it('la busqueda aplica el termino sobre nombre, emisor y categoria', async () => {
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

  describe('Ver todas (plegado)', () => {
    // Las DEFAULT_LIMIT primeras (orden de la API) son las destacadas; el resto
    // queda plegado tras "Ver todas".
    const many = Array.from({ length: DEFAULT_LIMIT + 7 }, (_, i) => ({
      ...sampleCert,
      name: `Cert ${i + 1}`,
    }));

    it('con mas filas que el limite, pinta solo las destacadas y muestra "Ver todas"', async () => {
      const grid = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve(many) });

      initCerts();
      await vi.waitFor(() => expect(grid.children.length).toBeGreaterThan(0));

      expect(grid.children.length).toBe(DEFAULT_LIMIT);
      expect(grid.children[0].textContent).toContain('Cert 1');
      const loadMoreContainer = document.getElementById('certs-load-more-container') as HTMLElement;
      expect(loadMoreContainer.classList.contains('hidden')).toBe(false);
      expect(document.querySelector('#certs-load-more-btn span')?.textContent).toBe(`Ver todas (${many.length})`);
    });

    it('"Ver todas" pinta el resto y oculta el boton', async () => {
      const grid = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve(many) });

      initCerts();
      await vi.waitFor(() => expect(grid.children.length).toBe(DEFAULT_LIMIT));

      document.getElementById('certs-load-more-btn')?.click();

      expect(grid.children.length).toBe(many.length);
      const loadMoreContainer = document.getElementById('certs-load-more-container') as HTMLElement;
      expect(loadMoreContainer.classList.contains('hidden')).toBe(true);
    });

    it('con el limite justo no hay boton', async () => {
      const grid = setupGrid();
      mockFetchOnce({ ok: true, json: () => Promise.resolve(many.slice(0, DEFAULT_LIMIT)) });

      initCerts();
      await vi.waitFor(() => expect(grid.children.length).toBe(DEFAULT_LIMIT));

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

describe('T16: titulo de certificacion sin truncate', () => {
  it('el nombre no lleva la clase truncate (el CSS aplica line-clamp 2)', () => {
    document.body.innerHTML = '<div id="x"></div>';
    const src = readFileSync(join(process.cwd(), 'src/components/CertRow.astro'), 'utf8');
    const js = readFileSync(join(process.cwd(), 'src/scripts/certifications.ts'), 'utf8');
    expect(src).not.toMatch(/cert-name[^"]*truncate/);
    expect(js).not.toMatch(/cert-name[^']*truncate/);
  });
});
