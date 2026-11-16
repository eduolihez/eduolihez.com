/**
 * experience-fold.ts - Movil (<768 px): pliega los puestos antiguos de
 * Experience.astro. El contenido sigue en el DOM; en escritorio y sin JS los
 * <details> quedan abiertos (el atributo `open` viene de serie en el HTML).
 */
export function foldExperience(): void {
  if (typeof window.matchMedia !== 'function' || !window.matchMedia('(max-width: 767px)').matches) return;
  document.querySelectorAll<HTMLDetailsElement>('details[data-exp-fold]').forEach((d) => {
    d.open = false;
  });
}
