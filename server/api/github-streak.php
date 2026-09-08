<?php
/**
 * GET /api/github-streak.php
 * Tarjeta SVG animada: racha de contribuciones (ultimos 12 meses, que es
 * la ventana que cubre el calendario de contribuciones de GitHub).
 * Ver server/lib/github.php: github_calc_streaks().
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/github.php';
require_once __DIR__ . '/../lib/svg_card.php';

require_method('GET');

if (!github_configured()) {
    svg_respond(svg_placeholder_card(
        'github --streak',
        'Falta configurar el token de GitHub en config.php.'
    ));
}

try {
    $profile = github_profile_cached();
} catch (Throwable $e) {
    svg_respond(svg_placeholder_card(
        'github --streak',
        'No se pudo consultar GitHub ahora mismo.'
    ), 300);
    exit;
}

$t = svg_theme();
$current = $profile['current_streak'];
$longest = $profile['longest_streak'];
$total   = $profile['total_contributions_year'];

$ringPercent = $longest > 0 ? min(100, round($current / $longest * 100, 1)) : 0;

$body = svg_stat_row(20, 60, 'Total (12 meses)', number_format($total), 0);
$body .= svg_stat_row(20, 82, 'Racha mas larga', $longest . ' dias', 1);
$body .= svg_progress_ring(340, 90, 34, $ringPercent, $t['accent2'], $current . 'd');
$body .= <<<SVG
  <text class="stat-label" x="340" y="140" text-anchor="middle" style="font-size:11px">Racha actual</text>
SVG;

svg_respond(svg_card('github --streak', $body));
