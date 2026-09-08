<?php
/**
 * svg_card.php - Marco visual compartido por las tarjetas SVG animadas de
 * GitHub (server/api/github-stats.php, github-langs.php, github-streak.php).
 *
 * Las animaciones son CSS @keyframes + SMIL <animate>, no JavaScript: un
 * <img src="...svg"> en un README renderiza el SVG como imagen normal del
 * navegador, que SI ejecuta CSS/SMIL dentro de ella (asi funcionan los
 * banners animados tipo capsule-render o readme-typing-svg). JavaScript
 * embebido en el SVG, en cambio, NO se ejecuta en ese contexto.
 */

const CARD_WIDTH  = 400;
const CARD_HEIGHT = 165;

/** Paleta oscura a juego con la identidad "SOC / Blue Team" del perfil. */
function svg_theme(): array
{
    return [
        'bg'       => '#0d1117',
        'border'   => '#2b3345',
        'title'    => '#7aa2f7',
        'text'     => '#c0caf5',
        'muted'    => '#7d8aad',
        'accent'   => '#9ece6a',
        'accent2'  => '#7dcfff',
    ];
}

/** Escapa texto para insertarlo dentro de un SVG. */
function svg_esc(string $s): string
{
    return htmlspecialchars($s, ENT_XML1 | ENT_QUOTES, 'UTF-8');
}

/**
 * Envuelve el contenido interior ($body, ya en SVG) con el marco comun:
 * fondo redondeado, borde, titulo y animacion de entrada del propio marco.
 */
function svg_card(string $title, string $body, int $width = CARD_WIDTH, int $height = CARD_HEIGHT): string
{
    $t = svg_theme();
    $titleEsc = svg_esc($title);

    return <<<SVG
<svg width="{$width}" height="{$height}" viewBox="0 0 {$width} {$height}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{$titleEsc}">
  <style>
    .card-title { font: 600 15px 'Segoe UI', Ubuntu, Sans-Serif; fill: {$t['title']}; }
    .stat-label { font: 400 12px 'Segoe UI', Ubuntu, Sans-Serif; fill: {$t['muted']}; }
    .stat-value { font: 600 12px 'Segoe UI', Ubuntu, Sans-Serif; fill: {$t['text']}; }
    .fade-in { opacity: 0; animation: fadeIn 0.6s ease-out forwards; }
    @keyframes fadeIn { to { opacity: 1; } }
    @keyframes slideIn { from { transform: translateX(-8px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
  </style>
  <rect x="0.5" y="0.5" rx="8" width="{$width}" height="{$height}" fill="{$t['bg']}" stroke="{$t['border']}" />
  <g transform="translate(20, 28)">
    <text class="card-title fade-in">{$titleEsc}</text>
  </g>
  {$body}
</svg>
SVG;
}

/**
 * Una fila "label ......... value" con animacion de entrada escalonada
 * (delay creciente segun $index) para dar sensacion de carga secuencial.
 */
function svg_stat_row(int $x, int $y, string $label, string $value, int $index): string
{
    $t = svg_theme();
    $labelEsc = svg_esc($label);
    $valueEsc = svg_esc($value);
    $delay = 0.15 + $index * 0.1;
    return <<<SVG
  <g transform="translate({$x}, {$y})" style="opacity:0; animation: fadeIn 0.5s ease-out {$delay}s forwards;">
    <text class="stat-label" x="0" y="0">{$labelEsc}</text>
    <text class="stat-value" x="150" y="0">{$valueEsc}</text>
  </g>
SVG;
}

/**
 * Anillo de progreso (para el "rank" o el streak): el trazo crece desde 0
 * hasta el porcentaje real via <animate> sobre stroke-dashoffset.
 */
function svg_progress_ring(int $cx, int $cy, int $r, float $percent, string $color, string $centerLabel): string
{
    $t = svg_theme();
    $circumference = 2 * M_PI * $r;
    $offset = $circumference * (1 - max(0, min(100, $percent)) / 100);
    $labelEsc = svg_esc($centerLabel);

    return <<<SVG
  <g transform="translate({$cx}, {$cy})">
    <circle r="{$r}" fill="none" stroke="{$t['border']}" stroke-width="6" />
    <circle r="{$r}" fill="none" stroke="{$color}" stroke-width="6" stroke-linecap="round"
      stroke-dasharray="{$circumference}" stroke-dashoffset="{$circumference}"
      transform="rotate(-90)">
      <animate attributeName="stroke-dashoffset" from="{$circumference}" to="{$offset}"
        dur="1s" begin="0.2s" fill="freeze" calcMode="spline" keySplines="0.2 0.8 0.2 1" />
    </circle>
    <text text-anchor="middle" dominant-baseline="middle" class="stat-value" style="font-size:14px">{$labelEsc}</text>
  </g>
SVG;
}

/**
 * Barra horizontal que crece de 0 al ancho real via <animate> (usada por el
 * card de lenguajes). $maxWidth es el ancho disponible en px para el 100%.
 */
function svg_bar(int $x, int $y, int $maxWidth, float $percent, string $color, int $index): string
{
    $targetWidth = round($maxWidth * max(0, min(100, $percent)) / 100, 1);
    $delay = 0.1 + $index * 0.12;
    return <<<SVG
  <rect x="{$x}" y="{$y}" width="0" height="8" rx="4" fill="{$color}">
    <animate attributeName="width" from="0" to="{$targetWidth}" dur="0.8s" begin="{$delay}s" fill="freeze" calcMode="spline" keySplines="0.2 0.8 0.2 1" />
  </rect>
SVG;
}

/** Tarjeta de aviso cuando falta configuracion (p.ej. sin token de GitHub). */
function svg_placeholder_card(string $title, string $message): string
{
    $t = svg_theme();
    $msgEsc = svg_esc($message);
    $body = <<<SVG
  <g transform="translate(20, 70)">
    <text class="stat-label" x="0" y="0" style="fill:{$t['muted']}">{$msgEsc}</text>
  </g>
SVG;
    return svg_card($title, $body);
}

/** Envia una respuesta SVG con las cabeceras correctas y cache HTTP corta. */
function svg_respond(string $svg, int $cacheSeconds = 3600): void
{
    header('Content-Type: image/svg+xml; charset=utf-8');
    header('Cache-Control: public, max-age=' . $cacheSeconds);
    send_security_headers(false); // una imagen no necesita X-Robots-Tag: noindex
    echo $svg;
    exit;
}
