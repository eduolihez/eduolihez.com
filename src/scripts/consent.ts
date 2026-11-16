/**
 * consent.ts - Consentimiento OPT-IN para la cookie de analitica `eo_vid`.
 * ---------------------------------------------------------------------------
 * Sin consentimiento la analitica sigue exactamente como antes (sessionStorage,
 * IP hasheada, sin cookies). Solo si el visitante pulsa "Aceptar analitica" se
 * crea una cookie propia `eo_vid` (16 hex aleatorios, 180 dias) que analytics.ts
 * envia en el cuerpo de /api/visit.php como `visitor_id`. Sirve para distinguir
 * visitantes nuevos de recurrentes; no se cruza con nada ni sale de este sitio.
 *
 * Decisiones:
 *  - La cookie la crea JS (el servidor no hace Set-Cookie), asi que NO puede ser
 *    HttpOnly. No es una cookie de sesion ni de autenticacion: solo un numero
 *    aleatorio sin datos personales, de modo que leerla desde JS no expone nada.
 *  - La eleccion vive en localStorage (`eo_consent` = "granted|<ms>" o
 *    "denied|<ms>") y caduca a los 6 meses para volver a preguntar.
 *  - DNT=1 o GPC: se trata como "denied" y no se muestra banner.
 *  - Si localStorage no esta disponible (modo privado estricto), tambien se
 *    trata como "denied" sin banner: no podriamos recordar la respuesta y el
 *    banner reapareceria en cada pagina.
 *  - Max-Age se fija solo al crear la cookie: dura 180 dias desde el
 *    consentimiento, no se renueva en cada visita.
 */

export type Consent = 'granted' | 'denied';

export const CONSENT_KEY = 'eo_consent';
export const COOKIE_NAME = 'eo_vid';
export const COOKIE_MAX_AGE_S = 180 * 24 * 60 * 60;
/** 6 meses (~183 dias) antes de volver a preguntar. */
export const CONSENT_TTL_MS = 183 * 24 * 60 * 60 * 1000;
const VID_RE = /^[a-f0-9]{16}$/;

export interface PrivacyNav {
  doNotTrack?: string | null;
  globalPrivacyControl?: boolean;
}

/** DNT=1 o Global Privacy Control activos. */
export function hasPrivacySignal(nav: PrivacyNav): boolean {
  return nav.doNotTrack === '1' || nav.globalPrivacyControl === true;
}

/** localStorage o null si el navegador lo bloquea. */
export function getStorage(): Storage | null {
  try {
    const s = window.localStorage;
    const probe = '__eo_probe';
    s.setItem(probe, '1');
    s.removeItem(probe);
    return s;
  } catch {
    return null;
  }
}

/** Eleccion guardada y vigente, o null si no hay, es basura o ha caducado. */
export function readConsent(storage: Storage, now: number): Consent | null {
  try {
    const raw = storage.getItem(CONSENT_KEY);
    if (!raw) return null;
    const [value, ts] = raw.split('|');
    const at = Number(ts);
    if ((value !== 'granted' && value !== 'denied') || !Number.isFinite(at) || at > now) {
      storage.removeItem(CONSENT_KEY);
      return null;
    }
    if (now - at > CONSENT_TTL_MS) {
      storage.removeItem(CONSENT_KEY);
      return null;
    }
    return value;
  } catch {
    return null;
  }
}

/**
 * Consentimiento efectivo: 'denied' con DNT/GPC o sin almacenamiento; si no,
 * lo guardado (o null = todavia no ha elegido -> hay que preguntar).
 */
export function effectiveConsent(storage: Storage | null, nav: PrivacyNav, now: number): Consent | null {
  if (hasPrivacySignal(nav) || !storage) return 'denied';
  return readConsent(storage, now);
}

export function saveConsent(storage: Storage | null, value: Consent, now: number): void {
  try {
    storage?.setItem(CONSENT_KEY, `${value}|${now}`);
  } catch {
    /* sin almacenamiento: se comporta como "denied" en la siguiente pagina */
  }
}

/** Lee `eo_vid` de document.cookie, solo si tiene el formato esperado. */
export function readVisitorCookie(cookieStr: string): string | null {
  for (const part of cookieStr.split(';')) {
    const [k, v] = part.trim().split('=');
    if (k === COOKIE_NAME && v && VID_RE.test(v)) return v;
  }
  return null;
}

export function buildVisitorCookie(id: string, secure: boolean): string {
  return `${COOKIE_NAME}=${id}; Max-Age=${COOKIE_MAX_AGE_S}; Path=/; SameSite=Lax${secure ? '; Secure' : ''}`;
}

export function buildDeleteCookie(secure: boolean): string {
  return `${COOKIE_NAME}=; Max-Age=0; Path=/; SameSite=Lax${secure ? '; Secure' : ''}`;
}

function newVisitorId(): string {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

function isSecure(): boolean {
  return location.protocol === 'https:';
}

/** Reutiliza la cookie valida si existe; si no, la crea (180 dias). */
export function getOrCreateVisitorId(doc: Document = document, secure = isSecure()): string {
  const existing = readVisitorCookie(doc.cookie);
  if (existing) return existing;
  const id = newVisitorId();
  doc.cookie = buildVisitorCookie(id, secure);
  return id;
}

export function clearVisitorId(doc: Document = document, secure = isSecure()): void {
  if (readVisitorCookie(doc.cookie) !== null || doc.cookie.includes(`${COOKIE_NAME}=`)) {
    doc.cookie = buildDeleteCookie(secure);
  }
}

/**
 * visitor_id a enviar con la visita, o undefined. Sin consentimiento vigente
 * (rechazado, caducado, DNT/GPC) borra la cookie si quedase alguna.
 */
export function consentedVisitorId(
  storage: Storage | null = getStorage(),
  nav: PrivacyNav = navigator as PrivacyNav,
  now: number = Date.now(),
  doc: Document = document,
): string | undefined {
  if (effectiveConsent(storage, nav, now) === 'granted') return getOrCreateVisitorId(doc);
  clearVisitorId(doc);
  return undefined;
}

/** Aplica una eleccion: guarda, crea o borra la cookie. */
export function applyChoice(value: Consent, storage: Storage | null = getStorage(), now = Date.now(), doc: Document = document): void {
  saveConsent(storage, value, now);
  if (value === 'granted') getOrCreateVisitorId(doc);
  else clearVisitorId(doc);
}

// --- Banner -----------------------------------------------------------------

let returnFocus: HTMLElement | null = null;

function banner(): HTMLElement | null {
  return document.querySelector<HTMLElement>('[data-consent-banner]');
}

export function openBanner(focus: boolean): void {
  const el = banner();
  if (!el) return;
  el.hidden = false;
  if (focus) el.querySelector<HTMLElement>('[data-consent-title]')?.focus();
}

function closeBanner(): void {
  const el = banner();
  if (el) el.hidden = true;
  returnFocus?.focus();
  returnFocus = null;
}

/** Engancha el banner y el enlace "Cookies" del pie. Idempotente por pagina. */
export function initConsent(): void {
  const el = banner();
  if (!el || el.dataset.consentReady) return;
  el.dataset.consentReady = '1';
  const storage = getStorage();
  const nav = navigator as PrivacyNav;
  const signal = hasPrivacySignal(nav);

  el.querySelectorAll<HTMLButtonElement>('[data-consent-choice]').forEach((btn) => {
    btn.addEventListener('click', () => {
      applyChoice(btn.dataset.consentChoice === 'granted' ? 'granted' : 'denied', storage);
      closeBanner();
    });
  });
  el.addEventListener('keydown', (e) => {
    // Escape solo cierra si ya habia una eleccion (reabierto desde el pie).
    if (e.key === 'Escape' && storage && readConsent(storage, Date.now()) !== null) closeBanner();
  });

  document.querySelectorAll<HTMLAnchorElement>('[data-consent-open]').forEach((link) => {
    // Con DNT/GPC o sin almacenamiento no hay nada que elegir: el enlace lleva
    // a la explicacion de "Sobre esta web" sin interceptar.
    if (signal || !storage) return;
    link.addEventListener('click', (e) => {
      e.preventDefault();
      returnFocus = link;
      openBanner(true);
    });
  });

  if (effectiveConsent(storage, nav, Date.now()) === null) openBanner(false);
}

if (typeof document !== 'undefined') {
  document.addEventListener('DOMContentLoaded', initConsent);
  document.addEventListener('astro:page-load', initConsent);
}
