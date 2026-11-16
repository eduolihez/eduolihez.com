# Plan de orquestación · Rediseño del panel /admin (estructura + Analítica)
Fuente de verdad: `.claude/flujo/ESTADO.md` + `.claude/flujo/rubrica.md`. Maqueta: `C:\Users\eduol\AppData\Local\Temp\claude\5fb047a1684d941d\5517a6ae-1b85-441a-ab6e-6894c0d7fc2a\scratchpad\maqueta-analitica.html`. Base: commit `588cf3d`, rama actual. Ejecución **en serie** (T1→T2→T3 comparten `layout.php`/`admin.css`/`spaces.php`).

## Restricciones globales
- Solo `server/admin/**` y `server/tests/**`. No tocar la web pública (`src/`), ni consultas SQL, ni datos.
- CSP: ningún `<style>`, `<script>` inline ni `on*=` en PHP del admin (`AdminCspTest`). `style=""` sí. Estilos solo en `assets/admin.css`.
- No romper el DOM que usa JS: `#admin-sidebar`, `#sidebar-open-btn`, `#sidebar-close-btn`, `#sidebar-overlay`, `[data-palette*]`, `[data-theme-toggle]`. `assets/palette.js` es generado: no editar a mano.
- Mantener los tokens de `admin.css` (`--accent`, `--card`, `--border`…); la maqueta usa los mismos valores. Tema claro y oscuro (`[data-theme=dark]` + `prefers-color-scheme`).
- Decisión de Edu: **Contenido NO entra en Global**. No tocar `page_spaces()`. Global = Resumen (Hoy, Bandeja) · Tráfico (Analítica) · Sistema (Seguridad, Ajustes, Backup, Integraciones, Apps). Site = Resumen · Contenido (Proyectos, Certs, Blog, Revisar) · Tráfico (Mensajes→Bandeja, Analítica).
- Commits con `git commit -- <rutas>`; nunca `git add -A`. Sin push. Sin FTP.
- Brief largo con Write, no heredocs. Ignorar `.playwright-mcp/` en greps y tests.
- PHP: `php -l` en cada fichero tocado. Tests PHP: ver `TESTING.md` (`composer test` en `server/`, con shim si hace falta).

## Tareas
| # | Objetivo | Ficheros dueños | Dificultad | Depende |
|---|---|---|---|---|
| T1 | Zonas en `space_nav` + `zone_for_page()` + tests + paleta | `server/admin/partials/spaces.php`, `server/tests/SpacesTest.php` | normal | — |
| T2 | Layout: zona activa, `aria-label`, bottom-nav, CSS de zonas, tarjeta con título interno, barra de filtros, anclas | `server/admin/partials/layout.php`, `server/admin/assets/admin.css` | diseño | T1 |
| T3 | `analytics.php` en 6 secciones, form de filtros, anclas, top 10 + `<details>`, tabla bloque→sección | `server/admin/analytics.php` (+ clases nuevas en `admin.css` solo si T2 no las cubre) | diseño | T2 |
| T4 | Verificación completa (rúbrica 1-10) | — (la hago yo con test-runner/Playwright) | — | T3 |
