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

require_once __DIR__ . '/spaces.php';
require_once __DIR__ . '/icons.php';

/**
 * Deja constancia en el log del servidor de un fallo que el panel tolera (tabla
 * ausente, consulta fallida) para que no quede invisible. Solo va al log: el
 * mensaje no se muestra al usuario.
 */
function admin_log_error(string $where, Throwable $e): void
{
    error_log('[admin] ' . $where . ': ' . get_class($e) . ': ' . $e->getMessage());
}

/**
 * Contexto de espacio de la peticion actual: ['space' => id, 'apps' => filas
 * slug/display_name]. UNICO sitio donde se resuelve el espacio (lo usan
 * admin_header y admin_space). Memoizado; la tabla `apps` puede no existir
 * todavia (migracion sin correr) -> [] sin tumbar el panel.
 */
function admin_space_context(): array
{
    static $ctx = null;
    if ($ctx !== null) {
        return $ctx;
    }
    try {
        $apps = db()->query('SELECT slug, display_name FROM apps ORDER BY created_at ASC')->fetchAll();
    } catch (Throwable $e) {
        admin_log_error('admin_space_context (tabla apps)', $e);
        $apps = [];
    }
    $slugs = array_map(static fn(array $a): string => (string) $a['slug'], $apps);
    $page  = basename((string) ($_SERVER['SCRIPT_NAME'] ?? ''));
    $ctx = [
        'space' => resolve_space($_GET, $_SESSION ?? [], $slugs, $page),
        'apps'  => $apps,
    ];
    return $ctx;
}

/** Espacio activo de la peticion actual (valido antes y despues de admin_header). */
function admin_space(): string
{
    return admin_space_context()['space'];
}

/** Slug de `apps` del espacio activo, o null en Global. */
function admin_app_slug(): ?string
{
    return space_app_slug(admin_space());
}

function admin_header(string $title, string $active = ''): void
{
    $user = function_exists('current_admin') ? current_admin() : '';

    $ctx      = admin_space_context();
    $space    = $ctx['space'];
    $appsRows = $ctx['apps'];
    if (($_SESSION['admin_space'] ?? null) !== $space) {
        $_SESSION['admin_space'] = $space;
    }

    // Contadores para los "badges" del menu. Cada uno tolera que falte la
    // tabla (BD recien creada, migracion a medias) devolviendo 0 en vez de
    // tumbar el panel entero, y solo se piden los del espacio visible.
    $countSafe = static function (string $sql): int {
        try {
            return (int) db()->query($sql)->fetchColumn();
        } catch (Throwable $e) {
            admin_log_error('contador del menu', $e);
            return 0;
        }
    };
    $counts = [];
    if ($space === SPACE_GLOBAL) {
        $counts['unread'] = $countSafe('SELECT COUNT(*) FROM messages WHERE is_read = 0 AND is_archived = 0');
        $counts['apps']   = $countSafe('SELECT COUNT(*) FROM apps');
    } elseif ($space === SPACE_SITE) {
        $counts['unread']   = $countSafe('SELECT COUNT(*) FROM messages WHERE is_read = 0 AND is_archived = 0');
        $counts['projects'] = $countSafe("SELECT COUNT(*) FROM projects WHERE status = 'published'");
        $counts['certs']    = $countSafe('SELECT COUNT(*) FROM certifications WHERE visible = 1');
        $counts['posts']    = $countSafe('SELECT COUNT(*) FROM posts WHERE visible = 1');
    } elseif ($space === SPACE_PHISHLAB) {
        $counts['lab_users'] = $countSafe('SELECT COUNT(*) FROM lab_users');
    }

    $navGroups    = space_nav($space, $counts);
    $spaceOptions = space_options($appsRows);
    $spaceLabel   = $space;
    foreach ($spaceOptions as $opt) {
        if ($opt['id'] === $space) {
            $spaceLabel = $opt['label'];
            break;
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
<?php /* Sincrono y antes del CSS: fija data-theme sin destello (CSP: script-src 'self'). */ ?>
<script src="<?= e(asset_url('theme.js')) ?>"></script>
<link rel="stylesheet" href="<?= e(asset_url('admin.css')) ?>">
</head>
<body>
<div class="admin-layout">
  <div id="sidebar-overlay" class="sidebar-overlay"></div>
  
  <aside id="admin-sidebar" class="sidebar">
    <div class="sidebar-header">
      <div class="brand-block">
        <a href="index.php?space=global" class="brand">&gt;_ <span>admin</span></a>
        <details class="app-switcher">
          <summary>
            <span class="app-switcher-current"><?= e($spaceLabel) ?></span>
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 9l6 6 6-6" /></svg>
          </summary>
          <div class="app-switcher-menu">
            <?php foreach ($spaceOptions as $opt): ?>
              <a href="<?= e(space_home($opt['id'])) ?>"
                 class="<?= $opt['id'] === $space ? 'active' : '' ?>"><?= e($opt['label']) ?></a>
            <?php endforeach; ?>
          </div>
        </details>
      </div>
      <button id="sidebar-close-btn" class="sidebar-toggle-btn mobile-only" aria-label="Cerrar menu">
        <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
      </button>
    </div>
    
    <nav class="sidebar-menu">
      <?php foreach ($navGroups as $group): ?>
        <?php if ($group['label'] !== ''): ?>
          <p class="nav-group-label"><?= e($group['label']) ?></p>
        <?php endif; ?>
        <?php foreach ($group['items'] as $item): ?>
          <a href="<?= e($item['href']) ?>" class="menu-item <?= $active === $item['page'] ? 'active' : '' ?>">
            <span class="menu-icon"><?= nav_icon($item['icon']) ?></span>
            <span class="menu-label"><?= e($item['label']) ?></span>
            <?php if ($item['badge'] !== ''): ?>
              <span class="badge-<?= $item['badge_type'] === 'alert' ? 'count' : 'muted' ?>"><?= e($item['badge']) ?></span>
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
        <button type="button" id="theme-toggle" class="action-btn" aria-label="Cambiar tema" aria-pressed="false">
          <svg class="icon-moon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.8z" /></svg>
          <svg class="icon-sun" xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="4" /><path stroke-linecap="round" stroke-linejoin="round" d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4l1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></svg>
          Cambiar tema
        </button>
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

<script src="<?= e(asset_url('admin.js')) ?>"></script>
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

/**
 * Cabecera comun de pagina: titulo, descripcion opcional y acciones a la derecha.
 * $title, $description y $titleMeta se escapan; $actionsHtml es HTML de confianza
 * generado por el llamador (botones, formularios con csrf_field(), etc.).
 * $titleMeta: texto atenuado junto al titulo, p. ej. "(3 visibles de 5)".
 */
function page_header(string $title, string $description = '', string $actionsHtml = '', string $titleMeta = ''): void
{
    echo '<div class="page-header"><div class="page-header-text"><h1>' . e($title)
        . ($titleMeta !== '' ? ' <span class="faint page-title-meta">' . e($titleMeta) . '</span>' : '')
        . '</h1>'
        . ($description !== '' ? '<p class="hint">' . e($description) . '</p>' : '')
        . '</div>'
        . ($actionsHtml !== '' ? '<div class="page-actions">' . $actionsHtml . '</div>' : '')
        . '</div>';
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
