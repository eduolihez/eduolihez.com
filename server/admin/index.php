<?php
/**
 * index.php - Panel principal (dashboard).
 *
 * Vista de un vistazo:
 *   - Avisos de seguridad y configuracion (lo primero, porque importa).
 *   - KPIs de trafico con comparativa frente al periodo anterior.
 *   - Contenido publicado, buzon y grafico de los ultimos 14 dias.
 *   - Ultimos mensajes, paginas top, salud del sistema y actividad reciente.
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

// --- Contenido --------------------------------------------------------------
$projects   = count_of('SELECT COUNT(*) FROM projects');
$published  = count_of("SELECT COUNT(*) FROM projects WHERE status='published'");
$drafts     = max(0, $projects - $published);
$certs      = count_of('SELECT COUNT(*) FROM certifications WHERE visible=1');
$certsTotal = count_of('SELECT COUNT(*) FROM certifications');

// --- Buzon ------------------------------------------------------------------
$unread   = count_of('SELECT COUNT(*) FROM messages WHERE is_read=0 AND is_archived=0');
$msgTotal = count_of('SELECT COUNT(*) FROM messages');
$msg30    = count_of('SELECT COUNT(*) FROM messages WHERE created_at > (NOW() - INTERVAL 30 DAY)');
$msgPrev30 = count_of(
    'SELECT COUNT(*) FROM messages
     WHERE created_at <= (NOW() - INTERVAL 30 DAY) AND created_at > (NOW() - INTERVAL 60 DAY)'
);

// --- Trafico ----------------------------------------------------------------
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

// Grafico de los ultimos 14 dias (relleno de dias sin visitas).
$dailyRaw = rows_of(
    "SELECT DATE(visited_at) AS d, COUNT(*) AS c FROM visits
     WHERE $HUMAN AND visited_at > (NOW() - INTERVAL 14 DAY)
     GROUP BY DATE(visited_at)"
);
$byDay = [];
foreach ($dailyRaw as $r) {
    $byDay[$r['d']] = (int) $r['c'];
}
$daily = [];
for ($i = 13; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i day"));
    $daily[] = ['d' => $d, 'c' => $byDay[$d] ?? 0];
}
$maxDay = max(1, max(array_column($daily, 'c')));

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
$failedLogins = count_of(
    'SELECT COUNT(*) FROM login_attempts WHERE success=0 AND attempted_at > (NOW() - INTERVAL 7 DAY)'
);

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

admin_header('Panel', 'index.php');
show_flash();
?>
<h1>Hola, <?= e(current_admin()) ?> 👋</h1>

<?php foreach ($warnings as [$type, $html]): ?>
  <div class="flash <?= $type === 'danger' ? 'err' : 'warn' ?>"><?= $html ?></div>
<?php endforeach; ?>

<h2 style="margin-top:.5rem;">Trafico</h2>
<div class="grid4">
  <div class="card stat">
    <div class="num"><?= number_format($visitsToday) ?><?= delta_badge($visitsToday, $visitsYest) ?></div>
    <div class="lbl">Visitas hoy<br><span class="faint">ayer: <?= number_format($visitsYest) ?></span></div>
  </div>
  <div class="card stat">
    <div class="num cyan"><?= number_format($visits7) ?><?= delta_badge($visits7, $visitsPrev7) ?></div>
    <div class="lbl">Ultimos 7 dias<br><span class="faint">vs. 7 anteriores</span></div>
  </div>
  <div class="card stat">
    <div class="num violet"><?= number_format($uniques30) ?></div>
    <div class="lbl">Visitantes unicos<br><span class="faint">ultimos 30 dias</span></div>
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
        <div class="bar-v" style="height:<?= max(3, $h) ?>px" title="<?= e($r['d']) ?>: <?= (int) $r['c'] ?>"></div>
        <div class="tick"><?= e(date('d/m', strtotime($r['d']))) ?></div>
      </div>
    <?php endforeach; ?>
  </div>
  <p class="hint">Solo visitas humanas: los bots y rastreadores se excluyen del conteo.
    Detalle completo en <a href="analytics.php">Analitica</a>.</p>
</div>

<h2>Contenido y buzon</h2>
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
    <div class="num <?= $unread > 0 ? 'warn' : '' ?>"><?= $unread ?></div>
    <div class="lbl">Mensajes sin leer<br><span class="faint"><?= number_format($msgTotal) ?> en total</span></div>
  </div>
  <div class="card stat">
    <div class="num violet"><?= $msg30 ?><?= delta_badge($msg30, $msgPrev30) ?></div>
    <div class="lbl">Mensajes (30 dias)<br><span class="faint">vs. 30 anteriores</span></div>
  </div>
</div>

<div class="row2">
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
    <h2>Paginas mas vistas (30 d)</h2>
    <div class="card">
      <?php if (!$topPages): ?>
        <p class="muted">Aun no hay datos de visitas.</p>
      <?php endif; ?>
      <?php foreach ($topPages as $r): ?>
        <?php bar_row($r['path'], (int) $r['c'], (int) $maxPage, 'green'); ?>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<h2>Accesos rapidos</h2>
<div class="card">
  <div class="actions">
    <a class="btn" href="project-edit.php">+ Nuevo proyecto</a>
    <a class="btn" href="cert-edit.php">+ Nueva certificacion</a>
    <a class="btn ghost" href="messages.php">Ver mensajes</a>
    <a class="btn ghost" href="analytics.php">Analitica completa</a>
    <a class="btn ghost" href="security.php">Seguridad</a>
    <a class="btn ghost" href="backup.php">Copia de seguridad</a>
  </div>
</div>

<div class="row2">
  <div>
    <h2>Actividad reciente</h2>
    <div class="card" style="padding:0;">
      <table>
        <tbody>
          <?php if (!$recentActivity): ?>
            <tr><td class="empty">Sin actividad registrada todavia.</td></tr>
          <?php endif; ?>
          <?php foreach ($recentActivity as $a): ?>
            <tr>
              <td>
                <span class="pill"><?= e($a['action']) ?></span>
                <span class="muted"><?= e($a['details'] !== '' ? $a['details'] : (string) $a['entity']) ?></span>
                <div class="faint"><?= e($a['username'] ?? '—') ?></div>
              </td>
              <td class="faint nowrap" style="text-align:right;"><?= e(ago($a['created_at'])) ?></td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>

  <div>
    <h2>Salud del sistema</h2>
    <div class="card" style="padding:0;">
      <table>
        <tr>
          <th>PHP</th>
          <td>
            <?= e(PHP_VERSION) ?>
            <?php if (version_compare(PHP_VERSION, '8.1', '<')): ?>
              <span class="pill danger">Desactualizado</span>
            <?php else: ?>
              <span class="pill on">OK</span>
            <?php endif; ?>
          </td>
        </tr>
        <tr>
          <th>Base de datos</th>
          <td class="mono faint"><?php
            try {
                echo e(db()->getAttribute(PDO::ATTR_SERVER_VERSION));
            } catch (Throwable $e) {
                echo '—';
            }
          ?></td>
        </tr>
        <tr>
          <th>HTTPS</th>
          <td><?= $isHttps ? '<span class="pill on">Activo</span>' : '<span class="pill danger">Inactivo</span>' ?></td>
        </tr>
        <tr>
          <th>Modo debug</th>
          <td><?= !empty(config()['debug'])
                ? '<span class="pill danger">Activado</span>'
                : '<span class="pill on">Desactivado</span>' ?></td>
        </tr>
        <tr>
          <th>setup.php</th>
          <td><?= is_file(__DIR__ . '/setup.php')
                ? '<span class="pill warn">Presente — borralo</span>'
                : '<span class="pill on">Eliminado</span>' ?></td>
        </tr>
        <tr>
          <th>Carpeta /uploads</th>
          <td><?php
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
                $wr = is_writable($updir) ? '<span class="pill on">escribible</span>' : '<span class="pill danger">sin permisos</span>';
                echo $files . ' archivos · ' . e(fbytes($bytes)) . ' ' . $wr;
            } else {
                echo '<span class="pill warn">No existe</span>';
            }
          ?></td>
        </tr>
        <tr>
          <th>Filas en BD</th>
          <td class="faint">
            <?= number_format(count_of('SELECT COUNT(*) FROM visits')) ?> visitas ·
            <?= number_format($msgTotal) ?> mensajes ·
            <?= number_format(count_of('SELECT COUNT(*) FROM activity_log')) ?> registros de auditoria
          </td>
        </tr>
        <tr>
          <th>Zona horaria</th>
          <td class="faint"><?= e(date_default_timezone_get()) ?> · <?= e(date('d/m/Y H:i')) ?></td>
        </tr>
      </table>
    </div>
  </div>
</div>

<?php admin_footer(); ?>
