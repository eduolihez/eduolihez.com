/**
 * Carga diferida de Cloudflare Turnstile (captcha del formulario de contacto).
 *
 * El script de Turnstile arrastra ~1,3 MB (iframe, fuentes, WASM) y ocupa el
 * hilo principal unos 400 ms. Cargarlo en cada visita a la portada lo pagaban
 * todos, aunque casi nadie llega al formulario. Ahora se inyecta solo cuando
 * el formulario se acerca al viewport o alguien enfoca uno de sus campos; al
 * cargar, Turnstile pinta solo los .cf-turnstile que encuentra (render implicito).
 */

/** Margen para empezar a cargar antes de que el formulario sea visible. */
const PRELOAD_MARGIN = '400px 0px';

export function loadTurnstileOnDemand(form: HTMLElement, src: string): void {
  if (!form.querySelector('.cf-turnstile')) return;

  let observer: IntersectionObserver | null = null;
  const load = (): void => {
    observer?.disconnect();
    form.removeEventListener('focusin', load);
    if (document.querySelector(`script[src="${src}"]`)) return;
    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    // Red caida o bloqueador: sin esto el captcha no aparecia nunca y el
    // formulario quedaba sin poder enviarse. Se reintenta al siguiente foco.
    script.addEventListener('error', () => {
      script.remove();
      form.addEventListener('focusin', load);
    });
    document.head.append(script);
  };

  if (typeof IntersectionObserver === 'undefined') {
    load();
    return;
  }

  form.addEventListener('focusin', load);
  observer = new IntersectionObserver(
    (entries) => {
      if (entries.some((entry) => entry.isIntersecting)) load();
    },
    { rootMargin: PRELOAD_MARGIN },
  );
  observer.observe(form);
}
