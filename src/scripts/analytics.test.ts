import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  bucketViewport,
  parseUtm,
  browserLangCode,
  generateId,
  getOrCreateSessionId,
  trackVisit,
  TOKEN_RE,
} from './analytics';

function readBody(mock: ReturnType<typeof vi.fn>, callIndex: number): Record<string, unknown> {
  const call = mock.mock.calls[callIndex];
  // sendBeacon(url, body) y fetch(url, {..., body}) llevan el body en sitios
  // distintos: se detecta por la forma del segundo argumento.
  const raw = typeof call[1] === 'string' ? call[1] : call[1].body;
  return JSON.parse(raw as string);
}

describe('bucketViewport()', () => {
  it.each([
    [0, 'xs'],
    [479, 'xs'],
    [480, 'sm'],
    [767, 'sm'],
    [768, 'md'],
    [1023, 'md'],
    [1024, 'lg'],
    [1439, 'lg'],
    [1440, 'xl'],
    [2560, 'xl'],
  ])('%ipx -> %s', (width, expected) => {
    expect(bucketViewport(width)).toBe(expected);
  });
});

describe('parseUtm()', () => {
  it('extrae las tres claves cuando estan presentes', () => {
    expect(parseUtm('?utm_source=linkedin&utm_medium=social&utm_campaign=lanzamiento')).toEqual({
      utm_source: 'linkedin',
      utm_medium: 'social',
      utm_campaign: 'lanzamiento',
    });
  });

  it('devuelve un objeto vacio sin query string', () => {
    expect(parseUtm('')).toEqual({});
  });

  it('omite claves ausentes o vacias, sin dejarlas como undefined', () => {
    const result = parseUtm('?utm_source=&utm_medium=email');
    expect(result).toEqual({ utm_medium: 'email' });
    expect('utm_source' in result).toBe(false);
  });

  it('ignora parametros que no son utm_*', () => {
    expect(parseUtm('?foo=bar&utm_source=x')).toEqual({ utm_source: 'x' });
  });

  it('recorta valores largos a 60 caracteres', () => {
    const long = 'a'.repeat(80);
    const result = parseUtm(`?utm_campaign=${long}`);
    expect(result.utm_campaign).toHaveLength(60);
  });

  it('un valor de solo espacios se trata como ausente', () => {
    const result = parseUtm('?utm_source=%20%20%20');
    expect('utm_source' in result).toBe(false);
  });
});

describe('browserLangCode()', () => {
  it.each([
    ['es-ES', 'es'],
    ['EN', 'en'],
    ['zh-Hant-TW', 'zh'],
    ['', ''],
    ['e', ''],
    ['123', ''],
  ])('%s -> %s', (input, expected) => {
    expect(browserLangCode(input)).toBe(expected);
  });
});

describe('generateId()', () => {
  it('genera un token de 16 hex', () => {
    expect(generateId()).toMatch(TOKEN_RE);
  });

  it('no repite el mismo id en llamadas consecutivas', () => {
    expect(generateId()).not.toBe(generateId());
  });
});

describe('getOrCreateSessionId()', () => {
  beforeEach(() => sessionStorage.clear());

  it('reutiliza un id ya guardado', () => {
    sessionStorage.setItem('eo_session_id', 'aaaaaaaaaaaaaaaa');
    expect(getOrCreateSessionId(sessionStorage)).toBe('aaaaaaaaaaaaaaaa');
  });

  it('crea y persiste un id nuevo si no habia ninguno valido', () => {
    const id = getOrCreateSessionId(sessionStorage);
    expect(id).toMatch(TOKEN_RE);
    expect(sessionStorage.getItem('eo_session_id')).toBe(id);
  });

  it('ignora un valor guardado que no tiene forma de token', () => {
    sessionStorage.setItem('eo_session_id', 'no-es-un-token');
    const id = getOrCreateSessionId(sessionStorage);
    expect(id).toMatch(TOKEN_RE);
  });

  it('si el almacenamiento falla, genera un id de un solo uso sin lanzar', () => {
    const brokenStorage = {
      getItem: () => {
        throw new Error('cuota agotada');
      },
      setItem: () => {
        throw new Error('cuota agotada');
      },
    } as unknown as Storage;
    expect(() => getOrCreateSessionId(brokenStorage)).not.toThrow();
    expect(getOrCreateSessionId(brokenStorage)).toMatch(TOKEN_RE);
  });
});

describe('trackVisit()', () => {
  beforeEach(() => {
    sessionStorage.clear();
    // Sin sendBeacon por defecto: fuerza la rama de fetch salvo que un test
    // concreto la reactive.
    Object.defineProperty(navigator, 'sendBeacon', {
      value: undefined,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(navigator, 'doNotTrack', {
      value: null,
      configurable: true,
      writable: true,
    });
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true }));
    // rAF sincrono: onScroll() lo usa para no recalcular el layout en cada
    // evento, pero los tests no necesitan esperar un frame real.
    vi.stubGlobal('requestAnimationFrame', (cb: FrameRequestCallback) => {
      cb(0);
      return 0;
    });
  });

  afterEach(() => {
    // Descarga cualquier hit_id pendiente (como haria un pagehide real) para
    // que el siguiente test arranque sin estado a medias de este.
    window.dispatchEvent(new Event('pagehide'));
    vi.unstubAllGlobals();
  });

  it('envia un hit con path, referrer, session_id y hit_id validos', () => {
    trackVisit();

    expect(fetch).toHaveBeenCalledTimes(1);
    const body = readBody(fetch as ReturnType<typeof vi.fn>, 0);
    expect(body.session_id).toMatch(TOKEN_RE);
    expect(body.hit_id).toMatch(TOKEN_RE);
    expect(['xs', 'sm', 'md', 'lg', 'xl']).toContain(body.viewport);
    expect(body.path).toBe(location.pathname);
  });

  it('reutiliza el mismo session_id entre paginas de la misma pestana', () => {
    trackVisit();
    const first = readBody(fetch as ReturnType<typeof vi.fn>, 0).session_id;

    trackVisit();
    const calls = (fetch as ReturnType<typeof vi.fn>).mock.calls.length;
    const second = readBody(fetch as ReturnType<typeof vi.fn>, calls - 1).session_id;

    expect(second).toBe(first);
  });

  it('al navegar a otra pagina, cierra la anterior con un beat antes del siguiente hit', () => {
    trackVisit();
    const firstHitId = readBody(fetch as ReturnType<typeof vi.fn>, 0).hit_id;

    trackVisit();

    expect(fetch).toHaveBeenCalledTimes(3); // hit, beat, hit
    const beat = readBody(fetch as ReturnType<typeof vi.fn>, 1);
    expect(beat.action).toBe('beat');
    expect(beat.hit_id).toBe(firstHitId);
    expect(beat.duration_s).toBeGreaterThanOrEqual(0);
    expect(beat.scroll_pct).toBeGreaterThanOrEqual(0);
    expect(beat.scroll_pct).toBeLessThanOrEqual(100);
  });

  it('no registra nada si el navegador pide Do Not Track', () => {
    Object.defineProperty(navigator, 'doNotTrack', {
      value: '1',
      configurable: true,
      writable: true,
    });

    trackVisit();

    expect(fetch).not.toHaveBeenCalled();
  });

  it('usa sendBeacon en vez de fetch cuando esta disponible', () => {
    const sendBeaconMock = vi.fn().mockReturnValue(true);
    Object.defineProperty(navigator, 'sendBeacon', {
      value: sendBeaconMock,
      configurable: true,
      writable: true,
    });

    trackVisit();

    expect(sendBeaconMock).toHaveBeenCalledTimes(1);
    expect(fetch).not.toHaveBeenCalled();
    const [url] = sendBeaconMock.mock.calls[0];
    expect(url).toBe('/api/visit.php');
  });

  it('al cerrar la pestana (pagehide), envia el beat de la pagina actual', () => {
    trackVisit();
    const hitId = readBody(fetch as ReturnType<typeof vi.fn>, 0).hit_id;

    window.dispatchEvent(new Event('pagehide'));

    expect(fetch).toHaveBeenCalledTimes(2);
    const beat = readBody(fetch as ReturnType<typeof vi.fn>, 1);
    expect(beat.action).toBe('beat');
    expect(beat.hit_id).toBe(hitId);

    // Un segundo pagehide no reenvia nada: ya no hay hit_id pendiente.
    window.dispatchEvent(new Event('pagehide'));
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('un beat disparado por pagehide no propaga si sendBeacon lanza', () => {
    trackVisit();
    Object.defineProperty(navigator, 'sendBeacon', {
      value: vi.fn(() => {
        throw new Error('quota exceeded');
      }),
      configurable: true,
      writable: true,
    });

    expect(() => window.dispatchEvent(new Event('pagehide'))).not.toThrow();
  });

  it('incluye los parametros utm de la URL de aterrizaje en el hit enviado', () => {
    const originalUrl = location.href;
    window.history.pushState({}, '', '/?utm_source=newsletter&utm_medium=email&utm_campaign=ago26');

    try {
      trackVisit();

      const body = readBody(fetch as ReturnType<typeof vi.fn>, 0);
      expect(body.utm_source).toBe('newsletter');
      expect(body.utm_medium).toBe('email');
      expect(body.utm_campaign).toBe('ago26');
    } finally {
      window.history.pushState({}, '', originalUrl);
    }
  });

  it('registra la profundidad MAXIMA de scroll, no la ultima', () => {
    const originalScrollHeight = document.documentElement.scrollHeight;
    const originalInnerHeight = window.innerHeight;
    const originalScrollY = window.scrollY;
    try {
      Object.defineProperty(document.documentElement, 'scrollHeight', {
        value: 2000,
        configurable: true,
      });
      Object.defineProperty(window, 'innerHeight', { value: 1000, configurable: true });

      trackVisit();

      Object.defineProperty(window, 'scrollY', { value: 800, configurable: true }); // 80%
      window.dispatchEvent(new Event('scroll'));
      Object.defineProperty(window, 'scrollY', { value: 100, configurable: true }); // vuelve al 10%
      window.dispatchEvent(new Event('scroll'));

      trackVisit(); // cierra la pagina anterior con un beat

      const calls = (fetch as ReturnType<typeof vi.fn>).mock.calls.length;
      const beat = readBody(fetch as ReturnType<typeof vi.fn>, calls - 2);
      expect(beat.action).toBe('beat');
      expect(beat.scroll_pct).toBe(80);
    } finally {
      Object.defineProperty(document.documentElement, 'scrollHeight', {
        value: originalScrollHeight,
        configurable: true,
      });
      Object.defineProperty(window, 'innerHeight', { value: originalInnerHeight, configurable: true });
      Object.defineProperty(window, 'scrollY', { value: originalScrollY, configurable: true });
    }
  });
});

// Bloque aparte, al final del archivo: usa vi.resetModules() + import()
// dinamico para conseguir una instancia de modulo realmente nueva (sessionId
// es un cache en memoria de modulo -- sessionStorage.clear() solo no basta
// para probar que trackVisit() lee sessionStorage de verdad en una carga
// fresca, no que se limita a devolver lo que ya tenia cacheado).
describe('trackVisit() - persistencia de sesion en una carga fresca', () => {
  beforeEach(() => {
    sessionStorage.clear();
    Object.defineProperty(navigator, 'sendBeacon', {
      value: undefined,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(navigator, 'doNotTrack', {
      value: null,
      configurable: true,
      writable: true,
    });
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true }));
  });

  afterEach(() => {
    window.dispatchEvent(new Event('pagehide'));
    vi.unstubAllGlobals();
  });

  it('persiste el session_id en sessionStorage, no solo en memoria del modulo', async () => {
    vi.resetModules();
    const fresh = await import('./analytics');
    fresh.trackVisit();

    const body = readBody(fetch as ReturnType<typeof vi.fn>, 0);
    expect(sessionStorage.getItem('eo_session_id')).toBe(body.session_id);
  });
});
