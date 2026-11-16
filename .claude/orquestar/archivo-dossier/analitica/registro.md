# Registro · Analítica ampliada
| Tarea | Estado | Base | Final | Notas |
|---|---|---|---|---|
| Cloudflare Web Analytics | HECHO sin cambios en repo | – | – | Ya "Enable (auto-injected)"; verificado en el DOM de /blog/: `<script src=static.cloudflareinsights.com/beacon.min.js/v…>` presente. Esa petición devolvió 503 en la comprobación (revisar con Edu; el panel CF muestra 6 vistas/24 h). No se tocó token ni BaseLayout. Aprendizaje csp-por-hash dice tenerlo apagado: choca con lo observado. |
| T1 | HECHA (revisada: PASA; `composer test` no ejecutable aquí: sin composer/vendor; EventsTest pasó con shim, 51 asserts) | 4a2f7a5 | f441f23 | Pendiente ronda final: tope anti-flood sin `session_id` (limitar eventos con `session_id IS NULL`, p. ej. 30/min); tope de `visits` aplica antes de la rama event; host "." pasa la regex (inofensivo); `events.php` no está en tests/bootstrap.php. Migración lista en `database/2026-11-16-eventos.sql`, SIN aplicar. |
| T2 | HECHA (revisada: PASA; 501 tests, build OK 105 págs) | f441f23 | a873e1e | `cv_download` = apertura del modal del CV (no hay PDF) → T4 debe decir «abrir el CV». Menores para ronda final: path con `%xx`/acentos se descarta en servidor (replicar regex en cliente); `not_found` doble si algún día hay ClientRouter. |
| T3 | HECHA (revisada: PASA; php -l / AdminCspTest sin ejecutar por el revisor; los 5 tests del helper pasaron con shim) | a873e1e | c2d1d45 | Ronda final: `error_log` en el catch de eventos/404 (hoy cualquier error SQL se muestra como «falta migración»); avisar en UI de que Eventos/404 no filtran por app. `style=` inline OK (style-attr unsafe-inline permitido). |
| T4 | pendiente | | | |

## Decisiones
- Tabla nueva `site_events` (no reutilizar `app_events`: es JSON libre por app, aquí forma fija y allowlist) · evita basura y permite índices · coste si me equivoco: migrar una tabla pequeña.
- Eventos por **delegación** en `events.ts` importado desde `analytics.ts` · no hay que tocar BaseLayout ni cada componente · coste: depender de selectores (`[data-theme-toggle]`, `[data-cv-open]`, `a[hreflang]`, `form[data-formspree]`).
- 404 como evento `not_found` (no como columna en `visits`) · sin migrar `visits`.

## Cierre (2026-11-16)
- T4 7115fd9 + T4b f3b864c (texto Cloudflare corregido) · T5 3186164, f945782, 77b13cb (cv_open, dedupe not_found, topes y DNT/GPC en servidor, panel con regex de posts corregida, texto "intento de envío").
- Revisión de rama (reviewer + security-reviewer): sin Críticos/Altos. Final: npm test 506/506, build 105 págs, php -l OK, EventsTest/AnalyticsReportTest con shim (57 casos). composer test no ejecutado (sin composer).
- Pendiente de Edu: aplicar SQL, build+FTP, decidir DNT/GPC en hit/beat, revisar 503 del beacon.
