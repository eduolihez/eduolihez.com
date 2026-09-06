<?php
/**
 * POST /api/events.php - ingesta de telemetria para admin.eduolihez.com
 * (docs/designs/admin-dashboard.md). Cada app registrada en `apps` manda
 * aqui sus eventos (instalaciones, errores, clics...); apareceran en su
 * sub-dashboard.
 *
 * Cuerpo esperado (JSON):
 *   { "event_id": "<uuid del cliente>", "type": "install|error|...", "payload": {...} }
 *
 * Auth: cabecera X-API-Key (se compara su SHA-256 contra apps.api_key_hash,
 * nunca se guarda la clave en claro).
 *
 * El Origin (si el cliente lo manda) se valida contra apps.allowed_origins
 * como defensa en profundidad -- CORS por si solo no evita que la peticion
 * LLEGUE al servidor, solo que el navegador deje leer la respuesta. La clave
 * de API sigue siendo el limite real de autorizacion; esto es una capa mas,
 * no un sustituto. Un cliente sin cabecera Origin (un programa standalone,
 * no un navegador) no la manda nunca, asi que su ausencia no se rechaza --
 * solo se valida cuando esta presente y no coincide.
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/validate.php';

/** Techo del body aceptado, en bytes. Ver Next Steps del diseno: firme, no ilustrativo. */
const EVENTS_MAX_BODY_BYTES = 16384;

/** Peticiones por minuto permitidas por clave de API (contador de ventana fija en MySQL). */
const EVENTS_RATE_PER_KEY_PER_MIN = 120;

/** Peticiones por minuto permitidas por IP, ANTES de identificar la clave -- frena
 *  fuerza bruta de claves invalidas, que nunca llegan al contador de arriba. */
const EVENTS_RATE_PER_IP_PER_MIN = 300;

/**
 * Cabeceras CORS para este endpoint especifico: el origen permitido depende
 * de la APP (apps.allowed_origins), no es un unico valor fijo de config como
 * apply_cors() en lib/http.php -- por eso este endpoint no la reutiliza.
 *
 * Se llama tanto en el preflight OPTIONS (antes de conocer la app, con el
 * origen recibido reflejado solo si hay una app que lo declare) como en la
 * respuesta real.
 */
function events_cors(?array $app): void
{
    $origin = (string) ($_SERVER['HTTP_ORIGIN'] ?? '');
    if ($origin === '') {
        return;
    }
    if ($app !== null && events_origin_allowed($origin, $app)) {
        // Nunca un wildcard ni el array entero: solo el valor exacto que coincidio.
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Vary: Origin');
    }
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: X-API-Key, Content-Type');
}

/**
 * Decodifica apps.allowed_origins (JSON) y delega la comparacion exacta a
 * origin_is_allowed() (lib/validate.php, testeada por separado porque no
 * toca la BD). Esta funcion si conoce la forma de la fila de `apps`, por
 * eso vive aqui y no en la libreria compartida.
 */
function events_origin_allowed(string $origin, array $app): bool
{
    $allowed = json_decode((string) ($app['allowed_origins'] ?? '[]'), true);
    return is_array($allowed) && origin_is_allowed($origin, $allowed);
}

/**
 * Hash de IP para el log de rate-limit. Misma sal y misma forma que
 * visit.php ($ip . '|' . $salt), sin cair en silencio a un hash debil si
 * falta la sal en config() -- por eso no usa `?? ''`.
 */
function events_ip_hash(string $ip): ?string
{
    $salt = (string) (config()['security']['ip_salt'] ?? '');
    if ($salt === '') {
        return null;
    }
    return hash('sha256', $ip . '|' . $salt);
}

/** Cuenta peticiones recientes de una IP a este endpoint (rate-limit por IP, pre-auth). */
function events_ip_rate_exceeded(string $ip): bool
{
    $hash = events_ip_hash($ip);
    if ($hash === null) {
        return false; // sin sal configurada, no podemos hashear -- no bloqueamos por esto
    }
    try {
        $st = db()->prepare(
            'SELECT COUNT(*) FROM app_events_ip_log WHERE ip_hash = ? AND created_at > (NOW() - INTERVAL 1 MINUTE)'
        );
        $st->execute([$hash]);
        return (int) $st->fetchColumn() >= EVENTS_RATE_PER_IP_PER_MIN;
    } catch (Throwable $e) {
        return false; // si el log de IP falla, no bloqueamos peticiones legitimas
    }
}

/** Registra esta peticion en el log de IP (ventana fija de 1 minuto, purgado por TTL natural del COUNT). */
function events_ip_rate_record(string $ip): void
{
    $hash = events_ip_hash($ip);
    if ($hash === null) {
        return;
    }
    try {
        db()->prepare('INSERT INTO app_events_ip_log (ip_hash, created_at) VALUES (?, NOW())')
            ->execute([$hash]);
    } catch (Throwable $e) {
        // no bloqueamos el flujo si el registro falla
    }
}

/** Cuenta eventos recientes de una app (rate-limit por clave, post-auth). */
function events_key_rate_exceeded(int $appId): bool
{
    try {
        $st = db()->prepare(
            'SELECT COUNT(*) FROM app_events WHERE app_id = ? AND created_at > (NOW() - INTERVAL 1 MINUTE)'
        );
        $st->execute([$appId]);
        return (int) $st->fetchColumn() >= EVENTS_RATE_PER_KEY_PER_MIN;
    } catch (Throwable $e) {
        return false;
    }
}

/** Busca la app duena de una clave de API por su hash. Null si no coincide ninguna. */
function events_find_app(string $rawKey): ?array
{
    if ($rawKey === '') {
        return null;
    }
    $hash = hash('sha256', $rawKey);
    $st = db()->prepare('SELECT id, allowed_origins FROM apps WHERE api_key_hash = ? LIMIT 1');
    $st->execute([$hash]);
    $row = $st->fetch();
    return $row ?: null;
}

// --- Preflight: responde ANTES de leer el body o exigir auth --------------
// El navegador manda OPTIONS sin la cabecera X-API-Key (no la conoce hasta
// que la peticion real la envia), asi que este endpoint no puede exigir
// auth aqui. Sin una app identificada todavia, solo se listan los metodos y
// cabeceras aceptados; el Access-Control-Allow-Origin del preflight se
// valida igual en la respuesta real de abajo.
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    $originHeader = (string) ($_SERVER['HTTP_ORIGIN'] ?? '');
    $preflightApp = null;
    if ($originHeader !== '') {
        // Busca CUALQUIER app que declare este origen, solo para el preflight:
        // no autentica nada, solo decide si vale la pena reflejar el origen.
        try {
            $st = db()->prepare('SELECT allowed_origins FROM apps WHERE allowed_origins IS NOT NULL');
            $st->execute();
            foreach ($st->fetchAll() as $row) {
                if (events_origin_allowed($originHeader, $row)) {
                    $preflightApp = $row;
                    break;
                }
            }
        } catch (Throwable $e) {
            // sin apps que consultar (o fallo de BD): preflight sin origen reflejado
        }
    }
    events_cors($preflightApp);
    http_response_code(204);
    exit;
}

require_method('POST');

$ip = client_ip();
if (events_ip_rate_exceeded($ip)) {
    events_cors(null);
    json(['error' => 'Demasiadas peticiones.'], 429);
}
events_ip_rate_record($ip);

$rawKey = (string) ($_SERVER['HTTP_X_API_KEY'] ?? '');
$app = events_find_app($rawKey);
if ($app === null) {
    events_cors(null);
    json(['error' => 'Clave de API invalida o ausente.'], 401);
}

$origin = (string) ($_SERVER['HTTP_ORIGIN'] ?? '');
if ($origin !== '' && !events_origin_allowed($origin, $app)) {
    events_cors(null);
    json(['error' => 'Origen no permitido para esta app.'], 403);
}
events_cors($app);

if (events_key_rate_exceeded((int) $app['id'])) {
    json(['error' => 'Demasiadas peticiones.'], 429);
}

// --- Validacion del cuerpo ---------------------------------------------------
// Un solo check para TODAS las formas de "cuerpo malformado" (JSON invalido,
// campos ausentes, payload no-objeto, body demasiado grande): 422 uniforme,
// sin un codigo distinto por tipo de fallo (decision de plan-eng-review,
// 2026-09-04 -- ninguno de los clientes de este endpoint mira la diferencia).
$raw = file_get_contents('php://input');
if ($raw === false || strlen($raw) > EVENTS_MAX_BODY_BYTES) {
    json(['error' => 'Cuerpo invalido.'], 422);
}

$body = json_decode($raw, true);
if (validate_event_body($body) !== null) {
    json(['error' => 'Cuerpo invalido.'], 422);
}
$eventId = (string) $body['event_id'];
$type    = (string) $body['type'];
$payload = $body['payload'] ?? null;

// --- Insercion con deduplicacion ---------------------------------------------
// UNIQUE KEY (app_id, event_id) en el schema hace que un event_id repetido
// (reintento de un cliente ante un fallo de red) nunca duplique la fila.
// INSERT IGNORE + comprobar filas afectadas distingue "nuevo" de "duplicado"
// sin necesitar una consulta SELECT previa.
try {
    $stmt = db()->prepare(
        'INSERT IGNORE INTO app_events (app_id, event_id, type, payload, created_at)
         VALUES (?, ?, ?, ?, NOW())'
    );
    $stmt->execute([
        (int) $app['id'],
        mb_substr($eventId, 0, 64),
        mb_substr($type, 0, 60),
        $payload !== null ? json_encode($payload, JSON_UNESCAPED_UNICODE) : null,
    ]);
    $isDuplicate = $stmt->rowCount() === 0;
} catch (Throwable $e) {
    json(['error' => 'No se pudo guardar el evento.'], 500);
}

// Purga probabilistica, mismo patron que server/api/visit.php: ~1% de las
// veces borra lo caducado, sin necesidad de cron.
if (random_int(1, 100) === 1) {
    try {
        db()->query('DELETE FROM app_events WHERE created_at < (NOW() - INTERVAL 400 DAY)');
        db()->query('DELETE FROM app_events_ip_log WHERE created_at < (NOW() - INTERVAL 1 DAY)');
    } catch (Throwable $e) {
        // no bloqueamos la respuesta si la purga falla
    }
}

json(['ok' => true], $isDuplicate ? 200 : 202);
