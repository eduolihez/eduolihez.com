# Flujo · Rediseño del panel /admin (estructura + Analítica)

**Fase:** 7/7 Finalizado (HEAD d767755, 12 commits sin push desde 588cf3d; 272 tests PHP, 520 npm, build 105 págs)
**Tamaño:** L
**Inicio:** 2026-11-16
(El flujo anterior, rediseño Dossier, está en `.claude/flujo/archivo/`.)

## Objetivo
Que el panel `/admin` sea claro y ordenado: navegación agrupada por zonas, una plantilla de página con cada cosa en su sección/tarjeta, y estética de dashboard SaaS limpio. Alcance de esta tanda: **estructura global + pantalla Analítica**. El resto de pantallas heredan después.

## Decisiones (Edu, 2026-11-16)
- Empezar por estructura (navegación + plantilla) + Analítica (901 líneas, la más cargada).
- Estética: **dashboard SaaS limpio** (barra lateral fija, tarjetas de borde suave, más aire, color de acento). Se aleja del tono "expediente" solo en el panel; la web pública no se toca.
- Sin producción ni push sin OK de Edu (FTP y SQL los hace Edu o con su permiso explícito).

## Mapa actual (para la fase 2)
- Layout: `server/admin/partials/layout.php` (531 l), `spaces.php` (263), `icons.php`; estilos `server/admin/assets/admin.css` (1066 l), `admin.js`, `palette.js`, `theme.js`.
- Pantallas: index (Hoy), messages (Bandeja), analytics, security, settings, backup, integrations, apps/app-edit, posts/post-edit, projects/project-edit, certifications/cert-edit, lab-users, revisar.
- Restricciones: CSP por hash (`style=` inline permitido, scripts inline no sin hash), tests `AdminCspTest`, tema claro/oscuro existente, paleta de comandos.

## Hallazgos fase 2 (Explore, 2026-11-16)
- Ya existe: sidebar fija + cajón móvil (<1024px) + bottom-nav, grupos con etiqueta (`space_nav` en `spaces.php:203`), `page_header($title,$desc,$actions)` (`layout.php:395`), `stat_card`, tokens claro/oscuro, `aria-current`. El rediseño es de **reorganización y pulido**, no de cero.
- Corrección: la CSP **no usa hashes** (`auth.php:31-33`, `style-src-attr 'unsafe-inline'`). `AdminCspTest`: prohíbe `<style>`, `<script>` inline y `on*=`; permite `style=""`.
- Restricciones DOM a conservar: `#admin-sidebar`, `#sidebar-open-btn/close-btn/overlay`, `[data-palette*]`, `[data-theme-toggle]`. `palette.js` es generado (`npm run admin:palette`, fuente `src/scripts/palette.ts`).
- `analytics.php`: 901 l, ~17 bloques en una sola columna larga (h2 + .card, gráficos CSS puro, sin JS propio). Filtros = botones sueltos en el page-header (sin form). Export CSV `?export=csv`.
- Páginas: `admin_header($title,$active)` recibe el fichero; las `*-edit` pasan el de su listado.

## Decisiones fase 2 (Edu confirmó, 2026-11-16)
- Zonas Global: Resumen (Hoy, Bandeja) · Tráfico (Analítica) · Contenido (Blog, Proyectos, Certs, Revisar) · Sistema (Seguridad, Ajustes, Backup, Integraciones, Apps).
- Plantilla: `page_header` siempre; título de sección dentro de la tarjeta; filtros en barra propia bajo la cabecera.
- Analítica: 6 secciones (Resumen, Audiencia, Contenido, Adquisición, Comportamiento, Bots) con índice de anclas sticky, sin JS nuevo.
- Maqueta estática: `scratchpad/maqueta-analitica.html` (probada a 1440 claro/oscuro y 390 oscuro, sin scroll horizontal). Ajuste: Contenido en 2 columnas.

## Plan de tareas (borrador)
1. `spaces.php`: reagrupar `space_nav` por zonas (+ zona activa) y `layout.php`: marcar zona activa, ajustar bottom-nav. Tests PHP del helper.
2. `admin.css`: estilos de zona, tarjeta con título interno (`.card h3`), barra de filtros, anclas sticky, secciones; mantener tokens y DOM de JS.
3. `layout.php`/`page_header`: plantilla común; revisar que todas las pantallas la usan.
4. `analytics.php`: reordenar bloques en 6 secciones, filtros en barra, anclas.
5. Verificación: AdminCspTest, `php -l`, `npm test`, `npm run build`, Playwright 390/768/1440 claro/oscuro, contraste AA.
(≥4 tareas → `orquestar` en fase 3, con worktree si hay agentes en paralelo.)

## Revisión de `critico` (2026-11-16) — ajustes al plan
- **ALTO 1:** Contenido en Global choca con `page_spaces()` (`spaces.php:63-81`) y `SpacesTest.php:159`. Falta decidir: (a) ampliar `page_spaces`, (b) enlazar a `?space=site` marcándolo, (c) Contenido solo en el espacio Site. Y definir zonas para site/phishlab/app.
- **ALTO 2:** "Incluir bots" necesita `<form method=get>` (con `days` y `space` ocultos) o enlace GET con aspecto de interruptor; el checkbox suelto no hace nada sin JS.
- **ALTO 3:** anclas sticky a `top: var(--topbar-h)` (topbar ya es sticky, `admin.css:446`); en móvil, una fila con `overflow-x:auto`.
- MEDIO: tabla bloque→sección de los ~21 bloques (incl. idioma navegador, pantalla, opt-in, KPI bots; condicionales `$hasVisitorCol`/eventos/app); recortar listas largas en PHP (top 10 + `<details>`); medir overflow con `getBoundingClientRect` (hay `overflow-x:hidden`, `admin.css:111`); medir contraste sobre `admin.css` real; `aria-label` en nav y zonas como grupos; actualizar `SpacesTest` (159/182/188) y crear `zone_for_page()` con tests; paleta usa `group.label`; tareas 1-4 en serie (tocan los mismos ficheros).
- BAJO: tarea 3 casi hecha (17 pantallas ya usan `page_header`); CSV sin `bots=1` y `&bots=1` sin escapar (`analytics.php:453,458`); unificar Bandeja/Mensajes; excluir `.playwright-mcp/t07a-env/` de greps.
- Verificación a añadir: CSP en consola, teclado, acciones del criterio 6, git/FTP, cajón a 768 px.

## Decisión ALTO 1 (Edu, 2026-11-16): opción (c)
Contenido NO entra en Global. Global = Resumen (Hoy, Bandeja) · Tráfico (Analítica) · Sistema (Seguridad, Ajustes, Backup, Integraciones, Apps). Site = Resumen · Contenido (Proyectos, Certs, Blog, Revisar) · Tráfico (Mensajes→Bandeja, Analítica). Sin tocar `page_spaces()`. ALTO 2: `<form method=get>` con `days`, `space` y bots + botón Aplicar (recomendado y no objetado).

## Plan final (tareas en serie)
1. `spaces.php` + `zone_for_page()` + tests (`SpacesTest` 159/182/188) + paleta.
2. `layout.php` + `admin.css`: zonas, `aria-label`, bottom-nav, tarjeta con título interno, barra de filtros.
3. `analytics.php`: 6 secciones, anclas sticky, form de filtros, top 10 + `<details>`, tabla bloque→sección.
4. Verificación completa (rúbrica 1-10).

**Fase:** 7/7 Finalizado (HEAD d767755, 12 commits sin push desde 588cf3d; 272 tests PHP, 520 npm, build 105 págs)

## Siguiente paso
Fase 3 con `orquestar` (tareas en serie, commit por tarea, sin push).

## Cierre (2026-11-16)
- Edu eligió "entra todo" (1-18). El punto 18 añadió SELECT nuevos (periodo anterior, semanas, deltas) sin migraciones: alcance ampliado por Edu.
- Pendiente de Edu: probar `/admin/analytics.php` con MySQL real (365d, índice `visited_at`/`is_bot`/`app_id`); build + FTP de `server/`; OK para push (11+ commits locales).
- Menores no hechos: `.stat::before` y `is-unread` con borde lateral (avisos de diseño, preexistentes).
