<?php
/**
 * analytics_report.php - Agregacion pura para el panel de analitica
 * (lectura por post). Sin DB: recibe los agregados ya calculados.
 */

/**
 * Rutas de post para "Lectura por post" (MySQL REGEXP; tambien vale en PCRE).
 * Los posts viven en /blog/post/<slug>/ (+ /en y /ca). Fuera quedan el indice
 * /blog/, el molde legacy /blog/post/ (?slug=, sin slug en la ruta), rss.xml,
 * translations.json y /blog/covers/.
 */
const READING_PATH_REGEXP = '^(/(en|ca))?/blog/post/[^/]+/?$';

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

/**
 * true si el error es "la tabla no existe" (SQLSTATE 42S02 / MySQL 1146):
 * migracion pendiente. Cualquier otro error es un fallo real.
 */
function is_missing_table(Throwable $e): bool
{
    if (!$e instanceof PDOException) {
        return false;
    }
    $info = $e->errorInfo ?? null;
    if (is_array($info) && (($info[0] ?? '') === '42S02' || (int) ($info[1] ?? 0) === 1146)) {
        return true;
    }
    return (string) $e->getCode() === '42S02';
}
