/**
 * analytics.ts - Registro de visitas para la analitica propia (sin terceros).
 * ---------------------------------------------------------------------------
 * Envia dos tipos de senal a /api/visit.php:
 *
 *  1. "hit": una pagina vista, al cargar y en cada navegacion con View
 *     Transitions (astro:page-load). Lleva un session_id (agrupa las
 *     paginas de una misma visita) y un hit_id (identifica esa pagina en
 *     concreto). Ninguno de los dos es un identificador persistente:
 *     session_id vive en sessionStorage y muere con la pestana; hit_id es
 *     de un solo uso, generado de nuevo en cada pagina.
 *
 *  2. "beat": al abandonar una pagina (siguiente navegacion, o pagehide si
 *     se cierra la pestana de verdad), se envia cuanto tiempo estuvo
 *     visible y hasta donde se hizo scroll, referenciando el hit_id de esa
 *     pagina. Es la unica forma en que esta analitica sabe algo de
 *     comportamiento, y no requiere guardar nada nuevo en el cliente.
 */
import { api } from '../config';

const SESSION_KEY = 'eo_session_id';
export const TOKEN_RE = /^[a-f0-9]{16}$/;

export type ViewportBucket = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

/** Bucket de ancho de viewport. Nunca se transmite el pixel exacto. */
export function bucketViewport(width: number): ViewportBucket {
  if (width < 480) return 'xs';
  if (width < 768) return 'sm';
  if (width < 1024) return 'md';
  if (width < 1440) return 'lg';
  return 'xl';
}

const UTM_KEYS = ['utm_source', 'utm_medium', 'utm_campaign'] as const;
type UtmKey = (typeof UTM_KEYS)[number];

/** Extrae utm_source/utm_medium/utm_campaign de la URL de aterrizaje. */
export function parseUtm(search: string): Partial<Record<UtmKey, string>> {
  const params = new URLSearchParams(search);
  const out: Partial<Record<UtmKey, string>> = {};
  for (const key of UTM_KEYS) {
    const value = params.get(key)?.trim();
    if (value) out[key] = value.slice(0, 60);
  }
  return out;
}

/** Subtag primario de navigator.language ("es-ES" -> "es"), o '' si no cuadra. */
export function browserLangCode(lang: string): string {
  const primary = (lang.split('-')[0] ?? '').toLowerCase();
  return /^[a-z]{2}$/.test(primary) ? primary : '';
}

/** Token de 16 hex (crypto-random), usado tanto para session_id como hit_id. */
export function generateId(): string {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Id de sesion: vive en sessionStorage (muere al cerrar la pestana), no en
 * localStorage ni en cookies. Si el almacenamiento no esta disponible (modo
 * privado estricto, cuotas agotadas), se genera un id de un solo uso sin
 * intentar persistirlo: la analitica nunca debe romper por esto.
 */
export function getOrCreateSessionId(storage: Storage): string {
  try {
    const existing = storage.getItem(SESSION_KEY);
    if (existing && TOKEN_RE.test(existing)) return existing;
    const id = generateId();
    storage.setItem(SESSION_KEY, id);
    return id;
  } catch {
    return generateId();
  }
}

/** Profundidad de scroll actual, 0-100. Sin contenido que hacer scroll, 100. */
function currentScrollPct(): number {
  const scrollable = document.documentElement.scrollHeight - window.innerHeight;
  if (scrollable <= 0) return 100;
  const pct = (window.scrollY / scrollable) * 100;
  return Math.max(0, Math.min(100, Math.round(pct)));
}

function send(body: string): void {
  const url = api('/api/visit.php');
  // sendBeacon no bloquea la carga; si no existe, usamos fetch.
  if (navigator.sendBeacon) {
    navigator.sendBeacon(url, body);
  } else {
    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      keepalive: true,
    }).catch(() => {});
  }
}

let sessionId: string | null = null;
let currentHitId: string | null = null;
let pageStart = 0;
let maxScrollPct = 0;
let scrollTicking = false;

// requestAnimationFrame-throttled: scroll dispara hasta 60+ veces/segundo, y
// currentScrollPct() lee scrollHeight/innerHeight (layout). Sin throttle, se
// recalcularia el layout en cada evento en vez de a lo sumo una vez por frame.
function onScroll(): void {
  if (scrollTicking) return;
  scrollTicking = true;
  requestAnimationFrame(() => {
    maxScrollPct = Math.max(maxScrollPct, currentScrollPct());
    scrollTicking = false;
  });
}

/**
 * Cierra la pagina actual: envia cuanto duro y hasta donde se vio.
 * Puede llamarse tanto desde trackVisit() (ya protegido por su propio
 * try/catch) como desde el listener de pagehide directamente, que no tiene
 * ninguno propio -- de ahi el try/catch aqui: la garantia de "la analitica
 * nunca debe romper la web" tiene que sostenerse tambien al cerrar pestana.
 */
function sendBeat(): void {
  if (!currentHitId) return;
  try {
    const duration = Math.round((performance.now() - pageStart) / 1000);
    send(
      JSON.stringify({
        action: 'beat',
        hit_id: currentHitId,
        // Limite real de la columna: SMALLINT UNSIGNED (65535, ~18.2 h).
        duration_s: Math.max(0, Math.min(65535, duration)),
        scroll_pct: maxScrollPct,
      }),
    );
  } catch {
    /* silencioso: ver comentario de la funcion */
  }
  currentHitId = null;
}

export function trackVisit(): void {
  try {
    // No registramos si el usuario pide "Do Not Track".
    if (navigator.doNotTrack === '1') return;

    // Cierra la pagina anterior (si la habia) antes de abrir la nueva.
    sendBeat();

    sessionId ??= getOrCreateSessionId(sessionStorage);
    currentHitId = generateId();
    pageStart = performance.now();
    maxScrollPct = currentScrollPct();

    const body = JSON.stringify({
      path: location.pathname,
      referrer: document.referrer || '',
      session_id: sessionId,
      hit_id: currentHitId,
      viewport: bucketViewport(window.innerWidth),
      browser_lang: browserLangCode(navigator.language || ''),
      ...parseUtm(location.search),
    });
    send(body);
  } catch {
    /* silencioso: la analitica nunca debe romper la web */
  }
}

// Se ejecuta tanto en carga normal como al navegar con View Transitions.
// DOMContentLoaded (no una llamada inmediata) porque este script se procesa
// como modulo ES (diferido): registrar el listener aqui es seguro, ya que la
// especificacion garantiza que los modulos se ejecutan antes de que
// DOMContentLoaded se dispare (mismo patron que reveal.ts).
document.addEventListener('DOMContentLoaded', trackVisit);
document.addEventListener('astro:page-load', trackVisit);
window.addEventListener('scroll', onScroll, { passive: true });
window.addEventListener('pagehide', sendBeat);
