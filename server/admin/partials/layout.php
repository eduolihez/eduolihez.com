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

/**
 * URL relativa de un asset del panel con cache-busting por fecha de
 * modificacion (?v=<filemtime>). Si el archivo no existe, devuelve la URL
 * sin version para no romper la pagina.
 */
function asset_url(string $file): string
{
    $path = __DIR__ . '/../assets/' . $file;
    if (!is_file($path)) {
        return 'assets/' . $file;
    }
    return 'assets/' . $file . '?v=' . filemtime($path);
}

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
        $appsList = db()->query('SELECT slug, display_name, has_content FROM apps ORDER BY created_at ASC')->fetchAll();
    } catch (Throwable $e) {
        $appsList = [];
    }
    $currentAppSlug = (string) ($_GET['app'] ?? '');
    $currentAppName = null;
    $currentAppHasContent = null; // null = ningun app concreto seleccionado ("todas las apps")
    foreach ($appsList as $ap) {
        if ($ap['slug'] === $currentAppSlug) {
            $currentAppName = $ap['display_name'];
            $currentAppHasContent = (bool) $ap['has_content'];
            break;
        }
    }
    // Selector de sitios (2026-09-08): secciones de contenido propio
    // (Proyectos/Certificaciones/Blog/Mensajes) solo tienen sentido para una
    // app que de verdad los gestiona -- eduolihez.com si, nowait (sitio
    // estatico sin CMS) no. "Todas las apps" (sin selecionar ninguna) se
    // trata como el contexto por defecto de siempre, para no cambiar el
    // comportamiento de nadie que no haya tocado el selector todavia.
    $showContentNav = $currentAppSlug === '' || $currentAppHasContent === true;
    $contentOnlyPages = ['projects.php', 'certifications.php', 'posts.php', 'messages.php'];
    // Query string que mantiene viva la app seleccionada al navegar por el
    // menu -- sin esto, cada clic del sidebar perdia el ?app= y volvia
    // silenciosamente a la vista "todas las apps" en la pagina siguiente.
    $appQs = $currentAppSlug !== '' ? '?app=' . rawurlencode($currentAppSlug) : '';

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
        // Antes "Multi-proyecto": colisionaba con "Proyectos" de arriba
        // (tarjetas del portfolio, tabla `projects`) aunque hablan de cosas
        // distintas -- este grupo es sobre `apps` (sitios con su propio
        // sub-dashboard en admin.eduolihez.com). Ver tambien el comentario
        // en database/schema.sql sobre esta misma confusion de nombres.
        'Apps' => [
            // admin.eduolihez.com (docs/designs/admin-dashboard.md): registro
            // de apps con su propio sub-dashboard y clave de ingesta.
            'apps.php' => ['Gestionar apps', (string) $countSafe('SELECT COUNT(*) FROM apps'), '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>', 'count'],
            // Cuentas de lab.eduolihez.com (PhishLab completo) -- gate propio
            // en PHP, ver server/lab/auth.php. Vive aparte de admin_users.
            // Etiqueta acortada de "PhishLab · Usuarios": con el nombre largo
            // partia en dos lineas a los 260px del sidebar. El icono de
            // persona + el contador ya dejan claro que es la lista de accesos.
            'lab-users.php' => ['PhishLab', (string) $countSafe('SELECT COUNT(*) FROM lab_users'), '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>', 'count'],
        ],
        'Sistema' => [
            'integrations.php' => ['Integraciones', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.828 10.172a4 4 0 010 5.656l-3 3a4 4 0 01-5.656-5.656l1.5-1.5M10.172 13.828a4 4 0 010-5.656l3-3a4 4 0 015.656 5.656l-1.5 1.5" /></svg>', 'count'],
            'security.php' => ['Seguridad', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>', 'count'],
            'settings.php' => ['Ajustes', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>', 'count'],
            'backup.php'   => ['Backup', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" /></svg>', 'count'],
        ],
    ];

    // Oculta las secciones de contenido propio (Proyectos/Certificaciones/
    // Blog/Mensajes) cuando la app seleccionada no las gestiona (ver
    // $showContentNav mas arriba). Si un grupo se queda sin items despues de
    // filtrar, se quita entero para no imprimir una cabecera vacia.
    if (!$showContentNav) {
        foreach ($navGroups as $groupLabel => $items) {
            foreach ($contentOnlyPages as $page) {
                unset($navGroups[$groupLabel][$page]);
            }
            if (!$navGroups[$groupLabel]) {
                unset($navGroups[$groupLabel]);
            }
        }
    }
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
<link rel="stylesheet" href="<?= e(asset_url('admin.css')) ?>">
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
              <a href="index.php" class="<?= $currentAppSlug === '' ? 'active' : '' ?>">Selector de sitios</a>
              <?php foreach ($appsList as $ap): ?>
                <a href="index.php?app=<?= e(rawurlencode($ap['slug'])) ?>"
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
          <a href="<?= e($file . $appQs) ?>" class="menu-item <?= $active === $file ? 'active' : '' ?>">
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
