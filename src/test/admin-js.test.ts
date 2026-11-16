import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

// server/admin/assets/admin.js es JS plano (IIFE, sin modulos): se evalua tal
// cual sobre un DOM minimo del panel para probar el cajon y el indice.
const code = readFileSync(resolve(process.cwd(), 'server/admin/assets/admin.js'), 'utf8');
const run = () => new Function(code)();

function key(k: string, shift = false) {
  const ev = new KeyboardEvent('keydown', { key: k, shiftKey: shift, bubbles: true, cancelable: true });
  document.dispatchEvent(ev);
  return ev;
}

describe('admin.js · cajon lateral movil', () => {
  let openBtn: HTMLElement, sidebar: HTMLElement, overlay: HTMLElement;

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="sidebar-overlay"></div>
      <aside id="admin-sidebar">
        <button id="sidebar-close-btn">x</button>
        <a href="/admin/a" id="l1">a</a>
        <a href="/admin/b" id="l2">b</a>
      </aside>
      <button id="sidebar-open-btn" aria-controls="admin-sidebar">menu</button>
      <a href="#" id="outside">fuera</a>`;
    run();
    openBtn = document.getElementById('sidebar-open-btn')!;
    sidebar = document.getElementById('admin-sidebar')!;
    overlay = document.getElementById('sidebar-overlay')!;
  });

  afterEach(() => {
    // Cierra para que los listeners de esta evaluacion no actuen en la siguiente.
    sidebar.classList.remove('open');
  });

  it('pone aria-expanded=false al cargar y true al abrir; el foco entra al cajon', () => {
    expect(openBtn.getAttribute('aria-expanded')).toBe('false');
    openBtn.click();
    expect(sidebar.classList.contains('open')).toBe(true);
    expect(openBtn.getAttribute('aria-expanded')).toBe('true');
    expect(document.activeElement?.id).toBe('sidebar-close-btn');
  });

  it('Esc cierra y devuelve el foco al boton', () => {
    openBtn.click();
    const ev = key('Escape');
    expect(ev.defaultPrevented).toBe(true);
    expect(sidebar.classList.contains('open')).toBe(false);
    expect(overlay.classList.contains('open')).toBe(false);
    expect(openBtn.getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(openBtn);
  });

  it('cerrar con el boton o el overlay devuelve el foco', () => {
    openBtn.click();
    document.getElementById('sidebar-close-btn')!.click();
    expect(document.activeElement).toBe(openBtn);
    openBtn.click();
    overlay.click();
    expect(document.activeElement).toBe(openBtn);
    expect(document.body.style.overflow).toBe('');
  });

  it('Tab y Shift+Tab ciclan dentro del cajon abierto', () => {
    openBtn.click();
    document.getElementById('l2')!.focus();
    expect(key('Tab').defaultPrevented).toBe(true);
    expect(document.activeElement?.id).toBe('sidebar-close-btn');
    expect(key('Tab', true).defaultPrevented).toBe(true);
    expect(document.activeElement?.id).toBe('l2');
    document.getElementById('l1')!.focus();
    expect(key('Tab').defaultPrevented).toBe(false);
  });

  it('con el foco fuera del cajon, Tab lo devuelve dentro', () => {
    openBtn.click();
    document.getElementById('outside')!.focus();
    key('Tab');
    expect(document.activeElement?.id).toBe('sidebar-close-btn');
  });

  it('cerrado, ni Esc ni Tab hacen nada', () => {
    openBtn.focus();
    expect(key('Escape').defaultPrevented).toBe(false);
    expect(key('Tab').defaultPrevented).toBe(false);
    expect(openBtn.getAttribute('aria-expanded')).toBe('false');
  });
});

describe('admin.js · indice de secciones', () => {
  let cb: ((e: Array<{ target: Element; isIntersecting: boolean }>) => void) | null;

  beforeEach(() => {
    cb = null;
    vi.stubGlobal(
      'IntersectionObserver',
      class {
        constructor(fn: typeof cb) { cb = fn; }
        observe() {}
      },
    );
    document.body.innerHTML = `
      <nav class="section-nav"><a href="#s1" id="a1">1</a><a href="#s2" id="a2">2</a></nav>
      <section id="s1"></section><section id="s2"></section>`;
  });

  afterEach(() => vi.unstubAllGlobals());

  function setup(scrollW: number, clientW: number, link: { left: number; right: number }) {
    const nav = document.querySelector<HTMLElement>('.section-nav')!;
    Object.defineProperty(nav, 'scrollWidth', { value: scrollW });
    Object.defineProperty(nav, 'clientWidth', { value: clientW });
    nav.getBoundingClientRect = () => ({ left: 0, right: clientW }) as DOMRect;
    document.getElementById('a2')!.getBoundingClientRect = () => link as DOMRect;
    run();
    cb!([{ target: document.getElementById('s2')!, isIntersecting: true }]);
    return nav;
  }

  it('marca aria-current y desplaza el scroller hasta el enlace por la derecha', () => {
    const nav = setup(600, 300, { left: 350, right: 420 });
    expect(document.getElementById('a2')!.getAttribute('aria-current')).toBe('true');
    expect(document.getElementById('a1')!.hasAttribute('aria-current')).toBe(false);
    expect(nav.scrollLeft).toBe(120);
  });

  it('desplaza hacia la izquierda si el enlace queda antes', () => {
    const nav = document.querySelector<HTMLElement>('.section-nav')!;
    nav.scrollLeft = 200;
    setup(600, 300, { left: -50, right: 20 });
    expect(nav.scrollLeft).toBe(150);
  });

  it('no toca scrollLeft si el enlace ya se ve o no hay scroll', () => {
    expect(setup(600, 300, { left: 10, right: 80 }).scrollLeft).toBe(0);
    document.body.innerHTML = `
      <nav class="section-nav"><a href="#s1" id="a1">1</a><a href="#s2" id="a2">2</a></nav>
      <section id="s1"></section><section id="s2"></section>`;
    expect(setup(300, 300, { left: 350, right: 420 }).scrollLeft).toBe(0);
  });
});
