/**
 * reveal.ts - Animacion de aparicion al hacer scroll.
 * Anade la clase "is-visible" a cualquier elemento con clase "reveal"
 * cuando entra en el viewport. Usa IntersectionObserver (nativo, sin librerias).
 */
export function initReveal() {
  // Gate de progressive enhancement (B1): solo AHORA, con JS ejecutandose,
  // activamos el ocultado inicial. Si este script no corre, el CSS deja todo
  // visible y nunca se queda nada oculto.
  document.documentElement.classList.add('js-reveal');

  const elements = document.querySelectorAll<HTMLElement>('.reveal');
  if (elements.length === 0) return;

  // Si el navegador no soporta IntersectionObserver, mostramos todo directamente.
  if (!('IntersectionObserver' in window)) {
    elements.forEach((el) => el.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target); // solo una vez
        }
      });
    },
    { threshold: 0.12, rootMargin: '0px 0px -40px 0px' },
  );

  elements.forEach((el) => observer.observe(el));
}

// Se ejecuta tanto en carga normal como al navegar con View Transitions.
document.addEventListener('DOMContentLoaded', initReveal);
document.addEventListener('astro:page-load', initReveal);
