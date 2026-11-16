import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  classifyClick,
  isValidEvent,
  trackEvent,
  trackNotFound,
  registerEventListeners,
} from './events';

function setNav(dnt: string | null, gpc: boolean | undefined): void {
  Object.defineProperty(navigator, 'doNotTrack', { value: dnt, configurable: true, writable: true });
  Object.defineProperty(navigator, 'globalPrivacyControl', { value: gpc, configurable: true, writable: true });
}

/** Monta HTML y devuelve el elemento con id="t". */
function mount(html: string): Element {
  document.body.innerHTML = html;
  return document.getElementById('t')!;
}

const HERE = 'eduolihez.com';

describe('classifyClick()', () => {
  beforeEach(() => document.documentElement.removeAttribute('data-theme'));

  it('cv_download en [data-cv-open] (tambien desde un hijo)', () => {
    const el = mount('<button data-cv-open><span id="t">CV</span></button>');
    expect(classifyClick(el, HERE)).toEqual({ name: 'cv_download' });
  });

  it('outbound: hostname en minusculas sin www.', () => {
    const el = mount('<a id="t" href="https://WWW.GitHub.com/edu">x</a>');
    expect(classifyClick(el, HERE)).toEqual({ name: 'outbound', target: 'github.com' });
  });

  it('ignora enlaces internos (relativos, absolutos y con www.)', () => {
    expect(classifyClick(mount('<a id="t" href="/blog">x</a>'), HERE)).toBeNull();
    expect(classifyClick(mount('<a id="t" href="https://www.eduolihez.com/x">x</a>'), HERE)).toBeNull();
  });

  it('ignora mailto: y tel:', () => {
    expect(classifyClick(mount('<a id="t" href="mailto:a@b.com">x</a>'), HERE)).toBeNull();
    expect(classifyClick(mount('<a id="t" href="tel:+34600000000">x</a>'), HERE)).toBeNull();
  });

  it('ignora href inparseable', () => {
    expect(classifyClick(mount('<a id="t" href="http://">x</a>'), HERE)).toBeNull();
  });

  it('lang_switch en el selector del Header', () => {
    const el = mount('<header><a id="t" href="/en/" hreflang="en">EN</a></header>');
    expect(classifyClick(el, HERE)).toEqual({ name: 'lang_switch', target: 'en' });
  });

  it('hreflang fuera del header o con idioma desconocido no es lang_switch', () => {
    expect(classifyClick(mount('<a id="t" href="/en/" hreflang="en">EN</a>'), HERE)).toBeNull();
    expect(classifyClick(mount('<header><a id="t" href="/x/" hreflang="fr">FR</a></header>'), HERE)).toBeNull();
  });

  it('theme_toggle con tema resultante, o sin target', () => {
    const el = mount('<button id="t" data-theme-toggle>t</button>');
    document.documentElement.dataset.theme = 'dark';
    expect(classifyClick(el, HERE)).toEqual({ name: 'theme_toggle', target: 'dark' });
    document.documentElement.removeAttribute('data-theme');
    expect(classifyClick(el, HERE)).toEqual({ name: 'theme_toggle' });
  });

  it('elementos sin enlace ni selector, o nulos, dan null', () => {
    expect(classifyClick(mount('<p id="t">x</p>'), HERE)).toBeNull();
    expect(classifyClick(null, HERE)).toBeNull();
  });
});

describe('isValidEvent()', () => {
  it('acepta sin target y con target valido', () => {
    expect(isValidEvent({ name: 'cv_download' }, '/')).toBe(true);
    expect(isValidEvent({ name: 'outbound', target: 'a-b.example.com' }, '/')).toBe(true);
  });
  it('descarta target invalido, path largo o vacio', () => {
    expect(isValidEvent({ name: 'outbound', target: 'Bad Host' }, '/')).toBe(false);
    expect(isValidEvent({ name: 'outbound', target: 'a'.repeat(81) }, '/')).toBe(false);
    expect(isValidEvent({ name: 'outbound', target: '' }, '/')).toBe(false);
    expect(isValidEvent({ name: 'not_found' }, '/' + 'a'.repeat(120))).toBe(false);
    expect(isValidEvent({ name: 'not_found' }, '')).toBe(false);
  });
});

describe('envio de eventos', () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    sessionStorage.clear();
    fetchMock.mockReset().mockResolvedValue({ ok: true });
    vi.stubGlobal('fetch', fetchMock);
    Object.defineProperty(navigator, 'sendBeacon', { value: undefined, configurable: true, writable: true });
    setNav(null, undefined);
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    document.body.innerHTML = '';
  });

  const body = (i = 0) => JSON.parse(fetchMock.mock.calls[i][1].body as string);

  it('trackEvent envia action/name/target/path/session_id', () => {
    trackEvent({ name: 'outbound', target: 'github.com' });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(body()).toMatchObject({ action: 'event', name: 'outbound', target: 'github.com', path: location.pathname });
    expect(body().session_id).toMatch(/^[a-f0-9]{16}$/);
  });

  it('omite target cuando no aplica', () => {
    trackEvent({ name: 'cv_download' });
    expect('target' in body()).toBe(false);
  });

  it('no envia con DNT ni con GPC', () => {
    setNav('1', undefined);
    trackEvent({ name: 'cv_download' });
    setNav(null, true);
    trackEvent({ name: 'cv_download' });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('no envia un target invalido', () => {
    trackEvent({ name: 'outbound', target: 'MAL HOST' });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('no propaga si el envio lanza', () => {
    fetchMock.mockImplementation(() => {
      throw new Error('boom');
    });
    expect(() => trackEvent({ name: 'cv_download' })).not.toThrow();
  });

  it('click y submit delegados: un envio por accion, aunque se registre dos veces', () => {
    expect(registerEventListeners()).toBe(false); // ya registrados al importar
    const link = mount('<a id="t" href="https://example.org/x">x</a>');
    link.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(body()).toMatchObject({ name: 'outbound', target: 'example.org' });

    fetchMock.mockClear();
    const form = mount('<form id="t" data-formspree="x"><input name="email" value="a@b.c"></form>');
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(body()).toMatchObject({ name: 'contact_submit' });
    expect(JSON.stringify(body())).not.toContain('a@b.c');
  });

  it('submit de otro formulario no envia nada', () => {
    mount('<form id="t"></form>').dispatchEvent(new Event('submit', { bubbles: true }));
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('not_found solo en pagina marcada 404', () => {
    mount('<section id="t" data-error-page="404"></section>');
    trackNotFound();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(body()).toMatchObject({ name: 'not_found', path: location.pathname });

    fetchMock.mockClear();
    mount('<section id="t"></section>');
    trackNotFound();
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
