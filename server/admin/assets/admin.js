/**
 * admin.js - JS del panel (externo, para cumplir la CSP estricta sin
 * manejadores en linea). Se carga en todas las paginas via admin_footer().
 *
 * Funciones:
 *   [data-confirm]      en un <form>  -> pide confirmacion al enviarlo.
 *   [data-confirm-btn]  en un <button> -> pide confirmacion solo con ese boton.
 *   #check-all          -> marca/desmarca todas las .row-check.
 *   #bulk-form          -> avisa si no hay nada seleccionado.
 *   [data-autosubmit]   -> envia el formulario al cambiar el control.
 */
(function () {
  'use strict';

  // --- Confirmacion por boton concreto (acciones en lote) -------------------
  // Se guarda en el formulario para que el handler de submit sepa que ya se
  // confirmo (o que debe cancelarse).
  document.addEventListener('click', function (e) {
    var btn = e.target && e.target.closest ? e.target.closest('[data-confirm-btn]') : null;
    if (!btn) return;
    if (!window.confirm(btn.getAttribute('data-confirm-btn') || '¿Continuar?')) {
      e.preventDefault();
      e.stopPropagation();
    }
  });

  // --- Confirmacion a nivel de formulario ----------------------------------
  document.addEventListener('submit', function (e) {
    var form = e.target;
    if (!form || !form.matches) return;

    // Aviso si se lanza una accion en lote sin nada seleccionado.
    if (form.id === 'bulk-form') {
      var anyChecked = form.querySelectorAll('.row-check:checked').length > 0;
      if (!anyChecked) {
        e.preventDefault();
        window.alert('Selecciona al menos un mensaje.');
        return;
      }
    }

    if (form.matches('[data-confirm]')) {
      var msg = form.getAttribute('data-confirm') || '¿Continuar?';
      if (!window.confirm(msg)) {
        e.preventDefault();
      }
    }
  });

  // --- Marcar / desmarcar todo ---------------------------------------------
  document.addEventListener('change', function (e) {
    var el = e.target;
    if (!el) return;

    if (el.id === 'check-all') {
      var boxes = document.querySelectorAll('.row-check');
      for (var i = 0; i < boxes.length; i++) {
        boxes[i].checked = el.checked;
      }
      return;
    }

    // Controles que envian su formulario al cambiar (selectores de filtro).
    if (el.matches && el.matches('[data-autosubmit]') && el.form) {
      el.form.submit();
    }
  });
})();
