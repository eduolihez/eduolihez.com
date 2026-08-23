import { describe, it, expect, vi, afterEach } from 'vitest';
import { initReveal } from './reveal';

function setupElements() {
  document.body.innerHTML = `
    <div class="reveal" id="a"></div>
    <div class="reveal" id="b"></div>
  `;
}

describe('initReveal()', () => {
  afterEach(() => {
    document.body.innerHTML = '';
    document.documentElement.classList.remove('js-reveal');
    vi.unstubAllGlobals();
  });

  it('marca <html> con js-reveal para activar el CSS de ocultado inicial', () => {
    setupElements();
    initReveal();
    expect(document.documentElement.classList.contains('js-reveal')).toBe(true);
  });

  it('no hace nada si no hay elementos .reveal en la pagina', () => {
    document.body.innerHTML = '';
    expect(() => initReveal()).not.toThrow();
  });

  it('sin soporte de IntersectionObserver, muestra todo de inmediato', () => {
    setupElements();
    const original = window.IntersectionObserver;
    // @ts-expect-error -- simula un navegador sin soporte
    delete window.IntersectionObserver;
    try {
      initReveal();
      document.querySelectorAll('.reveal').forEach((el) => {
        expect(el.classList.contains('is-visible')).toBe(true);
      });
    } finally {
      window.IntersectionObserver = original;
    }
  });

  it('con prefers-reduced-motion, muestra todo de inmediato sin esperar scroll (regresion)', () => {
    setupElements();
    vi.stubGlobal(
      'matchMedia',
      vi.fn().mockReturnValue({ matches: true } as MediaQueryList),
    );

    initReveal();

    document.querySelectorAll('.reveal').forEach((el) => {
      expect(el.classList.contains('is-visible')).toBe(true);
    });
  });

  it('con soporte normal, no revela hasta que IntersectionObserver dispara', () => {
    setupElements();
    let capturedCallback: IntersectionObserverCallback | null = null;
    const observeMock = vi.fn();
    class FakeIntersectionObserver {
      constructor(cb: IntersectionObserverCallback) {
        capturedCallback = cb;
      }
      observe = observeMock;
      unobserve = vi.fn();
      disconnect = vi.fn();
    }
    vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver);

    initReveal();

    const a = document.getElementById('a') as HTMLElement;
    expect(a.classList.contains('is-visible')).toBe(false);
    expect(observeMock).toHaveBeenCalledTimes(2);

    capturedCallback?.(
      [{ target: a, isIntersecting: true } as IntersectionObserverEntry],
      {} as IntersectionObserver,
    );

    expect(a.classList.contains('is-visible')).toBe(true);
  });
});
