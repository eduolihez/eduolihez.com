<?php
/**
 * Helpers puros de presentacion de analytics.php: sin require, sin BD y sin
 * sesion, para poder testearlos en la suite PHPUnit (ver tests/bootstrap.php).
 * El HTML que reciben como parametro es de confianza (ya escapado por el
 * llamador); lo que viene de datos se escapa aqui con e().
 */

/**
 * Tabla larga: las 10 primeras filas a la vista y el resto dentro de un
 * <details> nativo (sin JS). $rowHtml devuelve el <tr> ya escapado.
 */
function long_table(string $theadHtml, array $rows, callable $rowHtml, string $emptyRowHtml): string
{
    $table = static function (array $part, string $body = '') use ($theadHtml, $rowHtml): string {
        foreach ($part as $r) {
            $body .= $rowHtml($r);
        }
        return '<div class="scroll-x"><table><thead>' . $theadHtml . '</thead><tbody>' . $body . '</tbody></table></div>';
    };
    if (!$rows) {
        return $table([], $emptyRowHtml);
    }
    $html = $table(array_slice($rows, 0, 10));
    if (count($rows) > 10) {
        $html .= '<details class="more-rows"><summary>Ver todo (' . count($rows) . ')</summary>'
            . $table(array_slice($rows, 10)) . '</details>';
    }
    return $html;
}

/**
 * Cada cuantas columnas de un grafico se pinta la etiqueta del eje X para no
 * pasar de $maxTicks etiquetas (a 390 px no caben 30 fechas).
 */
function chart_tick_step(int $columns, int $maxTicks = 8): int
{
    if ($columns <= $maxTicks || $maxTicks < 1) {
        return 1;
    }
    return (int) ceil($columns / $maxTicks);
}

/**
 * Texto alternativo de un grafico de barras (role="img"): total y, si lo hay,
 * el mejor tramo. $best = ['label' => ..., 'c' => int] o null.
 */
function chart_aria_label(string $title, int $total, ?array $best, ?int $prevTotal = null): string
{
    $txt = $title . ': ' . number_format($total, 0, ',', '.') . ' visitas en total';
    if ($best !== null && (int) $best['c'] > 0) {
        $txt .= '; mejor: ' . $best['label'] . ' (' . number_format((int) $best['c'], 0, ',', '.') . ')';
    }
    if ($prevTotal !== null) {
        $txt .= '; periodo anterior: ' . number_format($prevTotal, 0, ',', '.') . ' visitas';
    }
    return $txt . '.';
}

/** Rangos de dias admitidos en analytics.php (allowlist: nunca se interpola otro valor). */
const ANALYTICS_ALLOWED_DAYS = [1, 7, 14, 30, 90, 365];
const ANALYTICS_DEFAULT_DAYS = 30;

/** Dominio publico al que apuntan las rutas de Global y Site. */
const ANALYTICS_PUBLIC_BASE = 'https://eduolihez.com';

/**
 * Filtros de analytics.php: ['days' => int, 'bots' => bool]. Con ?days= en la
 * URL mandan $get (y bots solo si bots=1: el form siempre envia days, asi que
 * desmarcar la casilla da false). Sin ?days= se usa lo recordado en
 * $session['admin_analytics']. La allowlist $allowed decide siempre.
 */
function analytics_filters(array $get, array $session, array $allowed = ANALYTICS_ALLOWED_DAYS, int $default = ANALYTICS_DEFAULT_DAYS): array
{
    if (array_key_exists('days', $get)) {
        $raw  = $get['days'];
        $days = is_string($raw) && ctype_digit($raw) ? (int) $raw : $default;
        $bots = ($get['bots'] ?? '') === '1';
    } else {
        $saved = is_array($session['admin_analytics'] ?? null) ? $session['admin_analytics'] : [];
        $days  = is_int($saved['days'] ?? null) ? $saved['days'] : $default;
        $bots  = ($saved['bots'] ?? false) === true;
    }
    if (!in_array($days, $allowed, true)) {
        $days = $default;
    }
    return ['days' => $days, 'bots' => $bots];
}

/**
 * URL publica de una ruta registrada, o '' si no se debe enlazar: solo en
 * Global y Site (en PhishLab y apps el dominio es otro) y solo rutas que
 * empiezan por una unica "/" (fuera "//host", esquemas y caracteres de control).
 */
function public_page_url(string $path, string $space): string
{
    if ($space !== 'global' && $space !== 'site') {
        return '';
    }
    // \x5c = barra invertida (algunos navegadores la tratan como "/").
    if (!preg_match('#^/(?![/\x5c])[^\s\x5c]*$#', $path)) {
        return '';
    }
    return ANALYTICS_PUBLIC_BASE . $path;
}

/**
 * Celda de ruta de la tabla de 404: la ruta (enlazada a la web publica si
 * public_page_url() lo permite) y un boton que la copia con [data-copy].
 * El id del <code> sale de un hash de la ruta: unico aunque las filas se
 * repartan entre la tabla visible y el <details> de long_table().
 */
function not_found_path_cell(string $path, string $space): string
{
    $id  = 'nf-' . substr(md5($path), 0, 10);
    $url = public_page_url($path, $space);
    $code = '<code id="' . $id . '">' . e($path) . '</code>';
    if ($url !== '') {
        $code = '<a href="' . e($url) . '" target="_blank" rel="noopener">' . $code . '</a>';
    }
    return '<td class="path-cell">' . $code
        . ' <button type="button" class="btn ghost sm" data-copy="#' . $id . '" aria-label="Copiar ruta ' . e($path) . '">Copiar</button></td>';
}

/** Tasa de rebote en % (0-100, redondeada); null sin sesiones (evita dividir por cero). */
function bounce_rate(int $bounced, int $sessions): ?float
{
    return $sessions > 0 ? round(($bounced / $sessions) * 100) : null;
}

/**
 * Variacion porcentual de una metrica frente al periodo anterior, con el
 * mismo marcado que delta_badge(). $lowerIsBetter (rebote): bajar se pinta
 * como mejora (clase up) y subir como empeoramiento (down). Sin valor previo
 * (null o 0: no hay base para un %) devuelve ''.
 */
function metric_delta_badge(?float $now, ?float $before, bool $lowerIsBetter = false): string
{
    if ($now === null || $before === null || $before == 0.0) {
        return '';
    }
    $pct = (int) round((($now - $before) / $before) * 100);
    $good = $lowerIsBetter ? $pct < 0 : $pct > 0;
    $cls = $pct === 0 ? 'flat' : ($good ? 'up' : 'down');
    return '<span class="delta ' . $cls . '">' . ($pct > 0 ? '+' : '') . $pct . '%</span>';
}

/** Rangos de mas de 60 dias se agregan por semanas en el grafico. */
function chart_uses_weeks(int $days): bool
{
    return $days > 60;
}

/**
 * Serie del grafico a partir de filas SQL ya agrupadas. $keys: claves de los
 * tramos en orden (fechas Y-m-d o indices de semana); $labels: etiqueta corta
 * de cada clave. $rows: filas ['k','c','u']; $prevRows: ['k','c'] del periodo
 * anterior ya desplazadas a la clave equivalente. Huecos -> 0.
 * Devuelve [['k','label','c','u','p'], ...].
 */
function build_chart_series(array $keys, array $labels, array $rows, array $prevRows): array
{
    $cur = $prev = [];
    foreach ($rows as $r) {
        $cur[(string) $r['k']] = ['c' => (int) $r['c'], 'u' => (int) ($r['u'] ?? 0)];
    }
    foreach ($prevRows as $r) {
        $prev[(string) $r['k']] = (int) $r['c'];
    }
    $out = [];
    foreach ($keys as $i => $k) {
        $k = (string) $k;
        $out[] = [
            'k'     => $k,
            'label' => (string) ($labels[$i] ?? $k),
            'c'     => $cur[$k]['c'] ?? 0,
            'u'     => $cur[$k]['u'] ?? 0,
            'p'     => $prev[$k] ?? 0,
        ];
    }
    return $out;
}

/**
 * Claves y etiquetas de los tramos semanales de un rango de $days dias,
 * del mas antiguo al actual. Semana w = dias atras FLOOR(DATEDIFF/7); la
 * etiqueta es el primer dia del tramo (d/m) relativo a $today (Y-m-d).
 * @return array{0: list<int>, 1: list<string>}
 */
function week_buckets(int $days, string $today): array
{
    $n = max(1, (int) ceil($days / 7));
    $base = strtotime($today);
    $keys = $labels = [];
    for ($w = $n - 1; $w >= 0; $w--) {
        $keys[] = $w;
        $labels[] = date('d/m', strtotime('-' . ($w * 7 + 6) . ' day', $base));
    }
    return [$keys, $labels];
}

/** Escala del grafico: maximo entre periodo actual y anterior (minimo 1). */
function chart_series_max(array $series): int
{
    $max = 1;
    foreach ($series as $r) {
        $max = max($max, (int) $r['c'], (int) $r['p']);
    }
    return $max;
}
