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

    // Contadores para los "badges" del menu.
    $unread = 0;
    try {
        $unread = (int) db()->query(
            'SELECT COUNT(*) FROM messages WHERE is_read = 0 AND is_archived = 0'
        )->fetchColumn();
    } catch (Throwable $e) {
        // ignora si la tabla o las columnas nuevas aun no existen
    }

    $nav = [
        'index.php'          => ['Panel', ''],
        'projects.php'       => ['Proyectos', ''],
        'certifications.php' => ['Certificaciones', ''],
        'messages.php'       => ['Mensajes', $unread > 0 ? (string) $unread : ''],
        'analytics.php'      => ['Analitica', ''],
        'security.php'       => ['Seguridad', ''],
        'settings.php'       => ['Ajustes', ''],
        'backup.php'         => ['Backup', ''],
    ];
    ?>
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title><?= e($title) ?> · Admin</title>
<style>
  :root {
    --bg: #080c10; --soft: #0e141f; --card: #131a26; --border: #202b3d;
    --text: #f0f3f6; --muted: #a0aec0; --faint: #6b7c96;
    --accent: #4ade80; --accent-hover: #22c55e; --danger: #f87171;
    --cyan: #22d3ee; --warn: #fbbf24; --violet: #a78bfa;
    --shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.35), 0 2px 8px -1px rgba(0, 0, 0, 0.2);
    --shadow-sm: 0 2px 8px rgba(0, 0, 0, 0.2);
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 14px; line-height: 1.6;
    -webkit-font-smoothing: antialiased;
    text-rendering: optimizeLegibility;
  }
  a { color: var(--accent); text-decoration: none; transition: color 0.2s ease; }
  a:hover { color: var(--accent-hover); text-decoration: none; }
  header.topbar {
    position: sticky; top: 0; z-index: 10;
    display: flex; align-items: center; justify-content: space-between;
    gap: 1rem; padding: 0.85rem 1.5rem;
    background: rgba(8, 12, 16, 0.9); backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border);
    box-shadow: 0 1px 10px rgba(0, 0, 0, 0.15);
  }
  .brand { font-family: ui-monospace, "JetBrains Mono", monospace; font-weight: 700; letter-spacing: -0.02em; font-size: 1.1rem; }
  .brand span { color: var(--accent); }
  nav.menu { display: flex; flex-wrap: wrap; gap: .35rem; }
  nav.menu a {
    color: var(--muted); padding: .45rem .8rem; border-radius: .375rem;
    font-size: .85rem; font-weight: 500; text-decoration: none; white-space: nowrap;
    transition: all 0.2s ease;
    border: 1px solid transparent;
  }
  nav.menu a:hover { background: var(--soft); color: var(--text); }
  nav.menu a.active { background: rgba(74,222,128,0.08); color: var(--accent); border-color: rgba(74,222,128,0.25); }
  .badge-count {
    display: inline-block; min-width: 18px; text-align: center;
    background: var(--accent); color: var(--bg); font-size: .68rem; font-weight: 800;
    border-radius: 999px; padding: 0.05rem .35rem; margin-left: .35rem;
  }
  .userbox { color: var(--faint); font-size: .82rem; display: flex; align-items: center; gap: .75rem; }
  .userbox a { color: var(--muted); font-weight: 500; }
  .userbox a:hover { color: var(--text); }
  .linkbtn {
    background: none; border: none; padding: 0; margin: 0; cursor: pointer;
    color: var(--muted); font: inherit; font-size: .82rem; text-decoration: none;
    transition: color 0.2s;
  }
  .linkbtn:hover { color: var(--danger); text-decoration: underline; }
  main { max-width: 1200px; margin: 0 auto; padding: 2rem 1.5rem 5rem; }
  h1 { font-size: 1.6rem; font-weight: 700; margin: .2rem 0 1.5rem; letter-spacing: -0.02em; }
  h2 { font-size: 1.15rem; font-weight: 600; margin: 2rem 0 1rem; letter-spacing: -0.01em; color: var(--text); }
  h3 { font-size: .9rem; font-weight: 600; margin: 0 0 .75rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
  .card {
    background: var(--card); border: 1px solid var(--border);
    border-radius: .75rem; padding: 1.5rem; margin-bottom: 1.5rem;
    box-shadow: var(--shadow);
  }
  .grid { display: grid; gap: 1.25rem; grid-template-columns: repeat(auto-fit, minmax(210px,1fr)); }
  .grid4 { display: grid; gap: 1.25rem; grid-template-columns: repeat(auto-fit, minmax(180px,1fr)); }
  .stat { transition: transform 0.2s ease, border-color 0.2s ease; }
  .stat:hover { border-color: rgba(255,255,255,0.08); transform: translateY(-2px); }
  .stat .num { font-family: ui-monospace, "JetBrains Mono", monospace; font-size: 2.2rem; font-weight: 700; color: var(--accent); line-height: 1; letter-spacing: -0.03em; }
  .stat .num.cyan { color: var(--cyan); }
  .stat .num.warn { color: var(--warn); }
  .stat .num.violet { color: var(--violet); }
  .stat .num.danger { color: var(--danger); }
  .stat .lbl { color: var(--muted); font-size: .8rem; margin-top: .6rem; font-weight: 500; line-height: 1.4; }
  .delta { font-size: .75rem; font-weight: 700; margin-left: .5rem; padding: 0.1rem 0.35rem; border-radius: 4px; background: rgba(255,255,255,0.05); }
  .delta.up { color: var(--accent); background: rgba(74,222,128,0.1); }
  .delta.down { color: var(--danger); background: rgba(248,113,113,0.1); }
  .delta.flat { color: var(--faint); }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: .85rem .75rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
  th { color: var(--faint); font-weight: 700; font-size: .75rem; text-transform: uppercase; letter-spacing: .08em; }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: rgba(255, 255, 255, 0.01); }
  .muted { color: var(--muted); }
  .faint { color: var(--faint); font-size: .8rem; }
  .mono { font-family: ui-monospace, "JetBrains Mono", monospace; }
  .pill { display: inline-block; padding: .15rem .6rem; border-radius: .375rem; font-size: .72rem; font-weight: 600; border: 1px solid var(--border); background: var(--soft); color: var(--muted); }
  .pill.on { color: var(--accent); border-color: rgba(74,222,128,.25); background: rgba(74,222,128,.05); }
  .pill.off { color: var(--faint); background: rgba(255, 255, 255, 0.02); }
  .pill.warn { color: var(--warn); border-color: rgba(251,191,36,.25); background: rgba(251,191,36,.05); }
  .pill.danger { color: var(--danger); border-color: rgba(248,113,113,.25); background: rgba(248,113,113,.05); }
  label { display: block; margin: 1.2rem 0 .4rem; font-weight: 600; font-size: .85rem; color: var(--text); }
  input[type=text], input[type=email], input[type=password], input[type=url],
  input[type=number], input[type=date], input[type=search], textarea, select {
    width: 100%; padding: .65rem .85rem; background: var(--bg);
    border: 1px solid var(--border); border-radius: .5rem; color: var(--text);
    font-size: .92rem; font-family: inherit; transition: all 0.2s ease-in-out;
  }
  input:focus, textarea:focus, select:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(74,222,128,0.15); }
  textarea { resize: vertical; min-height: 100px; }
  .row2 { display: grid; gap: 1.25rem; grid-template-columns: 1fr 1fr; }
  .row3 { display: grid; gap: 1.25rem; grid-template-columns: repeat(3, 1fr); }
  @media (max-width: 760px){ .row2, .row3 { grid-template-columns: 1fr; } }
  .btn {
    display: inline-flex; align-items: center; justify-content: center; gap: .45rem; cursor: pointer;
    padding: .6rem 1.1rem; border-radius: .5rem; font-weight: 600; font-size: .88rem;
    border: 1px solid transparent; background: var(--accent); color: var(--bg);
    transition: all 0.2s ease;
  }
  .btn:hover { background: var(--accent-hover); text-decoration: none; box-shadow: var(--shadow-sm); }
  .btn.ghost { background: transparent; color: var(--text); border-color: var(--border); }
  .btn.ghost:hover { border-color: var(--accent); color: var(--accent); background: rgba(74,222,128,0.02); }
  .btn.danger { background: transparent; color: var(--danger); border-color: rgba(248,113,113,.35); }
  .btn.danger:hover { background: rgba(248,113,113,.08); }
  .btn.sm { padding: .35rem .75rem; font-size: .78rem; border-radius: .375rem; }
  .btn.icon { padding: .35rem .55rem; font-size: .85rem; line-height: 1; border-radius: .375rem; }
  .btn[disabled] { opacity: .3; pointer-events: none; }
  .actions { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; }
  .flash { padding: .85rem 1.25rem; border-radius: .5rem; margin-bottom: 1.5rem; font-size: .88rem; font-weight: 500; }
  .flash.ok { background: rgba(74,222,128,.08); color: var(--accent); border: 1px solid rgba(74,222,128,.2); }
  .flash.err { background: rgba(248,113,113,.08); color: var(--danger); border: 1px solid rgba(248,113,113,.2); }
  .flash.warn { background: rgba(251,191,36,.06); color: var(--warn); border: 1px solid rgba(251,191,36,.2); }
  .toolbar { display: flex; align-items: center; justify-content: space-between; gap: 1.25rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
  .hint { color: var(--faint); font-size: .78rem; margin-top: .3rem; line-height: 1.4; }
  .bar-wrap { height: 6px; background: var(--soft); border-radius: 4px; overflow: hidden; margin-top: .4rem; }
  .bar { height: 100%; background: var(--cyan); border-radius: 4px; }
  .bar.green { background: var(--accent); }
  .bar.violet { background: var(--violet); }
  .barline { margin-bottom: .85rem; }
  .barline .lab { display: flex; justify-content: space-between; font-size: .82rem; gap: 1rem; }
  .barline .lab span:first-child { color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .barline .lab span:last-child { color: var(--faint); white-space: nowrap; font-family: ui-monospace, monospace; }
  .chart { display: flex; align-items: flex-end; gap: .35rem; height: 160px; overflow-x: auto; padding-bottom: .25rem; border-bottom: 1px solid var(--border); }
  .chart .col { flex: 1 0 14px; display: flex; flex-direction: column; align-items: center; gap: .35rem; min-width: 14px; }
  .chart .bar-v { width: 100%; background: var(--accent); border-radius: 4px 4px 0 0; min-height: 4px; transition: height 0.3s ease, background 0.3s ease; }
  .chart .bar-v:hover { background: var(--accent-hover); filter: brightness(1.2); cursor: pointer; }
  .chart .tick { color: var(--faint); font-size: .62rem; white-space: nowrap; margin-top: .2rem; }
  .chart .val { color: var(--faint); font-size: .68rem; font-family: ui-monospace, monospace; }
  .tabs { display: flex; gap: .35rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
  .tabs a { padding: .4rem .85rem; border-radius: .375rem; font-size: .82rem; font-weight: 500; color: var(--muted); border: 1px solid var(--border); transition: all 0.2s; }
  .tabs a.active { background: rgba(74,222,128,0.06); color: var(--accent); border-color: rgba(74,222,128,.25); }
  .tabs a:hover { text-decoration: none; color: var(--text); border-color: var(--muted); }
  .checkline { display: flex; align-items: flex-start; gap: .75rem; margin: 0 0 1.25rem; font-weight: 400; cursor: pointer; }
  .checkline input { width: auto; margin-top: .3rem; cursor: pointer; }
  .checkline strong { display: block; font-size: .9rem; color: var(--text); }
  .empty { padding: 2.5rem; color: var(--muted); text-align: center; font-style: italic; }
  .scroll-x { overflow-x: auto; border-radius: .5rem; border: 1px solid var(--border); background: var(--card); }
  .nowrap { white-space: nowrap; }
</style>
</head>
<body>
<header class="topbar">
  <div style="display:flex; align-items:center; gap:1.25rem; flex-wrap:wrap;">
    <span class="brand">&gt;_ <span>admin</span></span>
    <nav class="menu">
      <?php foreach ($nav as $file => [$label, $badge]): ?>
        <a href="<?= e($file) ?>" class="<?= $active === $file ? 'active' : '' ?>">
          <?= e($label) ?><?php if ($badge !== ''): ?><span class="badge-count"><?= e($badge) ?></span><?php endif; ?>
        </a>
      <?php endforeach; ?>
    </nav>
  </div>
  <div class="userbox">
    <span><?= e($user) ?></span> ·
    <a href="/" target="_blank" rel="noopener">Ver web</a> ·
    <!-- Logout por POST con token CSRF: un GET no puede cerrarte la sesion. -->
    <form method="post" action="logout.php" style="display:inline;">
      <?= csrf_field() ?>
      <button type="submit" class="linkbtn">Salir</button>
    </form>
  </div>
</header>
<main>
<?php
}

function admin_footer(): void
{
    ?>
</main>
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
