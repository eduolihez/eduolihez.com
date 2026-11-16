import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  CONSENT_KEY,
  CONSENT_TTL_MS,
  COOKIE_MAX_AGE_S,
  applyChoice,
  buildDeleteCookie,
  buildVisitorCookie,
  consentedVisitorId,
  effectiveConsent,
  getStorage,
  hasPrivacySignal,
  initConsent,
  readConsent,
  readVisitorCookie,
  saveConsent,
} from './consent';

const NOW = 1_800_000_000_000;
const noSignal = { doNotTrack: null, globalPrivacyControl: false };

function clearCookie(): void {
  document.cookie = 'eo_vid=; Max-Age=0; Path=/';
}

beforeEach(() => {
  localStorage.clear();
  clearCookie();
  document.body.innerHTML = '';
});

describe('hasPrivacySignal()', () => {
  it('DNT=1 y GPC cuentan; lo demas no', () => {
    expect(hasPrivacySignal({ doNotTrack: '1' })).toBe(true);
    expect(hasPrivacySignal({ globalPrivacyControl: true })).toBe(true);
    expect(hasPrivacySignal({ doNotTrack: '0' })).toBe(false);
    expect(hasPrivacySignal({})).toBe(false);
  });
});

describe('readConsent() / effectiveConsent()', () => {
  it('granted y denied vigentes', () => {
    saveConsent(localStorage, 'granted', NOW);
    expect(readConsent(localStorage, NOW + 1000)).toBe('granted');
    saveConsent(localStorage, 'denied', NOW);
    expect(effectiveConsent(localStorage, noSignal, NOW)).toBe('denied');
  });

  it('sin eleccion devuelve null (hay que preguntar)', () => {
    expect(effectiveConsent(localStorage, noSignal, NOW)).toBeNull();
  });

  it('caducada a los 6 meses: null y se borra', () => {
    saveConsent(localStorage, 'granted', NOW);
    expect(readConsent(localStorage, NOW + CONSENT_TTL_MS + 1)).toBeNull();
    expect(localStorage.getItem(CONSENT_KEY)).toBeNull();
  });

  it('valor corrupto o con fecha futura: null y se borra', () => {
    localStorage.setItem(CONSENT_KEY, 'quizas|123');
    expect(readConsent(localStorage, NOW)).toBeNull();
    localStorage.setItem(CONSENT_KEY, `granted|${NOW + 5000}`);
    expect(readConsent(localStorage, NOW)).toBeNull();
    localStorage.setItem(CONSENT_KEY, 'granted|abc');
    expect(readConsent(localStorage, NOW)).toBeNull();
  });

  it('DNT o GPC fuerzan denied aunque se hubiera aceptado', () => {
    saveConsent(localStorage, 'granted', NOW);
    expect(effectiveConsent(localStorage, { doNotTrack: '1' }, NOW)).toBe('denied');
    expect(effectiveConsent(localStorage, { globalPrivacyControl: true }, NOW)).toBe('denied');
  });

  it('sin almacenamiento disponible: denied', () => {
    expect(effectiveConsent(null, noSignal, NOW)).toBe('denied');
  });

  it('storage que lanza: readConsent null y saveConsent no rompe', () => {
    const broken = {
      getItem: () => {
        throw new Error('blocked');
      },
      setItem: () => {
        throw new Error('blocked');
      },
    } as unknown as Storage;
    expect(readConsent(broken, NOW)).toBeNull();
    expect(() => saveConsent(broken, 'granted', NOW)).not.toThrow();
  });

  it('getStorage() devuelve null si localStorage lanza', () => {
    const spy = vi.spyOn(window, 'localStorage', 'get').mockImplementation(() => {
      throw new Error('SecurityError');
    });
    expect(getStorage()).toBeNull();
    spy.mockRestore();
    expect(getStorage()).toBe(localStorage);
  });
});

describe('cookie eo_vid', () => {
  it('atributos: 180 dias, Path=/, SameSite=Lax y Secure solo en https', () => {
    const c = buildVisitorCookie('0123456789abcdef', true);
    expect(c).toBe(`eo_vid=0123456789abcdef; Max-Age=${COOKIE_MAX_AGE_S}; Path=/; SameSite=Lax; Secure`);
    expect(COOKIE_MAX_AGE_S).toBe(180 * 86400);
    expect(buildVisitorCookie('0123456789abcdef', false)).not.toContain('Secure');
    expect(buildDeleteCookie(true)).toBe('eo_vid=; Max-Age=0; Path=/; SameSite=Lax; Secure');
  });

  it('readVisitorCookie solo acepta 16 hex', () => {
    expect(readVisitorCookie('a=1; eo_vid=0123456789abcdef')).toBe('0123456789abcdef');
    expect(readVisitorCookie('eo_vid=XYZ')).toBeNull();
    expect(readVisitorCookie('')).toBeNull();
  });

  it('aceptar crea la cookie; rechazar la borra', () => {
    applyChoice('granted', localStorage, NOW);
    const id = readVisitorCookie(document.cookie);
    expect(id).toMatch(/^[a-f0-9]{16}$/);
    expect(localStorage.getItem(CONSENT_KEY)).toBe(`granted|${NOW}`);
    applyChoice('denied', localStorage, NOW);
    expect(readVisitorCookie(document.cookie)).toBeNull();
    expect(localStorage.getItem(CONSENT_KEY)).toBe(`denied|${NOW}`);
  });
});

describe('consentedVisitorId()', () => {
  it('con consentimiento devuelve y reutiliza la misma cookie', () => {
    saveConsent(localStorage, 'granted', NOW);
    const a = consentedVisitorId(localStorage, noSignal, NOW);
    const b = consentedVisitorId(localStorage, noSignal, NOW);
    expect(a).toMatch(/^[a-f0-9]{16}$/);
    expect(b).toBe(a);
  });

  it('sin eleccion, rechazado, caducado o con DNT: undefined y sin cookie', () => {
    expect(consentedVisitorId(localStorage, noSignal, NOW)).toBeUndefined();
    saveConsent(localStorage, 'granted', NOW);
    consentedVisitorId(localStorage, noSignal, NOW);
    expect(consentedVisitorId(localStorage, { doNotTrack: '1' }, NOW)).toBeUndefined();
    expect(readVisitorCookie(document.cookie)).toBeNull();
    saveConsent(localStorage, 'granted', NOW);
    consentedVisitorId(localStorage, noSignal, NOW);
    expect(consentedVisitorId(localStorage, noSignal, NOW + CONSENT_TTL_MS + 1)).toBeUndefined();
    expect(readVisitorCookie(document.cookie)).toBeNull();
  });
});

describe('initConsent() banner', () => {
  function mount(): HTMLElement {
    document.body.innerHTML = `
      <a href="/sobre-esta-web/" data-consent-open>Cookies</a>
      <section data-consent-banner hidden>
        <h2 data-consent-title tabindex="-1">t</h2>
        <button data-consent-choice="granted">ok</button>
        <button data-consent-choice="denied">no</button>
      </section>`;
    return document.querySelector('[data-consent-banner]')!;
  }

  it('primera visita: se muestra; Rechazar lo oculta y no deja cookie', () => {
    const el = mount();
    initConsent();
    expect(el.hidden).toBe(false);
    el.querySelector<HTMLButtonElement>('[data-consent-choice="denied"]')!.click();
    expect(el.hidden).toBe(true);
    expect(document.cookie).not.toContain('eo_vid=');
  });

  it('con eleccion no se muestra; el enlace del pie lo reabre con foco y Escape lo cierra', () => {
    saveConsent(localStorage, 'granted', Date.now());
    const el = mount();
    initConsent();
    expect(el.hidden).toBe(true);
    const link = document.querySelector<HTMLAnchorElement>('[data-consent-open]')!;
    link.click();
    expect(el.hidden).toBe(false);
    expect(document.activeElement).toBe(el.querySelector('[data-consent-title]'));
    el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    expect(el.hidden).toBe(true);
    expect(document.activeElement).toBe(link);
  });

  it('retirar desde el pie borra la cookie', () => {
    applyChoice('granted', localStorage, Date.now());
    const el = mount();
    initConsent();
    document.querySelector<HTMLAnchorElement>('[data-consent-open]')!.click();
    el.querySelector<HTMLButtonElement>('[data-consent-choice="denied"]')!.click();
    expect(readVisitorCookie(document.cookie)).toBeNull();
  });

  it('con DNT no hay banner y el enlace no se intercepta', () => {
    Object.defineProperty(navigator, 'doNotTrack', { value: '1', configurable: true });
    const el = mount();
    initConsent();
    expect(el.hidden).toBe(true);
    const ev = new MouseEvent('click', { cancelable: true, bubbles: true });
    document.querySelector('[data-consent-open]')!.dispatchEvent(ev);
    expect(ev.defaultPrevented).toBe(false);
    Object.defineProperty(navigator, 'doNotTrack', { value: null, configurable: true });
  });

  it('sin banner en la pagina no hace nada; doble init es idempotente', () => {
    expect(() => initConsent()).not.toThrow();
    const el = mount();
    initConsent();
    initConsent();
    el.querySelector<HTMLButtonElement>('[data-consent-choice="granted"]')!.click();
    expect(readVisitorCookie(document.cookie)).toMatch(/^[a-f0-9]{16}$/);
  });
});
