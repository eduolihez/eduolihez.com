/**
 * post-edit.js - JS de post-edit.php (externo, para cumplir la CSP estricta
 * `script-src 'self'`: antes era un <script> en linea y el navegador lo bloqueaba).
 *
 * Autogeneracion del slug a partir del titulo, en tiempo real. Solo al crear:
 * post-edit.php pone `data-slug-auto` en #slug unicamente cuando el articulo es
 * nuevo. Si la persona edita el slug a mano, deja de pisarselo.
 */
(function () {
  'use strict';

  function slugify(text) {
    return text
      .toLowerCase()
      .normalize('NFD') // Quitar acentos
      .replace(/[̀-ͯ]/g, '')
      .replace(/[^a-z0-9\s-]/g, '') // Eliminar caracteres especiales
      .trim()
      .replace(/\s+/g, '-') // Cambiar espacios por guiones
      .replace(/-+/g, '-'); // Quitar guiones duplicados
  }

  function init() {
    var titleIn = document.getElementById('title');
    var slugIn = document.getElementById('slug');
    if (!titleIn || !slugIn || !slugIn.hasAttribute('data-slug-auto')) return;

    var manualSlug = false;
    slugIn.addEventListener('input', function () {
      manualSlug = true;
    });
    titleIn.addEventListener('input', function () {
      if (!manualSlug) slugIn.value = slugify(titleIn.value);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
