<?php
/**
 * POST /api/visit.php
 * Registra una visita para la analitica propia (sin terceros).
 * La IP se guarda HASHEADA con una sal (no se almacena la IP real) para
 * respetar la privacidad y poder contar visitantes unicos aproximados.
 *
 * Se llama desde el frontend con navigator.sendBeacon(), por eso aceptamos
 * el cuerpo tanto en JSON como en texto plano.
 *
 * Defensas (todas silenciosas: la analitica nunca debe estorbar al visitante):
 *   - Solo se aceptan rutas con formato de URL interna (nada de basura de 255
 *     caracteres inventada por un bot para inflar la tabla).
 *   - Tope de visitas por visitante y minuto (config: visit_max_per_minute).
 *   - Deduplicado de 30 s por visitante+ruta.
 *   - Se puede desactivar del todo desde el panel (ajuste analytics_enabled).
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/ua.php';

apply_cors();

/** Responde 204 (sin cuerpo) y termina. La analitica nunca devuelve errores. */
function no_content(): void
{
    http_response_code(204);
    exit;
}

// sendBeacon puede enviar POST; toleramos solo POST.
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    no_content();
}

// Interruptor general desde el panel.
if (!setting_on('analytics_enabled', true)) {
    no_content();
}

$input = read_json_body();

// --- Ruta: solo aceptamos rutas internas con caracteres razonables ----------
$path = trim((string) ($input['path'] ?? '/'));
if ($path === '' || $path[0] !== '/' || strlen($path) > 120
    || !preg_match('#^/[a-zA-Z0-9/_\-.]*$#', $path)) {
    no_content();
}

// --- Referrer: guardamos solo esquema + host + ruta, sin query ni fragmento.
// Asi no se cuelan tokens ni datos personales de otras webs en nuestra BD.
$referrer = '';
$rawRef = trim((string) ($input['referrer'] ?? ''));
if ($rawRef !== '' && preg_match('#^https?://#i', $rawRef)) {
    $parts = parse_url($rawRef);
    if (!empty($parts['host'])) {
        $referrer = mb_substr(
            strtolower($parts['scheme'] ?? 'https') . '://' . strtolower($parts['host'])
                . ($parts['path'] ?? ''),
            0,
            255
        );
    }
}

$ua = mb_substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255);
$info = ua_parse($ua);

// Pais si el hosting/CDN lo aporta (CDMON/Cloudflare). Opcional.
$country = strtoupper(mb_substr((string) ($_SERVER['HTTP_CF_IPCOUNTRY'] ?? ''), 0, 2));
if (!preg_match('/^[A-Z]{2}$/', $country)) {
    $country = '';
}

// Idioma de la pagina visitada, deducido de la ruta (/en/... , /ca/...).
$lang = 'es';
if (preg_match('#^/(en|ca)(/|$)#', $path, $m)) {
    $lang = $m[1];
}

// Hash de la IP con sal (privacidad).
$salt   = config()['security']['ip_salt'] ?? 'default_salt';
$ipHash = hash('sha256', client_ip() . '|' . $salt);

try {
    // Anti-flood 1: tope por visitante y minuto (evita que un bot que cambia
    // de ruta constantemente llene la tabla).
    $maxPerMin = (int) (config()['security']['visit_max_per_minute'] ?? 30);
    if ($maxPerMin > 0) {
        $cap = db()->prepare(
            'SELECT COUNT(*) FROM visits
             WHERE ip_hash = ? AND visited_at > (NOW() - INTERVAL 1 MINUTE)'
        );
        $cap->execute([$ipHash]);
        if ((int) $cap->fetchColumn() >= $maxPerMin) {
            no_content();
        }
    }

    // Anti-flood 2: ignora visitas repetidas del mismo visitante a la misma
    // pagina en menos de 30 s (recargas rapidas).
    $dedupe = db()->prepare(
        "SELECT 1 FROM visits
         WHERE ip_hash = ? AND path = ? AND visited_at > (NOW() - INTERVAL 30 SECOND)
         LIMIT 1"
    );
    $dedupe->execute([$ipHash, $path]);
    if ($dedupe->fetchColumn()) {
        no_content();
    }

    $stmt = db()->prepare(
        'INSERT INTO visits
            (path, referrer, ip_hash, user_agent, country, device, browser, os, lang, is_bot, visited_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())'
    );
    $stmt->execute([
        $path,
        $referrer,
        $ipHash,
        $ua,
        $country !== '' ? $country : null,
        $info['device'],
        $info['browser'],
        $info['os'],
        $lang,
        $info['is_bot'] ? 1 : 0,
    ]);

    // Purga probabilistica: ~1% de las veces borra visitas de +400 dias para
    // que la tabla no crezca indefinidamente. Sin necesidad de cron.
    if (random_int(1, 100) === 1) {
        db()->query('DELETE FROM visits WHERE visited_at < (NOW() - INTERVAL 400 DAY)');
        db()->query('DELETE FROM login_attempts WHERE attempted_at < (NOW() - INTERVAL 90 DAY)');
        db()->query('DELETE FROM activity_log WHERE created_at < (NOW() - INTERVAL 365 DAY)');
    }
} catch (Throwable $e) {
    // Silencioso: no queremos que un fallo de analitica afecte al usuario.
}

no_content();
