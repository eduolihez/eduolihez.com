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
 *   [data-copy]         en un <button> -> copia el texto del elemento que
 *                        selecciona (querySelector) al portapapeles y
 *                        confirma con "Copiado" durante 1.6s.
 *   [data-autocopy]     en cualquier elemento -> copia su texto solo, en
 *                        cuanto la pagina carga (p.ej. una clave de API que
 *                        se muestra una sola vez).
 */
(function () {
  'use strict';

  // --- Copiar al portapapeles ------------------------------------------------
  // Texto a copiar: el valor de un <input>/<textarea>, o el textContent de
  // cualquier otro elemento -- asi el mismo helper sirve tanto para el campo
  // de solo-lectura de una clave de API como para un <code> suelto.
  function elementText(el) {
    if (!el) return '';
    if ('value' in el) return el.value;
    return el.textContent || '';
  }

  function copyText(text, onDone) {
    if (!text) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(onDone, onDone);
      return;
    }
    // Sin API de portapapeles (contexto no seguro, navegador antiguo):
    // fallback con un <textarea> temporal + document.execCommand.
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try {
      document.execCommand('copy');
    } catch (err) {
      // silencioso: el usuario siempre puede seleccionar el texto a mano.
    }
    document.body.removeChild(ta);
    if (onDone) onDone();
  }

  document.addEventListener('click', function (e) {
    var btn = e.target && e.target.closest ? e.target.closest('[data-copy]') : null;
    if (!btn) return;
    var target = document.querySelector(btn.getAttribute('data-copy'));
    var original = btn.textContent;
    copyText(elementText(target), function () {
      btn.textContent = btn.getAttribute('data-copy-label') || 'Copiado ✓';
      btn.disabled = true;
      setTimeout(function () {
        btn.textContent = original;
        btn.disabled = false;
      }, 1600);
    });
  });

  document.addEventListener('DOMContentLoaded', function () {
    var autocopy = document.querySelectorAll('[data-autocopy]');
    for (var i = 0; i < autocopy.length; i++) {
      copyText(elementText(autocopy[i]));
    }
  });

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
