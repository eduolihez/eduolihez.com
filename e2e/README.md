# E2E del panel /admin

Tests de Playwright que abren el panel de verdad (PHP + MariaDB) en un navegador:
login, espacios y menú, todas las páginas en tema claro y oscuro, CSP, cajón
móvil y operaciones reales (crear, editar y borrar proyectos, artículos,
usuarios del lab, mensajes, CSV de analítica).

## Regla de seguridad

Estos tests **crean y borran datos**. Por eso:

- `playwright.config.cjs` no arranca si `E2E_BASE_URL` no apunta a
  `127.0.0.1` o `localhost`.
- `global-setup.cjs` lee `../server/config.php` como texto (es la BD que usa de
  verdad el servidor PHP al que hablan los tests, no la del seed) y aborta toda
  la ejecución si `db.name` no termina en `_test`, si `db.host` no es
  `localhost`/`127.0.0.1`, o si el fichero falta o no se puede interpretar.
  La lógica está en `db-guard.cjs` y se prueba con `npm run test:guard`.
- `seed/seed.php` aborta si `DB_NAME` (y la base de datos a la que se conecta)
  no termina en `_test`.

Nunca los apuntes al sitio real ni a su base de datos.

## Variables de entorno

| Variable | Para qué | Por defecto |
| --- | --- | --- |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS` | Conexión del seed (BD de test) | host `127.0.0.1`, puerto `3306`; el resto obligatorias (`DB_PASS` puede ir vacía) |
| `E2E_USER`, `E2E_PASSWORD` | Admin que crea el seed y con el que entran los tests (contraseña de 12+ caracteres) | obligatorias |
| `E2E_BASE_URL` | Dónde está el servidor PHP | `http://127.0.0.1:8081` |
| `E2E_CHROME_PATH` | Usar un Chrome instalado en vez del Chromium de Playwright | — |
| `E2E_CHANNEL` | Canal de Playwright (`chrome`, `msedge`...) si no hay `E2E_CHROME_PATH` | — |
| `E2E_PHP` | Binario de PHP para el `webServer` si no hay ninguno levantado | `php` |

`server/config.php` debe apuntar a la misma base de datos de test (es el que usa
el panel). No se versiona.

## En local con XAMPP

1. Crea la base de datos `eduolihez_test` e importa `database/schema.sql`
   (`mysql -uroot --default-character-set=utf8mb4 eduolihez_test < database/schema.sql`).
2. Copia `server/config.example.php` a `server/config.php` y apúntalo a esa BD.
3. Levanta el panel: `php -S 127.0.0.1:8081 -t server` (si no lo levantas,
   Playwright lo arranca con `E2E_PHP`).
4. Desde `e2e/`:

```bash
npm ci
DB_NAME=eduolihez_test DB_USER=root DB_PASS= E2E_USER=e2e E2E_PASSWORD='una-contrasena-larga' php seed/seed.php
E2E_USER=e2e E2E_PASSWORD='una-contrasena-larga' \
E2E_CHROME_PATH="C:/Program Files/Google/Chrome/Application/chrome.exe" npx playwright test
```

El seed es idempotente: repítelo antes de cada pasada. Deja el admin
recreado, 2 mensajes sin leer y 1 leído, visitas de los últimos 6 días para
eduolihez y phishlab, y vacía `login_attempts`, `lab_login_attempts` y
`lab_users`. También borra restos de pasadas que fallaron a medias (todo lo que
crean los tests lleva el prefijo `E2E ` o `e2e-`).

Informe HTML: `npx playwright show-report`. Capturas y trazas de los fallos:
`test-results/` (ignorado por git).

Si tienes un antivirus que filtra el tráfico web (Kaspersky, por ejemplo),
inyecta su propio script y añade hosts a la CSP que ve el navegador. Los tests
ya lo tienen en cuenta, pero si algo falla solo en tu máquina, revisa eso antes.

## En CI

Workflow `.github/workflows/admin.yml` (nombre "Admin"), en cada pull request y
push a `master` que toque `server/`, `database/`, `e2e/` o `scripts/`:

- job `phpunit`: `composer install` y `composer test`.
- job `e2e`: MariaDB 10.11 como servicio, importa `schema.sql`, genera
  `server/config.php` a partir del ejemplo, ejecuta el seed y
  `npx playwright test` con el Chromium de Playwright. El informe y las
  capturas se suben como artefacto (7 días).
