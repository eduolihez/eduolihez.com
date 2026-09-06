<?php
/**
 * analytics.php - Analitica propia, sin terceros y sin cookies.
 *
 * Todo sale de la tabla `visits` (IP hasheada con sal + user-agent, nunca la
 * IP real). Incluye: KPIs con comparativa, rebote/duracion/scroll, grafico
 * diario, franjas horarias, dias de la semana, paginas, idiomas (de pagina y
 * de navegador), canales de trafico, atribucion UTM, referrers, paises,
 * dispositivos, navegadores, sistemas operativos, tamano de pantalla,
 * paginas de entrada/salida y bots. Export a CSV.
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

// --- App (docs/designs/admin-dashboard.md): filtra por app_id si se pide -----
// Sin ?app=, se ve todo (compatibilidad con el /admin de un solo sitio de
// hoy). El futuro selector de apps enlazara aqui con ?app=<slug>. $appId sale
// siempre de una consulta parametrizada -> se puede interpolar como INT en el
// resto de SQL de este archivo sin riesgo de inyeccion.
$appSlug = (string) ($_GET['app'] ?? '');
$appId   = null;
$appName = null;
if ($appSlug !== '') {
    $appRow = db()->prepare('SELECT id, display_name FROM apps WHERE slug = ?');
    $appRow->execute([$appSlug]);
    $appRow = $appRow->fetch();
    if ($appRow) {
        $appId   = (int) $appRow['id'];
        $appName = (string) $appRow['display_name'];
    }
}
$appFilterSql = $appId !== null ? " AND app_id = $appId" : '';
$appQs        = $appSlug !== '' ? '&app=' . rawurlencode($appSlug) : '';

$botFilter = ($withBots ? '1=1' : 'is_bot = 0') . $appFilterSql;

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

/**
 * Maximo de la columna 'c' de un desglose (o 0 si esta vacio). Cada grafico
 * de barras la usa para escalar el ancho de la barra mas larga al 100%.
 */
function max_count(array $rows): int
{
    return $rows ? (int) max(array_column($rows, 'c')) : 0;
}

/**
 * Dado un conjunto de IDs de `visits` (p.ej. el primer o ultimo hit de cada
 * sesion), devuelve las rutas mas frecuentes entre esas filas. $limit es
 * siempre un literal fijo del propio codigo, nunca dato de usuario -- se
 * interpola igual que el resto de LIMIT de este archivo.
 */
function paths_for_ids(array $ids, int $limit): array
{
    if (!$ids) {
        return [];
    }
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    return q_rows(
        "SELECT path, COUNT(*) AS c FROM visits WHERE id IN ($placeholders)
         GROUP BY path ORDER BY c DESC LIMIT $limit",
        $ids
    );
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
        "SELECT visited_at, path, lang, referrer, country, device, browser, os, is_bot,
                duration_s, scroll_pct, utm_source, utm_medium, utm_campaign, viewport, browser_lang
         FROM visits
         WHERE visited_at > (NOW() - INTERVAL ? DAY)$appFilterSql
         ORDER BY visited_at DESC
         LIMIT 20000",
        [$days]
    );
    csv_download(
        'visitas-' . $days . 'd-' . date('Y-m-d') . '.csv',
        ['Fecha', 'Pagina', 'Idioma', 'Referrer', 'Pais', 'Dispositivo', 'Navegador', 'SO', 'Bot',
         'Duracion (s)', 'Scroll (%)', 'UTM origen', 'UTM medio', 'UTM campana', 'Viewport', 'Idioma navegador'],
        array_map(static fn(array $r): array => [
            $r['visited_at'], $r['path'], $r['lang'], $r['referrer'],
            $r['country'], $r['device'], $r['browser'], $r['os'],
            $r['is_bot'] ? 'si' : 'no',
            $r['duration_s'], $r['scroll_pct'], $r['utm_source'], $r['utm_medium'],
            $r['utm_campaign'], $r['viewport'], $r['browser_lang'],
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
$botCount = q_int("SELECT COUNT(*) FROM visits WHERE is_bot = 1$appFilterSql AND visited_at > (NOW() - INTERVAL ? DAY)", [$days]);
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
     WHERE is_bot = 1$appFilterSql AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY user_agent ORDER BY c DESC LIMIT 8",
    [$days]
);

// --- Comportamiento: rebote, duracion y scroll -------------------------------
// session_id agrupa las paginas vistas en una misma pestana (vive en
// sessionStorage, no es un identificador persistente). Una sesion de un solo
// "hit" es un rebote.
$totalSessions = q_int(
    "SELECT COUNT(DISTINCT session_id) FROM visits
     WHERE $botFilter AND session_id IS NOT NULL AND visited_at > (NOW() - INTERVAL ? DAY)",
    [$days]
);
$bouncedSessions = q_int(
    "SELECT COUNT(*) FROM (
        SELECT session_id FROM visits
        WHERE $botFilter AND session_id IS NOT NULL AND visited_at > (NOW() - INTERVAL ? DAY)
        GROUP BY session_id HAVING COUNT(*) = 1
     ) t",
    [$days]
);
$bounceRate = $totalSessions > 0 ? round(($bouncedSessions / $totalSessions) * 100) : 0;

$avgDuration = (float) (q_rows(
    "SELECT AVG(duration_s) AS v FROM visits
     WHERE $botFilter AND duration_s IS NOT NULL AND visited_at > (NOW() - INTERVAL ? DAY)",
    [$days]
)[0]['v'] ?? 0);
$avgScroll = (float) (q_rows(
    "SELECT AVG(scroll_pct) AS v FROM visits
     WHERE $botFilter AND scroll_pct IS NOT NULL AND visited_at > (NOW() - INTERVAL ? DAY)",
    [$days]
)[0]['v'] ?? 0);

// Paginas de entrada / salida: primer y ultimo "hit" de cada sesion. Un solo
// GROUP BY por session_id calcula ambos extremos a la vez (antes eran dos
// consultas identicas salvo MIN/MAX, cada una recorriendo y agrupando el
// mismo conjunto de filas por separado).
$sessionEdges = q_rows(
    "SELECT MIN(id) AS first_id, MAX(id) AS last_id FROM visits
     WHERE $botFilter AND session_id IS NOT NULL AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY session_id",
    [$days]
);
$entryPages = paths_for_ids(array_column($sessionEdges, 'first_id'), 10);
$exitPages  = paths_for_ids(array_column($sessionEdges, 'last_id'), 10);

// --- Atribucion: UTM de la propia URL de aterrizaje --------------------------
$utmRows = q_rows(
    "SELECT utm_source, utm_medium, utm_campaign, COUNT(*) AS c FROM visits
     WHERE $botFilter AND utm_source IS NOT NULL AND utm_source <> ''
       AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY utm_source, utm_medium, utm_campaign ORDER BY c DESC LIMIT 12",
    [$days]
);

// --- Datos tecnicos: idioma del navegador y tamano de pantalla ---------------
$browserLangs = q_rows(
    "SELECT COALESCE(browser_lang,'?') AS k, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY k ORDER BY c DESC LIMIT 8",
    [$days]
);
$viewports = q_rows(
    "SELECT COALESCE(viewport,'?') AS k, COUNT(*) AS c FROM visits
     WHERE $botFilter AND visited_at > (NOW() - INTERVAL ? DAY)
     GROUP BY k ORDER BY FIELD(k,'xs','sm','md','lg','xl','?')",
    [$days]
);

$maxPage = max_count($topPages);
$maxRef  = max_count($topRefs);
$maxCty  = max_count($countries);
$maxDev  = max_count($devices);
$maxBro  = max_count($browsers);
$maxSys  = max_count($systems);
$maxLang = max_count($langs);
$maxBot  = max_count($topBots);
$maxEntry = max_count($entryPages);
$maxExit  = max_count($exitPages);
$maxUtm   = max_count($utmRows);
$maxBroLang = max_count($browserLangs);
$maxViewport = max_count($viewports);

$deviceLabels  = ['desktop' => 'Escritorio', 'mobile' => 'Movil', 'tablet' => 'Tablet', 'desconocido' => 'Desconocido'];
$langLabels    = ['es' => 'Espanol', 'en' => 'Ingles', 'ca' => 'Catalan', '?' => 'Desconocido'];
// Los cortes (480/768/1024/1440) tienen que coincidir con bucketViewport()
// en src/scripts/analytics.ts: si cambian alli, cambiar tambien aqui.
$viewportLabels = ['xs' => '< 480 px', 'sm' => '480–767 px', 'md' => '768–1023 px',
                    'lg' => '1024–1439 px', 'xl' => '≥ 1440 px', '?' => 'Desconocido'];

admin_header('Analitica', 'analytics.php');
// Sub-dashboard (docs/designs/admin-dashboard.md): estilos compartidos en
// partials/layout.php (bloque ".subdash"), reutilizados por todas las
// paginas re-skinadas de la Entrega 2 -- no se duplican aqui.
?>
<div class="toolbar">
  <h1 style="margin:0;">
    Analitica
    <?php if ($appName !== null): ?><span class="faint" style="font-size:1rem;">— <?= e($appName) ?></span><?php endif; ?>
  </h1>
  <div class="actions">
    <?php foreach ($allowedDays as $d): ?>
      <a class="btn <?= $d === $days ? '' : 'ghost' ?> sm"
         href="?days=<?= $d ?><?= $withBots ? '&bots=1' : '' ?><?= e($appQs) ?>"><?= $d === 1 ? '24 h' : $d . 'd' ?></a>
    <?php endforeach; ?>
    <a class="btn ghost sm" href="?days=<?= $days ?><?= $withBots ? '' : '&bots=1' ?><?= e($appQs) ?>">
      <?= $withBots ? '✓ Bots incluidos' : 'Incluir bots' ?>
    </a>
    <a class="btn ghost sm" href="?days=<?= $days ?>&amp;export=csv<?= e($appQs) ?>">Exportar CSV</a>
  </div>
</div>
<?php if ($appSlug !== '' && $appId === null): ?>
  <p class="hint" style="color:var(--warn, #c77);">
    No se encontro ninguna app con slug "<?= e($appSlug) ?>" — mostrando datos de todas las apps.
  </p>
<?php endif; ?>

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

<div class="grid4">
  <div class="card stat">
    <div class="num"><?= $bounceRate ?>%</div>
    <div class="lbl">Rebote<br><span class="faint">sesiones de una sola pagina</span></div>
  </div>
  <div class="card stat">
    <div class="num cyan"><?= $avgDuration >= 60 ? sprintf('%d:%02d', (int) ($avgDuration / 60), (int) $avgDuration % 60) : round($avgDuration) . 's' ?></div>
    <div class="lbl">Duracion media<br><span class="faint">tiempo visible en pantalla</span></div>
  </div>
  <div class="card stat">
    <div class="num violet"><?= round($avgScroll) ?>%</div>
    <div class="lbl">Scroll medio<br><span class="faint">profundidad alcanzada</span></div>
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
    <h2>Idioma del navegador</h2>
    <div class="card">
      <?php if (!$browserLangs): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($browserLangs as $r): ?>
        <?php bar_row($langLabels[$r['k']] ?? strtoupper((string) $r['k']), (int) $r['c'], $maxBroLang, ''); ?>
      <?php endforeach; ?>
      <p class="hint">Idioma declarado por el navegador, no el de la pagina servida:
        una demanda visible de un idioma que aun no ofreces se veria aqui.</p>
    </div>
  </div>
  <div>
    <h2>Tamano de pantalla</h2>
    <div class="card">
      <?php if (!$viewports): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($viewports as $r): ?>
        <?php bar_row($viewportLabels[$r['k']] ?? $r['k'], (int) $r['c'], $maxViewport, 'violet'); ?>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<div class="row2">
  <div>
    <h2>Paginas de entrada</h2>
    <div class="card">
      <?php if (!$entryPages): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($entryPages as $r): ?>
        <?php bar_row($r['path'], (int) $r['c'], $maxEntry, 'green'); ?>
      <?php endforeach; ?>
    </div>
  </div>
  <div>
    <h2>Paginas de salida</h2>
    <div class="card">
      <?php if (!$exitPages): ?><p class="muted">Sin datos.</p><?php endif; ?>
      <?php foreach ($exitPages as $r): ?>
        <?php bar_row($r['path'], (int) $r['c'], $maxExit, 'violet'); ?>
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

<h2>Atribucion (UTM)</h2>
<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead><tr><th>Origen</th><th>Medio</th><th>Campana</th><th style="text-align:right;">Visitas</th></tr></thead>
      <tbody>
        <?php if (!$utmRows): ?>
          <tr><td colspan="4" class="empty">Sin datos: ningun enlace de entrada trae parametros utm_*.</td></tr>
        <?php endif; ?>
        <?php foreach ($utmRows as $r): ?>
          <tr>
            <td><?= e((string) $r['utm_source']) ?></td>
            <td><?= e((string) ($r['utm_medium'] ?? '—')) ?></td>
            <td><?= e((string) ($r['utm_campaign'] ?? '—')) ?></td>
            <td style="text-align:right;"><?= (int) $r['c'] ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<p class="hint" style="margin-top:.5rem;">
  De <code>utm_source</code>/<code>utm_medium</code>/<code>utm_campaign</code> en la URL de
  aterrizaje, nunca del referrer de otra web (ese se guarda sin query, ver nota de privacidad).
</p>

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
  <strong>Privacidad:</strong> las IPs se guardan hasheadas con sal (mas user-agent), no se
  usan cookies de seguimiento y no se comparte nada con terceros. Los referrers se almacenan
  sin parametros de query. La sesion (rebote, entrada/salida) se identifica con un id que vive
  solo en <code>sessionStorage</code> mientras la pestana esta abierta: no persiste, no se cruza
  con otras visitas y no sale del navegador salvo para contar "estas paginas son la misma
  visita". Compatible con RGPD sin banner de cookies.
</p>

<?php admin_footer(); ?>
