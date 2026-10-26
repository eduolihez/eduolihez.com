/**
 * Tema claro/oscuro. Por defecto sigue al sistema (sin atributo data-theme, y
 * el CSS decide con prefers-color-scheme); si la persona elige, se guarda y
 * se fija data-theme. El primer pintado lo resuelve public/theme-init.js,
 * sincrono en el <head>, para que no haya destello; este modulo gestiona el
 * boton y la paleta de comandos.
 */
export type ThemePreference = 'light' | 'dark' | 'system';
export type EffectiveTheme = 'light' | 'dark';

export const THEME_STORAGE_KEY = 'theme';

/** Mismos valores que --color-bg en tokens.css (barra del navegador movil). */
const THEME_COLOR: Record<EffectiveTheme, string> = {
  light: '#f5f6f3',
  dark: '#0a0e14',
};

export function getStoredTheme(): ThemePreference {
  try {
    const saved = localStorage.getItem(THEME_STORAGE_KEY);
    if (saved === 'light' || saved === 'dark') return saved;
  } catch {
    // localStorage bloqueado: se sigue al sistema.
  }
  return 'system';
}

export function effectiveTheme(pref: ThemePreference): EffectiveTheme {
  if (pref !== 'system') return pref;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function applyTheme(pref: ThemePreference): void {
  const root = document.documentElement;
  if (pref === 'system') root.removeAttribute('data-theme');
  else root.dataset.theme = pref;

  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute('content', THEME_COLOR[effectiveTheme(pref)]);
}

export function setTheme(pref: ThemePreference): void {
  try {
    if (pref === 'system') localStorage.removeItem(THEME_STORAGE_KEY);
    else localStorage.setItem(THEME_STORAGE_KEY, pref);
  } catch {
    // Sin almacenamiento el cambio vale solo para esta visita.
  }
  applyTheme(pref);
}

/** Alterna entre claro y oscuro partiendo del tema que se ve ahora mismo. */
export function toggleTheme(): EffectiveTheme {
  const next: EffectiveTheme = effectiveTheme(getStoredTheme()) === 'dark' ? 'light' : 'dark';
  setTheme(next);
  return next;
}

function syncPressed(): void {
  const dark = effectiveTheme(getStoredTheme()) === 'dark';
  document
    .querySelectorAll<HTMLElement>('[data-theme-toggle]')
    .forEach((btn) => btn.setAttribute('aria-pressed', String(dark)));
}

// Una sola instancia viva: reiniciar (astro:page-load) suelta los listeners de
// la anterior, si no el boton alternaria dos veces por clic.
let teardown: AbortController | null = null;

export function initThemeToggle(): void {
  teardown?.abort();
  teardown = null;

  const buttons = document.querySelectorAll<HTMLElement>('[data-theme-toggle]');
  if (buttons.length === 0) return;

  const controller = new AbortController();
  teardown = controller;
  const { signal } = controller;

  syncPressed();
  buttons.forEach((btn) =>
    btn.addEventListener(
      'click',
      () => {
        toggleTheme();
        syncPressed();
      },
      { signal },
    ),
  );

  // Si se sigue al sistema y este cambia, el boton y la barra se actualizan.
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener(
    'change',
    () => {
      if (getStoredTheme() === 'system') {
        applyTheme('system');
        syncPressed();
      }
    },
    { signal },
  );
}
