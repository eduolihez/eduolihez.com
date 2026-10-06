/**
 * theme.js - fija el tema (claro/oscuro) del panel antes del primer pintado.
 * Se carga de forma sincrona en el <head>, antes del CSS, para evitar el
 * destello. Prioridad: valor guardado en localStorage ('admin-theme', solo
 * 'light' o 'dark') y, si no hay, la preferencia del sistema. El interruptor
 * vive en admin.js.
 */
(function () {
  'use strict';
  var theme = null;
  try {
    var saved = localStorage.getItem('admin-theme');
    if (saved === 'light' || saved === 'dark') theme = saved;
  } catch (err) {
    // localStorage bloqueado: se usa la preferencia del sistema.
  }
  if (!theme) {
    var dark = false;
    try {
      dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    } catch (err) {
      // sin matchMedia: tema claro.
    }
    theme = dark ? 'dark' : 'light';
  }
  document.documentElement.dataset.theme = theme;
})();
