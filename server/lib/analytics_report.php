<?php
/**
 * analytics_report.php - Agregacion pura para el panel de analitica
 * (lectura por post). Sin DB: recibe los agregados ya calculados.
 */

/** Visitas minimas para dar un porcentaje fiable en la lectura por post. */
const READING_MIN_VISITS = 5;

/** Umbral de scroll (%) que cuenta como "llego al final". */
const READING_DEEP_SCROLL = 90;

/**
 * Resume la lectura de una ruta de post.
 *
 * @param int        $visits    visitas de la ruta
 * @param int        $scrollN   visitas con scroll_pct no nulo
 * @param int        $deep      de ellas, las que llegaron a >= 90 %
 * @param float|null $avgDur    duracion media en segundos (null si no hay datos)
 * @param float|null $avgScroll scroll medio en % (null si no hay datos)
 * @return array{visits:int,few:bool,avg_duration:?int,avg_scroll:?int,deep_pct:?int}
 *   `few` = menos de READING_MIN_VISITS visitas: no se da porcentaje.
 *   `deep_pct` es null con pocos datos o sin visitas con scroll medido.
 */
function reading_summary(int $visits, int $scrollN, int $deep, ?float $avgDur, ?float $avgScroll): array
{
    $few = $visits < READING_MIN_VISITS;
    return [
        'visits'       => $visits,
        'few'          => $few,
        'avg_duration' => $avgDur === null ? null : (int) round($avgDur),
        'avg_scroll'   => $avgScroll === null ? null : (int) round($avgScroll),
        'deep_pct'     => ($few || $scrollN <= 0) ? null : (int) round(($deep / $scrollN) * 100),
    ];
}
