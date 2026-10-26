/**
 * Ventana con todas las habilidades (Skills.astro). Se abre desde el titulo de
 * la seccion; el contenido ya esta en el HTML (oculto), asi que buscadores y
 * lectores de pantalla lo tienen aunque el JS no cargue.
 */
const FOCUSABLE = 'a[href], button:not([disabled])';

// Una sola instancia viva: reiniciar (astro:page-load) suelta los listeners
// del documento de la anterior.
let teardown: AbortController | null = null;

export function initSkillsModal(): void {
  teardown?.abort();
  teardown = null;

  const modal = document.querySelector<HTMLElement>('[data-skills-modal]');
  const openers = document.querySelectorAll<HTMLElement>('[data-skills-open]');
  if (!modal || openers.length === 0) return;

  const controller = new AbortController();
  teardown = controller;
  const { signal } = controller;
  let lastOpener: HTMLElement | null = null;

  const focusables = (): HTMLElement[] => [...modal.querySelectorAll<HTMLElement>(FOCUSABLE)];

  function open(opener: HTMLElement): void {
    lastOpener = opener;
    modal!.hidden = false;
    document.body.style.overflow = 'hidden';
    openers.forEach((el) => el.setAttribute('aria-expanded', 'true'));
    // Fuerza el reflujo para que la transicion de opacidad arranque.
    void modal!.offsetWidth;
    modal!.classList.add('open');
    modal!.querySelector<HTMLElement>('[data-skills-close]')?.focus();
  }

  function close(): void {
    modal!.classList.remove('open');
    modal!.hidden = true;
    document.body.style.overflow = '';
    openers.forEach((el) => el.setAttribute('aria-expanded', 'false'));
    lastOpener?.focus();
  }

  openers.forEach((el) => el.addEventListener('click', () => open(el), { signal }));
  modal.querySelectorAll('[data-skills-close]').forEach((el) => el.addEventListener('click', close, { signal }));
  modal.addEventListener(
    'click',
    (e) => {
      if (e.target === modal) close();
    },
    { signal },
  );

  document.addEventListener(
    'keydown',
    (e) => {
      if (modal.hidden) return;
      // La paleta (Ctrl+K) puede abrirse encima: su Escape es suyo.
      if (e.key === 'Escape') {
        if (document.querySelector('[data-palette]:not([hidden])')) return;
        e.preventDefault();
        close();
        return;
      }
      if (e.key !== 'Tab') return;
      // El foco da la vuelta dentro de la ventana.
      const items = focusables();
      if (items.length === 0) return;
      const first = items[0];
      const last = items[items.length - 1];
      const active = document.activeElement;
      if (!active || !modal.contains(active)) {
        e.preventDefault();
        first.focus();
      } else if (e.shiftKey && active === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    },
    { signal },
  );
}
