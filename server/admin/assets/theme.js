/**
 * theme.js - fija el tema (claro/oscuro) del panel antes del primer pintado.
 * Se carga de forma sincrona en el <head>, antes del CSS, para evitar el
 * destello. Solo escribe data-theme si hay una eleccion guardada en
 * localStorage ('theme': 'light' | 'dark'); sin eleccion el CSS sigue a
 * prefers-color-scheme (admin.css). El interruptor y la paleta de comandos
 * (assets/palette.js, generado desde src/scripts/) guardan la eleccion.
 */
(function () {
  'use strict';
  try {
    var saved = localStorage.getItem('theme') || localStorage.getItem('admin-theme');
    if (saved === 'light' || saved === 'dark') {
      document.documentElement.dataset.theme = saved;
    }
  } catch (err) {
    // localStorage bloqueado: se sigue al sistema.
  }
})();
