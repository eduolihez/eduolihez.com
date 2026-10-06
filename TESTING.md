# Testing

100% de cobertura de tests es el objetivo a largo plazo: los tests permiten
mover rápido y confiar en los cambios sin tener que releer todo el código cada
vez. Sin ellos, cualquier cambio en `config.ts`, `experience.ts`, `skills.ts`
o `faq.ts` puede romper en silencio lo que una IA lee sobre este perfil, y
nadie lo nota hasta que la respuesta ya salió mal.

## Framework

**Vitest**, vía el helper oficial `getViteConfig()` de Astro (`vitest.config.ts`).
Reutiliza el `vite.config` real del proyecto — sin configuración duplicada.
Cubre el lado **TypeScript/Astro** (`src/`).

El backend en PHP (`server/`) usa **PHPUnit** (`composer.json` +
`phpunit.xml`, raíz del repo) — instalación e iniciativa separadas de Vitest,
sin relación entre ambos runners. Cubre solo código SIN dependencias externas
(de momento: `server/lib/text.php`, `server/lib/validate.php` y la lógica
de espacios del panel, `server/admin/partials/spaces.php` e `icons.php`) —
`server/tests/bootstrap.php` deja claro por qué no arranca
`server/lib/http.php` ni `config.php`: eso abriría una conexión real a MySQL
de producción, que no existe (ni debe existir) en un entorno de test o CI, y
`db()` corta el proceso entero con `exit;` si lo intenta. Testear algo que sí
necesite DB requeriría una base de datos de test propia, inyectada aparte.

## Cómo correr los tests

```bash
npm test              # TypeScript/Astro (Vitest)
composer install       # PHP: instala PHPUnit (solo la primera vez)
composer test          # PHP (PHPUnit)
```

`npm test` corre en CI en cada push/PR a `master`
(`.github/workflows/test.yml`, check "Vitest", obligatorio). PHPUnit y la
suite E2E corren en otro workflow, `.github/workflows/admin.yml` ("Admin",
jobs `phpunit` y `e2e`), solo cuando el cambio toca `server/`, `database/`,
`e2e/` o `scripts/`; no son checks obligatorios.

**Vitest desde un worktree anidado:** si ejecutas `npm test` dentro de un
worktree de git que vive dentro del propio repo (`.claude/worktrees/…`),
falla con `Tsconfig not found astro/tsconfigs/strict` (peculiaridad del
resolver de Vite 8 al encontrar dos `node_modules` encadenados). No es un fallo
de los tests: en un checkout normal y en CI pasan. Córrelo desde el checkout
principal.

### PHP en local sin Composer

```bash
bash scripts/php-test.sh
```

Necesita un PHP local y `.superpowers/tools/phpunit.phar`. Si falta el phar,
el script imprime el comando de descarga:

```bash
mkdir -p .superpowers/tools && curl -sSfL -o .superpowers/tools/phpunit.phar https://phar.phpunit.de/phpunit-10.5.66.phar
```

El script fija la versión (PHPUnit 10.5.66) y su SHA-256
(`42bcac97bbf9fb1aecf5a7d6a1b37123a11e7e295458978f0e268999f6d9e50f`) y se
niega a ejecutar un phar que no coincida. Al fijarlo se comprobó también la
firma GPG de `phpunit-10.5.66.phar.asc` (clave de Sebastian Bergmann,
huella `D840 6D0D 8294 7747 2937 7831 4AA3 9408 6372 C20A`). Para subir de
versión: descarga la nueva, verifica su firma y actualiza `PHPUNIT_VERSION` y
`PHPUNIT_SHA256` en `scripts/php-test.sh`.

`composer test` sigue funcionando donde haya Composer. Compromiso conocido: no
hay `composer.lock` versionado (no está ignorado a propósito, simplemente aún
no se ha generado), así que el `composer install` de CI resuelve `^10.5` y puede
ir por delante del 10.5.66 fijado en `php-test.sh`; para fijarlo, ejecuta
`composer update` una vez donde haya Composer y versiona el `composer.lock`.
En ambos casos los
tests de `server/tests/` no deben cargar `auth.php`, `http.php` ni `db.php`
(ver el comentario de `server/tests/bootstrap.php`). Por eso
`server/admin/partials/spaces.php` y `icons.php` son puras: sin dependencias
de esos archivos, se pueden testear (`SpacesTest`).

## Capas de test

- **Unit / smoke tests** (`src/**/*.test.ts`): el endpoint `/llms.txt` —
  verifica que el texto generado incluye los datos reales de identidad, que
  ninguna interpolación queda como `undefined`/`[object Object]`, y que las
  secciones que dependen de arrays (experiencia, FAQ) no salen vacías.
  `src/scripts/shared.ts` (`safeUrl()`, `fetchWithRetry()`,
  `setStatusPanel()` — compartidas por Blog, Proyectos y Certificaciones):
  esquemas bloqueados/permitidos incluidos los bypass de `\`/`//`/tabulador
  incrustado en la URL (ver el comentario del propio archivo), número exacto
  de reintentos en fallo total (regresión del bug de cascada). Y los scripts
  de cada isla (`blog.ts`, `projects.ts`, `certifications.ts`): carga/vacío/
  error/reintento (incluido el rechazo directo de `fetch()`, no solo
  `!res.ok`) sin duplicar listeners, apertura/cierre de modal (foco,
  backdrop, Escape) en Proyectos, y en Certificaciones los 5 filtros por
  categoría, drill-down de emisor con migas de pan, y paginación
  ("cargar más").
- **PHPUnit** (`server/tests/*.php`): `to_plain_text()` (limpieza HTML→texto
  de los artículos del blog) y `validate_public_url()` (el esquema de URL
  permitido en los formularios de `/admin`, incluidos los mismos bypass de
  `\`/`//`/tabulador que en `safeUrl()` — misma regla, dos implementaciones
  independientes que no comparten fuente). También la lógica pura de
  espacios del panel admin (`server/admin/partials/spaces.php`, en
  `server/tests/SpacesTest.php`).
- **PHPUnit, secretos** (`server/tests/NoSecretsTest.php`): la clave de
  ingesta de PhishLab no vuelve al repo (el JSON de ejemplo lleva el
  placeholder, `telemetry.config.json` y `server/config.php` no están
  versionados, y ningún archivo versionado de `public/` o `server/` lleva un
  `"apiKey": "<64 hex>"`). El detector se prueba primero con entradas falsas.
- **E2E del panel `/admin`** (`e2e/`, Playwright): ver la sección siguiente.
  El sitio público (Astro) sigue sin E2E.

## E2E del panel /admin

Proyecto aparte en `e2e/` (su propio `package.json`, solo `@playwright/test`;
no añade nada al `package.json` del sitio). Prueba el panel real (PHP +
MariaDB) en Chromium: login/logout, espacios y menú, todas las páginas de
`server/admin/` en claro y oscuro (HTTP 200, sin avisos PHP, sin errores de
consola ni violaciones de CSP, un `<h1>`, sin desbordamiento a 1280 y 375 px),
tema, cajón móvil, CSP, y operaciones reales (proyectos, artículos, usuarios
del lab, mensajes, CSV de analítica, apps).

**Regla de seguridad:** crea y borra datos. Tres guardas: (1)
`playwright.config.cjs` se niega a arrancar si `E2E_BASE_URL` no es
`127.0.0.1`/`localhost`; (2) `e2e/global-setup.cjs` lee `server/config.php`
como texto (es la BD que usa el servidor PHP al que hablan los tests) y aborta
la ejecución si `db.name` no termina en `_test` o si `db.host` no es
`localhost`/`127.0.0.1` (o si el fichero falta o no se entiende); su lógica
(`e2e/db-guard.cjs`) se prueba con `cd e2e && npm run test:guard`; (3)
`e2e/seed/seed.php` aborta si la base de datos del seed no termina en `_test`.

En local con XAMPP (BD `eduolihez_test` con `database/schema.sql` importado y
`server/config.php` apuntando a ella):

```bash
php -S 127.0.0.1:8081 -t server          # o deja que Playwright lo arranque (E2E_PHP)
cd e2e && npm ci
DB_NAME=eduolihez_test DB_USER=root DB_PASS= E2E_USER=e2e E2E_PASSWORD='…12+ caracteres…' php seed/seed.php
E2E_USER=e2e E2E_PASSWORD='…' E2E_CHROME_PATH="C:/Program Files/Google/Chrome/Application/chrome.exe" npx playwright test
```

Variables: `DB_HOST`/`DB_PORT`/`DB_NAME`/`DB_USER`/`DB_PASS` (seed),
`E2E_USER`/`E2E_PASSWORD` (seed y tests), `E2E_BASE_URL` (por defecto
`http://127.0.0.1:8081`), `E2E_CHROME_PATH` o `E2E_CHANNEL` (navegador; sin
ellas, el Chromium de Playwright), `E2E_PHP` (PHP del `webServer`). Detalle en
`e2e/README.md`.

En CI: job `e2e` de `.github/workflows/admin.yml` (MariaDB 10.11 como
servicio, `schema.sql`, `config.php` generado desde el ejemplo, seed y
`npx playwright test`; informe y capturas como artefacto 7 días).

## Convenciones

- Un archivo de test por cada archivo fuente que se testea: `foo.ts` →
  `foo.test.ts`, en el mismo directorio — **excepto dentro de `src/pages/`**
  (ver aviso justo abajo).
- **`src/pages/` es zona prohibida para archivos de test.** Astro trata
  CUALQUIER archivo dentro de `src/pages/` como una ruta a compilar. Un
  `describe()`/`it()` de Vitest ahí dentro rompe `npm run build` en
  silencio durante el prerender (Astro intenta evaluar el módulo de test
  como si fuera un endpoint). Los tests de algo que vive en `src/pages/`
  van en `src/test/pages/`, con la misma ruta relativa (ej.
  `src/pages/llms.txt.ts` → `src/test/pages/llms.txt.test.ts`). Antes de
  dar por bueno un cambio en los tests, corre `npm run build` además de
  `npm test` — un test roto falla ruidoso, pero esto fallaba en silencio.
- `describe()` con el nombre del endpoint/función; `it()` en español,
  describiendo el comportamiento esperado, no la implementación.
- No mockear `src/config.ts`/`data/*.ts` a propósito en los smoke tests del
  contenido generado: el riesgo real que se quiere cubrir es que esos
  archivos cambien de forma y rompan el output, así que el test debe usar
  los datos reales para detectarlo.
- Nunca importar secretos o credenciales en un archivo de test.
