<?php
/**
 * Plantilla comun del panel de administracion.
 *   admin_header($title, $active): abre el HTML + navegacion.
 *   admin_footer(): cierra el HTML.
 * Ademas incluye helpers de presentacion reutilizados por todas las paginas
 * (tarjetas de estadistica, barras, formato de fechas, exportacion CSV segura).
 *
 * El CSS va embebido (tema oscuro) para que el panel sea autonomo: no depende
 * de ningun CDN, lo que encaja con la CSP estricta de auth.php.
 */

// Esta plantilla usa e(), db() y csrf_field(). En la practica las paginas ya
// cargan auth.php antes, pero lo declaramos para que el archivo sea autonomo
// y no dependa del orden de los require. Al ser require_once, no se ejecuta
// dos veces ni reenvia cabeceras.
require_once __DIR__ . '/../auth.php';

function admin_header(string $title, string $active = ''): void
{
    $user = function_exists('current_admin') ? current_admin() : '';

    // Contadores para los "badges" del menu. Cada uno tolera que falte la
    // tabla (BD recien creada, migracion a medias) devolviendo 0 en vez de
    // tumbar el panel entero -- por eso el conteo pasa por un closure que
    // atrapa el Throwable de cada query por separado en lugar de una sola
    // vez alrededor de las cuatro.
    $countSafe = static function (string $sql): int {
        try {
            return (int) db()->query($sql)->fetchColumn();
        } catch (Throwable $e) {
            return 0;
        }
    };
    $unread             = $countSafe('SELECT COUNT(*) FROM messages WHERE is_read = 0 AND is_archived = 0');
    $publishedProjects  = $countSafe("SELECT COUNT(*) FROM projects WHERE status = 'published'");
    $visibleCerts       = $countSafe('SELECT COUNT(*) FROM certifications WHERE visible = 1');
    $visiblePosts       = $countSafe('SELECT COUNT(*) FROM posts WHERE visible = 1');

    // Selector de apps (docs/designs/admin-dashboard.md): que sub-dashboard
    // se esta viendo. Mismo patron try/catch que $countSafe -- la tabla
    // puede no existir todavia si la migracion no se ha corrido.
    try {
        $appsList = db()->query('SELECT slug, display_name FROM apps ORDER BY created_at ASC')->fetchAll();
    } catch (Throwable $e) {
        $appsList = [];
    }
    $currentAppSlug = (string) ($_GET['app'] ?? '');
    $currentAppName = null;
    foreach ($appsList as $ap) {
        if ($ap['slug'] === $currentAppSlug) {
            $currentAppName = $ap['display_name'];
            break;
        }
    }

    // [etiqueta_grupo, url, [titulo, badge, icono, tipo_badge]]. tipo_badge:
    // 'alert' (verde/llamada a la accion, como Mensajes) o 'count' (gris,
    // solo informativo). Grupo '' no imprime cabecera (Panel va suelto).
    $navGroups = [
        '' => [
            'index.php' => ['Panel', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>', 'count'],
        ],
        'Contenido' => [
            'projects.php'       => ['Proyectos', (string) $publishedProjects, '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>', 'count'],
            'certifications.php' => ['Certificaciones', (string) $visibleCerts, '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" /></svg>', 'count'],
            'posts.php'          => ['Blog', (string) $visiblePosts, '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 4a2 2 0 012 2v6a2 2 0 01-2 2h-2m-4-6h.01M9 16h.01M9 12h.01M12 12h.01M12 16h.01M16 16h.01M16 12h.01" /></svg>', 'count'],
        ],
        'Actividad' => [
            'messages.php'  => ['Mensajes', $unread > 0 ? (string) $unread : '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>', 'alert'],
            'analytics.php' => ['Analítica', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>', 'count'],
        ],
        'Multi-proyecto' => [
            // admin.eduolihez.com (docs/designs/admin-dashboard.md): registro
            // de apps con su propio sub-dashboard y clave de ingesta.
            'apps.php' => ['Apps', (string) $countSafe('SELECT COUNT(*) FROM apps'), '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>', 'count'],
        ],
        'Sistema' => [
            'security.php' => ['Seguridad', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>', 'count'],
            'settings.php' => ['Ajustes', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>', 'count'],
            'backup.php'   => ['Backup', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" /></svg>', 'count'],
        ],
    ];
    ?>
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title><?= e($title) ?> · Admin</title>
<?php /*
  Las fuentes se sirven desde el propio dominio.

  Antes habia aqui tres <link> a Google Fonts que NO cargaban: la CSP de
  auth.php es "default-src 'self'" sin font-src propio, asi que tanto la hoja
  de fonts.googleapis.com como los ficheros de fonts.gstatic.com quedaban
  bloqueados y el panel se pintaba con la fuente del sistema. Ademas
  contradecia el "no depende de ningun CDN" que dice la cabecera de este
  mismo archivo.

  Los .woff2 son los mismos que usa el sitio publico (Inter Variable y
  JetBrains Mono Variable, subconjunto latino, licencia OFL). Se copian a
  assets/fonts/ para que el panel siga siendo autonomo y sin compilacion.
*/ ?>
<style>
  @font-face {
    font-family: 'Inter';
    font-style: normal;
    font-weight: 100 900;
    font-display: swap;
    src: url('assets/fonts/inter-latin-wght-normal.woff2') format('woff2-variations');
  }
  @font-face {
    font-family: 'JetBrains Mono';
    font-style: normal;
    font-weight: 100 800;
    font-display: swap;
    src: url('assets/fonts/jetbrains-mono-latin-wght-normal.woff2') format('woff2-variations');
  }
</style>
<style>
  :root {
    --bg: #0a0e14; --soft: #0f141c; --card: rgba(20, 26, 36, 0.72); --border: #1f2733;
    --text: #e6edf3; --muted: #9aa7b8; --faint: #78849a;
    --accent: #4ade80; --accent-hover: #22c55e; --danger: #f87171;
    --cyan: #22d3ee; --warn: #f59e0b; --violet: #a78bfa;
    --shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.4), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
    --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font-family: 'Inter', system-ui, -apple-system, sans-serif;
    font-size: 14px; line-height: 1.6;
    -webkit-font-smoothing: antialiased;
    overflow-x: hidden;
  }
  
  /* Scrollbar personalizado */
  ::-webkit-scrollbar { width: 6px; height: 6px; }
  ::-webkit-scrollbar-track { background: var(--bg); }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 99px; }
  ::-webkit-scrollbar-thumb:hover { background: var(--muted); }

  a { color: var(--accent); text-decoration: none; transition: color 0.15s ease; }
  a:hover { color: var(--accent-hover); }
  /* Foco general para enlaces y botones sueltos (los que no tienen ya un
     anillo propio, como .menu-item o los campos de formulario mas abajo). */
  a:focus-visible, button:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }

  /* Grid Layout Principal */
  .admin-layout {
    display: grid;
    grid-template-columns: 260px 1fr;
    min-height: 100vh;
  }

  /* Sidebar */
  .sidebar {
    background: var(--soft);
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    height: 100vh;
    position: sticky;
    top: 0;
    padding: 1.5rem;
    overflow-y: auto;
    z-index: 100;
  }

  .sidebar-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 2rem;
  }

  .brand-block {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .brand {
    font-family: 'JetBrains Mono', monospace;
    font-weight: 700;
    font-size: 1.15rem;
    letter-spacing: -0.04em;
    color: var(--text);
    text-decoration: none;
  }
  .brand span { color: var(--accent); }

  /* Selector de apps (docs/designs/admin-dashboard.md): a que sub-dashboard
     apuntan las paginas de datos (hoy solo Analitica lee ?app=). <details>
     nativo -- sin JS, se cierra solo al navegar a otra pagina. */
  .app-switcher { position: relative; }
  .app-switcher summary {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    list-style: none;
    cursor: pointer;
    user-select: none;
    font-size: 0.75rem;
    color: var(--muted);
    padding: 0.2rem 0.4rem;
    margin-left: -0.4rem;
    border-radius: 6px;
    width: fit-content;
  }
  .app-switcher summary::-webkit-details-marker { display: none; }
  .app-switcher summary:hover { background: var(--soft); color: var(--text); }
  .app-switcher[open] summary { color: var(--text); }
  .app-switcher-current { font-weight: 600; }
  .app-switcher summary svg {
    width: 12px; height: 12px; flex-shrink: 0;
    transition: transform 0.15s;
  }
  .app-switcher[open] summary svg { transform: rotate(180deg); }
  .app-switcher-menu {
    position: absolute;
    top: calc(100% + 4px);
    left: -0.4rem;
    z-index: 200;
    min-width: 190px;
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    box-shadow: var(--shadow);
    padding: 0.35rem;
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
    backdrop-filter: blur(8px);
  }
  .app-switcher-menu a {
    display: block;
    padding: 0.4rem 0.55rem;
    border-radius: 6px;
    font-size: 0.8rem;
    color: var(--text);
    text-decoration: none;
  }
  .app-switcher-menu a:hover { background: var(--soft); }
  .app-switcher-menu a.active { color: var(--accent); font-weight: 600; }
  .app-switcher-manage {
    margin-top: 0.25rem;
    padding-top: 0.45rem !important;
    border-top: 1px solid var(--border);
    color: var(--faint) !important;
    font-size: 0.72rem !important;
  }

  .sidebar-menu {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
    flex: 1;
  }

  /* Cabecera de grupo (Contenido / Actividad / Sistema): mismo patron mono
     versalita que el "section-kicker" del sitio publico, para que el panel
     no se sienta un sistema aparte. */
  .nav-group-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--faint);
    margin: 1.1rem 0 0.4rem 0.85rem;
  }
  .nav-group-label:first-child {
    margin-top: 0;
  }

  .menu-item {
    position: relative;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.6rem 0.85rem 0.6rem 1.05rem;
    border-radius: 0.5rem;
    color: var(--muted);
    font-weight: 500;
    font-size: 0.88rem;
    transition: background-color 0.2s ease, color 0.2s ease, border-color 0.2s ease;
    border: 1px solid transparent;
  }

  /* Barra de acento a la izquierda en vez de solo el tinte de fondo: se
     reconoce la seccion activa incluso pasando la vista rapido por el menu. */
  .menu-item::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0.25rem;
    bottom: 0.25rem;
    width: 2px;
    border-radius: 99px;
    background: var(--accent);
    opacity: 0;
    transition: opacity 0.2s ease;
  }

  .menu-item:hover {
    background: rgba(255, 255, 255, 0.03);
    color: var(--text);
  }

  .menu-item.active {
    background: rgba(74, 222, 128, 0.08);
    color: var(--accent);
    border-color: rgba(74, 222, 128, 0.18);
  }
  .menu-item.active::before {
    opacity: 1;
  }

  .menu-item:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 1px;
  }

  .menu-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    color: inherit;
    flex-shrink: 0;
  }

  .menu-label {
    flex-grow: 1;
  }

  .badge-count {
    background: var(--accent);
    color: var(--bg);
    font-size: 0.7rem;
    font-weight: 700;
    border-radius: 99px;
    padding: 0.05rem 0.4rem;
    min-width: 18px;
    text-align: center;
  }

  /* Contador informativo (cuantos hay), distinto del aviso de "hay algo que
     mirar" (badge-count, verde): mismo hueco, tono neutro. */
  .badge-muted {
    background: rgba(255, 255, 255, 0.06);
    color: var(--faint);
    font-size: 0.7rem;
    font-weight: 700;
    font-family: 'JetBrains Mono', monospace;
    border-radius: 99px;
    padding: 0.05rem 0.45rem;
    min-width: 18px;
    text-align: center;
  }
  .menu-item.active .badge-muted {
    color: var(--accent);
    background: rgba(74, 222, 128, 0.14);
  }

  .sidebar-footer {
    border-top: 1px solid var(--border);
    padding-top: 1rem;
    margin-top: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .user-info {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .user-info .avatar {
    width: 32px;
    height: 32px;
    border-radius: 0.375rem;
    background: var(--border);
    color: var(--text);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 0.75rem;
    font-family: 'JetBrains Mono', monospace;
  }

  .user-info .details {
    display: flex;
    flex-direction: column;
  }

  .user-info .username {
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text);
  }

  .user-info .role {
    font-size: 0.72rem;
    color: var(--faint);
  }

  .sidebar-actions {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .action-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 0.75rem;
    border-radius: 0.375rem;
    font-size: 0.8rem;
    color: var(--muted);
    font-weight: 500;
    transition: all 0.2s;
    background: none;
    border: none;
    cursor: pointer;
    width: 100%;
    text-align: left;
  }

  .action-btn:hover {
    background: rgba(255, 255, 255, 0.02);
    color: var(--text);
  }

  .action-btn:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 1px;
  }

  .action-btn.danger-text:hover {
    color: var(--danger);
    background: rgba(248, 113, 113, 0.05);
  }

  /* Main Content Wrapper */
  .main-content-wrapper {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    min-width: 0;
  }

  header.topbar {
    position: sticky;
    top: 0;
    z-index: 90;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 2rem;
    background: rgba(10, 14, 20, 0.8);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border);
  }

  .topbar-left {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .topbar-title {
    font-weight: 700;
    font-size: 1.1rem;
    color: var(--text);
  }

  .user-greeting {
    font-size: 0.85rem;
    color: var(--faint);
    font-weight: 500;
  }

  .sidebar-toggle-btn {
    background: none;
    border: none;
    padding: 0.25rem;
    color: var(--text);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mobile-only {
    display: none;
  }

  .sidebar-overlay {
    display: none;
  }

  main {
    flex-grow: 1;
    padding: 2rem;
    max-width: 1300px;
    width: 100%;
    margin: 0 auto;
  }

  /* Cards premium */
  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 0.75rem;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: var(--shadow);
    backdrop-filter: blur(8px);
  }

  /* Card "hundida": para contenido citado/preformateado (p.ej. el cuerpo de
     un mensaje) dentro de otra card, un tono de fondo distinto en vez de
     borde extra. */
  .card.inset { background: var(--bg); box-shadow: none; backdrop-filter: none; }

  /* Caja de fondo neutro para miniaturas/paneles sueltos que no son una
     .card completa (marcador de imagen sin logo, vista previa de un
     campo...). Clase en vez de "style=background:var(--soft)" repetido
     para que el re-skin por pagina (.subdash) tambien la alcance. */
  .soft-box { background: var(--soft); }

  h1 { font-size: 1.75rem; font-weight: 700; margin: 0 0 1.5rem; letter-spacing: -0.03em; }
  h2 { font-size: 1.25rem; font-weight: 700; margin: 1.5rem 0 1rem; letter-spacing: -0.02em; color: var(--text); }
  h3 { font-size: 0.85rem; font-weight: 600; margin: 0 0 1rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }

  .grid { display: grid; gap: 1.5rem; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
  .grid4 { display: grid; gap: 1.5rem; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); }
  
  .stat { 
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), border-color 0.25s ease;
    position: relative;
    overflow: hidden;
  }
  .stat::before {
    content: ''; position: absolute; top: 0; left: 0; width: 3px; height: 100%;
    background: var(--accent); opacity: 0; transition: opacity 0.25s;
  }
  .stat:hover::before { opacity: 1; }
  .stat:hover { border-color: rgba(255,255,255,0.15); transform: translateY(-4px); }
  .stat .num { 
    font-family: 'JetBrains Mono', monospace; 
    font-size: 2.25rem; 
    font-weight: 700; 
    color: var(--accent); 
    line-height: 1; 
    letter-spacing: -0.04em; 
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }
  .stat .num.cyan { color: var(--cyan); }
  .stat .num.warn { color: var(--warn); }
  .stat .num.violet { color: var(--violet); }
  .stat .num.danger { color: var(--danger); }
  .stat .lbl { color: var(--muted); font-size: 0.82rem; margin-top: 0.75rem; font-weight: 500; line-height: 1.5; }
  
  .delta { 
    font-size: 0.72rem; font-weight: 700; margin-left: 0.5rem; padding: 0.15rem 0.4rem; 
    border-radius: 0.375rem; vertical-align: middle;
  }
  .delta.up { color: var(--accent); background: rgba(74, 222, 128, 0.12); }
  .delta.down { color: var(--danger); background: rgba(248, 113, 113, 0.12); }
  .delta.flat { color: var(--faint); background: rgba(255, 255, 255, 0.04); }

  /* Tablas */
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 1rem 0.85rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
  th { color: var(--faint); font-weight: 600; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; }
  tr:last-child td { border-bottom: none; }
  tr { transition: background-color 0.15s ease; }
  tr:hover td { background: rgba(255, 255, 255, 0.02); }

  /* Form Controls */
  label { display: block; margin: 1rem 0 0.4rem; font-weight: 600; font-size: 0.85rem; color: var(--text); }
  input[type=text], input[type=email], input[type=password], input[type=url],
  input[type=number], input[type=date], input[type=search], textarea, select {
    width: 100%; padding: 0.7rem 0.9rem; background: rgba(10, 14, 20, 0.7);
    border: 1px solid var(--border); border-radius: 0.5rem; color: var(--text);
    font-size: 0.92rem; font-family: inherit; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  input:focus, textarea:focus, select:focus { 
    outline: none; border-color: var(--accent); 
    box-shadow: 0 0 0 3px rgba(74, 222, 128, 0.18); 
    background: rgba(10, 14, 20, 0.9);
  }
  textarea { resize: vertical; min-height: 120px; }
  
  .row2 { display: grid; gap: 1.5rem; grid-template-columns: 1fr 1fr; }
  .row3 { display: grid; gap: 1.5rem; grid-template-columns: repeat(3, 1fr); }

  /* Botones */
  .btn {
    display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem; cursor: pointer;
    padding: 0.65rem 1.25rem; border-radius: 0.5rem; font-weight: 600; font-size: 0.88rem;
    border: 1px solid transparent; background: var(--accent); color: var(--bg);
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .btn:hover { background: var(--accent-hover); box-shadow: var(--shadow); }
  .btn.ghost { background: transparent; color: var(--text); border-color: var(--border); }
  .btn.ghost:hover { border-color: var(--accent); color: var(--accent); background: rgba(74, 222, 128, 0.05); }
  .btn.danger { background: transparent; color: var(--danger); border-color: rgba(248, 113, 113, 0.35); }
  .btn.danger:hover { background: rgba(248, 113, 113, 0.08); }
  .btn.sm { padding: 0.4rem 0.85rem; font-size: 0.8rem; border-radius: 0.375rem; }
  .btn.icon { padding: 0.4rem 0.55rem; font-size: 0.85rem; border-radius: 0.375rem; }
  .btn[disabled] { opacity: 0.35; pointer-events: none; }
  .btn:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

  /* Badges */
  .pill { 
    display: inline-block; padding: 0.15rem 0.5rem; border-radius: 0.375rem; 
    font-size: 0.72rem; font-weight: 600; border: 1px solid var(--border); 
    background: var(--soft); color: var(--muted); 
  }
  .pill.on { color: var(--accent); border-color: rgba(74, 222, 128, 0.28); background: rgba(74, 222, 128, 0.06); }
  .pill.off { color: var(--faint); background: rgba(255, 255, 255, 0.02); }
  .pill.warn { color: var(--warn); border-color: rgba(245, 158, 11, 0.25); background: rgba(245, 158, 11, 0.06); }
  .pill.danger { color: var(--danger); border-color: rgba(248, 113, 113, 0.25); background: rgba(248, 113, 113, 0.06); }

  .actions { display: flex; gap: 0.5rem; flex-wrap: wrap; align-items: center; }
  .flash { padding: 0.85rem 1.25rem; border-radius: 0.5rem; margin-bottom: 1.5rem; font-size: 0.88rem; font-weight: 500; }
  .flash.ok { background: rgba(74, 222, 128, 0.08); color: var(--accent); border: 1px solid rgba(74, 222, 128, 0.18); }
  .flash.err { background: rgba(248, 113, 113, 0.08); color: var(--danger); border: 1px solid rgba(248, 113, 113, 0.15); }
  .flash.warn { background: rgba(245, 158, 11, 0.06); color: var(--warn); border: 1px solid rgba(245, 158, 11, 0.15); }
  .toolbar { display: flex; align-items: center; justify-content: space-between; gap: 1.25rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
  .hint { color: var(--faint); font-size: 0.78rem; margin-top: 0.3rem; line-height: 1.5; }
  
  /* Horizontal bar graphs */
  .bar-wrap { height: 6px; background: rgba(255, 255, 255, 0.04); border-radius: 99px; overflow: hidden; margin-top: 0.4rem; }
  .bar { height: 100%; background: var(--cyan); border-radius: 99px; }
  .bar.green { background: var(--accent); }
  .bar.violet { background: var(--violet); }
  .barline { margin-bottom: 0.85rem; }
  .barline .lab { display: flex; justify-content: space-between; font-size: 0.82rem; gap: 1rem; }
  .barline .lab span:first-child { color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .barline .lab span:last-child { color: var(--faint); white-space: nowrap; font-family: 'JetBrains Mono', monospace; }
  
  /* Vertical bar charts */
  .chart { display: flex; align-items: flex-end; gap: 0.5rem; height: 180px; overflow-x: auto; padding-bottom: 0.25rem; border-bottom: 1px solid var(--border); }
  .chart .col { flex: 1 0 16px; display: flex; flex-direction: column; align-items: center; gap: 0.35rem; min-width: 16px; }
  .chart .bar-v { width: 100%; background: var(--accent); border-radius: 4px 4px 0 0; min-height: 4px; transition: height 0.3s ease, background 0.15s; }
  .chart .bar-v:hover { background: var(--accent-hover); filter: brightness(1.1); cursor: pointer; }
  .chart .tick { color: var(--faint); font-size: 0.62rem; white-space: nowrap; margin-top: 0.2rem; }
  .chart .val { color: var(--faint); font-size: 0.68rem; font-family: 'JetBrains Mono', monospace; }
  
  .tabs { display: flex; gap: 0.35rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
  .tabs a { padding: 0.45rem 1rem; border-radius: 0.5rem; font-size: 0.82rem; font-weight: 500; color: var(--muted); border: 1px solid var(--border); transition: all 0.2s; }
  .tabs a.active { background: rgba(74, 222, 128, 0.08); color: var(--accent); border-color: rgba(74, 222, 128, 0.18); }
  .tabs a:hover { text-decoration: none; color: var(--text); border-color: var(--muted); }
  .tabs a:focus-visible { outline: 2px solid var(--accent); outline-offset: 1px; }
  
  .checkline { display: flex; align-items: flex-start; gap: 0.75rem; margin: 0 0 1.25rem; font-weight: 400; cursor: pointer; }
  .checkline input { width: auto; margin-top: 0.25rem; cursor: pointer; }
  .checkline strong { display: block; font-size: 0.9rem; color: var(--text); }
  .empty { padding: 3rem; color: var(--muted); text-align: center; font-style: italic; }
  .scroll-x { overflow-x: auto; border-radius: 0.5rem; border: 1px solid var(--border); background: var(--card); }
  .nowrap { white-space: nowrap; }

  /* Titulo de seccion con icono: mismo peso visual que h2 pero mas facil de
     escanear en una pagina con muchas secciones (dashboard). */
  .h2-icon { display: flex; align-items: center; gap: 0.55rem; }
  .h2-icon svg { flex-shrink: 0; color: var(--accent); opacity: 0.9; }

  /* Mini grafico de tendencia embebido en una stat card: mismas barras que
     .chart pero sin ejes ni etiquetas, para no competir con el numero grande. */
  .spark { display: flex; align-items: flex-end; gap: 2px; height: 26px; margin-top: 0.85rem; }
  .spark i { flex: 1; display: block; background: var(--accent); opacity: 0.28; border-radius: 2px 2px 0 0; min-height: 2px; font-style: normal; }
  .spark i:last-child { opacity: 1; }
  .spark.cyan i { background: var(--cyan); }
  .spark.violet i { background: var(--violet); }
  .spark.warn i { background: var(--warn); }

  /* Rejilla de "casillas" de estado (salud del sistema, seguridad): se lee de
     un vistazo mucho mas rapido que una tabla de filas clave/valor. */
  .health-grid { display: grid; gap: 0.75rem; grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); }
  .health-item { display: flex; align-items: center; gap: 0.75rem; padding: 0.85rem 1rem; background: rgba(255, 255, 255, 0.02); border: 1px solid var(--border); border-radius: 0.6rem; }
  .health-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; background: var(--faint); box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.03); }
  .health-dot.ok { background: var(--accent); box-shadow: 0 0 0 3px rgba(74, 222, 128, 0.15); }
  .health-dot.warn { background: var(--warn); box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.15); }
  .health-dot.danger { background: var(--danger); box-shadow: 0 0 0 3px rgba(248, 113, 113, 0.15); }
  .health-body { min-width: 0; }
  .health-val { font-size: 0.86rem; font-weight: 600; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .health-lbl { font-size: 0.72rem; color: var(--faint); margin-top: 0.1rem; }

  /* Linea de tiempo para actividad reciente: mas facil de seguir que filas de
     tabla sueltas, y el color del punto adelanta el tipo de accion. */
  .timeline-item { display: flex; gap: 0.85rem; padding: 0.8rem 0; border-bottom: 1px solid var(--border); }
  .timeline-item:last-child { border-bottom: none; padding-bottom: 0; }
  .timeline-item:first-child { padding-top: 0; }
  .timeline-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--muted); flex-shrink: 0; margin-top: 0.4rem; }
  .timeline-dot.green { background: var(--accent); }
  .timeline-dot.cyan { background: var(--cyan); }
  .timeline-dot.violet { background: var(--violet); }
  .timeline-dot.danger { background: var(--danger); }
  .timeline-body { flex: 1; min-width: 0; }

  /* Responsive Sidebar rules */
  @media (max-width: 900px) {
    .admin-layout {
      grid-template-columns: 1fr;
    }
    .sidebar {
      position: fixed;
      left: 0;
      top: 0;
      bottom: 0;
      width: 270px;
      transform: translateX(-100%);
      transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
      box-shadow: 10px 0 25px rgba(0, 0, 0, 0.5);
    }
    .sidebar.open {
      transform: translateX(0);
    }
    .mobile-only {
      display: flex;
    }
    .sidebar-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.6);
      backdrop-filter: blur(4px);
      z-index: 99;
      display: none;
      transition: opacity 0.25s;
    }
    .sidebar-overlay.open {
      display: block;
    }
    header.topbar {
      padding: 1rem 1.5rem;
    }
    main {
      padding: 1.5rem;
    }
    .subdash {
      margin: -1.5rem -1.5rem 0;
      padding: 1.5rem;
    }
  }

  /* ===========================================================================
     SUB-DASHBOARD (docs/designs/admin-dashboard.md, Entrega 1 + Entrega 2):
     tema claro, minimal, tipo Linear/Vercel -- deliberadamente distinto del
     panel oscuro de siempre. La barra lateral y la topbar SIGUEN oscuras a
     proposito: dan continuidad de navegacion mientras cada pagina de
     contenido va pasando a este tema (Entrega 2 se aplica pagina por
     pagina, no de golpe). Vive bajo <div class="subdash">...</div> -- MISMO
     HTML que el resto del panel (.card, .btn, .table, inputs...), apariencia
     nueva solo por cascada, sin tocar la logica de ninguna pagina.
     =========================================================================== */
  .subdash {
    --sd-bg: #fbfbfa; --sd-surface: #ffffff;
    --sd-border: #ececea; --sd-border-strong: #dbdad6;
    --sd-text: #16151a; --sd-muted: #6b6b74; --sd-faint: #9c9ba3;
    --sd-accent: #5b5bd6; --sd-accent-soft: #eeeefc;
    --sd-green: #17794f; --sd-green-soft: #e6f6ee;
    --sd-warn: #a15c00; --sd-warn-soft: #fdf1de;
    --sd-danger: #b3261e; --sd-danger-soft: #fbe9e8;
    background: var(--sd-bg);
    color: var(--sd-text);
    margin: -2rem -2rem 0;
    padding: 2rem;
    font-feature-settings: "tnum" 1;
  }
  .subdash h1 { color: var(--sd-text); font-weight: 650; letter-spacing: -0.03em; }
  .subdash h1 .faint { color: var(--sd-faint); font-weight: 500; }
  .subdash h2 {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.7rem; font-weight: 600; text-transform: uppercase;
    letter-spacing: 0.09em; color: var(--sd-faint);
    border: 0; padding: 0; margin: 2.25rem 0 0.75rem;
  }
  .subdash h3 { color: var(--sd-faint); }
  .subdash .card {
    background: var(--sd-surface); border: 1px solid var(--sd-border);
    border-radius: 10px; box-shadow: none; backdrop-filter: none;
  }
  .subdash .stat:hover { border-color: var(--sd-border-strong); transform: none; }
  .subdash .stat::before { background: var(--sd-accent); }
  .subdash .stat .num {
    font-family: 'Inter', sans-serif; font-weight: 650; font-size: 2rem;
    letter-spacing: -0.03em; color: var(--sd-text);
  }
  .subdash .stat .num.cyan,
  .subdash .stat .num.violet { color: var(--sd-accent); }
  .subdash .stat .num.warn { color: var(--sd-warn); }
  .subdash .stat .num.danger { color: var(--sd-danger); }
  .subdash .stat .lbl { color: var(--sd-muted); }
  .subdash .delta.up { color: var(--sd-green); background: var(--sd-green-soft); }
  .subdash .delta.down { color: var(--sd-danger); background: var(--sd-danger-soft); }
  .subdash .delta.flat { color: var(--sd-faint); background: var(--sd-border); }
  .subdash table th, .subdash table td { border-bottom: 1px solid var(--sd-border); }
  .subdash table th { color: var(--sd-faint); font-family: 'JetBrains Mono', monospace; letter-spacing: 0.07em; }
  .subdash table td { color: var(--sd-text); }
  .subdash tr:hover td { background: var(--sd-bg); }
  .subdash .btn { border-radius: 7px; font-weight: 600; background: var(--sd-text); color: var(--sd-surface); }
  .subdash .btn:hover { background: #000; box-shadow: none; }
  /* .ghost y .danger PISAN el fondo solido de .btn de arriba a proposito:
     sin este "background: transparent" se quedaban con el fondo negro de
     .btn pero el texto oscuro (o rojo) de su propia variante -- texto
     invisible o casi, la caja parecia un boton roto en vez de uno "outline". */
  .subdash .btn.ghost { background: transparent; color: var(--sd-text); border-color: var(--sd-border-strong); }
  .subdash .btn.ghost:hover { border-color: var(--sd-accent); color: var(--sd-accent); background: var(--sd-accent-soft); }
  .subdash .btn.danger { background: transparent; color: var(--sd-danger); border-color: var(--sd-danger-soft); }
  .subdash .btn.danger:hover { background: var(--sd-danger-soft); }
  .subdash .btn[disabled] { opacity: 0.4; }
  /* Enlaces sueltos (no .btn): sin esto heredaban el verde del tema oscuro
     de layout.php (regla global "a { color: var(--accent) }"), que desentona
     dentro de una pagina ya re-skinada en claro con acento indigo. */
  .subdash a { color: var(--sd-accent); }
  .subdash a:hover { color: #4747c2; }
  .subdash .pill { background: var(--sd-accent-soft); color: var(--sd-accent); border-color: transparent; }
  .subdash .pill.on { background: var(--sd-green-soft); color: var(--sd-green); }
  .subdash .pill.off { background: var(--sd-border); color: var(--sd-faint); }
  .subdash .pill.warn { background: var(--sd-warn-soft); color: var(--sd-warn); }
  .subdash .pill.danger { background: var(--sd-danger-soft); color: var(--sd-danger); }
  .subdash .hint, .subdash .muted, .subdash .empty { color: var(--sd-muted); }
  .subdash .faint { color: var(--sd-faint); }
  .subdash .chart { border-bottom: 1px solid var(--sd-border); }
  .subdash .chart .bar-v { background: var(--sd-accent); border-radius: 3px 3px 0 0; }
  .subdash .chart .bar-v:hover { background: #4747c2; filter: none; }
  .subdash .chart .tick, .subdash .chart .val { color: var(--sd-faint); }
  .subdash .bar-wrap { background: var(--sd-border); }
  .subdash .bar { background: var(--sd-accent); }
  .subdash .bar.green { background: var(--sd-green); }
  .subdash .bar.violet { background: var(--sd-accent); }
  .subdash .barline .lab span:first-child { color: var(--sd-text); }
  .subdash .barline .lab span:last-child { color: var(--sd-faint); }
  .subdash .scroll-x { background: var(--sd-surface); border-color: var(--sd-border); }
  .subdash .flash.ok { background: var(--sd-green-soft); color: var(--sd-green); border-color: transparent; }
  .subdash .flash.err { background: var(--sd-danger-soft); color: var(--sd-danger); border-color: transparent; }
  .subdash .flash.warn { background: var(--sd-warn-soft); color: var(--sd-warn); border-color: transparent; }
  .subdash .tabs a { color: var(--sd-muted); border-color: var(--sd-border-strong); }
  .subdash .tabs a.active { background: var(--sd-accent-soft); color: var(--sd-accent); border-color: transparent; }
  .subdash .tabs a:hover { color: var(--sd-text); border-color: var(--sd-faint); }
  .subdash .checkline strong { color: var(--sd-text); }
  .subdash label { color: var(--sd-text); }
  .subdash input[type=text], .subdash input[type=email], .subdash input[type=password],
  .subdash input[type=url], .subdash input[type=number], .subdash input[type=date],
  .subdash input[type=search], .subdash textarea, .subdash select {
    background: var(--sd-surface); border: 1px solid var(--sd-border-strong); color: var(--sd-text);
  }
  .subdash input:focus, .subdash textarea:focus, .subdash select:focus {
    border-color: var(--sd-accent); background: var(--sd-surface);
    box-shadow: 0 0 0 3px var(--sd-accent-soft);
  }
  .subdash .health-item { background: var(--sd-surface); border-color: var(--sd-border); }
  .subdash .health-dot { background: var(--sd-faint); box-shadow: 0 0 0 3px var(--sd-border); }
  .subdash .health-dot.ok { background: var(--sd-green); box-shadow: 0 0 0 3px var(--sd-green-soft); }
  .subdash .health-dot.warn { background: var(--sd-warn); box-shadow: 0 0 0 3px var(--sd-warn-soft); }
  .subdash .health-dot.danger { background: var(--sd-danger); box-shadow: 0 0 0 3px var(--sd-danger-soft); }
  .subdash .health-val { color: var(--sd-text); }
  .subdash .health-lbl { color: var(--sd-faint); }
  .subdash .timeline-item { border-color: var(--sd-border); }
  .subdash .timeline-dot { background: var(--sd-faint); }
  .subdash .timeline-dot.green { background: var(--sd-green); }
  .subdash .timeline-dot.cyan,
  .subdash .timeline-dot.violet { background: var(--sd-accent); }
  .subdash .timeline-dot.danger { background: var(--sd-danger); }
  .subdash .spark i { background: var(--sd-accent); }
  .subdash .spark.cyan i,
  .subdash .spark.violet i { background: var(--sd-accent); }
  .subdash .spark.warn i { background: var(--sd-warn); }
  .subdash .h2-icon svg { color: var(--sd-accent); opacity: 1; }
  .subdash .card.inset { background: var(--sd-bg); }
  .subdash .soft-box { background: var(--sd-bg); }
</style>
</head>
<body>
<div class="admin-layout">
  <div id="sidebar-overlay" class="sidebar-overlay"></div>
  
  <aside id="admin-sidebar" class="sidebar">
    <div class="sidebar-header">
      <div class="brand-block">
        <a href="index.php" class="brand">&gt;_ <span>admin</span></a>
        <?php if ($appsList): ?>
          <details class="app-switcher">
            <summary>
              <span class="app-switcher-current"><?= e($currentAppName ?? 'Todas las apps') ?></span>
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 9l6 6 6-6" /></svg>
            </summary>
            <div class="app-switcher-menu">
              <a href="analytics.php" class="<?= $currentAppSlug === '' ? 'active' : '' ?>">Todas las apps</a>
              <?php foreach ($appsList as $ap): ?>
                <a href="analytics.php?app=<?= e(rawurlencode($ap['slug'])) ?>"
                   class="<?= $currentAppSlug === $ap['slug'] ? 'active' : '' ?>"><?= e($ap['display_name']) ?></a>
              <?php endforeach; ?>
              <a href="apps.php" class="app-switcher-manage">Gestionar apps &rarr;</a>
            </div>
          </details>
        <?php endif; ?>
      </div>
      <button id="sidebar-close-btn" class="sidebar-toggle-btn mobile-only" aria-label="Cerrar menu">
        <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
      </button>
    </div>
    
    <nav class="sidebar-menu">
      <?php foreach ($navGroups as $groupLabel => $items): ?>
        <?php if ($groupLabel !== ''): ?>
          <p class="nav-group-label"><?= e($groupLabel) ?></p>
        <?php endif; ?>
        <?php foreach ($items as $file => [$label, $badge, $icon, $badgeType]): ?>
          <a href="<?= e($file) ?>" class="menu-item <?= $active === $file ? 'active' : '' ?>">
            <span class="menu-icon"><?= $icon ?></span>
            <span class="menu-label"><?= e($label) ?></span>
            <?php if ($badge !== ''): ?>
              <span class="badge-<?= $badgeType === 'alert' ? 'count' : 'muted' ?>"><?= e($badge) ?></span>
            <?php endif; ?>
          </a>
        <?php endforeach; ?>
      <?php endforeach; ?>
    </nav>
    
    <div class="sidebar-footer">
      <div class="user-info">
        <div class="avatar"><?= e(strtoupper(substr($user, 0, 2))) ?></div>
        <div class="details">
          <span class="username"><?= e($user) ?></span>
          <span class="role">Administrador</span>
        </div>
      </div>
      <div class="sidebar-actions">
        <?php /* Absoluta a proposito (docs/designs/admin-dashboard.md): en
                admin.eduolihez.com, un href="/" relativo llevaria al propio
                panel (el Worker de enrutado lo reescribe hacia /admin/),
                no al portfolio publico. */ ?>
        <a href="https://eduolihez.com/" target="_blank" rel="noopener" class="action-btn">
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
          Ver web
        </a>
        <form method="post" action="logout.php" style="display:inline; width:100%;">
          <?= csrf_field() ?>
          <button type="submit" class="action-btn danger-text">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
            Cerrar sesion
          </button>
        </form>
      </div>
    </div>
  </aside>
  
  <div class="main-content-wrapper">
    <header class="topbar">
      <div class="topbar-left">
        <button id="sidebar-open-btn" class="sidebar-toggle-btn mobile-only" aria-label="Abrir menu">
          <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" /></svg>
        </button>
        <span class="topbar-title"><?= e($title) ?></span>
      </div>
      <div class="topbar-right">
        <span class="user-greeting">Consola de Control</span>
      </div>
    </header>
    <main>
<?php
}

function admin_footer(): void
{
    ?>
    </main>
  </div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', () => {
    const openBtn = document.getElementById('sidebar-open-btn');
    const closeBtn = document.getElementById('sidebar-close-btn');
    const overlay = document.getElementById('sidebar-overlay');
    const sidebar = document.getElementById('admin-sidebar');

    const toggleSidebar = (state) => {
      if (sidebar && overlay) {
        sidebar.classList.toggle('open', state);
        overlay.classList.toggle('open', state);
        document.body.style.overflow = state ? 'hidden' : '';
      }
    };

    if (openBtn) openBtn.addEventListener('click', () => toggleSidebar(true));
    if (closeBtn) closeBtn.addEventListener('click', () => toggleSidebar(false));
    if (overlay) overlay.addEventListener('click', () => toggleSidebar(false));
  });
</script>
<script src="assets/admin.js"></script>
</body>
</html>
<?php
}

// ---------------------------------------------------------------------------
// Mensajes flash
// ---------------------------------------------------------------------------

/** Guarda un mensaje flash en sesion para mostrarlo tras un redirect. */
function set_flash(string $type, string $msg): void
{
    $_SESSION['flash'] = ['type' => $type, 'msg' => $msg];
}

/** Imprime y limpia el mensaje flash si existe. */
function show_flash(): void
{
    if (empty($_SESSION['flash'])) {
        return;
    }
    $f = $_SESSION['flash'];
    unset($_SESSION['flash']);
    $cls = in_array($f['type'], ['ok', 'warn'], true) ? $f['type'] : 'err';
    echo '<div class="flash ' . $cls . '">' . e($f['msg']) . '</div>';
}

// ---------------------------------------------------------------------------
// Helpers de presentacion
// ---------------------------------------------------------------------------

/** Tarjeta de estadistica. $color: '' | cyan | warn | violet | danger */
function stat_card(string $value, string $label, string $color = '', string $sub = ''): void
{
    echo '<div class="card stat">'
        . '<div class="num ' . e($color) . '">' . e($value) . '</div>'
        . '<div class="lbl">' . $label
        . ($sub !== '' ? '<br><span class="faint">' . e($sub) . '</span>' : '')
        . '</div></div>';
}

/** Etiqueta de variacion porcentual respecto al periodo anterior. */
function delta_badge(int $now, int $before): string
{
    if ($before === 0) {
        return $now > 0 ? '<span class="delta up">nuevo</span>' : '';
    }
    $pct = round((($now - $before) / $before) * 100);
    $cls = $pct > 0 ? 'up' : ($pct < 0 ? 'down' : 'flat');
    $sig = $pct > 0 ? '+' : '';
    return '<span class="delta ' . $cls . '">' . $sig . $pct . '%</span>';
}

/** Titulo de seccion con icono SVG delante (mismo tamano que h2). */
function h2_icon(string $svg, string $text): void
{
    echo '<h2 class="h2-icon">' . $svg . '<span>' . e($text) . '</span></h2>';
}

/**
 * Mini grafico de tendencia para embeber dentro de una stat card.
 * $color: '' (verde) | cyan | violet | warn.
 */
function sparkline(array $values, string $color = ''): string
{
    if (!$values) {
        return '';
    }
    $max = max(1, max($values));
    $bars = '';
    foreach ($values as $v) {
        $h = max(2, (int) round(((float) $v / $max) * 26));
        $bars .= '<i style="height:' . $h . 'px" title="' . (int) $v . '"></i>';
    }
    return '<div class="spark ' . e($color) . '">' . $bars . '</div>';
}

/** Casilla de estado para rejillas de salud/seguridad. $state: ok|warn|danger|neutral. */
function status_tile(string $label, string $value, string $state = 'neutral'): void
{
    echo '<div class="health-item">'
        . '<span class="health-dot ' . e($state) . '"></span>'
        . '<div class="health-body"><div class="health-val">' . e($value) . '</div>'
        . '<div class="health-lbl">' . e($label) . '</div></div>'
        . '</div>';
}

/** Fila de barra horizontal con etiqueta y valor. */
function bar_row(string $label, int $value, int $max, string $color = '', string $suffix = ''): void
{
    $pct = $max > 0 ? max(1, (int) round(($value / $max) * 100)) : 0;
    echo '<div class="barline">'
        . '<div class="lab"><span>' . e($label) . '</span>'
        . '<span>' . number_format($value) . ($suffix !== '' ? ' · ' . e($suffix) : '') . '</span></div>'
        . '<div class="bar-wrap"><div class="bar ' . e($color) . '" style="width:' . $pct . '%"></div></div>'
        . '</div>';
}

/** Fecha corta legible a partir de un DATETIME de MySQL. */
function fdate(?string $sqlDate, string $format = 'd/m/Y H:i'): string
{
    if (!$sqlDate) {
        return '—';
    }
    $ts = strtotime($sqlDate);
    return $ts ? date($format, $ts) : '—';
}

/** "hace 5 min", "hace 2 h", "hace 3 d"... a partir de un DATETIME. */
function ago(?string $sqlDate): string
{
    if (!$sqlDate) {
        return '—';
    }
    $ts = strtotime($sqlDate);
    if (!$ts) {
        return '—';
    }
    $diff = max(0, time() - $ts);
    if ($diff < 60)     return 'hace ' . $diff . ' s';
    if ($diff < 3600)   return 'hace ' . floor($diff / 60) . ' min';
    if ($diff < 86400)  return 'hace ' . floor($diff / 3600) . ' h';
    if ($diff < 2592000) return 'hace ' . floor($diff / 86400) . ' d';
    return date('d/m/Y', $ts);
}

/** Tamano legible a partir de bytes. */
function fbytes(float $bytes): string
{
    $units = ['B', 'KB', 'MB', 'GB'];
    $i = 0;
    while ($bytes >= 1024 && $i < count($units) - 1) {
        $bytes /= 1024;
        $i++;
    }
    return round($bytes, $i === 0 ? 0 : 1) . ' ' . $units[$i];
}

// ---------------------------------------------------------------------------
// Exportacion CSV segura
// ---------------------------------------------------------------------------

/**
 * Neutraliza la INYECCION DE FORMULAS en CSV.
 *
 * Excel y LibreOffice ejecutan como formula cualquier celda que empiece por
 * = + - @ (o tab / retorno de carro). Un mensaje de contacto con
 * `=HYPERLINK("http://malo","click")` -o algo peor- se ejecutaria al abrir
 * el CSV exportado. Le anteponemos un apostrofe para que se trate como texto.
 */
function csv_safe($value): string
{
    $v = (string) $value;
    if ($v !== '' && strpbrk($v[0], "=+-@\t\r") !== false) {
        return "'" . $v;
    }
    return $v;
}

/**
 * Envia un CSV como descarga y termina la ejecucion.
 * @param array<int,string>       $headers Cabecera de columnas
 * @param iterable<int,array>     $rows    Filas (arrays de valores)
 */
function csv_download(string $filename, array $headers, iterable $rows): void
{
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('X-Content-Type-Options: nosniff');

    $out = fopen('php://output', 'w');
    fwrite($out, "\xEF\xBB\xBF"); // BOM UTF-8 para que Excel lea bien los acentos
    fputcsv($out, $headers);
    foreach ($rows as $row) {
        fputcsv($out, array_map('csv_safe', $row));
    }
    fclose($out);
    exit;
}
