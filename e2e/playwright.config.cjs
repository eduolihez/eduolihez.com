// @ts-check
/**
 * Configuracion de Playwright para la suite E2E del panel /admin.
 *
 * Estos tests CREAN Y BORRAN datos (proyectos, articulos, usuarios del lab,
 * estados de mensajes). Por eso la configuracion se niega a arrancar si la
 * URL base no apunta a esta maquina (y global-setup.cjs exige que server/config.php
 * apunte a una BD "_test" local): nunca deben tocar el sitio real.
 * La base de datos de test la prepara seed/seed.php (que a su vez exige que
 * el nombre de la BD termine en "_test").
 */
const path = require('node:path');
const { defineConfig, devices } = require('@playwright/test');

const BASE_URL = process.env.E2E_BASE_URL || 'http://127.0.0.1:8081';

let parsed;
try {
  parsed = new URL(BASE_URL);
} catch {
  throw new Error(`E2E_BASE_URL no es una URL valida: ${BASE_URL}`);
}
if (!['127.0.0.1', 'localhost'].includes(parsed.hostname)) {
  throw new Error(
    `E2E_BASE_URL=${BASE_URL} no es local. Esta suite crea y borra datos: ` +
      'solo se ejecuta contra 127.0.0.1 o localhost.'
  );
}

// Navegador: un Chrome instalado (E2E_CHROME_PATH), un canal de Playwright
// (E2E_CHANNEL, p.ej. "chrome") o, por defecto, el Chromium que trae
// Playwright (`npx playwright install chromium`, lo que hace CI).
/** @type {import('@playwright/test').LaunchOptions} */
const launchOptions = {};
/** @type {string | undefined} */
let channel;
if (process.env.E2E_CHROME_PATH) {
  launchOptions.executablePath = process.env.E2E_CHROME_PATH;
} else if (process.env.E2E_CHANNEL) {
  channel = process.env.E2E_CHANNEL;
}

// Sesion del admin guardada por tests/auth.setup.cjs (mismo valor en helpers.cjs).
const AUTH_FILE = path.join(__dirname, '.auth', 'admin.json');
const PHP = process.env.E2E_PHP || 'php';

module.exports = defineConfig({
  // Aborta si server/config.php no apunta a una BD de test local (db-guard.cjs).
  globalSetup: require.resolve('./global-setup.cjs'),
  testDir: './tests',
  testMatch: /.*\.(spec|setup)\.cjs$/,
  outputDir: './test-results',
  // Un solo worker: todos los tests comparten la misma BD y la misma sesion
  // de admin (el espacio activo se guarda en sesion).
  workers: 1,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  // Sin reintentos: los tests cambian estado (crean/borran datos) y un reintento
  // tras un fallo a medias partiria de datos sucios.
  retries: 0,
  timeout: 30_000,
  expect: { timeout: 5_000 },
  reporter: [['list'], ['html', { outputFolder: 'playwright-report', open: 'never' }]],
  use: {
    baseURL: BASE_URL,
    locale: 'es-ES',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    channel,
    launchOptions,
  },
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.cjs$/ },
    {
      name: 'admin',
      testMatch: /.*\.spec\.cjs$/,
      dependencies: ['setup'],
      use: { ...devices['Desktop Chrome'], channel, launchOptions, storageState: AUTH_FILE },
    },
  ],
  // En local el servidor suele estar ya levantado (XAMPP o `php -S`): se
  // reutiliza. En CI no hay ninguno y se arranca aqui con el PHP del PATH.
  webServer: {
    command: `${PHP} -S ${parsed.hostname}:${parsed.port || '80'} -t ../server`,
    url: new URL('/admin/login.php', BASE_URL).toString(),
    reuseExistingServer: true,
    timeout: 30_000,
    stdout: 'ignore',
    stderr: 'pipe',
  },
});
