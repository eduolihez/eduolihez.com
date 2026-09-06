<?php
/**
 * validate.php - Validaciones compartidas de los formularios de /admin.
 */

/**
 * Comprueba que una URL publica (algo que el frontend va a poner en un
 * href/src) solo pueda ser https:// o una ruta interna -- nunca javascript:,
 * data: ni cualquier otro esquema ejecutable. Vacio es valido (campo
 * opcional en los tres formularios que la usan).
 *
 * Antes esta misma regla vivia copiada tres veces (settings.php,
 * project-edit.php, cert-edit.php); una sola fuente de verdad para el
 * esquema permitido y su porque.
 *
 * Nota de paridad: esto exige https:// (nunca http:// sin la "s"), a
 * diferencia de safeUrl() en src/scripts/shared.ts (acepta http:// tambien).
 * Es intencional en direcciones distintas: esto valida lo que un ADMIN
 * escribe a mano (fuerza https, coherente con que todo el sitio fuerza TLS);
 * shared.ts valida datos que YA estan en la API publica (enlaces a terceros
 * como GitHub/Credly, donde exigir https podria ocultar un enlace real). No
 * hay un tipo compartido entre PHP y TS que fuerce que ambas reglas
 * evolucionen juntas -- si cambias el esquema aceptado aqui, revisa tambien
 * el otro lado.
 *
 * @param string $label Nombre del campo tal y como debe salir en el error
 *                       (ej. "El enlace del aviso", "La URL de la imagen").
 * @return string|null  El mensaje de error si no es valida, o null si esta bien.
 */
function validate_public_url(string $value, string $label): ?string
{
    if ($value === '') {
        return null;
    }

    // Bypass de "empieza por /" (auditoria de seguridad del 2026-08-25, dos
    // rondas -- ver server/tests/ValidateTest.php para el porque de cada
    // caso):
    //
    // 1) Los navegadores tratan "\" como equivalente a "/" al parsear una
    //    URL con esquema especial (http/https/ws/wss/ftp/file) -- es
    //    compatibilidad heredada de IE, parte del propio estandar WHATWG
    //    URL. "/\evil.example/x" EMPIEZA por "/" (pasaria un check ingenuo)
    //    pero el navegador lo resuelve como "//evil.example/x": protocolo-
    //    relativo a un dominio externo.
    // 2) El parser WHATWG tambien QUITA cualquier tabulador, salto de linea
    //    o retorno de carro (\t \n \r) de CUALQUIER posicion de la URL --no
    //    solo al principio o al final-- antes de interpretarla. Por eso
    //    "/\t/evil.example/x" (una tabulacion real entre las dos barras) NO
    //    contiene "\" literal ni empieza por "//" tal cual, pero el
    //    navegador la reduce a "//evil.example/x" igual que el caso 1.
    //
    // Se corta ANTES del check de esquema, no despues.
    if (
        str_contains($value, '\\')
        || preg_match('#^//#', $value)
        || preg_match('/[\x09\x0A\x0D]/', $value)
    ) {
        return "{$label} no es una ruta interna valida (contiene una secuencia que el navegador podria interpretar como un dominio externo).";
    }

    if (!preg_match('#^(https://|/)#i', $value)) {
        return "{$label} debe empezar por https:// o por / (ruta interna).";
    }
    return null;
}

/**
 * Compara un Origin de peticion contra la lista de origenes permitidos de
 * una app (server/api/events.php). SIEMPRE comparacion exacta de string,
 * nunca prefijo/substring/regex -- un check laxo es bypasseable, mismo
 * motivo que la regla de barra invertida de validate_public_url() de arriba.
 * Soporta esquemas de extension de navegador (chrome-extension://,
 * moz-extension://) ademas de https://, que es el caso de uso real.
 *
 * Extraida como funcion pura (sin tocar la BD) para poder testearla: la
 * decodificacion del JSON guardado en apps.allowed_origins vive en
 * events.php, que si toca la BD y por eso no tiene test unitario, igual que
 * el resto de endpoints de server/api/ (ver server/tests/bootstrap.php).
 */
function origin_is_allowed(string $origin, array $allowedOrigins): bool
{
    foreach ($allowedOrigins as $candidate) {
        if (is_string($candidate) && hash_equals($candidate, $origin)) {
            return true;
        }
    }
    return false;
}

/**
 * Valida la forma del body de POST /api/events.php (server/api/events.php):
 * event_id y type son strings no vacios, payload es opcional pero si esta
 * presente debe ser un objeto JSON (array asociativo en PHP). Devuelve el
 * mensaje de error, o null si el body es valido.
 *
 * $body es lo que devuelve json_decode($raw, true) -- puede ser cualquier
 * cosa (null si el JSON no parseaba, un escalar, una lista...), de ahi el
 * mixed en la firma en vez de exigir array desde fuera.
 */
function validate_event_body(mixed $body): ?string
{
    if (!is_array($body)) {
        return 'Cuerpo invalido.';
    }
    $eventId = $body['event_id'] ?? '';
    $type    = $body['type'] ?? '';
    $payload = $body['payload'] ?? null;

    // is_string() explicito, no solo "no vacio": un event_id/type que llega
    // como numero, bool, array u objeto JSON debe rechazarse, no coaccionarse
    // en silencio a texto -- (string) sobre un array dispara un warning de
    // PHP y guardaria literalmente el texto "Array" como si fuera valido.
    if (!is_string($eventId) || $eventId === '' || !is_string($type) || $type === '') {
        return 'Cuerpo invalido.';
    }
    if ($payload !== null) {
        // json_decode(..., true) no distingue un objeto JSON ({...}) de una
        // lista JSON ([...]): ambos son array en PHP. array_is_list()
        // detecta el caso lista (indices 0..n-1 consecutivos) para
        // rechazarlo -- el payload debe ser un objeto, no un array suelto.
        // Un array vacio es ambiguo ({} y [] decodifican igual) y se acepta.
        if (!is_array($payload) || ($payload !== [] && array_is_list($payload))) {
            return 'Cuerpo invalido.';
        }
    }
    return null;
}
