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

export function initCvModal(): void {
  const modal = document.getElementById('cv-modal');
  if (!modal || modal.dataset.cvReady) return;
  modal.dataset.cvReady = 'true';

  const closeBtn = document.getElementById('cv-modal-close');
  let opener: HTMLElement | null = null;

  const isOpen = (): boolean => modal.classList.contains('open');

  const show = (): void => {
    opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
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
      document.body.style.overflow = '';
      opener?.focus();
    }, CLOSE_DELAY_MS);
  };

  document.addEventListener('click', (e) => {
    const trigger = (e.target as Element | null)?.closest?.('[data-cv-open]');
    if (!trigger) return;
    e.preventDefault();
    show();
  });
  document.addEventListener(CV_OPEN_EVENT, show);
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isOpen()) hide();
  });

  closeBtn?.addEventListener('click', hide);
  document.getElementById('cv-modal-btn-close')?.addEventListener('click', hide);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) hide();
  });
}
