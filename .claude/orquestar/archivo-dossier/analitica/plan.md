# Plan · Analítica propia ampliada (2026-11-16)
Carpeta propia: el `plan.md` de `.claude/orquestar/` es del rediseño (cerrado). Ejecución **secuencial**.

## Restricciones globales
- Sin cookies nuevas ni identificadores persistentes. DNT=1 o GPC → no se envía nada (ni hit, ni beat, ni evento).
- NO tocar `src/layouts/BaseLayout.astro`, `SITE.cfBeaconToken` ni el beacon de Cloudflare (Web Analytics va por inyección automática de Cloudflare).
- NADA a producción: ni SQL en phpMyAdmin ni FTP. La migración se deja en `database/2026-11-16-eventos.sql` (gitignored, `*.sql`) y se avisa a Edu.
- Sin commit de ficheros ajenos: `git commit -- <paths>`; nunca `git add -A`; sin push.
- Tests de `src/pages/` en `src/test/pages/`. Función/rama nueva → test. Vitest (`npm test`) y PHPUnit (`composer test`).
- El analítico nunca debe romper la web: todo en try/catch, el endpoint responde 204 pase lo que pase; tabla sin migrar → no-op + `error_log`, nunca 500.
- Texto público (T4) → `humanizer-es` antes de dar por bueno.

## Contrato de eventos (lo fija T1, lo consume T2/T3)
Tabla `site_events` (CREATE TABLE IF NOT EXISTS, purga 400 días):
`id, name VARCHAR(24), target VARCHAR(80) NULL, path VARCHAR(120), lang CHAR(2) NULL, session_id CHAR(16) NULL, country CHAR(2) NULL, device VARCHAR(10) NULL, is_bot TINYINT(1), created_at DATETIME`.
POST `/api/visit.php` con `{"action":"event","name":…,"target":…,"path":…,"session_id":…}`.
Nombres permitidos (allowlist): `cv_open`, `outbound`, `lang_switch`, `theme_toggle`, `contact_submit`, `not_found`.
- `outbound`: `target` = hostname en minúsculas (`^[a-z0-9.-]{1,80}$`, sin esquema ni ruta).
- `lang_switch`: `target` ∈ `es|en|ca`.
- `theme_toggle`: `target` ∈ `light|dark` (tema resultante) o vacío.
- `not_found`: `path` = ruta rota; `cv_open`/`contact_submit`: sin target.
Nombre fuera de la lista, o target que no cuadra con su regla → 204 sin insertar.

## Tareas
| # | Tarea | Ficheros dueños | Dif. | Dep. |
|---|---|---|---|---|
| T1 | Backend de eventos | `database/schema.sql`, `database/2026-11-16-eventos.sql`, `server/lib/events.php`, `server/api/visit.php`, `server/tests/EventsTest.php` | normal | – |
| T2 | Cliente de eventos + GPC | `src/scripts/analytics.ts`, `src/scripts/analytics.test.ts`, `src/scripts/events.ts`, `src/scripts/events.test.ts`, `src/components/ErrorPage.astro` (solo marcar 404) | normal | T1 |
| T3 | Panel: eventos, lectura por post, 404 | `server/admin/analytics.php`, `server/lib/` helper nuevo si hace falta + su test | normal | T1 |
| T4 | «Sobre esta web» ES/EN/CA | `src/pages/sobre-esta-web.astro`, `src/pages/en/about-this-website.astro`, `src/pages/ca/sobre-aquesta-web.astro` (+ `src/i18n/ui.ts` si el texto vive ahí) | normal | T1-T3 |

Cierre: `test-runner` (npm test, npm run build, composer test) → `reviewer` + `security-reviewer` sobre la rama → una ronda de arreglos → `guardar`.
