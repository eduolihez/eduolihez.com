<?php
/**
 * GET /api/github-stats.php
 * Tarjeta SVG animada: metricas generales de GitHub + anillo de % de dias
 * activos en los ultimos 12 meses.
 * Pensada para incrustarse en el README de perfil via <img src="...">.
 * Sustituye a github-readme-stats.vercel.app (ver server/lib/github.php).
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/github.php';
require_once __DIR__ . '/../lib/svg_card.php';

require_method('GET');

if (!github_configured()) {
    svg_respond(svg_placeholder_card(
        "Eduardo's GitHub Stats",
        'Falta configurar el token de GitHub en config.php.'
    ));
}

try {
    $profile = github_profile_cached();
} catch (Throwable $e) {
    svg_respond(svg_placeholder_card(
        "Eduardo's GitHub Stats",
        'No se pudo consultar GitHub ahora mismo.'
    ), 300);
    exit;
}

$s = $profile['stats'];
$activePercent = $profile['active_days_percent'];
$t = svg_theme();

$rows = [
    ['Estrellas', number_format($s['stars'])],
    ['Commits (total)', number_format($s['commits'])],
    ['Pull requests', number_format($s['prs'])],
    ['Issues', number_format($s['issues'])],
    ['Repos contribuidos', number_format($s['contributed_to'])],
];

$body = '';
foreach ($rows as $i => [$label, $value]) {
    $body .= svg_stat_row(20, 55 + $i * 20, $label, $value, $i);
}
$body .= svg_progress_ring(340, 90, 34, $activePercent, $t['accent2'], round($activePercent) . '%');
$body .= <<<SVG
  <text class="stat-label" x="340" y="140" text-anchor="middle" style="font-size:11px">Días activos (12m)</text>
SVG;

svg_respond(svg_card("Eduardo's GitHub Stats", $body));
