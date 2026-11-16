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
 *   [data-toggle-hidden="id"] en un <button> -> muestra/oculta el elemento
 *                        con ese id (atributo hidden) y actualiza aria-expanded.
 *   [data-select-on-click] -> selecciona el texto del campo al hacer clic.
 *   #sidebar-open-btn / #sidebar-close-btn / #sidebar-overlay -> abren y
 *                        cierran el cajon lateral movil (clase .open en
 *                        #admin-sidebar y en el overlay).
 *   nav.section-nav     -> marca con aria-current="true" el ancla de la
 *                        seccion visible (IntersectionObserver).
 */
(function () {
  'use strict';

  // --- Cajon lateral movil -------------------------------------------------
  function initSidebarDrawer() {
    var openBtn = document.getElementById('sidebar-open-btn');
    var closeBtn = document.getElementById('sidebar-close-btn');
    var overlay = document.getElementById('sidebar-overlay');
    var sidebar = document.getElementById('admin-sidebar');

    function toggleSidebar(state) {
      if (sidebar && overlay) {
        sidebar.classList.toggle('open', state);
        overlay.classList.toggle('open', state);
        document.body.style.overflow = state ? 'hidden' : '';
      }
    }

    if (openBtn) openBtn.addEventListener('click', function () { toggleSidebar(true); });
    if (closeBtn) closeBtn.addEventListener('click', function () { toggleSidebar(false); });
    if (overlay) overlay.addEventListener('click', function () { toggleSidebar(false); });
  }

  // --- Indice de secciones: marca la seccion visible ------------------------
  // Cada ancla de nav.section-nav apunta a una <section id>. La que ocupa la
  // franja superior de la ventana (bajo la topbar y el indice sticky) lleva
  // aria-current="true". Sin IntersectionObserver no se marca nada.
  function initSectionSpy() {
    var nav = document.querySelector('.section-nav');
    if (!nav || !('IntersectionObserver' in window)) return;
    var links = nav.querySelectorAll('a[href^="#"]');
    var byId = {};
    var sections = [];
    for (var i = 0; i < links.length; i++) {
      var id = decodeURIComponent(links[i].getAttribute('href').slice(1));
      var section = id ? document.getElementById(id) : null;
      if (section) {
        byId[id] = links[i];
        sections.push(section);
      }
    }
    if (!sections.length) return;
    var visible = {};
    function mark() {
      var current = null;
      for (var j = 0; j < sections.length; j++) {
        if (visible[sections[j].id]) { current = sections[j].id; break; }
      }
      if (!current) return;
      for (var k in byId) {
        if (k === current) byId[k].setAttribute('aria-current', 'true');
        else byId[k].removeAttribute('aria-current');
      }
    }
    var observer = new IntersectionObserver(function (entries) {
      for (var n = 0; n < entries.length; n++) {
        visible[entries[n].target.id] = entries[n].isIntersecting;
      }
      mark();
    }, { rootMargin: '-140px 0px -55% 0px' });
    for (var m = 0; m < sections.length; m++) observer.observe(sections[m]);
  }

  function initAll() {
    initSidebarDrawer();
    initSectionSpy();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAll);
  } else {
    initAll();
  }

  // El interruptor de tema (#theme-toggle[data-theme-toggle]) y la paleta de
  // comandos los gestiona assets/palette.js (generado desde src/scripts/).

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

  // --- Mostrar/ocultar y seleccionar al clic (sustituyen a onclick="" en
  // linea, que la CSP script-src 'self' bloquea sin avisar) ----------------
  document.addEventListener('click', function (e) {
    if (!e.target || !e.target.closest) return;
    var toggler = e.target.closest('[data-toggle-hidden]');
    if (toggler) {
      var panel = document.getElementById(toggler.getAttribute('data-toggle-hidden'));
      if (panel) {
        panel.hidden = !panel.hidden;
        toggler.setAttribute('aria-expanded', panel.hidden ? 'false' : 'true');
      }
      return;
    }
    var selectable = e.target.closest('[data-select-on-click]');
    if (selectable && typeof selectable.select === 'function') selectable.select();
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

  // --- Modo "Seleccionar" del buzon (T10, solo se ve a < 768 px) -----------
  document.addEventListener('click', function (e) {
    var btn = e.target && e.target.closest ? e.target.closest('[data-select-toggle]') : null;
    if (!btn) return;
    var form = btn.closest('form');
    if (!form) return;
    var on = form.classList.toggle('select-mode');
    btn.setAttribute('aria-pressed', on ? 'true' : 'false');
    btn.textContent = on ? 'Cancelar selección' : 'Seleccionar';
    if (!on) {
      var boxes = form.querySelectorAll('.row-check, #check-all');
      for (var i = 0; i < boxes.length; i++) boxes[i].checked = false;
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

  // --- Validacion inline accesible (T7b) -----------------------------------
  // El aviso nativo del navegador se sustituye por un mensaje junto al campo
  // (aria-invalid + aria-describedby); el primer campo invalido recibe el foco.
  var invalidFocused = false;
  function errId(el) {
    var base = el.id || String(el.name || 'campo').toLowerCase().replace(/[^a-z0-9_-]+/g, '-').replace(/^-+|-+$/g, '') || 'campo';
    return base + '-error';
  }
  document.addEventListener('invalid', function (e) {
    var el = e.target;
    if (!el || !el.form || el.form.hasAttribute('data-native-validation')) return;
    e.preventDefault();
    el.setAttribute('aria-invalid', 'true');
    var id = errId(el);
    var msg = document.getElementById(id);
    if (!msg) {
      msg = document.createElement('p');
      msg.id = id;
      msg.className = 'field-error';
      el.insertAdjacentElement('afterend', msg);
    }
    msg.textContent = el.validationMessage || 'Revisa este campo.';
    var ids = (el.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean);
    if (ids.indexOf(id) === -1) ids.push(id);
    el.setAttribute('aria-describedby', ids.join(' '));
    if (!invalidFocused) {
      invalidFocused = true;
      el.focus();
      setTimeout(function () { invalidFocused = false; }, 0);
    }
  }, true);

  function clearInvalid(e) {
    var el = e.target;
    if (!el || !el.getAttribute || el.getAttribute('aria-invalid') !== 'true') return;
    if (el.validity && !el.validity.valid) return;
    el.removeAttribute('aria-invalid');
    var msg = document.getElementById(errId(el));
    if (msg) msg.remove();
  }
  document.addEventListener('input', clearInvalid);
  document.addEventListener('change', clearInvalid);
})();
