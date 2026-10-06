// Utilidades compartidas por los specs del panel.
const fs = require('node:fs');
const path = require('node:path');
const { expect } = require('@playwright/test');

const AUTH_FILE = path.join(__dirname, '..', '.auth', 'admin.json');
const ADMIN_DIR = path.join(__dirname, '..', '..', 'server', 'admin');

/** Avisos de PHP impresos en la pagina (display_errors). */
const PHP_WARNING = /(?:<b>)?(?:Warning|Notice|Fatal error|Deprecated|Parse error)(?:<\/b>)?:\s/;

function credentials() {
  const user = process.env.E2E_USER;
  const password = process.env.E2E_PASSWORD;
  if (!user || !password) {
    throw new Error('Faltan E2E_USER / E2E_PASSWORD (las mismas que uso seed/seed.php).');
  }
  return { user, password };
}

/** Paginas del panel con sesion: server/admin/*.php salvo las de acceso. */
function adminPages() {
  const skip = new Set(['login.php', 'logout.php', 'setup.php', 'auth.php']);
  return fs
    .readdirSync(ADMIN_DIR)
    .filter((f) => f.endsWith('.php') && !skip.has(f))
    .sort();
}

/** Inicia sesion en la pagina dada (contexto propio, sin storageState). */
async function login(page, user, password) {
  await page.goto('/admin/login.php');
  await page.locator('#username').fill(user);
  await page.locator('#password').fill(password);
  await page.locator('button[type=submit]').click();
}

/**
 * Engancha a la pagina los recolectores de problemas: errores de consola
 * (incluye recursos 404 como un favicon roto), excepciones JS y violaciones
 * de CSP (evento securitypolicyviolation, registrado antes de cualquier
 * script de la pagina). Devuelve un objeto con las listas y un reset().
 */
async function watchProblems(page) {
  const found = { console: [], errors: [] };
  page.on('console', (m) => {
    if (m.type() === 'error') found.console.push(m.text());
  });
  page.on('pageerror', (e) => found.errors.push(e.message));
  await page.addInitScript(() => {
    window.__csp = [];
    document.addEventListener('securitypolicyviolation', (e) => {
      window.__csp.push(`${e.violatedDirective} ${e.blockedURI}`);
    });
  });
  return {
    found,
    async csp() {
      return page.evaluate(() => window.__csp || []);
    },
    reset() {
      found.console.length = 0;
      found.errors.length = 0;
    },
  };
}

/** Etiquetas del menu lateral, en orden. */
async function menuLabels(page) {
  return page.locator('.sidebar-menu a.menu-item .menu-label').allInnerTexts();
}

/** Etiqueta del unico item activo del menu (falla si hay 0 o varios). */
async function expectActive(page, label) {
  const active = page.locator('.sidebar-menu .menu-item.active');
  await expect(active).toHaveCount(1);
  await expect(active.locator('.menu-label')).toHaveText(label);
}

async function expectSpace(page, label) {
  await expect(page.locator('.app-switcher summary .app-switcher-current')).toHaveText(label);
}

/** Acepta el siguiente confirm() nativo y devuelve una promesa con su texto. */
function acceptNextDialog(page) {
  return new Promise((resolve) => {
    page.once('dialog', async (d) => {
      const msg = d.message();
      await d.accept();
      resolve(msg);
    });
  });
}

/**
 * Sigue un enlace con page.goto(href) en vez de con un clic. Solo para
 * enlaces a analytics.php: algunos antivirus con filtro "anti-banner" (visto
 * con Kaspersky en la maquina de desarrollo) cortan la navegacion por clic a
 * una URL que contiene "analytics" (respuesta 499 + PNG de 1x1) y el test
 * fallaria por el entorno, no por el panel. El href se comprueba igual.
 */
async function followLink(page, link) {
  const href = await link.getAttribute('href');
  expect(href, 'el enlace no tiene href').toBeTruthy();
  await page.goto(new URL(href, page.url()).toString());
}

/** Sufijo unico por ejecucion para no chocar con restos de otra pasada. */
function stamp() {
  return `${Date.now().toString(36)}${Math.floor(Math.random() * 1e4)}`;
}

module.exports = {
  AUTH_FILE,
  PHP_WARNING,
  credentials,
  adminPages,
  login,
  watchProblems,
  menuLabels,
  expectActive,
  expectSpace,
  acceptNextDialog,
  followLink,
  stamp,
};
