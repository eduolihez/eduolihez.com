<?php
/**
 * turnstile.php - Verificacion del captcha de Cloudflare Turnstile.
 * ---------------------------------------------------------------------------
 * turnstile_parse_response() es PURA (se testea sin red). turnstile_verify()
 * hace la llamada a Cloudflare y devuelve SIEMPRE un resultado con codigos:
 * antes devolvia solo true/false y cualquier fallo -- clave secreta mal
 * puesta, token caducado o repetido, el hosting sin salida a Cloudflare --
 * acababa en el mismo "Verificacion anti-bot fallida" sin pistas.
 *
 * Codigos de Cloudflare: missing-input-secret, invalid-input-secret,
 * missing-input-response, invalid-input-response, bad-request,
 * timeout-or-duplicate, internal-error. Los propios de aqui: no-response
 * (no se pudo contactar con Cloudflare), invalid-json, curl-error, unknown.
 */

const TURNSTILE_VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
const TURNSTILE_MAX_CODES = 5;

/**
 * Interpreta la respuesta cruda de siteverify.
 *
 * @param string|false|null $body
 * @return array{ok:bool,codes:string[]}
 */
function turnstile_parse_response($body): array
{
    if (!is_string($body) || $body === '') {
        return ['ok' => false, 'codes' => ['no-response']];
    }
    $json = json_decode($body, true);
    if (!is_array($json)) {
        return ['ok' => false, 'codes' => ['invalid-json']];
    }
    if (($json['success'] ?? null) === true) {
        return ['ok' => true, 'codes' => []];
    }

    // Los codigos vienen de un tercero y acaban en el log y en la respuesta:
    // solo se aceptan cadenas con forma de codigo.
    $codes = [];
    foreach ((array) ($json['error-codes'] ?? []) as $code) {
        if (is_string($code) && preg_match('/^[a-z0-9-]{1,40}$/', $code)) {
            $codes[] = $code;
        }
    }
    return ['ok' => false, 'codes' => array_slice($codes, 0, TURNSTILE_MAX_CODES) ?: ['unknown']];
}

/**
 * Verifica un token contra Cloudflare. Usa cURL si esta; si no, file_get_contents.
 *
 * @return array{ok:bool,codes:string[]}
 */
function turnstile_verify(string $secret, string $token, string $ip): array
{
    $data = ['secret' => $secret, 'response' => $token, 'remoteip' => $ip];

    $body = null;
    if (function_exists('curl_init')) {
        $ch = curl_init(TURNSTILE_VERIFY_URL);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => http_build_query($data),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT        => 8,
        ]);
        $body = curl_exec($ch);
        if ($body === false) {
            // Sin salida a Cloudflare o problema de certificados del hosting.
            error_log('[contact] turnstile: curl fallo: ' . curl_error($ch));
            curl_close($ch);
            return ['ok' => false, 'codes' => ['curl-error']];
        }
        curl_close($ch);
    } elseif (ini_get('allow_url_fopen')) {
        $ctx = stream_context_create([
            'http' => [
                'method'  => 'POST',
                'header'  => 'Content-Type: application/x-www-form-urlencoded',
                'content' => http_build_query($data),
                'timeout' => 8,
            ],
        ]);
        $body = @file_get_contents(TURNSTILE_VERIFY_URL, false, $ctx);
    }

    $result = turnstile_parse_response($body);
    if (!$result['ok']) {
        error_log('[contact] turnstile rechazado: ' . implode(',', $result['codes']));
    }
    return $result;
}
