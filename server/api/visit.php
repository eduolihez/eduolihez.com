<?php
/**
 * POST /api/visit.php
 * Registra una visita para la analitica propia (sin terceros).
 * La IP se guarda HASHEADA con una sal (no se almacena la IP real) para
 * respetar la privacidad y poder contar visitantes unicos aproximados.
 *
 * Dos acciones, seleccionadas por el campo "action" del body:
 *   - "hit" (o ausente, por compatibilidad): registra una pagina vista.
 *   - "beat": actualiza duration_s/scroll_pct de un "hit" ya insertado,
 *     localizandolo por hit_id. hit_id y session_id son tokens generados en
 *     el navegador (16 hex) que NO son identificadores persistentes: hit_id
 *     es de un solo uso por pagina, y session_id vive en sessionStorage
 *     (muere al cerrar la pestana). Ninguno de los dos se guarda en el
 *     cliente entre visitas ni se cruza con otra tabla.
 *
 * Se llama desde el frontend con navigator.sendBeacon(), por eso aceptamos
 * el cuerpo tanto en JSON como en texto plano.
 *
 * Defensas (todas silenciosas: la analitica nunca debe estorbar al visitante):
 *   - Solo se aceptan rutas con formato de URL interna (nada de basura de 255
 *     caracteres inventada por un bot para inflar la tabla).
 *   - Tope de visitas por visitante y minuto (config: visit_max_per_minute).
 *     Solo cuenta INSERTs (accion "hit"): un "beat" nunca inserta fila, asi
 *     que no puede hacer crecer este contador. Por eso el UPDATE de "beat"
 *     exige ademas "AND ip_hash = ?": solo puede tocar un hit_id que el
 *     mismo ip_hash haya creado, y crear ese hit_id ya paso por este tope.
 *     Sin esa condicion, "beat" seria un endpoint sin limite de peticiones
 *     alguno (ni siquiera el de "hit"), y al no exigir mismo origen (ver
 *     apply_cors() en lib/http.php) cualquier pagina externa podria
 *     dispararlo por sendBeacon().
 *   - Deduplicado de 30 s por visitante+ruta (solo en "hit").
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

/** Recorta y descarta vacios. Usado para los campos UTM (texto libre corto). */
function clean_short(string $v, int $max): ?string
{
    $v = trim($v);
    return $v !== '' ? mb_substr($v, 0, $max) : null;
}

/** Valida un token cliente de 16 hex (session_id / hit_id), o null si no cuadra. */
function clean_token(string $v): ?string
{
    return preg_match('/^[a-f0-9]{16}$/', $v) ? $v : null;
}

/** Entero dentro de [$min, $max], o null si no es numerico o se sale de rango. */
function clean_int(mixed $v, int $min, int $max): ?int
{
    if (!is_numeric($v)) {
        return null;
    }
    $n = (int) $v;
    return ($n >= $min && $n <= $max) ? $n : null;
}

$input = read_json_body();
$action = ($input['action'] ?? 'hit') === 'beat' ? 'beat' : 'hit';

$ua = mb_substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255);

// Hash de la IP con sal + user-agent (privacidad). El UA entra en el hash
// para distinguir mejor visitantes que comparten IP (oficina, wifi
// domestica, CGNAT) sin anadir ninguna senal nueva: el UA ya se guardaba en
// texto para todo lo demas. Sin sal propia no hay caida silenciosa a un
// valor adivinable: si falta en config(), el hash de IP se debilitaria sin
// que nadie se entere, asi que preferimos un error 500 explicito.
$salt = config()['security']['ip_salt'] ?? '';
if ($salt === '') {
    json(['error' => 'Configuracion incompleta.'], 500);
}
$ipHash = hash('sha256', client_ip() . '|' . $ua . '|' . $salt);

try {
    // Anti-flood: tope por visitante y minuto. Solo cuenta INSERTs (accion
    // "hit"); ver comentario al inicio del archivo sobre por que "beat" no
    // necesita su propio contador.
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

    // --- action=beat: actualiza duration_s/scroll_pct de un hit existente --
    if ($action === 'beat') {
        $hitId = clean_token((string) ($input['hit_id'] ?? ''));
        if ($hitId === null) {
            no_content();
        }
        // Limite real de la columna: SMALLINT UNSIGNED (65535, ~18.2 h). Un
        // valor mayor pasaria esta validacion pero no cabria en la columna.
        $duration = clean_int($input['duration_s'] ?? null, 0, 65535);
        $scroll = clean_int($input['scroll_pct'] ?? null, 0, 100);
        if ($duration === null && $scroll === null) {
            no_content();
        }

        // "AND ip_hash = ?": un beat solo puede tocar un hit_id creado por
        // el mismo visitante (ver comentario de cabecera). Si el hit_id no
        // existe o pertenece a otro ip_hash, la UPDATE no afecta filas y no
        // pasa nada; nunca se informa del resultado al cliente.
        $stmt = db()->prepare(
            'UPDATE visits SET
                duration_s = COALESCE(?, duration_s),
                scroll_pct = COALESCE(?, scroll_pct)
             WHERE hit_id = ? AND ip_hash = ? ORDER BY id DESC LIMIT 1'
        );
        $stmt->execute([$duration, $scroll, $hitId, $ipHash]);
        no_content();
    }

    // --- action=hit (por defecto): registra una pagina vista ---------------

    // Ruta: solo aceptamos rutas internas con caracteres razonables.
    $path = trim((string) ($input['path'] ?? '/'));
    if ($path === '' || $path[0] !== '/' || strlen($path) > 120
        || !preg_match('#^/[a-zA-Z0-9/_\-.]*$#', $path)) {
        no_content();
    }

    // Referrer: guardamos solo esquema + host + ruta, sin query ni fragmento.
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

    // session_id / hit_id: tokens generados en el navegador (16 hex), no
    // identificadores persistentes. Ver comentario al inicio del archivo.
    $sessionId = clean_token((string) ($input['session_id'] ?? ''));
    $hitId = clean_token((string) ($input['hit_id'] ?? ''));

    // UTM de la propia URL de aterrizaje (no del referrer: eso es harina de
    // otro costal, ver el bloque de arriba).
    $utmSource = clean_short((string) ($input['utm_source'] ?? ''), 60);
    $utmMedium = clean_short((string) ($input['utm_medium'] ?? ''), 60);
    $utmCampaign = clean_short((string) ($input['utm_campaign'] ?? ''), 60);

    // Bucket de ancho de viewport (xs/sm/md/lg/xl), nunca el pixel exacto:
    // asi no anadimos entropia de fingerprint por esta via.
    $viewport = (string) ($input['viewport'] ?? '');
    if (!in_array($viewport, ['xs', 'sm', 'md', 'lg', 'xl'], true)) {
        $viewport = null;
    }

    // Idioma declarado del navegador (navigator.language), distinto de $lang
    // (idioma de LA PAGINA vista): sirve para ver si hay demanda de un idioma
    // que aun no ofrecemos.
    $browserLang = strtolower((string) ($input['browser_lang'] ?? ''));
    if (!preg_match('/^[a-z]{2}$/', $browserLang)) {
        $browserLang = null;
    }

    // Anti-flood: ignora visitas repetidas del mismo visitante a la misma
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
            (path, referrer, ip_hash, user_agent, country, device, browser, os, lang, is_bot,
             session_id, hit_id, utm_source, utm_medium, utm_campaign, viewport, browser_lang,
             visited_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())'
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
        $sessionId,
        $hitId,
        $utmSource,
        $utmMedium,
        $utmCampaign,
        $viewport,
        $browserLang,
    ]);

    // Purga probabilistica: ~1% de las veces borra visitas de +400 dias para
    // que la tabla no crezca indefinidamente. Sin necesidad de cron.
    if (random_int(1, 100) === 1) {
        db()->query('DELETE FROM visits WHERE visited_at < (NOW() - INTERVAL 400 DAY)');
        db()->query('DELETE FROM login_attempts WHERE attempted_at < (NOW() - INTERVAL 90 DAY)');
        db()->query('DELETE FROM activity_log WHERE created_at < (NOW() - INTERVAL 365 DAY)');
    }
} catch (Throwable $e) {
    // Silencioso de cara al visitante (nunca 500 por un fallo de analitica),
    // pero se deja rastro en el log del servidor: sin esto, un despliegue
    // donde el codigo llega antes que la migracion de schema.sql (columna
    // inexistente) fallaria en silencio total y se veria solo como trafico
    // "perdido" en el panel, sin ninguna pista de por que.
    error_log('visit.php: ' . $e->getMessage());
}

no_content();
