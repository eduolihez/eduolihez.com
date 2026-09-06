<?php
/**
 * index.php - Panel principal (dashboard).
 *
 * Vista de un vistazo:
 *   - Avisos de seguridad y configuracion (lo primero, porque importa).
 *   - KPIs de trafico con comparativa y tendencia de 14 dias por tarjeta.
 *   - Canales de trafico y dispositivos (ultimos 30 dias).
 *   - Contenido publicado y buzon, con frescura de cada tipo de contenido.
 *   - Accesos rapidos, actividad reciente (linea de tiempo) y salud del
 *     sistema (rejilla de estado en vez de tabla, para verlo de un vistazo).
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/ua.php';
require_login();

/** COUNT(*) tolerante a fallos (por si falta alguna tabla). */
function count_of(string $sql, array $params = []): int
{
    try {
        if (!$params) {
            return (int) db()->query($sql)->fetchColumn();
        }
        $st = db()->prepare($sql);
        $st->execute($params);
        return (int) $st->fetchColumn();
    } catch (Throwable $e) {
        return 0;
    }
}

/**
 * Como count_of(), pero distingue "0 confirmado" de "la consulta fallo": para
 * indicadores de seguridad (accesos fallidos) un fallo de BD nunca debe
 * pintarse como "todo ok" -- eso ocultaria justo el incidente que la casilla
 * existe para avisar, y suele coincidir con el propio ataque que satura la tabla.
 */
function count_or_null(string $sql, array $params = []): ?int
{
    try {
        if (!$params) {
            return (int) db()->query($sql)->fetchColumn();
        }
        $st = db()->prepare($sql);
        $st->execute($params);
        return (int) $st->fetchColumn();
    } catch (Throwable $e) {
        return null;
    }
}

/** SELECT tolerante a fallos que devuelve todas las filas. */
function rows_of(string $sql, array $params = []): array
{
    try {
        $st = db()->prepare($sql);
        $st->execute($params);
        return $st->fetchAll();
    } catch (Throwable $e) {
        return [];
    }
}

// Solo contamos visitas humanas (is_bot = 0) en los KPIs.
$HUMAN = 'is_bot = 0';

// --- Contenido ---------------------------------------------------------
$projects     = count_of('SELECT COUNT(*) FROM projects');
$published    = count_of("SELECT COUNT(*) FROM projects WHERE status='published'");
$drafts       = max(0, $projects - $published);
$certs        = count_of('SELECT COUNT(*) FROM certifications WHERE visible=1');
$certsTotal   = count_of('SELECT COUNT(*) FROM certifications');
$postsTotal   = count_of('SELECT COUNT(*) FROM posts');
$postsVisible = count_of('SELECT COUNT(*) FROM posts WHERE visible=1');
$postsDraft   = max(0, $postsTotal - $postsVisible);

// Frescura: ultimo elemento tocado de cada tipo de contenido.
$lastProject = rows_of('SELECT title_es AS t, updated_at AS d FROM projects ORDER BY updated_at DESC LIMIT 1')[0] ?? null;
$lastCert    = rows_of('SELECT name AS t, created_at AS d FROM certifications ORDER BY created_at DESC LIMIT 1')[0] ?? null;
$lastPost    = rows_of('SELECT title AS t, COALESCE(published_at, created_at) AS d FROM posts ORDER BY COALESCE(published_at, created_at) DESC LIMIT 1')[0] ?? null;

// --- Buzon ---------------------------------------------------------------
$unread    = count_of('SELECT COUNT(*) FROM messages WHERE is_read=0 AND is_archived=0');
$msgTotal  = count_of('SELECT COUNT(*) FROM messages');
$msgStarred = count_of('SELECT COUNT(*) FROM messages WHERE is_starred=1 AND is_archived=0');
$msgArchived = count_of('SELECT COUNT(*) FROM messages WHERE is_archived=1');
$msg30     = count_of('SELECT COUNT(*) FROM messages WHERE created_at > (NOW() - INTERVAL 30 DAY)');
$msgPrev30 = count_of(
    'SELECT COUNT(*) FROM messages
     WHERE created_at <= (NOW() - INTERVAL 30 DAY) AND created_at > (NOW() - INTERVAL 60 DAY)'
);

// Mensajes por semana (8 semanas) para la tendencia de la tarjeta de buzon.
// Se agrupa por DATE() (sin ambiguedad) y se suma en PHP en vez de cruzar
// YEARWEEK() de MySQL con el numero de semana ISO de PHP: son dos calculos
// independientes del mismo estandar que podrian discrepar en el cambio de ano.
$msgDailyRaw = rows_of(
    'SELECT DATE(created_at) AS d, COUNT(*) AS c FROM messages
     WHERE created_at > (NOW() - INTERVAL 8 WEEK) GROUP BY DATE(created_at)'
);
$byDayMsg = [];
foreach ($msgDailyRaw as $r) {
    $byDayMsg[$r['d']] = (int) $r['c'];
}
$msgSpark = [];
for ($i = 7; $i >= 0; $i--) {
    $weekStart = strtotime("-$i week", strtotime('monday this week'));
    $sum = 0;
    for ($d = 0; $d < 7; $d++) {
        $day = date('Y-m-d', strtotime("+$d day", $weekStart));
        $sum += $byDayMsg[$day] ?? 0;
    }
    $msgSpark[] = $sum;
}

// --- Trafico ---------------------------------------------------------------
$visitsToday = count_of("SELECT COUNT(*) FROM visits WHERE $HUMAN AND DATE(visited_at)=CURDATE()");
$visitsYest  = count_of("SELECT COUNT(*) FROM visits WHERE $HUMAN AND DATE(visited_at)=CURDATE()-INTERVAL 1 DAY");
$visitsTotal = count_of("SELECT COUNT(*) FROM visits WHERE $HUMAN");
$visits7     = count_of("SELECT COUNT(*) FROM visits WHERE $HUMAN AND visited_at > (NOW() - INTERVAL 7 DAY)");
$visitsPrev7 = count_of(
    "SELECT COUNT(*) FROM visits WHERE $HUMAN
     AND visited_at <= (NOW() - INTERVAL 7 DAY) AND visited_at > (NOW() - INTERVAL 14 DAY)"
);
$uniques30   = count_of("SELECT COUNT(DISTINCT ip_hash) FROM visits WHERE $HUMAN AND visited_at > (NOW() - INTERVAL 30 DAY)");
$botsRecent  = count_of('SELECT COUNT(*) FROM visits WHERE is_bot=1 AND visited_at > (NOW() - INTERVAL 30 DAY)');

// Grafico de los ultimos 14 dias (relleno de dias sin visitas) + visitantes
// unicos por dia, para la tendencia de la tarjeta "Visitantes unicos".
$dailyRaw = rows_of(
    "SELECT DATE(visited_at) AS d, COUNT(*) AS c, COUNT(DISTINCT ip_hash) AS u FROM visits
     WHERE $HUMAN AND visited_at > (NOW() - INTERVAL 14 DAY)
     GROUP BY DATE(visited_at)"
);
$byDay = [];
foreach ($dailyRaw as $r) {
    $byDay[$r['d']] = ['c' => (int) $r['c'], 'u' => (int) $r['u']];
}
$daily = [];
for ($i = 13; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i day"));
    $daily[] = ['d' => $d, 'c' => $byDay[$d]['c'] ?? 0, 'u' => $byDay[$d]['u'] ?? 0];
}
$maxDay = max(1, max(array_column($daily, 'c')));
$sparkVisits  = array_column($daily, 'c');
$sparkUniques = array_column($daily, 'u');

// Canales de trafico y dispositivos de los ultimos 30 dias.
$channelRows = rows_of(
    "SELECT referrer, COUNT(*) AS c FROM visits
     WHERE $HUMAN AND visited_at > (NOW() - INTERVAL 30 DAY) GROUP BY referrer"
);
$channels = [];
foreach ($channelRows as $r) {
    $ch = referrer_channel($r['referrer']);
    $channels[$ch] = ($channels[$ch] ?? 0) + (int) $r['c'];
}
arsort($channels);
$maxChannel = $channels ? max($channels) : 0;

$deviceLabels = ['desktop' => 'Escritorio', 'mobile' => 'Movil', 'tablet' => 'Tablet', 'desconocido' => 'Desconocido'];
$deviceRows = rows_of(
    "SELECT COALESCE(device,'desconocido') AS k, COUNT(*) AS c FROM visits
     WHERE $HUMAN AND visited_at > (NOW() - INTERVAL 30 DAY) GROUP BY k ORDER BY c DESC"
);
$maxDevice = $deviceRows ? max(array_column($deviceRows, 'c')) : 0;

// --- Listas -----------------------------------------------------------------
$lastMessages = rows_of(
    'SELECT id, name, email, subject, is_read, created_at FROM messages
     WHERE is_archived = 0 ORDER BY created_at DESC LIMIT 5'
);
$topPages = rows_of(
    "SELECT path, COUNT(*) AS c FROM visits
     WHERE $HUMAN AND visited_at > (NOW() - INTERVAL 30 DAY)
     GROUP BY path ORDER BY c DESC LIMIT 5"
);
$maxPage = $topPages ? max(array_column($topPages, 'c')) : 0;
$recentActivity = rows_of(
    'SELECT action, entity, entity_id, details, username, created_at
     FROM activity_log ORDER BY created_at DESC LIMIT 8'
);
$failedLogins   = count_or_null(
    'SELECT COUNT(*) FROM login_attempts WHERE success=0 AND attempted_at > (NOW() - INTERVAL 7 DAY)'
);
$failedLogins30 = count_or_null(
    'SELECT COUNT(*) FROM login_attempts WHERE success=0 AND attempted_at > (NOW() - INTERVAL 30 DAY)'
);

/** Color del punto de la linea de tiempo segun el tipo de accion registrada. */
function activity_dot(string $action): string
{
    return match ($action) {
        'create' => 'green',
        'delete' => 'danger',
        'login', 'logout' => 'violet',
        'update', 'export', 'import', 'unblock', 'password_change' => 'cyan',
        default => '',
    };
}

// --- Avisos de seguridad / configuracion ------------------------------------
$warnings = [];
if (is_file(__DIR__ . '/setup.php')) {
    $warnings[] = ['danger', 'El archivo <strong>server/admin/setup.php</strong> sigue en el servidor. '
        . 'Ya no puede crear usuarios (ya existe uno), pero borralo por FTP: es un archivo menos que exponer.'];
}
if (!empty(config()['debug'])) {
    $warnings[] = ['danger', 'El modo <strong>debug</strong> esta ACTIVADO en config.php. '
        . 'Muestra errores con rutas internas a cualquier visitante. Ponlo a <code>false</code>.'];
}
$salt = (string) (config()['security']['ip_salt'] ?? '');
if ($salt === '' || str_starts_with($salt, 'CAMBIA_ESTO')) {
    $warnings[] = ['danger', 'La sal de hasheo de IPs (<strong>ip_salt</strong>) sigue con el valor de ejemplo. '
        . 'Cambiala en config.php por una cadena larga y aleatoria.'];
}
$isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
    || strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
if (!$isHttps) {
    $warnings[] = ['warn', 'Estas viendo el panel por <strong>HTTP sin cifrar</strong>. '
        . 'Tu contrasena viaja en claro: entra siempre por https://'];
}
if ($failedLogins >= 20) {
    $warnings[] = ['warn', "Se han registrado <strong>{$failedLogins} intentos de acceso fallidos</strong> "
        . 'en los ultimos 7 dias. Revisalos en <a href="security.php">Seguridad</a>.'];
}

// Iconos de seccion (mismo trazo que los del menu lateral).
$icoTraffic = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>';
$icoContent = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>';
$icoInbox   = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>';
$icoClock   = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>';
$icoShield  = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>';

admin_header('Panel', 'index.php');
show_flash();
?>
<div class="subdash">
<h1>Hola, <?= e(current_admin()) ?> 👋</h1>

<?php foreach ($warnings as [$type, $html]): ?>
  <div class="flash <?= $type === 'danger' ? 'err' : 'warn' ?>"><?= $html ?></div>
<?php endforeach; ?>

<?php h2_icon($icoTraffic, 'Trafico'); ?>
<div class="grid4">
  <div class="card stat">
    <div class="num"><?= number_format($visitsToday) ?><?= delta_badge($visitsToday, $visitsYest) ?></div>
    <div class="lbl">Visitas hoy<br><span class="faint">ayer: <?= number_format($visitsYest) ?></span></div>
    <?= sparkline($sparkVisits) ?>
  </div>
  <div class="card stat">
    <div class="num cyan"><?= number_format($visits7) ?><?= delta_badge($visits7, $visitsPrev7) ?></div>
    <div class="lbl">Ultimos 7 dias<br><span class="faint">vs. 7 anteriores</span></div>
    <?= sparkline(array_slice($sparkVisits, -7), 'cyan') ?>
  </div>
  <div class="card stat">
    <div class="num violet"><?= number_format($uniques30) ?></div>
    <div class="lbl">Visitantes unicos<br><span class="faint">ultimos 30 dias · tendencia 14 d</span></div>
    <?= sparkline($sparkUniques, 'violet') ?>
  </div>
  <div class="card stat">
    <div class="num"><?= number_format($visitsTotal) ?></div>
    <div class="lbl">Visitas totales<br><span class="faint"><?= number_format($botsRecent) ?> bots filtrados (30 d)</span></div>
  </div>
</div>

<div class="card">
  <h3>Ultimos 14 dias</h3>
  <div class="chart">
    <?php foreach ($daily as $r): ?>
      <?php $h = (int) round(((int) $r['c'] / $maxDay) * 120); ?>
      <div class="col">
        <div class="val"><?= (int) $r['c'] ?></div>
        <div class="bar-v" style="height:<?= max(3, $h) ?>px" title="<?= e($r['d']) ?>: <?= (int) $r['c'] ?> visitas · <?= (int) $r['u'] ?> unicos"></div>
        <div class="tick"><?= e(date('d/m', strtotime($r['d']))) ?></div>
      </div>
    <?php endforeach; ?>
  </div>
  <p class="hint">Solo visitas humanas: los bots y rastreadores se excluyen del conteo.
    Detalle completo en <a href="analytics.php">Analitica</a>.</p>
</div>

<div class="row2">
  <div>
    <h2>Canales de trafico <span class="faint" style="font-weight:500;">(30 d)</span></h2>
    <div class="card">
      <?php if (!$channels): ?><p class="muted">Sin datos de trafico todavia.</p><?php endif; ?>
      <?php foreach ($channels as $name => $c): ?>
        <?php bar_row((string) $name, $c, $maxChannel, 'green'); ?>
      <?php endforeach; ?>
    </div>
  </div>
  <div>
    <h2>Dispositivos <span class="faint" style="font-weight:500;">(30 d)</span></h2>
    <div class="card">
      <?php if (!$deviceRows): ?><p class="muted">Sin datos de trafico todavia.</p><?php endif; ?>
      <?php foreach ($deviceRows as $r): ?>
        <?php bar_row($deviceLabels[$r['k']] ?? $r['k'], (int) $r['c'], $maxDevice, 'violet'); ?>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<?php h2_icon($icoContent, 'Contenido'); ?>
<div class="grid4">
  <div class="card stat">
    <div class="num"><?= $published ?></div>
    <div class="lbl">Proyectos publicados<br><span class="faint"><?= $drafts ?> en borrador</span></div>
  </div>
  <div class="card stat">
    <div class="num cyan"><?= $certs ?></div>
    <div class="lbl">Certificaciones visibles<br><span class="faint"><?= $certsTotal ?> en total</span></div>
  </div>
  <div class="card stat">
    <div class="num violet"><?= $postsVisible ?></div>
    <div class="lbl">Entradas de blog<br><span class="faint"><?= $postsDraft ?> en borrador</span></div>
  </div>
</div>

<?php h2_icon($icoInbox, 'Buzon'); ?>
<div class="grid4">
  <div class="card stat">
    <div class="num <?= $unread > 0 ? 'warn' : '' ?>"><?= $unread ?></div>
    <div class="lbl">Mensajes sin leer<br><span class="faint"><?= number_format($msgTotal) ?> en total</span></div>
  </div>
  <div class="card stat">
    <div class="num violet"><?= $msg30 ?><?= delta_badge($msg30, $msgPrev30) ?></div>
    <div class="lbl">Mensajes (30 dias)<br><span class="faint">vs. 30 anteriores</span></div>
    <?= sparkline($msgSpark, 'violet') ?>
  </div>
  <div class="card stat">
    <div class="num cyan"><?= $msgStarred ?></div>
    <div class="lbl">Destacados<br><span class="faint">en bandeja de entrada</span></div>
  </div>
  <div class="card stat">
    <div class="num"><?= $msgArchived ?></div>
    <div class="lbl">Archivados<br><span class="faint">fuera de la bandeja</span></div>
  </div>
</div>

<div class="row3">
  <div>
    <h2>Ultimos mensajes</h2>
    <div class="card" style="padding:0;">
      <table>
        <tbody>
          <?php if (!$lastMessages): ?>
            <tr><td class="empty">Aun no hay mensajes.</td></tr>
          <?php endif; ?>
          <?php foreach ($lastMessages as $m): ?>
            <tr>
              <td>
                <a href="messages.php?id=<?= (int) $m['id'] ?>"
                   style="<?= (int) $m['is_read'] === 0 ? 'font-weight:700;' : '' ?>">
                  <?= e($m['name']) ?>
                </a>
                <?php if ((int) $m['is_read'] === 0): ?>
                  <span class="pill on" style="margin-left:.3rem;">Nuevo</span>
                <?php endif; ?>
                <div class="faint"><?= e($m['subject'] !== '' ? $m['subject'] : '(sin asunto)') ?></div>
              </td>
              <td class="faint nowrap" style="text-align:right;"><?= e(ago($m['created_at'])) ?></td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>

  <div>
    <h2>Paginas mas vistas <span class="faint" style="font-weight:500;">(30 d)</span></h2>
    <div class="card">
      <?php if (!$topPages): ?>
        <p class="muted">Aun no hay datos de visitas.</p>
      <?php endif; ?>
      <?php foreach ($topPages as $r): ?>
        <?php bar_row($r['path'], (int) $r['c'], (int) $maxPage, 'green'); ?>
      <?php endforeach; ?>
    </div>
  </div>

  <div>
    <h2>Frescura de contenido</h2>
    <div class="card" style="padding:0;">
      <table>
        <tbody>
          <tr>
            <td>
              <div class="faint">Ultimo proyecto</div>
              <?php if ($lastProject): ?>
                <a href="projects.php"><?= e((string) $lastProject['t']) ?></a>
              <?php else: ?>
                <span class="muted">Sin proyectos</span>
              <?php endif; ?>
            </td>
            <td class="faint nowrap" style="text-align:right;"><?= e(ago($lastProject['d'] ?? null)) ?></td>
          </tr>
          <tr>
            <td>
              <div class="faint">Ultima certificacion</div>
              <?php if ($lastCert): ?>
                <a href="certifications.php"><?= e((string) $lastCert['t']) ?></a>
              <?php else: ?>
                <span class="muted">Sin certificaciones</span>
              <?php endif; ?>
            </td>
            <td class="faint nowrap" style="text-align:right;"><?= e(ago($lastCert['d'] ?? null)) ?></td>
          </tr>
          <tr>
            <td>
              <div class="faint">Ultima entrada de blog</div>
              <?php if ($lastPost): ?>
                <a href="posts.php"><?= e((string) $lastPost['t']) ?></a>
              <?php else: ?>
                <span class="muted">Sin entradas</span>
              <?php endif; ?>
            </td>
            <td class="faint nowrap" style="text-align:right;"><?= e(ago($lastPost['d'] ?? null)) ?></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

<h2>Accesos rapidos</h2>
<div class="card">
  <div class="actions">
    <a class="btn" href="project-edit.php">+ Nuevo proyecto</a>
    <a class="btn" href="cert-edit.php">+ Nueva certificacion</a>
    <a class="btn" href="post-edit.php">+ Nueva entrada de blog</a>
    <a class="btn ghost" href="messages.php">Ver mensajes</a>
    <a class="btn ghost" href="analytics.php">Analitica completa</a>
    <a class="btn ghost" href="security.php">Seguridad</a>
    <a class="btn ghost" href="backup.php">Copia de seguridad</a>
  </div>
</div>

<div class="row2">
  <div>
    <?php h2_icon($icoClock, 'Actividad reciente'); ?>
    <div class="card">
      <?php if (!$recentActivity): ?>
        <p class="empty" style="padding:1.5rem;">Sin actividad registrada todavia.</p>
      <?php endif; ?>
      <?php foreach ($recentActivity as $a): ?>
        <div class="timeline-item">
          <span class="timeline-dot <?= e(activity_dot((string) $a['action'])) ?>"></span>
          <div class="timeline-body">
            <span class="pill"><?= e($a['action']) ?></span>
            <span class="muted"><?= e($a['details'] !== '' ? $a['details'] : (string) $a['entity']) ?></span>
            <div class="faint"><?= e($a['username'] ?? '—') ?> · <?= e(ago($a['created_at'])) ?></div>
          </div>
        </div>
      <?php endforeach; ?>
    </div>
  </div>

  <div>
    <?php h2_icon($icoShield, 'Salud del sistema'); ?>
    <div class="card">
      <div class="health-grid">
        <?php
          $phpOk = version_compare(PHP_VERSION, '8.1', '>=');
          status_tile('Version de PHP', PHP_VERSION, $phpOk ? 'ok' : 'warn');

          $dbVersion = '—';
          try {
              $dbVersion = (string) db()->getAttribute(PDO::ATTR_SERVER_VERSION);
          } catch (Throwable $e) {
          }
          status_tile('Base de datos', $dbVersion, $dbVersion !== '—' ? 'ok' : 'danger');

          status_tile('HTTPS', $isHttps ? 'Activo' : 'Inactivo', $isHttps ? 'ok' : 'danger');
          status_tile('Modo debug', !empty(config()['debug']) ? 'Activado' : 'Desactivado', !empty(config()['debug']) ? 'danger' : 'ok');
          status_tile('setup.php', is_file(__DIR__ . '/setup.php') ? 'Presente — borralo' : 'Eliminado', is_file(__DIR__ . '/setup.php') ? 'warn' : 'ok');

          $updir = config()['uploads']['dir'] ?? '';
          if ($updir && is_dir($updir)) {
              $bytes = 0; $files = 0;
              try {
                  $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($updir, FilesystemIterator::SKIP_DOTS));
                  foreach ($it as $file) {
                      if ($file->isFile()) { $bytes += $file->getSize(); $files++; }
                  }
              } catch (Throwable $e) {
                  // sin permisos de lectura recursiva: mostramos lo que haya
              }
              $writable = is_writable($updir);
              status_tile('Carpeta /uploads', $files . ' archivos · ' . fbytes($bytes), $writable ? 'ok' : 'danger');
          } else {
              status_tile('Carpeta /uploads', 'No existe', 'warn');
          }

          status_tile(
              'Accesos fallidos (7 d)',
              $failedLogins === null ? 'No disponible' : (string) $failedLogins,
              $failedLogins === null ? 'warn' : ($failedLogins >= 20 ? 'danger' : ($failedLogins > 0 ? 'warn' : 'ok'))
          );
          status_tile(
              'Accesos fallidos (30 d)',
              $failedLogins30 === null ? 'No disponible' : (string) $failedLogins30,
              $failedLogins30 === null ? 'warn' : ($failedLogins30 >= 50 ? 'danger' : ($failedLogins30 > 0 ? 'warn' : 'ok'))
          );
          status_tile(
              'Visitas registradas',
              number_format(count_of('SELECT COUNT(*) FROM visits')),
              'neutral'
          );
          status_tile(
              'Registros de auditoria',
              number_format(count_of('SELECT COUNT(*) FROM activity_log')),
              'neutral'
          );
          status_tile('Zona horaria', date_default_timezone_get(), 'neutral');
        ?>
      </div>
    </div>
  </div>
</div>

</div><!-- /.subdash -->
<?php admin_footer(); ?>
