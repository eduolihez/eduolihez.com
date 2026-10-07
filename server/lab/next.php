<?php
/**
 * next.php - Validacion del parametro "next" del login de lab.eduolihez.com.
 *
 * Archivo puro, sin sesion ni cabeceras, para poder testearlo en PHPUnit
 * (server/lab/auth.php abre su propia sesion y fija su CSP al cargarse).
 */

/**
 * Devuelve $next si es una ruta del propio host, o '' si no lo es.
 *
 * "Ruta del propio host" = empieza por UNA sola barra y no contiene nada que
 * un navegador pueda reinterpretar. Comprobar solo que no empiece por "//" no
 * basta: los navegadores convierten la barra invertida en barra, asi que
 * "/\evil.com" acaba siendo "//evil.com" (protocol-relative, otro dominio) y
 * un tabulador o un salto de linea se descartan antes de interpretar la URL.
 * Por eso se rechazan tambien "\", los caracteres de control, el espacio y el
 * DEL. Lo codificado en porcentaje (%5C, %09...) no cambia de host y se deja.
 */
function lab_safe_next(string $next): string
{
    if ($next === '' || strlen($next) > 1024) {
        return '';
    }
    if ($next[0] !== '/' || (isset($next[1]) && ($next[1] === '/' || $next[1] === '\\'))) {
        return '';
    }
    if (preg_match('/[\x00-\x20\x7f\\\\]/', $next) === 1) {
        return '';
    }
    return $next;
}
