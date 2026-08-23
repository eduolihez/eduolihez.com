// Setup global de Vitest (registrado via vitest.config.ts -> test.setupFiles).
// jsdom no implementa window.matchMedia por defecto (no es parte del DOM, es
// una API de layout del navegador) -- cualquier codigo que lo llame revienta
// con "not implemented" salvo que se rellene aqui una vez para todos los tests.
if (typeof window !== 'undefined' && !window.matchMedia) {
  window.matchMedia = (query: string): MediaQueryList =>
    ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    }) as MediaQueryList;
}
