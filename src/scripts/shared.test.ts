import { describe, it, expect, vi, afterEach } from 'vitest';
import { safeUrl, setStatusPanel, fetchWithRetry } from './shared';

describe('safeUrl()', () => {
  it('permite http(s), rutas relativas y mailto', () => {
    expect(safeUrl('https://example.com/img.png')).toBe('https://example.com/img.png');
    expect(safeUrl('/img.png')).toBe('/img.png');
    expect(safeUrl('mailto:hola@example.com')).toBe('mailto:hola@example.com');
  });

  it('bloquea esquemas ejecutables', () => {
    expect(safeUrl('javascript:alert(1)')).toBe('');
    expect(safeUrl('data:text/html,<script>alert(1)</script>')).toBe('');
    expect(safeUrl('vbscript:msgbox(1)')).toBe('');
  });

  it('devuelve cadena vacia si no es un string', () => {
    expect(safeUrl(null)).toBe('');
    expect(safeUrl(undefined)).toBe('');
    expect(safeUrl(42)).toBe('');
  });

  it('recorta espacios antes de validar', () => {
    expect(safeUrl('  https://example.com  ')).toBe('https://example.com');
  });

  it('bloquea el bypass "/" + backslash (protocolo-relativo a dominio externo)', () => {
    // Regresion (auditoria de seguridad 2026-08-25): los navegadores tratan
    // "\" como "/" al parsear un esquema especial, asi que "/\evil.com/x"
    // pasaria un check ingenuo de "empieza por /" pero resuelve como
    // "//evil.com/x" -> dominio externo, no ruta interna.
    expect(safeUrl('/\\evil.example/x.jpg')).toBe('');
    expect(safeUrl('\\evil.example/x.jpg')).toBe('');
    expect(safeUrl('/foo\\bar')).toBe('');
  });

  it('bloquea "//" inicial (protocolo-relativo explicito)', () => {
    expect(safeUrl('//evil.example/x.jpg')).toBe('');
  });

  it('sigue permitiendo una ruta interna normal, sin backslash', () => {
    expect(safeUrl('/uploads/projects/foo.jpg')).toBe('/uploads/projects/foo.jpg');
  });

  it('bloquea el bypass de tabulador/salto de linea/retorno de carro incrustado', () => {
    // Regresion (auditoria de seguridad 2026-08-25, segunda ronda): el
    // parser WHATWG quita \t/\n/\r de CUALQUIER posicion antes de parsear,
    // no solo de los extremos (que .trim() ya cubre). "/\t/evil.example/x"
    // no tiene "\" literal ni empieza por "//" tal cual, pero el navegador
    // lo colapsa a "//evil.example/x" igual que el bypass de backslash.
    expect(safeUrl('/\t/evil.example/x')).toBe('');
    expect(safeUrl('/\n/evil.example/x')).toBe('');
    expect(safeUrl('/\r/evil.example/x')).toBe('');
    expect(safeUrl('/foo\tbar')).toBe('');
  });
});

describe('setStatusPanel()', () => {
  function panel() {
    document.body.innerHTML = `
      <div id="status" class="hidden">
        <span id="status-text"></span>
      </div>
    `;
    return {
      status: document.getElementById('status') as HTMLElement,
      statusText: document.getElementById('status-text') as HTMLElement,
    };
  }

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('fija data-state, el texto y quita "hidden"', () => {
    const { status, statusText } = panel();
    setStatusPanel(status, statusText, 'loading', 'Cargando…');

    expect(status.getAttribute('data-state')).toBe('loading');
    expect(status.classList.contains('hidden')).toBe(false);
    expect(statusText.textContent).toBe('Cargando…');
  });

  it('no lanza si status o statusText son null', () => {
    expect(() => setStatusPanel(null, null, 'error', 'x')).not.toThrow();
  });
});

describe('fetchWithRetry()', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it('devuelve el JSON en el primer intento si la respuesta es ok', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ a: 1 }) }));

    const result = await fetchWithRetry('/api/x');

    expect(result).toEqual({ a: 1 });
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('reintenta exactamente retries+1 veces y no mas (regresion del bug de cascada)', async () => {
    // BUG HISTORICO: la version original encadenaba .then().catch() en cada
    // nivel de recursion, asi que cada nivel volvia a aplicar su PROPIO
    // presupuesto de reintentos sobre el rechazo que subia del nivel de
    // abajo -- con retries=3 el total real de llamadas a fetch podia ser muy
    // superior a 4 (3 reintentos + intento inicial). Este test fija ese
    // numero exacto para que la cascada no pueda reaparecer sin que el test
    // lo note.
    vi.useFakeTimers();
    const fetchMock = vi.fn().mockResolvedValue({ ok: false });
    vi.stubGlobal('fetch', fetchMock);

    const promise = fetchWithRetry('/api/x', {}, 3, 10).catch((e) => e);
    await vi.runAllTimersAsync();
    const result = await promise;

    expect(result).toBeInstanceOf(Error);
    // 1 intento inicial + 3 reintentos = 4 llamadas. Con el bug antiguo esto
    // podia dispararse muy por encima de 4.
    expect(fetchMock).toHaveBeenCalledTimes(4);
  });

  it('con retries=0 hace exactamente un intento', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false }));

    await expect(fetchWithRetry('/api/x', {}, 0, 10)).rejects.toThrow('HTTP');
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('se recupera si un intento intermedio tiene exito', async () => {
    vi.useFakeTimers();
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({ ok: false })
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ ok: 'yes' }) });
    vi.stubGlobal('fetch', fetchMock);

    const promise = fetchWithRetry('/api/x', {}, 3, 10);
    await vi.runAllTimersAsync();
    const result = await promise;

    expect(result).toEqual({ ok: 'yes' });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('tambien reintenta cuando fetch() rechaza directamente (sin red), no solo cuando responde !ok', async () => {
    vi.useFakeTimers();
    const fetchMock = vi.fn().mockRejectedValue(new Error('network down'));
    vi.stubGlobal('fetch', fetchMock);

    const promise = fetchWithRetry('/api/x', {}, 2, 10).catch((e) => e);
    await vi.runAllTimersAsync();
    const result = await promise;

    expect(result).toBeInstanceOf(Error);
    expect((result as Error).message).toBe('network down');
    expect(fetchMock).toHaveBeenCalledTimes(3); // 1 + 2 reintentos
  });
});
