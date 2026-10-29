/**
 * Modal "CV en actualizacion", compartido por todas las paginas.
 *
 * Antes vivia dentro de <Hero> y solo lo abria el boton del hero; el pie y la
 * paleta enlazaban a /cv/*.pdf, que no existe (404 en cada pagina). Ahora el
 * modal se pinta una vez en BaseLayout y lo abre cualquier elemento con
 * [data-cv-open] o el evento CV_OPEN_EVENT (lo lanza la paleta de comandos).
 */

/** Evento que abre el modal desde codigo que no tiene un boton propio. */
export const CV_OPEN_EVENT = 'cv:open';

/** Coincide con la transicion de .modal-backdrop en global.css. */
const CLOSE_DELAY_MS = 200;

// Listeners del init anterior: si el modal se vuelve a pintar (otro DOM), se
// desenganchan para no tener dos copias reaccionando al mismo clic.
let bound: AbortController | null = null;

export function initCvModal(): void {
  const modal = document.getElementById('cv-modal');
  if (!modal || modal.dataset.cvReady) return;
  modal.dataset.cvReady = 'true';
  bound?.abort();
  bound = new AbortController();
  const { signal } = bound;

  const closeBtn = document.getElementById('cv-modal-close');
  let opener: HTMLElement | null = null;

  const isOpen = (): boolean => modal.classList.contains('open');

  // aria-modal no basta para retener el foco: el resto de la pagina queda
  // inert mientras el aviso esta abierto (mismo patron que la paleta).
  const inerted: Element[] = [];
  const setPageInert = (on: boolean): void => {
    if (!on) {
      inerted.splice(0).forEach((el) => el.removeAttribute('inert'));
      return;
    }
    [...document.body.children].forEach((el) => {
      if (el === modal || el.tagName === 'SCRIPT' || el.hasAttribute('inert')) return;
      el.setAttribute('inert', '');
      inerted.push(el);
    });
  };

  const show = (): void => {
    // Reabierto durante la transicion de cierre: el foco esta en el boton de
    // cerrar y no es quien lo abrio, asi que se conserva el opener anterior.
    if (modal.hasAttribute('hidden')) {
      opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    }
    setPageInert(true);
    modal.removeAttribute('hidden');
    void modal.offsetWidth; // fuerza el reflow para que arranque la transicion
    modal.classList.add('open');
    document.body.style.overflow = 'hidden';
    closeBtn?.focus();
  };

  const hide = (): void => {
    modal.classList.remove('open');
    setTimeout(() => {
      if (isOpen()) return;
      modal.setAttribute('hidden', '');
      setPageInert(false);
      document.body.style.overflow = '';
      opener?.focus();
    }, CLOSE_DELAY_MS);
  };

  document.addEventListener(
    'click',
    (e) => {
      const trigger = (e.target as Element | null)?.closest?.('[data-cv-open]');
      if (!trigger) return;
      e.preventDefault();
      show();
    },
    { signal },
  );
  document.addEventListener(CV_OPEN_EVENT, show, { signal });
  document.addEventListener(
    'keydown',
    (e) => {
      if (e.key === 'Escape' && isOpen()) hide();
    },
    { signal },
  );

  closeBtn?.addEventListener('click', hide);
  document.getElementById('cv-modal-btn-close')?.addEventListener('click', hide);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) hide();
  });
}
