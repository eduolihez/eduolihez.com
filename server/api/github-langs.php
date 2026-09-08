<?php
/**
 * GET /api/github-langs.php
 * Tarjeta SVG animada: top 5 lenguajes por bytes agregados en repos propios
 * publicos (no forks). Barras que crecen de 0 al valor real. Ver
 * server/lib/github.php para de donde salen los datos y el cacheo.
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/github.php';
require_once __DIR__ . '/../lib/svg_card.php';

require_method('GET');

if (!github_configured()) {
    svg_respond(svg_placeholder_card(
        'Top Languages',
        'Falta configurar el token de GitHub en config.php.'
    ));
}

try {
    $profile = github_profile_cached();
} catch (Throwable $e) {
    svg_respond(svg_placeholder_card(
        'Top Languages',
        'No se pudo consultar GitHub ahora mismo.'
    ), 300);
    exit;
}

$languages = $profile['languages'];
if (empty($languages)) {
    svg_respond(svg_placeholder_card('Top Languages', 'Sin datos de lenguajes todavia.'));
}

$body = '';
$barMaxWidth = 360;
foreach ($languages as $i => $lang) {
    $rowY = 50 + $i * 22;
    $delay = 0.1 + $i * 0.1;
    $nameEsc = svg_esc($lang['name']);
    $percentEsc = svg_esc($lang['percent'] . '%');
    $body .= <<<SVG
  <g style="opacity:0; animation: fadeIn 0.5s ease-out {$delay}s forwards;">
    <text class="stat-label" x="20" y="{$rowY}">{$nameEsc}</text>
    <text class="stat-value" x="380" y="{$rowY}" text-anchor="end">{$percentEsc}</text>
  </g>
SVG;
    $body .= svg_bar(20, $rowY + 6, $barMaxWidth, $lang['percent'], $lang['color'], $i);
}

svg_respond(svg_card('Top Languages', $body));
