/* Fija el tema elegido antes del primer pintado (sin destello). Sincrono y
   externo para cumplir la CSP (script-src 'self'). Sin eleccion guardada el CSS
   sigue a prefers-color-scheme y aqui solo se ajusta la barra del navegador.
   La logica completa vive en src/scripts/theme.ts. */
(function () {
  var theme = null;
  try {
    var saved = localStorage.getItem('theme');
    if (saved === 'light' || saved === 'dark') {
      theme = saved;
      document.documentElement.setAttribute('data-theme', saved);
    }
  } catch (err) {
    /* localStorage bloqueado: se sigue al sistema. */
  }
  if (!theme) {
    try {
      theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    } catch (err) {
      theme = 'light';
    }
  }
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', theme === 'dark' ? '#0a0e14' : '#f5f6f3');
})();
