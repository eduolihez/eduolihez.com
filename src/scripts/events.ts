/**
 * events.ts - Eventos de uso (clics) para la analitica propia.
 * ---------------------------------------------------------------------------
 * Delegacion: un unico `click` y un unico `submit` en document, registrados
 * una sola vez (el modulo es un singleton; View Transitions no lo reejecuta).
 * Envia POST /api/visit.php {action:"event", name, target?, path, session_id}.
 * Con DNT/GPC no se envia nada. Nunca se leen datos de formularios.
 *
 * cv_open: el CvModal NO tiene enlace de descarga al PDF (solo LinkedIn y
 * email), asi que se cuenta la apertura del modal: clic en [data-cv-open] o
 * CV_OPEN_EVENT (paleta). Hoy no se solapan (la paleta no usa [data-cv-open]),
 * pero un guard simetrico de CV_DEDUPE_MS evita contar dos veces la misma
 * apertura si algun dia llegan ambas.
 */
import { hasPrivacySignal, type PrivacyNav } from './consent';
import { getOrCreateSessionId, send } from './analytics';
import { CV_OPEN_EVENT } from './cvModal';

export interface ClassifiedEvent {
  name: string;
  target?: string;
}

const TARGET_RE = /^[a-z0-9.-]{1,80}$/;
const LANGS = ['es', 'en', 'ca'];
const MAX_PATH = 120;
/** Misma regex de ruta que el servidor (lib/events.php). */
const PATH_RE = /^\/[a-zA-Z0-9/_\-.]*$/;
/** Ventana en la que una segunda apertura del CV se considera la misma. */
export const CV_DEDUPE_MS = 1000;

/** Hostname en minusculas sin "www.". */
function cleanHost(host: string): string {
  return host.toLowerCase().replace(/^www\./, '');
}

/**
 * Clasifica un clic. `here` es el hostname de la pagina actual. Devuelve null
 * si no es un evento a registrar.
 */
export function classifyClick(target: Element | null, here: string): ClassifiedEvent | null {
  if (!target || typeof target.closest !== 'function') return null;

  if (target.closest('[data-cv-open]')) return { name: 'cv_open' };

  if (target.closest('[data-theme-toggle]')) {
    const theme = document.documentElement.dataset.theme;
    return theme === 'light' || theme === 'dark' ? { name: 'theme_toggle', target: theme } : { name: 'theme_toggle' };
  }

  const a = target.closest('a[href]') as HTMLAnchorElement | null;
  if (!a) return null;

  if (a.hasAttribute('hreflang') && a.closest('header')) {
    const code = (a.getAttribute('hreflang') ?? '').toLowerCase().split('-')[0];
    return LANGS.includes(code) ? { name: 'lang_switch', target: code } : null;
  }

  let url: URL;
  try {
    url = new URL(a.getAttribute('href') ?? '', `https://${here}/`);
  } catch {
    return null;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
  const host = cleanHost(url.hostname);
  if (host === cleanHost(here)) return null;
  return { name: 'outbound', target: host };
}

/** Evento valido para el servidor (target ^[a-z0-9.-]{1,80}$, path <= 120 con su regex). */
export function isValidEvent(ev: ClassifiedEvent, path: string): boolean {
  if (path.length === 0 || path.length > MAX_PATH || !PATH_RE.test(path)) return false;
  return ev.target === undefined || TARGET_RE.test(ev.target);
}

/** Envia un evento. Silencioso ante cualquier fallo; no-op con DNT/GPC. */
export function trackEvent(ev: ClassifiedEvent): void {
  try {
    if (hasPrivacySignal(navigator as PrivacyNav)) return;
    const path = location.pathname;
    if (!isValidEvent(ev, path)) return;
    const payload: Record<string, string> = { action: 'event', name: ev.name };
    if (ev.target) payload.target = ev.target;
    payload.path = path;
    payload.session_id = getOrCreateSessionId(sessionStorage);
    send(JSON.stringify(payload));
  } catch {
    /* silencioso: la analitica nunca debe romper la web */
  }
}

let lastCvOpenAt = -Infinity;

/** cv_open con dedupe: dos aperturas en menos de CV_DEDUPE_MS cuentan una. */
export function trackCvOpen(): void {
  const now = Date.now();
  if (now - lastCvOpenAt < CV_DEDUPE_MS) return;
  lastCvOpenAt = now;
  trackEvent({ name: 'cv_open' });
}

function onClick(e: Event): void {
  try {
    const ev = classifyClick(e.target as Element | null, location.hostname);
    if (ev?.name === 'cv_open') trackCvOpen();
    else if (ev) trackEvent(ev);
  } catch {
    /* silencioso */
  }
}

function onSubmit(e: Event): void {
  try {
    const t = e.target as Element | null;
    if (t && typeof t.matches === 'function' && t.matches('form[data-formspree]')) {
      trackEvent({ name: 'contact_submit' });
    }
  } catch {
    /* silencioso */
  }
}

let lastNotFoundPath: string | null = null;

/**
 * Pagina 404 (marcada en ErrorPage.astro): envia not_found con la ruta rota.
 * Se llama en DOMContentLoaded y en astro:page-load; un solo envio por ruta
 * (se rearma al pasar por una pagina que no es 404).
 */
export function trackNotFound(): void {
  try {
    if (!document.querySelector('[data-error-page="404"]')) {
      lastNotFoundPath = null;
      return;
    }
    if (location.pathname === lastNotFoundPath) return;
    lastNotFoundPath = location.pathname;
    trackEvent({ name: 'not_found' });
  } catch {
    /* silencioso */
  }
}

let registered = false;

/** Registra los listeners una sola vez. Devuelve false si ya estaban. */
export function registerEventListeners(): boolean {
  if (registered) return false;
  registered = true;
  document.addEventListener('click', onClick);
  document.addEventListener('submit', onSubmit);
  document.addEventListener(CV_OPEN_EVENT, trackCvOpen);
  document.addEventListener('DOMContentLoaded', trackNotFound);
  document.addEventListener('astro:page-load', trackNotFound);
  return true;
}

if (typeof document !== 'undefined') registerEventListeners();
