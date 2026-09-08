<?php
/**
 * svg_card.php - Marco visual compartido por las tarjetas SVG animadas de
 * GitHub (server/api/github-stats.php, github-langs.php, github-streak.php).
 *
 * Identidad visual: "terminal / HUD de SOC" (barra de acento superior,
 * corchetes de esquina tipo mira, punto de estado parpadeante, tipografia
 * monoespaciada, barrido de escaner) en vez del típico theme "tokyonight"
 * que usan la mayoria de tarjetas de github-readme-stats -- deliberadamente
 * distinto, y coherente con la identidad "SOC Analyst / Blue Team" del
 * resto del README (mismo verde que el badge "Portfolio" de la cabecera).
 * Paleta de acento validada con la skill dataviz (validate_palette.js):
 * contraste >=3:1 sobre el fondo y separacion CVD >=8 entre verde y cian
 * (uso decorativo puntual, no una serie categorica, asi que la banda de
 * luminosidad de esa validacion no aplica -- ver nota del propio script).
 *
 * Las animaciones son CSS @keyframes + SMIL <animate>, no JavaScript: un
 * <img src="...svg"> en un README renderiza el SVG como imagen normal del
 * navegador, que SI ejecuta CSS/SMIL dentro de ella (asi funcionan los
 * banners animados tipo capsule-render o readme-typing-svg). JavaScript
 * embebido en el SVG, en cambio, NO se ejecuta en ese contexto.
 */

const CARD_WIDTH  = 400;
const CARD_HEIGHT = 165;

/** Paleta "SOC / terminal" -- ver cabecera del archivo. */
function svg_theme(): array
{
    return [
        'bg'       => '#0a0e14',
        'border'   => '#1a2332',
        'track'    => '#20293b', // fondo de las barras/anillos sin rellenar
        'title'    => '#10B981', // mismo verde que el badge "Portfolio" del header
        'text'     => '#e2e8f0',
        'muted'    => '#64748b',
        'accent'   => '#10B981',
        'accent2'  => '#22d3ee', // cian: resalta valores/anillos sobre el verde de marca
    ];
}

const SVG_FONT_MONO = "ui-monospace, 'Cascadia Code', 'JetBrains Mono', Consolas, 'SFMono-Regular', monospace";

/** Escapa texto para insertarlo dentro de un SVG. */
function svg_esc(string $s): string
{
    return htmlspecialchars($s, ENT_XML1 | ENT_QUOTES, 'UTF-8');
}

/**
 * CSS propio del usuario (ajuste `github_stats_custom_css`, editable desde
 * /admin/integrations.php), como bloque <style> adicional que se pinta
 * DESPUES del <style> con las reglas por defecto -- mismo empate de
 * especificidad, gana el ultimo en orden de documento, asi que sobreescribe
 * sin tener que tocar el CSS base.
 *
 * No hay sanitizado de propiedades: quien lo escribe es el propio dueno del
 * sitio, autenticado en /admin (mismo nivel de confianza que editar
 * config.php a mano). El unico filtro es evitar que el texto rompa la
 * propia etiqueta <style> si contiene literalmente "</style" -- eso NO es
 * una defensa contra el autor, es una defensa contra un error tonto (pegar
 * CSS que por lo que sea trae ese texto) que dejaria el SVG entero mal
 * formado.
 */
function svg_custom_css_block(): string
{
    $css = trim(setting_get('github_stats_custom_css', ''));
    if ($css === '') {
        return '';
    }
    $css = (string) preg_replace('#</style#i', '<\\/style', $css);
    return "<style>{$css}</style>";
}

/**
 * Corchetes de esquina (estilo mira/HUD) -- firma visual del marco, en las
 * 4 esquinas, a un margen fijo del borde.
 */
function svg_corner_brackets(int $width, int $height, string $color): string
{
    $m = 6;   // margen desde el borde
    $l = 10;  // longitud de cada brazo
    $x2 = $width - $m;   // borde derecho (con margen)
    $y2 = $height - $m;  // borde inferior (con margen)
    $mPlusL = $m + $l;
    $x2MinusL = $x2 - $l;
    $y2MinusL = $y2 - $l;

    return <<<SVG
  <g fill="none" stroke="{$color}" stroke-width="1.5" stroke-linecap="round" stroke-opacity="0.55">
    <path d="M {$m} {$mPlusL} L {$m} {$m} L {$mPlusL} {$m}" />
    <path d="M {$x2MinusL} {$m} L {$x2} {$m} L {$x2} {$mPlusL}" />
    <path d="M {$m} {$y2MinusL} L {$m} {$y2} L {$mPlusL} {$y2}" />
    <path d="M {$x2MinusL} {$y2} L {$x2} {$y2} L {$x2} {$y2MinusL}" />
  </g>
SVG;
}

/**
 * Envuelve el contenido interior ($body, ya en SVG) con el marco comun:
 * fondo, borde, barra de acento superior, corchetes de esquina, punto de
 * estado parpadeante, titulo en monoespaciada y barrido de escaner de
 * fondo (loop continuo, muy sutil).
 */
function svg_card(string $title, string $body, int $width = CARD_WIDTH, int $height = CARD_HEIGHT): string
{
    $t = svg_theme();
    $titleEsc = svg_esc($title);
    $inset = $width - 16; // ancho de la barra de acento superior, con margen de 8px a cada lado
    $font = SVG_FONT_MONO;
    $brackets = svg_corner_brackets($width, $height, $t['accent']);
    $customCss = svg_custom_css_block();

    return <<<SVG
<svg width="{$width}" height="{$height}" viewBox="0 0 {$width} {$height}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{$titleEsc}">
  <defs>
    <linearGradient id="scan" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{$t['accent2']}" stop-opacity="0" />
      <stop offset="50%" stop-color="{$t['accent2']}" stop-opacity="0.10" />
      <stop offset="100%" stop-color="{$t['accent2']}" stop-opacity="0" />
    </linearGradient>
    <clipPath id="cardClip">
      <rect x="0.5" y="0.5" rx="8" width="{$width}" height="{$height}" />
    </clipPath>
  </defs>
  <style>
    .card-title { font: 700 12.5px {$font}; fill: {$t['title']}; letter-spacing: 1.5px; text-transform: uppercase; }
    .stat-label { font: 400 12px {$font}; fill: {$t['muted']}; }
    .stat-value { font: 700 12px {$font}; fill: {$t['text']}; }
    .fade-in { opacity: 0; animation: fadeIn 0.6s ease-out forwards; }
    @keyframes fadeIn { to { opacity: 1; } }
    .pulse-dot { animation: pulse 2s ease-in-out infinite; transform-origin: center; transform-box: fill-box; }
    @keyframes pulse { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.4; transform: scale(0.75); } }
  </style>
  {$customCss}
  <g clip-path="url(#cardClip)">
    <rect x="0.5" y="0.5" rx="8" width="{$width}" height="{$height}" fill="{$t['bg']}" stroke="{$t['border']}" />
    <rect x="0" y="-40" width="{$width}" height="40" fill="url(#scan)">
      <animate attributeName="y" values="-40;{$height}" dur="6s" repeatCount="indefinite" />
    </rect>
    <rect x="8" y="0" width="{$inset}" height="2.5" fill="{$t['accent']}" opacity="0.9" />
  </g>
  {$brackets}
  <g transform="translate(20, 27)">
    <circle cx="-8" cy="-4" r="3" fill="{$t['accent']}" class="pulse-dot" />
    <text class="card-title fade-in" x="0" y="0">{$titleEsc}</text>
  </g>
  {$body}
</svg>
SVG;
}

/**
 * Una fila "label ......... value" con animacion de entrada escalonada
 * (delay creciente segun $index) para dar sensacion de carga secuencial.
 * Prefijo "›" para reforzar la estetica de log de terminal.
 */
function svg_stat_row(int $x, int $y, string $label, string $value, int $index): string
{
    $labelEsc = svg_esc($label);
    $valueEsc = svg_esc($value);
    $delay = 0.15 + $index * 0.1;
    return <<<SVG
  <g transform="translate({$x}, {$y})" style="opacity:0; animation: fadeIn 0.5s ease-out {$delay}s forwards;">
    <text class="stat-label" x="0" y="0">&#8250; {$labelEsc}</text>
    <text class="stat-value" x="150" y="0">{$valueEsc}</text>
  </g>
SVG;
}

/**
 * Anillo de progreso: el trazo crece desde 0 hasta el porcentaje real via
 * <animate> sobre stroke-dashoffset, sobre una pista de fondo visible (da
 * contexto de escala: se ve cuanto es el 100%, no solo el valor logrado).
 */
function svg_progress_ring(int $cx, int $cy, int $r, float $percent, string $color, string $centerLabel): string
{
    $t = svg_theme();
    $circumference = 2 * M_PI * $r;
    $offset = $circumference * (1 - max(0, min(100, $percent)) / 100);
    $labelEsc = svg_esc($centerLabel);

    return <<<SVG
  <g transform="translate({$cx}, {$cy})">
    <circle r="{$r}" fill="none" stroke="{$t['track']}" stroke-width="6" />
    <circle r="{$r}" fill="none" stroke="{$color}" stroke-width="6" stroke-linecap="round"
      stroke-dasharray="{$circumference}" stroke-dashoffset="{$circumference}"
      transform="rotate(-90)">
      <animate attributeName="stroke-dashoffset" from="{$circumference}" to="{$offset}"
        dur="1s" begin="0.3s" fill="freeze" calcMode="spline" keySplines="0.2 0.8 0.2 1" />
    </circle>
    <text text-anchor="middle" dominant-baseline="middle" class="stat-value" style="font-size:14px">{$labelEsc}</text>
  </g>
SVG;
}

/**
 * Barra horizontal que crece de 0 al ancho real via <animate> (usada por el
 * card de lenguajes), sobre una pista de fondo que marca el 100% -- asi se
 * ve la escala real, no solo el numero. $maxWidth es el ancho disponible
 * en px para el 100%.
 */
function svg_bar(int $x, int $y, int $maxWidth, float $percent, string $color, int $index): string
{
    $t = svg_theme();
    $targetWidth = round($maxWidth * max(0, min(100, $percent)) / 100, 1);
    $delay = 0.1 + $index * 0.12;
    return <<<SVG
  <rect x="{$x}" y="{$y}" width="{$maxWidth}" height="8" rx="4" fill="{$t['track']}" />
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
