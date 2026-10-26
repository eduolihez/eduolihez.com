/**
 * Duplica los elementos de la franja de stack para que el bucle sea continuo.
 * Las copias van aria-hidden: el contenido real sigue siendo una sola lista.
 */
export function cloneMarquee(): void {
  const track = document.querySelector<HTMLElement>('[data-marquee]');
  if (!track || track.dataset.cloned === 'true') return;

  const originals = [...track.children];
  if (originals.length === 0) return;

  originals.forEach((item) => {
    const copy = item.cloneNode(true) as HTMLElement;
    copy.setAttribute('aria-hidden', 'true');
    track.append(copy);
  });
  track.dataset.cloned = 'true';
}
