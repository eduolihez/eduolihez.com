<?php
/**
 * post.php - Helpers del blog compartidos por el API y el panel.
 *
 * Estan aqui y no duplicados en cada endpoint para que el listado y el detalle
 * no puedan discrepar: seria facil que uno normalizase las etiquetas y el otro
 * no, y que la misma entrada se viera distinta segun desde donde se abriera.
 */

/**
 * Convierte la cadena CSV de la columna `tags` en una lista limpia.
 *
 * Se guarda como texto separado por comas porque son un punado por articulo y
 * no hace falta una tabla aparte. A cambio, hay que normalizar al leer: la
 * columna la rellena una persona a mano y llegan espacios sobrantes, comas
 * dobles y mayusculas inconsistentes.
 *
 * @return string[] Etiquetas sin vacios ni repetidas, en minusculas.
 */
function post_tags(?string $raw): array
{
    if ($raw === null || trim($raw) === '') {
        return [];
    }
    $tags = array_map(
        static fn(string $t): string => mb_strtolower(trim($t)),
        explode(',', $raw)
    );
    // array_values para que json_encode lo serialice como lista y no como
    // objeto: array_unique conserva los indices originales y un hueco basta
    // para que el JSON salga {"0":...,"2":...} en vez de [...].
    return array_values(array_unique(array_filter(
        $tags,
        static fn(string $t): bool => $t !== ''
    )));
}

/**
 * Estima los minutos de lectura a partir del numero de caracteres del cuerpo.
 *
 * Se calcula sobre la longitud en bruto (con etiquetas HTML incluidas) porque
 * el dato viene de un CHAR_LENGTH en SQL y asi no hace falta traerse el
 * articulo entero solo para medirlo. El marcado infla la cuenta, y por eso el
 * divisor es mas alto que los ~1.000 caracteres de texto plano por minuto que
 * se suelen usar. Es una estimacion para orientar al lector, no una medida.
 */
function post_read_minutes(int $contentLength): int
{
    return max(1, (int) ceil($contentLength / 1400));
}
