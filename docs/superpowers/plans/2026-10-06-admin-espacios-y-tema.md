# Panel admin: espacios y sistema visual — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El panel arranca en un espacio Global, el menú muestra solo lo del espacio elegido, y todo el panel tiene tema claro/oscuro con interruptor y una estructura de página común.

**Architecture:** Refactor in situ de `server/admin/partials/layout.php`. La lógica de espacios es una unidad pura (`partials/spaces.php`, sin BD ni sesión) con tests PHPUnit; el layout solo la consume. El CSS sale a `assets/admin.css` con tokens claro/oscuro. Sin mover archivos ni cambiar URLs.

**Tech Stack:** PHP 8.1+, MySQL (PDO), PHPUnit 10.5, CSS/JS plano, despliegue por FTP (CDMON). CSP del panel: `script-src 'self'`, `style-src 'self' 'unsafe-inline'`.

**Spec:** `docs/superpowers/specs/2026-10-06-admin-espacios-y-tema-design.md`

## Global Constraints

- Sin Node ni SPA en producción; despliegue por FTP; sin migraciones de BD en esta pieza.
- Ninguna URL actual deja de funcionar; `?app=<slug>` sigue valiendo como alias de espacio.
- CSP: ningún `<script>` en línea; todo JS en archivos `assets/*.js` del propio dominio.
- El valor de `?space=` / `?app=` es entrada externa: se valida por lista blanca antes de usarlo, guardarlo en sesión o pintarlo en un enlace.
- Si falta una tabla (`apps`, `lab_users`...), el menú sigue funcionando con contadores a 0 (patrón `$countSafe`).
- Tests PHP sin BD: `server/tests/bootstrap.php` prohíbe que un test cargue `auth.php`, `http.php` o `db.php` (matan el proceso de PHPUnit). `partials/spaces.php` no puede requerirlos.
- `site` ≡ app `eduolihez`; `phishlab` ≡ app `phishlab` (ya existen en `apps`); el resto `app:<slug>`.
- Tema: preferencia en `localStorage`; si no hay, `prefers-color-scheme`. `assets/theme.js` síncrono en `<head>`.
- Cache: `admin.css` y `theme.js` se enlazan con `?v=<filemtime>`.
- Commits pequeños; nunca force-push; trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

- `?space=` con basura (`../`, `app:`, vacío, array `space[]=x`, slug de app borrado): no rompe la página y cae a la regla de respaldo (Task 1 tests).
- Sesión con un espacio al que la página visitada no pertenece (p. ej. sesión `phishlab`, visita `projects.php`): se muestra el espacio de la página, no uno incoherente (Task 1).
- Tabla `apps` inexistente o vacía: el selector muestra solo Global/eduolihez.com/PhishLab y no lanza excepción (Task 1: lista de slugs vacía).
- Primera visita en oscuro sin preferencia guardada: no hay destello blanco (Task 3, verificación manual).
- `localStorage` bloqueado o con valor inválido (`"banana"`): el tema cae al del sistema sin error (Task 3).

---

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `server/admin/partials/spaces.php` (nuevo) | Lógica pura de espacios: resolver, validar, estructura del menú. Sin `require`. |
| `server/admin/partials/icons.php` (nuevo) | `nav_icon(string $key): string` → SVG. Saca los SVG del layout. |
| `server/admin/assets/admin.css` (nuevo) | Todos los estilos: tokens claro/oscuro, base, componentes, layout. |
| `server/admin/assets/theme.js` (nuevo) | Aplica el tema antes del primer pintado. |
| `server/admin/assets/admin.js` (mod.) | + interruptor de tema, + cajón móvil (hoy inline en `layout.php`). |
| `server/admin/partials/layout.php` (mod.) | Cabecera/pie/helpers; consume spaces.php, enlaza CSS/JS. |
| `server/tests/SpacesTest.php` (nuevo) | Tests de spaces.php. |
| `server/admin/*.php` (mod.) | Migración a `page_header()` y clases; `analytics.php` e `index.php` leen el espacio. |

---

### Task 0: Entorno de verificación local

El equipo no tiene `php` ni `composer` en PATH; sí hay Docker.

**Files:**
- Create: `scripts/php-test.sh` (envoltorio de PHPUnit en Docker)
- Create (no versionado): `.superpowers/dev/config.php` (config de BD local; **no** usar el `server/config.php` real, que puede llevar credenciales de producción)

- [ ] **Step 1: Crear `scripts/php-test.sh`** que ejecute `docker run --rm -v "$PWD":/app -w /app composer:2 sh -c "composer install --no-interaction --quiet && vendor/bin/phpunit"` (mismo contenido que `composer test`).
- [ ] **Step 2: Línea base.** Run: `bash scripts/php-test.sh`. Expected: `OK` con los tests de `TextTest` y `ValidateTest`.
- [ ] **Step 3: Montar stack manual** (para la verificación visual de las Tasks 3-8): contenedores `mysql:8` (con `database/schema.sql` cargado) y `php:8.3-apache` con `server/` montado en `/var/www/html` y `.superpowers/dev/config.php` montado encima de `server/config.php` del contenedor, de modo que el real nunca se use. Dejar los comandos exactos en `scripts/dev-admin.md` (2-3 líneas por contenedor). Verificar: `http://localhost:8080/admin/login.php` responde 200 y se puede crear/entrar con un usuario admin de prueba (`setup.php`).
- [ ] **Step 4: Commit** `chore: scripts para correr PHPUnit y el panel en Docker`.

### Task 1: Lógica de espacios (TDD)

**Files:**
- Create: `server/admin/partials/spaces.php`
- Create: `server/admin/partials/icons.php`
- Test: `server/tests/SpacesTest.php`
- Modify: `server/tests/bootstrap.php` (añadir `require_once __DIR__ . '/../admin/partials/spaces.php';`)

**Interfaces:**
- Produces (todas puras, sin BD/sesión; `$appSlugs` = slugs de la tabla `apps`):
  - `const SPACE_GLOBAL = 'global'; const SPACE_SITE = 'site'; const SPACE_PHISHLAB = 'phishlab';`
  - `normalize_space(string $raw, array $appSlugs): ?string` — `'global'|'site'|'phishlab'` tal cual; `'app:<slug>'` válido si `<slug>` ∈ `$appSlugs`; un slug de app sin prefijo (alias de `?app=`) → `'site'` si `eduolihez`, `'phishlab'` si `phishlab`, `'app:<slug>'` si ∈ `$appSlugs`; cualquier otra cosa → `null`.
  - `space_app_slug(string $space): ?string` — `site`→`'eduolihez'`, `phishlab`→`'phishlab'`, `app:x`→`'x'`, `global`→`null`.
  - `page_spaces(string $page): array` — espacios a los que pertenece una página; el primero es su espacio de origen. Tabla: `index.php`, `messages.php` → `[global, site]`; `analytics.php` → `[global, site, phishlab, *]` (el comodín `*` = cualquier `app:<slug>`); `projects.php`, `certifications.php`, `posts.php` → `[site]`; `lab-users.php` → `[phishlab]`; `apps.php`, `integrations.php`, `security.php`, `settings.php`, `backup.php` → `[global]`; página desconocida → `[global]`.
  - `resolve_space(array $get, array $session, array $appSlugs, string $page): string` — orden: `$get['space']`, luego `$get['app']` (alias), válidos y que la página admita (`page_spaces`); luego `$session['admin_space']` si es válido y la página lo admite; si no, el espacio de origen de la página. Valores no string (`space[]=x`) se ignoran.
  - `space_options(array $apps): array` — `$apps` = filas `['slug','display_name']`; devuelve `[['id'=>..., 'label'=>...], ...]`: Global, eduolihez.com, PhishLab y después cada app restante como `app:<slug>`.
  - `space_nav(string $space, array $counts): array` — grupos `[['label'=>string,'items'=>[['page'=>string,'href'=>string,'label'=>string,'icon'=>string,'badge'=>string,'badge_type'=>'alert'|'count']]]]`. `$counts` claves opcionales: `unread, projects, certs, posts, apps, lab_users`. `href` = `<page>?space=<urlencode(space)>`. Contenido por espacio según la tabla de la spec: Global (Resumen `index.php`, Bandeja `messages.php` con badge `unread` tipo `alert`, Analítica; grupo Sistema: Seguridad, Ajustes, Backup, Integraciones, Gestionar apps); `site` (Proyectos, Certificaciones, Blog, Analítica); `phishlab` (Resumen→`analytics.php`, Usuarios→`lab-users.php` con badge `lab_users`); `app:<slug>` (Resumen→`analytics.php`).
  - `icons.php`: `nav_icon(string $key): string` con claves `grid, briefcase, award, edit, mail, chart, activity, shield, settings, database, link, users`; clave desconocida → `''`.

  Nota sobre «Actividad»: la spec la lista en Global, pero hoy no tiene página propia (el registro `activity_log` aparece en el dashboard de eduolihez.com y en `security.php`). Esta pieza no crea ese ítem; la página de actividad global queda para la pieza 4.

- [ ] **Step 1: Escribir tests que fallan** en `SpacesTest.php` (clase `SpacesTest extends TestCase`), con `$apps = ['eduolihez','phishlab','nowait']`:
  - `testNormalizeAceptaEspaciosFijos`: `normalize_space('global', $apps) === 'global'`, igual `site`, `phishlab`.
  - `testNormalizeAliasDeAppSinPrefijo`: `'eduolihez'`→`'site'`, `'phishlab'`→`'phishlab'`, `'nowait'`→`'app:nowait'`.
  - `testNormalizeRechazaBasura`: `''`, `'../etc'`, `'app:'`, `'app:borrada'`, `'GLOBAL '` → `null`.
  - `testSpaceAppSlug`: los cuatro casos de la tabla.
  - `testResolveSinNadaUsaOrigenDePagina`: `resolve_space([], [], $apps, 'projects.php') === 'site'`; `'lab-users.php'`→`'phishlab'`; `'index.php'`→`'global'`; `'inventada.php'`→`'global'`.
  - `testResolveGetGanaASesion`: `get['space']='phishlab'`, sesión `site`, página `analytics.php` → `'phishlab'`.
  - `testResolveAliasApp`: `get['app']='nowait'`, página `analytics.php` → `'app:nowait'`.
  - `testResolveSesionSoloSiLaPaginaLaAdmite`: sesión `phishlab` + `projects.php` → `'site'`; sesión `site` + `analytics.php` → `'site'`.
  - `testResolveIgnoraEntradaInvalida`: `get['space']='../x'` + `projects.php` → `'site'`; `get['space']=['x']` (array) → origen de la página.
  - `testResolveGetNoAdmitidoPorLaPagina`: `get['space']='phishlab'` + `projects.php` → `'site'`.
  - `testSpaceOptionsSinApps`: `space_options([])` → exactamente 3 opciones (Global, eduolihez.com, PhishLab).
  - `testSpaceOptionsConApps`: con `nowait` añade `['id'=>'app:nowait','label'=>'NoWait']` y no duplica `eduolihez`/`phishlab`.
  - `testSpaceNavGlobalIncluyeSistema`: el espacio `global` contiene las páginas `index.php, messages.php, analytics.php, security.php, settings.php, backup.php, integrations.php, apps.php` y NO `projects.php`.
  - `testSpaceNavSiteContieneContenido`: `site` contiene `projects.php, certifications.php, posts.php` y NO `security.php`.
  - `testSpaceNavBadges`: `space_nav('global', ['unread'=>3])` → el ítem `messages.php` tiene `badge==='3'` y `badge_type==='alert'`; con `unread=0` → `badge===''`.
  - `testSpaceNavHrefLlevaElEspacio`: en `phishlab`, el ítem `lab-users.php` tiene `href==='lab-users.php?space=phishlab'`; en `app:nowait` el href de analytics es `'analytics.php?space=app%3Anowait'`.
  - `testNavIconDesconocidaDevuelveVacio`: `nav_icon('nope') === ''` y `str_starts_with(nav_icon('grid'), '<svg')`.
- [ ] **Step 2: Run** `bash scripts/php-test.sh`. Expected: FAIL (`Call to undefined function normalize_space`).
- [ ] **Step 3: Implementar** `spaces.php` e `icons.php` con las firmas de arriba. `icons.php`: mover aquí los SVG que hoy están en `layout.php` (líneas 80-125 aprox.).
- [ ] **Step 4: Run** `bash scripts/php-test.sh`. Expected: OK, todos los tests (los previos + los nuevos).
- [ ] **Step 5: Commit** `feat(admin): lógica pura de espacios y menú por espacio`.

### Task 2: Extraer el CSS a `admin.css` (sin cambio visual)

**Files:**
- Create: `server/admin/assets/admin.css`
- Modify: `server/admin/partials/layout.php:147-866` (los dos `<style>`) y la cabecera
- Modify: `server/admin/partials/layout.php` (helper `asset_url`)

**Interfaces:**
- Produces: `asset_url(string $file): string` en `layout.php` → `assets/<file>?v=<filemtime>` (si el archivo no existe, sin `?v`).

- [ ] **Step 1:** Mover tal cual el contenido del segundo `<style>` a `assets/admin.css` y los `@font-face` del primero al inicio del mismo archivo (las rutas `url('assets/fonts/...')` pasan a `url('fonts/...')`, relativas al CSS).
- [ ] **Step 2:** Sustituir ambos `<style>` por `<link rel="stylesheet" href="<?= e(asset_url('admin.css')) ?>">`. Mantener el comentario sobre fuentes locales/CSP junto al `<link>`.
- [ ] **Step 3: Verificar** con el stack de Task 0 que `index.php`, `projects.php`, `lab-users.php` y `analytics.php` se ven idénticos a antes (capturas antes/después con el navegador) y que `admin.css` responde 200 con `Content-Type: text/css`. Si alguna ruta de fuente falla, revisar la consola.
- [ ] **Step 4: Commit** `refactor(admin): extraer el CSS del layout a assets/admin.css`.

### Task 3: Tokens claro/oscuro, `theme.js` e interruptor

**Files:**
- Create: `server/admin/assets/theme.js`
- Modify: `server/admin/assets/admin.css` (tokens `[data-theme="dark"]`, estilos del botón de tema)
- Modify: `server/admin/assets/admin.js` (interruptor)
- Modify: `server/admin/partials/layout.php` (`<script src>` en `<head>`, botón en `.sidebar-footer`)

**Interfaces:**
- Produces: atributo `data-theme="light|dark"` en `<html>`; clave `localStorage` `admin-theme` con valor `"light"`/`"dark"`; botón `#theme-toggle`.

- [ ] **Step 1: `theme.js`** (IIFE, sin dependencias): lee `localStorage.getItem('admin-theme')` dentro de `try/catch`; si el valor no es `light`/`dark`, usa `matchMedia('(prefers-color-scheme: dark)')`; pone `document.documentElement.dataset.theme`. Enlazar en `<head>` **antes** del CSS, sin `defer`.
- [ ] **Step 2: Tokens oscuros** en `admin.css`: `[data-theme="dark"]` redefine `--bg --soft --card --border --text --muted --faint --accent --accent-hover --accent-soft --danger(-soft) --warn(-soft) --green(-soft) --cyan(-soft) --violet(-soft) --shadow --shadow-sm`, y `color-scheme: dark`. Valores guía de la maqueta aprobada: fondo `#0e0f13`, tarjeta `#171821`, borde `#262833`, texto `#e7e7ec`, apagado `#8b8c98`, acento `#8b8bf0`, acento suave `#23244a`. Los 8 colores hexadecimales sueltos que quedan en el CSS pasan a variables.
- [ ] **Step 3: Botón `#theme-toggle`** en `.sidebar-footer` (icono sol/luna, `aria-label` «Cambiar tema», `aria-pressed`). En `admin.js`: al hacer clic alterna `data-theme`, guarda en `localStorage` dentro de `try/catch` y actualiza `aria-pressed`.
- [ ] **Step 4: Verificar manualmente** en el stack: (a) primera visita con el sistema en oscuro → sin destello blanco (recargar con caché vacía); (b) botón alterna y persiste tras recargar; (c) `localStorage.setItem('admin-theme','banana')` y recargar → usa el tema del sistema sin errores en consola; (d) bloquear datos de sitio en el navegador → el panel carga y el botón no lanza error; (e) revisar en ambos temas `index.php`, `analytics.php` (sparklines y barras), `projects.php`, `messages.php`, `lab-users.php`, `security.php` buscando texto ilegible o fondos blancos fijos; corregir con variables lo que aparezca.
- [ ] **Step 5: Commit** `feat(admin): tema claro/oscuro con interruptor`.

### Task 4: Menú por espacios en el layout

**Files:**
- Modify: `server/admin/partials/layout.php` (`admin_header`, cajón móvil)
- Modify: `server/admin/assets/admin.js` (cajón móvil movido desde el `<script>` en línea de `admin_footer`)
- Modify: `server/admin/assets/admin.css` (selector de espacio)

**Interfaces:**
- Consumes: `resolve_space`, `space_options`, `space_nav`, `space_app_slug`, `nav_icon` (Task 1).
- Produces: en `layout.php`, `admin_space(): string` → espacio activo de la petición actual (memoizado con `static`); `admin_app_slug(): ?string` → `space_app_slug(admin_space())`, para que `analytics.php`/`index.php` filtren por app.

- [ ] **Step 1:** En `admin_header`, cargar los slugs de `apps` con `try/catch` (tabla ausente → `[]`), llamar a `resolve_space($_GET, $_SESSION, $slugs, basename($_SERVER['SCRIPT_NAME']))`, guardar el resultado en `$_SESSION['admin_space']` y calcular `$counts` (mismos `$countSafe` de hoy, pero solo los del espacio visible).
- [ ] **Step 2:** Sustituir `$navGroups`, `$showContentNav`, `$contentOnlyPages` y `$appQs` por `space_nav($space, $counts)`; el bucle de render usa `nav_icon($item['icon'])` y `$item['href']`. Resaltar el ítem activo con `$active === $item['page']`.
- [ ] **Step 3:** Reemplazar el `<details class="app-switcher">` por un selector de espacio basado en `space_options($appsRows)`: cada opción enlaza a la página de inicio del espacio (`index.php?space=global`, `projects.php?space=site`, `lab-users.php?space=phishlab`, `analytics.php?space=app:<slug>`). Siempre visible (ya no depende de que `$appsList` tenga filas).
- [ ] **Step 4:** Mover el `<script>` en línea del cajón móvil de `admin_footer` a `admin.js` (misma lógica, `DOMContentLoaded`); `admin_footer` deja solo `<script src="<?= e(asset_url('admin.js')) ?>">`. Es requisito de la CSP, no solo limpieza.
- [ ] **Step 5: Verificar** en el stack: entrar al panel sin parámetros → espacio Global con Sistema visible; cambiar a eduolihez.com → solo Proyectos/Certificaciones/Blog/Analítica; PhishLab → Resumen/Usuarios; `?app=nowait` antiguo sigue abriendo `analytics.php` de esa app; `projects.php` sin `?space` → menú de eduolihez.com; menú móvil (ancho 375 px) abre y cierra. Comprobar la consola: sin errores de CSP.
- [ ] **Step 6: Commit** `feat(admin): menú y selector por espacios, Global por defecto`.

### Task 5: Páginas que dependen del espacio (`index.php`, `analytics.php`)

**Files:**
- Modify: `server/admin/index.php:75-195`
- Modify: `server/admin/analytics.php:28-46`

**Interfaces:**
- Consumes: `admin_space()`, `admin_app_slug()` (Task 4).

- [ ] **Step 1: `analytics.php`:** `$appSlug` pasa de `$_GET['app']` a `admin_app_slug() ?? ''`; en Global (sin app) sigue mostrando todo. El filtro por `app_id` y la consulta parametrizada no cambian. Los enlaces de rango/exportación conservan `&space=<admin_space()>` en vez de `&app=`.
- [ ] **Step 2: `index.php`:** en espacio `global` muestra el selector de tarjetas actual retitulado «Resumen global» (mismas consultas); en `site` o `app:<slug>` con contenido muestra el dashboard actual de esa app; app sin contenido sigue redirigiendo a `analytics.php?space=app:<slug>`. Las tarjetas del selector enlazan con `?space=`. Mantener la compatibilidad de `?app=` (llega por `resolve_space`).
- [ ] **Step 3: Verificar** en el stack con los datos de `schema.sql`: Global muestra una tarjeta por app; entrar en eduolihez.com abre su dashboard; `analytics.php` sin espacio muestra totales; `analytics.php?space=phishlab` solo PhishLab; `?app=phishlab` (alias) igual.
- [ ] **Step 4: Commit** `feat(admin): resumen global y analítica filtrada por espacio`.

### Task 6: Plantilla común de página

**Files:**
- Modify: `server/admin/partials/layout.php` (helper nuevo)
- Modify: `server/admin/assets/admin.css` (`.page-header`, estados vacíos)
- Modify: las 18 páginas que llaman a `admin_header(...)`, en lotes (ver abajo)

**Interfaces:**
- Produces: `page_header(string $title, string $description = '', string $actionsHtml = ''): void` — imprime `<div class="page-header"><div><h1>…</h1><p class="hint">…</p></div><div class="page-actions">…</div></div>`; `$title` y `$description` se escapan, `$actionsHtml` es HTML de confianza generado por el llamador.

- [ ] **Step 1:** Implementar `page_header` y su CSS (cabecera flexible, acciones a la derecha, apilado en móvil).
- [ ] **Step 2: Lote A** (global): `index.php`, `analytics.php`, `messages.php`, `apps.php`, `app-edit.php`, `integrations.php`, `security.php`, `settings.php`, `backup.php` → cabecera con `page_header`, contenido en `.card`, tablas con clase común, estado vacío con mensaje. Convertir los `style="..."` repetidos a clases utilitarias en `admin.css` (`.mb-1`, `.flex-between`, etc.) a medida que se toca cada archivo.
- [ ] **Step 3: Lote B** (eduolihez.com): `projects.php`, `project-edit.php`, `certifications.php`, `cert-edit.php`, `posts.php`, `post-edit.php`.
- [ ] **Step 4: Lote C** (PhishLab): `lab-users.php`.
- [ ] **Step 5: Verificar por lote** (claro, oscuro, 375 px y 1280 px): ninguna página con cabecera propia distinta, tablas con el mismo estilo, sin desbordes horizontales, formularios y POST de cada página siguen funcionando (crear/editar/borrar en el stack).
- [ ] **Step 6: Commit por lote** `refactor(admin): plantilla de página común (lote A/B/C)`.

### Task 7: Revisión final, documentación y limpieza

**Files:**
- Modify: `CHANGELOG.md`, `DEPLOY.md` (nota de subida por FTP de `assets/admin.css` y `assets/theme.js`)
- Modify: `TESTING.md` (cómo correr PHPUnit con `scripts/php-test.sh`)

- [ ] **Step 1:** `bash scripts/php-test.sh` → todo OK; `npm test` → todo OK (no debe haber regresiones en `src/`).
- [ ] **Step 2:** Recorrer las 18 páginas en claro/oscuro y móvil con el navegador, adjuntando capturas; buscar errores de consola (CSP) y enlaces `?app=` rotos con `grep -n "app=" server/admin/*.php`.
- [ ] **Step 3:** Entrada de `CHANGELOG.md` (siguiente versión de cuatro números) y notas de despliegue (archivos nuevos a subir: `assets/admin.css`, `assets/theme.js`, `partials/spaces.php`, `partials/icons.php`).
- [ ] **Step 4: Commit** `docs: changelog y despliegue de espacios y tema`.
- [ ] **Step 5:** Eliminar `.superpowers/` del árbol si no hace falta y parar el servidor del companion.

---

## Self-review

- **Cobertura de la spec:** espacios y alias (Task 1, 4, 5); validación por lista blanca (Task 1); selector (4); CSS en capas (2); tema, `theme.js`, `localStorage`, `prefers-color-scheme` (3); plantilla de página (6); móvil (4, 6); tests PHPUnit (1); caché `?v=filemtime` (2); sin migraciones (restricciones globales). El apartado «gráficos y sparklines con variables» queda en Task 3 Step 2/4. El «cajón móvil» se mueve a `admin.js` en Task 4 (requisito de CSP).
- **Consistencia de nombres:** `admin_space()` / `admin_app_slug()` definidos en Task 4 y usados en Task 5; `asset_url` definido en Task 2 y usado en 3 y 4; `page_header` definido y usado en 6.
- **Desviación de la spec:** el ítem «Actividad» de Global no se crea en esta pieza (no existe la página); se pospone a la pieza 4.
