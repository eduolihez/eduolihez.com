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
function chart_aria_label(string $title, int $total, ?array $best): string
{
    $txt = $title . ': ' . number_format($total, 0, ',', '.') . ' visitas en total';
    if ($best !== null && (int) $best['c'] > 0) {
        $txt .= '; mejor: ' . $best['label'] . ' (' . number_format((int) $best['c'], 0, ',', '.') . ')';
    }
    return $txt . '.';
}
