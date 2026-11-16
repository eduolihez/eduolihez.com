<?php
/**
 * events.php - Validacion pura de eventos de la analitica propia.
 * Sin BD ni sesion: se testea con PHPUnit (server/tests/EventsTest.php).
 * Lo usa server/api/visit.php (action=event).
 */

/** Nombres de evento permitidos (allowlist). */
const EVENT_NAMES = ['cv_open', 'outbound', 'lang_switch', 'theme_toggle', 'contact_submit', 'not_found'];

/**
 * Valida y limpia un evento. Devuelve [name, target, path, session_id] o null
 * si algo no cuadra (el llamador responde 204 sin insertar).
 *   - outbound: target = hostname en minusculas, obligatorio.
 *   - lang_switch: target obligatorio, es|en|ca.
 *   - theme_toggle: target light|dark o vacio.
 *   - cv_open / contact_submit / not_found: sin target.
 * path ausente = '/' (igual que el "hit"); session_id invalido = null.
 */
function normalize_event(array $in): ?array
{
    $name = $in['name'] ?? null;
    if (!is_string($name) || !in_array($name, EVENT_NAMES, true)) {
        return null;
    }

    $rawTarget = $in['target'] ?? null;
    if ($rawTarget !== null && !is_string($rawTarget)) {
        return null;
    }
    $target = ($rawTarget === null || $rawTarget === '') ? null : $rawTarget;

    switch ($name) {
        case 'outbound':
            if ($target === null || !preg_match('/^[a-z0-9.-]{1,80}\z/', $target)) {
                return null;
            }
            break;
        case 'lang_switch':
            if (!in_array($target, ['es', 'en', 'ca'], true)) {
                return null;
            }
            break;
        case 'theme_toggle':
            if ($target !== null && !in_array($target, ['light', 'dark'], true)) {
                return null;
            }
            break;
        default:
            if ($target !== null) {
                return null;
            }
    }

    $path = $in['path'] ?? '/';
    if (!is_string($path) || strlen($path) > 120 || !preg_match('#^/[a-zA-Z0-9/_\-.]*\z#', $path)) {
        return null;
    }

    $session = $in['session_id'] ?? null;
    $session = (is_string($session) && preg_match('/^[a-f0-9]{16}\z/', $session)) ? $session : null;

    return ['name' => $name, 'target' => $target, 'path' => $path, 'session_id' => $session];
}

/** Topes por minuto de site_events (sin ip_hash: global, por sesion y sin sesion). */
const EVENT_CAP_TOTAL = 300;
const EVENT_CAP_SESSION = 20;
const EVENT_CAP_NO_SESSION = 30;

/**
 * Decide si un evento supera el tope del ultimo minuto.
 *   $total = eventos de todos en el minuto.
 *   $mine  = eventos con el mismo session_id (con session_id null, los que
 *            tampoco tienen sesion: asi los anonimos comparten un cupo bajo
 *            propio y no consumen el global).
 */
function event_over_cap(int $total, int $mine, ?string $sessionId): bool
{
    if ($total >= EVENT_CAP_TOTAL) {
        return true;
    }
    return $mine >= ($sessionId === null ? EVENT_CAP_NO_SESSION : EVENT_CAP_SESSION);
}

/** DNT: 1 o Sec-GPC: 1 en la peticion: no se guarda nada (hit, beat ni event). */
function event_privacy_opt_out(array $server): bool
{
    return ($server['HTTP_DNT'] ?? '') === '1' || ($server['HTTP_SEC_GPC'] ?? '') === '1';
}
