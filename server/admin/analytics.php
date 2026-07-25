<?php
/**
 * analytics.php - Analitica propia, sin terceros y sin cookies.
 *
 * Todo sale de la tabla `visits` (IP hasheada con sal, nunca la IP real).
 * Incluye: KPIs con comparativa, grafico diario, franjas horarias, dias de la
 * semana, paginas, idiomas, canales de trafico, referrers, paises,
 * dispositivos, navegadores, sistemas operativos y bots. Export a CSV.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/ua.php';
require_login();

// --- Rango de fechas: lista blanca, nunca se interpola valor del usuario ----
$allowedDays = [1, 7, 14, 30, 90, 365];
$days = (int) ($_GET['days'] ?? 30);
if (!in_array($days, $allowedDays, true)) {
    $days = 30;
}

// ¿Incluir bots en las cifras? Por defecto NO (falsean todo).
$withBots = ($_GET['bots'] ?? '') === '1';
$botFilter = $withBots ? '1=1' : 'is_bot = 0';

/** Ejecuta una consulta parametrizada y devuelve las filas (tolerante a fallos). */
function q_rows(string $sql, array $params = []): array
{
    try {
        $st = db()->prepare($sql);
        $st->execute($params);
        return $st->fetchAll();
    } catch (Throwable $e) {
        return [];
    }
}

/** Igual, pero devuelve un unico valor entero. */
function q_int(string $sql, array $params = []): int
{
    try {
        $st = db()->prepare($sql);
        $st->execute($params);
        return (int) $st->fetchColumn();
    } catch (Throwable $e) {
        return 0;
    }
}

// --- Exportacion CSV --------------------------------------------------------
if (($_GET['export'] ?? '') === 'csv') {
    $rows = q_rows(
        "SELECT visited_at, path, lang, referrer, country, device, browser, os, is_bot
         FROM visits
         WHERE visited_at > (NOW() - INTERVAL ? DAY)
         ORDER BY visited_at DESC
         LIMIT 20000",
        [$days]
    );
    csv_download(
        'visitas-' . $days . 'd-' . date('Y-m-d') . '.csv',
        ['Fecha', 'Pagina', 'Idioma', 'Referrer', 'Pais', 'Dispositivo', 'Navegador', 'SO', 'Bot'],
        array_map(static fn(array $r): array => [
            $r['visited_at'], $r['path'], $r['lang'], $r['referrer'],
            $r['country'], $r['device'], $r['browser'], $r['os'],
            $r['is_bot'] ? 'si' : 'no',
        ], $rows)
    );
}

// --- KPIs -------------------------------------------------------------------
$total   = q_int("SELECT COUNT(*) FROM visits WHERE $botFilter");
$inRange = q_int("SELECT COUNT(*) FROM visits WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)", [$days]);
$prevRange = q_int(
    "SELECT COUNT(*) FROM visits WHERE $botFilter
     AND visited_at <= (NOW() - INTERVAL ? DAY) AND visited_at > (NOW() - INTERVAL ? DAY)",
    [$days, $days * 2]
);
$uniques = q_int("SELECT COUNT(DISTINCT ip_hash) FROM visits WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)", [$days]);
$prevUniques = q_int(
    "SELECT COUNT(DISTINCT ip_hash) FROM visits WHERE $botFilter
     AND visited_at <= (NOW() - INTERVAL ? DAY) AND visited_at > (NOW() - INTERVAL ? DAY)",
    [$days, $days * 2]
);
$botCount = q_int('SELECT COUNT(*) FROM visits WHERE is_bot = 1 AND visited_at > (NOW() - INTERVAL ? DAY)', [$days]);
$today   = q_int("SELECT COUNT(*) FROM visits WHERE $botFilter AND DATE(visited_at)=CURDATE()");

// Paginas por visitante (profundidad media de la visita).
$perVisitor = $uniques > 0 ? round($inRange / $uniques, 1) : 0;

// --- Serie diaria (rellenando huecos) ---------------------------------------
$chartDays = min($days, 60);
$dailyRaw = q_rows(
    "SELECT DATE(visited_at) AS d, COUNT(*) AS c, COUNT(DISTINCT ip_hash) AS u
     FROM visits WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY DATE(visited_at)",
    [$chartDays]
);
$byDay = [];
foreach ($dailyRaw as $r) {
    $byDay[$r['d']] = ['c' => (int) $r['c'], 'u' => (int) $r['u']];
}
$daily = [];
for ($i = $chartDays - 1; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i day"));
    $daily[] = ['d' => $d, 'c' => $byDay[$d]['c'] ?? 0, 'u' => $byDay[$d]['u'] ?? 0];
}
$maxDay = max(1, max(array_column($daily, 'c')));
$bestDay = null;
foreach ($daily as $r) {
    if ($bestDay === null || $r['c'] > $bestDay['c']) {
        $bestDay = $r;
    }
}

// --- Desgloses --------------------------------------------------------------
$topPages = q_rows(
    "SELECT path, COUNT(*) AS c FROM visits WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY path ORDER BY c DESC LIMIT 12",
    [$days]
);
$topRefs = q_rows(
    "SELECT referrer, COUNT(*) AS c FROM visits
     WHERE $botFilter AND referrer <> '' AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY referrer ORDER BY c DESC LIMIT 12",
    [$days]
);
$countries = q_rows(
    "SELECT country, COUNT(*) AS c FROM visits
     WHERE $botFilter AND country IS NOT NULL AND country <> '' AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY country ORDER BY c DESC LIMIT 12",
    [$days]
);
$devices = q_rows(
    "SELECT COALESCE(device,'desconocido') AS k, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY k ORDER BY c DESC",
    [$days]
);
$browsers = q_rows(
    "SELECT COALESCE(browser,'Desconocido') AS k, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY k ORDER BY c DESC LIMIT 8",
    [$days]
);
$systems = q_rows(
    "SELECT COALESCE(os,'Desconocido') AS k, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY k ORDER BY c DESC LIMIT 8",
    [$days]
);
$langs = q_rows(
    "SELECT COALESCE(lang,'?') AS k, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY k ORDER BY c DESC",
    [$days]
);
$hours = q_rows(
    "SELECT HOUR(visited_at) AS h, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY h",
    [$days]
);
$byHour = array_fill(0, 24, 0);
foreach ($hours as $r) {
    $byHour[(int) $r['h']] = (int) $r['c'];
}
$maxHour = max(1, max($byHour));

$weekdays = q_rows(
    "SELECT DAYOFWEEK(visited_at) AS w, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY w",
    [$days]
);
// DAYOFWEEK: 1=domingo ... 7=sabado. Lo reordenamos a lunes-domingo.
$dowNames = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
$dowMap   = [2 => 0, 3 => 1, 4 => 2, 5 => 3, 6 => 4, 7 => 5, 1 => 6];
$byDow = array_fill(0, 7, 0);
foreach ($weekdays as $r) {
    $byDow[$dowMap[(int) $r['w']]] = (int) $r['c'];
}
$maxDow = max(1, max($byDow));

// Canales de trafico: se agrupan en PHP con referrer_channel().
$channelRows = q_rows(
    "SELECT referrer, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY referrer",
    [$days]
);
$channels = [];
foreach ($channelRows as $r) {
    $ch = referrer_channel($r['referrer']);
    $channels[$ch] = ($channels[$ch] ?? 0) + (int) $r['c'];
}
arsort($channels);
$maxChannel = $channels ? max($channels) : 0;

// Bots mas activos (util para saber si te esta indexando una IA).
$topBots = q_rows(
    "SELECT user_agent, COUNT(*) AS c FROM visits
     WHERE is_bot = 1 AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY user_agent ORDER BY c DESC LIMIT 8",
    [$days]
);

$maxPage = $topPages ? max(array_column($topPages, 'c')) : 0;
$maxRef  = $topRefs ? max(array_column($topRefs, 'c')) : 0;
$maxCty  = $countries ? max(array_column($countries, 'c')) : 0;
$maxDev  = $devices ? max(array_column($devices, 'c')) : 0;
$maxBro  = $browsers ? max(array_column($browsers, 'c')) : 0;
$maxSys  = $systems ? max(array_column($systems, 'c')) : 0;
$maxLang = $langs ? max(array_column($langs, 'c')) : 0;
$maxBot  = $topBots ? max(array_column($topBots, 'c')) : 0;

$deviceLabels = ['desktop' => 'Escritorio', 'mobile' => 'Movil', 'tablet' => 'Tablet', 'desconocido' => 'Desconocido'];
$langLabels   = ['es' => 'Espanol', 'en' => 'Ingles', 'ca' => 'Catalan', '?' => 'Desconocido'];

admin_header('Analitica', 'analytics.php');
?>
<div class="toolbar">
  <h1 style="margin:0;">Analitica</h1>
  <div class="actions">
    <?php foreach ($allowedDays as $d): ?>
      <a class="btn <?= $d === $days ? '' : 'ghost' ?> sm"
         href="?days=<?= $d ?><?= $withBots ? '&bots=1' : '' ?>"><?= $d === 1 ? '24 h' : $d . 'd' ?></a>
    <?php endforeach; ?>
    <a class="btn ghost sm" href="?days=<?= $days ?><?= $withBots ? '' : '&bots=1' ?>">
      <?= $withBots ? '✓ Bots incluidos' : 'Incluir bots' ?>
    </a>
    <a class="btn ghost sm" href="?days=<?= $days ?>&amp;export=csv">Exportar CSV</a>
  </div>
</div>

<div class="grid4">
  <div class="card stat">
    <div class="num"><?= number_format($inRange) ?><?= delta_badge($inRange, $prevRange) ?></div>
    <div class="lbl">Visitas (<?= $days === 1 ? '24 h' : $days . ' dias' ?>)<br><span class="faint">vs. periodo anterior</span></div>
  </div>
  <div class="card stat">
    <div class="num cyan"><?= number_format($uniques) ?><?= delta_badge($uniques, $prevUniques) ?></div>
    <div class="lbl">Visitantes unicos<br><span class="faint"><?= $perVisitor ?> paginas por visitante</span></div>
  </div>
  <div class="card stat">
    <div class="num violet"><?= number_format($today) ?></div>
    <div class="lbl">Hoy<br><span class="faint">
      <?php if ($bestDay): ?>mejor dia: <?= e(date('d/m', strtotime($bestDay['d']))) ?> (<?= $bestDay['c'] ?>)<?php endif; ?>
    </span></div>
  </div>
  <div class="card stat">
    <div class="num warn"><?= number_format($botCount) ?></div>
    <div class="lbl">Visitas de bots<br><span class="faint"><?= number_format($total) ?> humanas en total</span></div>
  </div>
</div>

<h2>Visitas por dia</h2>
<div class="card">
  <?php if (!array_sum(array_column($daily, 'c'))): ?>
    <p class="muted">Aun no hay datos de visitas en este rango.</p>
  <?php else: ?>
    <div class="chart">
      <?php foreach ($daily as $r): ?>
        <?php $h = (int) round(($r['c'] / $maxDay) * 120); ?>
        <div class="col">
          <div class="val"><?= $r['c'] ?: '' ?></div>
          <div class="bar-v" style="height:<?= max(3, $h) ?>px"
               title="<?= e($r['d']) ?>: <?= $r['c'] ?> visitas · <?= $r['u'] ?> unicos"></div>
          <div class="tick"><?= e(date('d/m', strtotime($r['d']))) ?></div>
        </div>
      <?php endforeach; ?>
    </div>
    <p class="hint">Pasa el raton por una barra para ver visitas y visitantes unicos de ese dia.</p>
  <?php endif; ?>
</div>

<div class="row2">
  <div>
    <h2>Franja horaria</h2>
    <div class="card">
      <div class="chart" style="height:110px;">
        <?php foreach ($byHour as $h => $c): ?>
          <div class="col">
            <div class="bar-v" style="height:<?= max(3, (int) round(($c / $maxHour) * 80)) ?>px; background:var(--cyan);"
                 title="<?= $h ?>:00 — <?= $c ?> visitas"></div>
            <div class="tick"><?= $h % 3 === 0 ? $h : '' ?></div>
          </div>
        <?php endforeach; ?>
      </div>
      <p class="hint">Hora local del servidor (<?= e(date_default_timezone_get()) ?>).</p>
    </div>
  </div>
  <div>
    <h2>Dia de la semana</h2>
    <div class="card">
      <?php foreach ($dowNames as $i => $name): ?>
        <?php bar_row($name, $byDow[$i], $maxDow, 'violet'); ?>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<div class="row2">
  <div>
    <h2>Canales de trafico</h2>
    <div class="card">
      <?php if (!$channels): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($channels as $name => $c): ?>
        <?php bar_row($name, $c, $maxChannel, 'green',
            $inRange > 0 ? round(($c / $inRange) * 100) . '%' : ''); ?>
      <?php endforeach; ?>
      <p class="hint">"IA / Chatbots" agrupa visitas llegadas desde ChatGPT, Claude, Perplexity,
        Gemini y Copilot: es la senal de que las IAs te estan citando.</p>
    </div>
  </div>
  <div>
    <h2>Idioma de la pagina</h2>
    <div class="card">
      <?php if (!$langs): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($langs as $r): ?>
        <?php bar_row($langLabels[$r['k']] ?? $r['k'], (int) $r['c'], $maxLang, 'green',
            $inRange > 0 ? round(((int) $r['c'] / $inRange) * 100) . '%' : ''); ?>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<div class="row2">
  <div>
    <h2>Paginas mas vistas</h2>
    <div class="card">
      <?php if (!$topPages): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($topPages as $r): ?>
        <?php bar_row($r['path'], (int) $r['c'], $maxPage, 'green'); ?>
      <?php endforeach; ?>
    </div>
  </div>
  <div>
    <h2>Paises</h2>
    <div class="card">
      <?php if (!$countries): ?>
        <p class="muted">Sin datos de pais. Requiere que el trafico pase por Cloudflare
          (cabecera CF-IPCountry).</p>
      <?php endif; ?>
      <?php foreach ($countries as $r): ?>
        <?php bar_row(
            country_flag($r['country']) . ' ' . country_name($r['country']),
            (int) $r['c'], $maxCty, 'violet'
        ); ?>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<div class="row3">
  <div>
    <h2>Dispositivos</h2>
    <div class="card">
      <?php if (!$devices): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($devices as $r): ?>
        <?php bar_row($deviceLabels[$r['k']] ?? $r['k'], (int) $r['c'], $maxDev, '',
            $inRange > 0 ? round(((int) $r['c'] / $inRange) * 100) . '%' : ''); ?>
      <?php endforeach; ?>
    </div>
  </div>
  <div>
    <h2>Navegadores</h2>
    <div class="card">
      <?php if (!$browsers): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($browsers as $r): ?>
        <?php bar_row($r['k'], (int) $r['c'], $maxBro, 'green'); ?>
      <?php endforeach; ?>
    </div>
  </div>
  <div>
    <h2>Sistemas operativos</h2>
    <div class="card">
      <?php if (!$systems): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($systems as $r): ?>
        <?php bar_row($r['k'], (int) $r['c'], $maxSys, 'violet'); ?>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<h2>Origen del trafico (referrers)</h2>
<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead><tr><th>Referrer</th><th>Canal</th><th style="text-align:right;">Visitas</th></tr></thead>
      <tbody>
        <?php if (!$topRefs): ?>
          <tr><td colspan="3" class="empty">Sin datos: todo el trafico llega directo.</td></tr>
        <?php endif; ?>
        <?php foreach ($topRefs as $r): ?>
          <tr>
            <td style="word-break:break-all;"><?= e($r['referrer']) ?></td>
            <td><span class="pill"><?= e(referrer_channel($r['referrer'])) ?></span></td>
            <td style="text-align:right;"><?= (int) $r['c'] ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>

<h2>Bots y rastreadores</h2>
<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead><tr><th>User-Agent</th><th style="text-align:right;">Peticiones</th></tr></thead>
      <tbody>
        <?php if (!$topBots): ?>
          <tr><td colspan="2" class="empty">Ningun bot registrado en este rango.</td></tr>
        <?php endif; ?>
        <?php foreach ($topBots as $r): ?>
          <tr>
            <td class="mono faint" style="word-break:break-all; font-size:.78rem;">
              <?= e(mb_substr((string) $r['user_agent'], 0, 140)) ?>
            </td>
            <td style="text-align:right;"><?= (int) $r['c'] ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<p class="hint" style="margin-top:.5rem;">
  Aqui veras a Googlebot, Bingbot y a los rastreadores de IA (GPTBot, ClaudeBot,
  PerplexityBot...). Que aparezcan es buena senal: significa que te estan indexando.
</p>

<p class="hint" style="margin-top:1.5rem;">
  <strong>Privacidad:</strong> las IPs se guardan hasheadas con sal, no se usan cookies
  de seguimiento y no se comparte nada con terceros. Los referrers se almacenan sin
  parametros de query. Compatible con RGPD sin banner de cookies.
</p>

<?php admin_footer(); ?>
