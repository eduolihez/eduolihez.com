<?php
/**
 * Helpers HTTP compartidos por los endpoints del API.
 * - json(): responde JSON y termina.
 * - read_json_body(): lee el cuerpo de la peticion (JSON) como array.
 * - apply_cors(): cabeceras CORS solo si has configurado allowed_origin.
 * - require_method(): valida el metodo HTTP.
 */

require_once __DIR__ . '/bootstrap.php';

/** Responde con JSON y finaliza la ejecucion. */
function json($data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    // Evita que el navegador cachee respuestas del API por defecto.
    header('Cache-Control: no-store');
    // El API nunca debe indexarse ni interpretarse como otro tipo de contenido.
    send_security_headers(true);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

/** Lee y decodifica el cuerpo JSON de la peticion. Devuelve [] si no hay. */
function read_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return [];
    }
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

/**
 * Aplica cabeceras CORS SOLO si has definido un origen permitido en config.
 * Si el sitio y el API comparten dominio, no hace falta (deja allowed_origin='').
 */
function apply_cors(): void
{
    $origin = config()['security']['allowed_origin'] ?? '';
    if ($origin === '') {
        return; // mismo dominio: sin CORS
    }
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Accept');
    header('Vary: Origin');

    // Responde de inmediato a las peticiones preflight.
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

/** Exige un metodo HTTP concreto; si no coincide, responde 405. */
function require_method(string $method): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== $method) {
        json(['error' => 'Metodo no permitido'], 405);
    }
}

/**
 * Devuelve la IP real del cliente.
 *
 * SEGURIDAD: por defecto usamos REMOTE_ADDR (la IP de la conexion TCP), que
 * NO se puede falsear. Las cabeceras tipo X-Forwarded-For / CF-Connecting-IP
 * SI se pueden falsear si el hosting no esta detras de un proxy de confianza,
 * y permitirian saltarse el rate-limit. Por eso solo las usamos cuando tu
 * config declara explicitamente 'trust_proxy' => true (p.ej. con Cloudflare).
 */
function client_ip(): string
{
    $trustProxy = config()['security']['trust_proxy'] ?? false;

    if ($trustProxy) {
        // Solo con proxy/CDN de confianza (Cloudflare pone la IP real aqui).
        foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR'] as $key) {
            if (!empty($_SERVER[$key])) {
                $ip = trim(explode(',', $_SERVER[$key])[0]);
                if (filter_var($ip, FILTER_VALIDATE_IP)) {
                    return $ip;
                }
            }
        }
    }

    $remote = $_SERVER['REMOTE_ADDR'] ?? '';
    return filter_var($remote, FILTER_VALIDATE_IP) ? $remote : '0.0.0.0';
}
