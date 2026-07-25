<?php

// ── Security headers ──────────────────────────────────────────────────────────
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('Permissions-Policy: geolocation=(), camera=(), microphone=()');
// Content-Security-Policy: restricts resource origins for this JSON API endpoint
header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");

// ── CORS — restringit a APP_URL en producció ──────────────────────────────────
// config.php no s'ha carregat encara aquí, llegim APP_URL directament del .env
(function () {
    $envPath = __DIR__ . '/../.env';
    $appUrl  = 'http://localhost';
    if (is_readable($envPath)) {
        foreach (file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            $line = trim($line);
            if (str_starts_with($line, 'APP_URL=')) {
                $appUrl = trim(substr($line, 8));
                break;
            }
        }
    }
    header("Access-Control-Allow-Origin: $appUrl");
})();
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-CSRF-Token");
header("Vary: Origin");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

// ── Config + Session ──────────────────────────────────────────────────────────
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/RateLimiter.php';

// Use a project-local session directory so it's always writable regardless of
// server configuration, and configure cookie attributes explicitly.
$_sessionDir = __DIR__ . '/sessions';
if (!is_dir($_sessionDir)) {
    mkdir($_sessionDir, 0700, true);
}
session_save_path($_sessionDir);
session_set_cookie_params([
    'lifetime' => 0,
    'path'     => '/',
    'secure'   => defined('APP_ENV') && APP_ENV === 'production',
    'httponly' => true,
    'samesite' => 'Lax',
]);
session_start();

// ── CSRF ──────────────────────────────────────────────────────────────────────
function generateCsrfToken(): string {
    if (empty($_SESSION['csrf_token']))
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    return $_SESSION['csrf_token'];
}

function validateCsrfToken(string $token): bool {
    return !empty($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

function requireCsrf(): void {
    $t = $_POST['_csrf_token'] ?? $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    if (!validateCsrfToken($t))
        sendResponse(["status" => "error", "message" => "Token de seguretat invàlid."], 403);
}

// ── Utilities ─────────────────────────────────────────────────────────────────
function connectDB(): mysqli|false {
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($conn->connect_error) {
        error_log("DB connection failed: " . $conn->connect_error);
        return false;
    }
    $conn->set_charset("utf8mb4");
    return $conn;
}

function sendResponse(array $data, int $http_code = 200): never {
    http_response_code($http_code);
    echo json_encode($data);
    exit;
}

function makeValuesReferenced(array $arr): array {
    $refs = [];
    foreach ($arr as $key => $value) $refs[$key] = &$arr[$key];
    return $refs;
}

function sanitizeText(string $input, int $max = 500): string {
    return mb_substr(
        htmlspecialchars(strip_tags(trim($input)), ENT_QUOTES | ENT_HTML5, 'UTF-8'),
        0, $max
    );
}

function validateCoordinates(float $lat, float $lng): bool {
    return $lat >= 40.5 && $lat <= 42.9 && $lng >= 0.15 && $lng <= 3.35;
}

// ── Maintenance ───────────────────────────────────────────────────────────────
// Returns true at most once per $intervalSecs using a marker file — avoids rand() unreliability.
function shouldRunMaintenance(int $intervalSecs = 600): bool {
    $marker = __DIR__ . '/rate_cache/.maintenance_last_run';
    if (file_exists($marker) && (time() - filemtime($marker)) < $intervalSecs) return false;
    @touch($marker);
    return true;
}

// Soft delete (archivado=1) instead of physical DELETE — preserves audit trail & historial FK
// CHANGED: 2 DAY → 30 DAY. Auto-archiving after 48 h was too aggressive for a real municipal
// workflow where reports need a proper review cycle before any automated action.
function autoDeleteDenuncias(mysqli $conn): void {
    $stmt = $conn->prepare(
        "UPDATE incidencias SET archivado=1
         WHERE categoria='denuncia' AND estado='pendiente'
           AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
           AND archivado = 0"
    );
    if ($stmt) { $stmt->execute(); }
}

// ── Reverse geocode ───────────────────────────────────────────────────────────
function handleReverseGeocode(): never {
    if (!extension_loaded('curl'))
        sendResponse(["status" => "error", "message" => "cURL no disponible."], 500);

    $lat = filter_var($_GET['lat'] ?? '', FILTER_VALIDATE_FLOAT);
    $lng = filter_var($_GET['lng'] ?? '', FILTER_VALIDATE_FLOAT);
    if (!$lat || !$lng)
        sendResponse(["status" => "error", "message" => "Lat/Lng requerits."], 400);

    $url = "https://nominatim.openstreetmap.org/reverse?format=json&lat={$lat}&lon={$lng}&zoom=18&addressdetails=1";
    $ch  = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_USERAGENT      => 'BadaVeu-App-v1.0 (https://badaveu.badalona.cat)',
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    $result    = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err       = curl_error($ch);
    curl_close($ch);

    if ($result === false || $http_code >= 400)
        sendResponse(["status" => "error", "message" => "Error geocodificació: " . ($err ?: "HTTP $http_code")], 500);

    $data = json_decode($result, true);
    if (json_last_error() !== JSON_ERROR_NONE)
        sendResponse(["status" => "error", "message" => "Resposta geocodificació invàlida."], 500);

    sendResponse($data);
}

// ── New incident ──────────────────────────────────────────────────────────────
function handleNewIncident(mysqli $conn): never {
    requireCsrf();

    $rl = new RateLimiter();
    $rl->enforce('new_incident', 5, 3600);

    $lat      = filter_var($_POST['lat'] ?? '', FILTER_VALIDATE_FLOAT);
    $lng      = filter_var($_POST['lng'] ?? '', FILTER_VALIDATE_FLOAT);
    $categoria = $_POST['categoria'] ?? '';
    $urgencia  = $_POST['urgencia']  ?? 'media';

    if (!$lat || !$lng)
        sendResponse(["status" => "error", "message" => "Coordenades invàlides."], 400);
    if (!validateCoordinates((float)$lat, (float)$lng))
        sendResponse(["status" => "error", "message" => "Coordenades fora del rang permès."], 400);
    if (!in_array($categoria, ['infraestructura', 'denuncia'], true))
        sendResponse(["status" => "error", "message" => "Categoria no vàlida."], 400);
    if (!in_array($urgencia, ['baja', 'media', 'alta'], true)) $urgencia = 'media';

    $titulo      = sanitizeText($_POST['titulo']      ?? '', 150);
    $descripcion = sanitizeText($_POST['descripcion'] ?? '', 1500);
    $tipo        = sanitizeText($_POST['tipo']        ?? '', 100);
    $direccion   = sanitizeText($_POST['direccion']   ?? '', 255);
    $barri       = sanitizeText($_POST['barri']       ?? '', 100);
    $districte   = sanitizeText($_POST['districte']   ?? '', 10);
    $cp          = sanitizeText($_POST['cp']          ?? '', 10);
    $afectacion  = in_array($_POST['afectacion'] ?? '', ['individual', 'col·lectiva'], true)
                   ? $_POST['afectacion'] : 'individual';
    $email       = filter_var($_POST['email'] ?? '', FILTER_VALIDATE_EMAIL) ? $_POST['email'] : null;

    if (empty($titulo))
        sendResponse(["status" => "error", "message" => "El títol és obligatori."], 400);

    // ── Upload dir ────────────────────────────────────────────────────────────
    $foto_url   = null;
    $upload_dir = __DIR__ . '/../uploads/';
    if (!is_dir($upload_dir)) @mkdir($upload_dir, 0775, true);

    // Base64 image (compressed from JS)
    if (!empty($_POST['compressed_image'])) {
        $raw = $_POST['compressed_image'];

        // Strip data-URI prefix
        if (preg_match('/^data:image\/(.*?);base64,(.+)$/s', $raw, $m)) {
            $ext_from_header = strtolower($m[1]) === 'jpeg' ? 'jpg' : strtolower($m[1]);
            $base64_data     = $m[2];
        } else {
            $base64_data = $raw;
            $ext_from_header = 'jpg';
        }

        // Size check: base64 encodes ~1.37× — 2 MB raw → 2.74 MB b64
        if (strlen($base64_data) > 2 * 1024 * 1024 * 1.37)
            sendResponse(["status" => "error", "message" => "Imatge massa gran (màx 2 MB)."], 400);

        $image_data = base64_decode($base64_data, true);
        if ($image_data === false)
            sendResponse(["status" => "error", "message" => "Error processant imatge."], 400);

        // Magic bytes
        $magic = substr($image_data, 0, 4);
        $valid_image = substr($magic, 0, 3) === "\xFF\xD8\xFF"  // JPEG
                    || $magic === "\x89PNG"                      // PNG
                    || substr($magic, 0, 4) === "RIFF";          // WEBP

        if (!$valid_image)
            sendResponse(["status" => "error", "message" => "Format d'imatge no permès (JPG/PNG/WEBP)."], 400);

        $allowed_exts = ['jpg', 'jpeg', 'png', 'webp'];
        $ext = in_array($ext_from_header, $allowed_exts, true) ? $ext_from_header : 'jpg';
        // Crypto-random filename — no extension-guessing, no timing attacks
        $filename = bin2hex(random_bytes(16)) . '.' . $ext;

        if (@file_put_contents($upload_dir . $filename, $image_data) !== false)
            $foto_url = 'uploads/' . $filename;
        else
            error_log("Failed to save base64 image: " . $upload_dir . $filename);
    }

    // Traditional file upload fallback — MIME + size + magic bytes validation
    if (!$foto_url && isset($_FILES['foto']) && $_FILES['foto']['error'] === UPLOAD_ERR_OK) {
        $tmp = $_FILES['foto']['tmp_name'];

        // 1. Size check: max 5 MB
        if ($_FILES['foto']['size'] > 5 * 1024 * 1024) {
            sendResponse(["status" => "error", "message" => "La imatge no pot superar els 5 MB."], 400);
        }

        // 2. Real MIME type via finfo (ignores file extension)
        $allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mime  = $finfo->file($tmp);
        if (!in_array($mime, $allowedMimes, true)) {
            sendResponse(["status" => "error", "message" => "Tipus de fitxer no permès. Només JPG, PNG o WEBP."], 400);
        }

        // 3. Magic bytes cross-check
        $magic = file_get_contents($tmp, false, null, 0, 4);
        $validMagic = substr($magic, 0, 3) === "\xFF\xD8\xFF"  // JPEG
                   || $magic === "\x89PNG"                      // PNG
                   || substr($magic, 0, 4) === "RIFF";          // WEBP

        if (!$validMagic) {
            sendResponse(["status" => "error", "message" => "Format d'imatge no vàlid."], 400);
        }

        // 4. Generate random filename — NEVER use the original filename
        $extMap = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
        $ext      = $extMap[$mime] ?? 'jpg';
        $filename = bin2hex(random_bytes(16)) . '.' . $ext; // crypto-random, unguessable

        if (@move_uploaded_file($tmp, $upload_dir . $filename)) {
            $foto_url = 'uploads/' . $filename;
        } else {
            error_log("Failed to move uploaded file to: " . $upload_dir . $filename);
        }
    }

    $sql  = "INSERT INTO incidencias (lat,lng,titulo,descripcion,categoria,tipo_problema,
                direccion,barri,districte,urgencia,afectacion,email,cp,foto_url,estado,created_at)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,'pendiente',NOW())";
    $stmt = $conn->prepare($sql);
    if ($stmt === false)
        sendResponse(["status" => "error", "message" => "Error preparant inserció."], 500);

    $stmt->bind_param("ddssssssssssss",
        $lat, $lng, $titulo, $descripcion, $categoria, $tipo,
        $direccion, $barri, $districte, $urgencia, $afectacion, $email, $cp, $foto_url
    );

    if ($stmt->execute())
        sendResponse(["status" => "success", "message" => "Incidència reportada!", "id" => $conn->insert_id]);
    else {
        error_log('[BadaVeu] Error inserint incidència: ' . $stmt->error);
        sendResponse(["status" => "error", "message" => "Error intern en desar la incidència."], 500);
    }
}

// ── Votes ─────────────────────────────────────────────────────────────────────
function handleVote(mysqli $conn, int|false $id, string $action): never {
    requireCsrf();

    $rl = new RateLimiter();
    $rl->enforce('vote', 50, 3600);

    if (!$id) sendResponse(["status" => "error", "message" => "ID requerit."], 400);

    $sql  = "UPDATE incidencias SET votos=CASE
                WHEN ?='unvote' AND votos>0 THEN votos-1
                WHEN ?='vote'               THEN votos+1
                ELSE votos END
             WHERE id=?";
    $stmt = $conn->prepare($sql);
    if ($stmt === false) sendResponse(["status" => "error", "message" => "Error DB vot."], 500);
    $stmt->bind_param("ssi", $action, $action, $id);

    if (!$stmt->execute())
        sendResponse(["status" => "error", "message" => "Error executant vot."], 500);

    $rStmt = $conn->prepare("SELECT votos FROM incidencias WHERE id=?");
    if ($rStmt) { $rStmt->bind_param("i", $id); $rStmt->execute(); $res = $rStmt->get_result(); }
    if (isset($res) && $res && $row = $res->fetch_assoc())
        sendResponse(["status" => "success", "new_votes" => (int)$row['votos']]);
    else
        sendResponse(["status" => "error", "message" => "Vot actualitzat, no s'ha pogut recuperar el total."], 500);
}

// ── Public data (paginated + optional bounding-box) ──────────────────────────
function getPublicData(mysqli $conn): never {
    header('Cache-Control: public, max-age=60');
    if (shouldRunMaintenance()) autoDeleteDenuncias($conn);

    $page   = max(1, (int)($_GET['page']  ?? 1));
    $limit  = min(100, max(10, (int)($_GET['limit'] ?? 50)));
    $offset = ($page - 1) * $limit;

    // Optional bounding-box: ?bbox=minLat,minLng,maxLat,maxLng
    $bbox = null;
    if (!empty($_GET['bbox'])) {
        $parts = array_map('trim', explode(',', $_GET['bbox']));
        if (count($parts) === 4) {
            $vals = array_map(fn($v) => filter_var($v, FILTER_VALIDATE_FLOAT), $parts);
            if (!in_array(false, $vals, true)) {
                [$minLat, $minLng, $maxLat, $maxLng] = $vals;
                // Clamp to Badalona area to prevent unbounded queries
                if ($minLat >= 40.5 && $maxLat <= 42.9 && $minLng >= 0.15 && $maxLng <= 3.35) {
                    $bbox = [$minLat, $minLng, $maxLat, $maxLng];
                }
            }
        }
    }

    $baseWhere = $bbox
        ? "archivado = 0 AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?"
        : "archivado = 0";

    // Total count for pagination metadata
    $cStmt = $conn->prepare("SELECT COUNT(id) AS c FROM incidencias WHERE $baseWhere");
    if (!$cStmt) sendResponse(["status" => "error", "message" => "Error preparant consulta."], 500);
    if ($bbox) $cStmt->bind_param("dddd", $bbox[0], $bbox[2], $bbox[1], $bbox[3]);
    $cStmt->execute();
    $total = (int)$cStmt->get_result()->fetch_assoc()['c'];

    $sql = "SELECT id,lat,lng,titulo,descripcion,categoria,tipo_problema AS tipo,
                   direccion,barri,districte,votos,estado,foto_url,created_at,urgencia,
                   COALESCE(views,0) AS views
            FROM incidencias WHERE $baseWhere ORDER BY created_at DESC LIMIT ? OFFSET ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) sendResponse(["status" => "error", "message" => "Error preparant paginació."], 500);
    if ($bbox) {
        $stmt->bind_param("ddddii", $bbox[0], $bbox[2], $bbox[1], $bbox[3], $limit, $offset);
    } else {
        $stmt->bind_param("ii", $limit, $offset);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $incidents = [];
    while ($row = $result->fetch_assoc()) {
        $row['lat']   = (float)$row['lat'];
        $row['lng']   = (float)$row['lng'];
        $row['votos'] = (int)($row['votos'] ?? 0);
        $row['views'] = (int)($row['views'] ?? 0);
        $incidents[]  = $row;
    }

    sendResponse([
        'data'  => $incidents,
        'meta'  => [
            'total' => $total,
            'page'  => $page,
            'limit' => $limit,
            'pages' => max(1, (int)ceil($total / $limit)),
        ],
        'total' => $total,
        'page'  => $page,
        'limit' => $limit,
        'pages' => max(1, (int)ceil($total / $limit)),
        'bbox'  => $bbox !== null,
    ]);
}

// ── Public single incident ────────────────────────────────────────────────────
function getPublicIncident(mysqli $conn): never {
    $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
    if (!$id) sendResponse(["status" => "error", "message" => "ID no vàlid."], 400);

    // Increment view counter — only on active (non-archived) incidents
    $vStmt = $conn->prepare("UPDATE incidencias SET views=COALESCE(views,0)+1 WHERE id=? AND archivado=0");
    if ($vStmt) { $vStmt->bind_param("i", $id); $vStmt->execute(); }

    $stmt = $conn->prepare(
        "SELECT id,lat,lng,titulo,descripcion,categoria,tipo_problema AS tipo,
                direccion,barri,districte,votos,estado,foto_url,created_at,urgencia,
                COALESCE(views,0) AS views
         FROM incidencias WHERE id=? AND archivado=0 LIMIT 1"
    );
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();

    if (!$row) sendResponse(["status" => "error", "message" => "Incidència no trobada."], 404);

    $row['lat']   = (float)$row['lat'];
    $row['lng']   = (float)$row['lng'];
    $row['votos'] = (int)($row['votos'] ?? 0);
    $row['views'] = (int)($row['views'] ?? 0);

    // Attach public timeline (only entries with an admin comment)
    $tStmt = $conn->prepare(
        "SELECT estado_nuevo, comentario_admin, fecha
         FROM historial_incidencias
         WHERE incidencia_id = ? AND comentario_admin IS NOT NULL AND comentario_admin != ''
         ORDER BY fecha DESC"
    );
    $tStmt->bind_param("i", $id);
    $tStmt->execute();
    $row['timeline'] = $tStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    sendResponse(["status" => "success", "data" => $row]);
}

// ── Public stats ──────────────────────────────────────────────────────────────
function getPublicStats(mysqli $conn): never {
    header('Cache-Control: public, max-age=60');
    if (shouldRunMaintenance()) autoDeleteDenuncias($conn);

    $stats = ['total_incidents' => 0, 'by_category' => [], 'by_status' => [], 'by_barri' => [], 'most_viewed' => null];

    $r = $conn->query("SELECT COUNT(id) AS c FROM incidencias WHERE archivado=0");
    if ($r && $row = $r->fetch_assoc()) $stats['total_incidents'] = (int)$row['c'];

    $r = $conn->query("SELECT categoria, COUNT(id) AS c FROM incidencias WHERE archivado=0 GROUP BY categoria");
    if ($r) while ($row = $r->fetch_assoc()) $stats['by_category'][$row['categoria']] = (int)$row['c'];
    $stats['by_category'] += ['infraestructura' => 0, 'denuncia' => 0];

    $r = $conn->query("SELECT estado, COUNT(id) AS c FROM incidencias WHERE archivado=0 GROUP BY estado");
    if ($r) while ($row = $r->fetch_assoc()) $stats['by_status'][$row['estado']] = (int)$row['c'];
    $stats['by_status'] += ['pendiente' => 0, 'proceso' => 0, 'resuelto' => 0];

    $r = $conn->query("SELECT barri, COUNT(id) AS c FROM incidencias WHERE archivado=0 AND barri IS NOT NULL AND barri!='' GROUP BY barri ORDER BY c DESC LIMIT 5");
    if ($r) while ($row = $r->fetch_assoc()) $stats['by_barri'][$row['barri']] = (int)$row['c'];

    $r = $conn->query("SELECT id,titulo,COALESCE(views,0) AS views,COALESCE(votos,0) AS votos FROM incidencias WHERE archivado=0 AND views IS NOT NULL ORDER BY views DESC LIMIT 1");
    if ($r && $row = $r->fetch_assoc()) $stats['most_viewed'] = $row;

    sendResponse(["status" => "success", "data" => $stats]);
}

// ── Admin data ────────────────────────────────────────────────────────────────
function getAdminData(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);

    // 'archived' param lets superadmin browse archived incidents explicitly
    $show_archived = ($_SESSION['admin_role'] ?? '') === 'superadmin'
                     && ($_GET['archived'] ?? '0') === '1';

    $where    = [$show_archived ? "archivado=1" : "archivado=0"];
    $bindings = [];
    $types    = "";

    $access_type         = $_SESSION['access_type']      ?? 'all';
    $district_access_raw = $_SESSION['district_access']  ?? 'all';

    if ($access_type === 'infraestructura')     $where[] = "categoria='infraestructura'";
    elseif ($access_type === 'denuncia')        $where[] = "categoria='denuncia'";

    if ($district_access_raw && $district_access_raw !== 'all') {
        $districts = array_map('trim', explode(',', $district_access_raw));
        if (!empty($districts)) {
            $where[] = "districte IN (" . implode(',', array_fill(0, count($districts), '?')) . ")";
            foreach ($districts as $d) { $bindings[] = $d; $types .= "s"; }
        }
    }

    // Urgency score formula: (votos × 0.4) + (urgency_weight × 0.6)
    // Weights: alta=3, media=2, baja=1  →  alta contributes 1.8, media 1.2, baja 0.6
    $scoreExpr = "(COALESCE(votos,0) * 0.4 + CASE urgencia WHEN 'alta' THEN 1.8 WHEN 'media' THEN 1.2 ELSE 0.6 END)";

    $validSorts = ['score', 'date', 'votes'];
    $sort = in_array($_GET['sort'] ?? '', $validSorts, true) ? ($_GET['sort']) : 'date';
    $orderBy = match($sort) {
        'score' => "$scoreExpr DESC, created_at DESC",
        'votes' => "votos DESC, created_at DESC",
        default => "created_at DESC",
    };

    $sql  = "SELECT id,lat,lng,titulo,descripcion,categoria,tipo_problema AS tipo,
                    direccion,barri,districte,votos,estado,urgencia,afectacion,email,
                    foto_url,created_at,updated_at,
                    ROUND($scoreExpr, 2) AS urgency_score
             FROM incidencias WHERE " . implode(" AND ", $where) . " ORDER BY $orderBy";
    $stmt = $conn->prepare($sql);

    if ($types) {
        $param_arr = array_merge([$types], $bindings);
        call_user_func_array([$stmt, 'bind_param'], makeValuesReferenced($param_arr));
    }

    if (!$stmt->execute()) {
        error_log('[BadaVeu] Error executant query de vot: ' . $conn->error);
        sendResponse(["status" => "error", "message" => "Error intern en processar la petició."], 500);
    }

    $result    = $stmt->get_result();
    $incidents = [];
    while ($row = $result->fetch_assoc()) {
        $row['lat']          = (float)$row['lat'];
        $row['lng']          = (float)$row['lng'];
        $row['votos']        = (int)($row['votos'] ?? 0);
        $row['urgency_score'] = (float)($row['urgency_score'] ?? 0);
        $incidents[]  = $row;
    }
    sendResponse([
        "status" => "success",
        "data"   => $incidents,
        "sort"   => $sort,
        "meta"   => ["total" => count($incidents)],
    ]);
}

// ── Admin stats ───────────────────────────────────────────────────────────────
function getAdminStats(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);

    $monthly_res = $conn->query("SELECT DATE_FORMAT(created_at,'%Y-%m') AS month, COUNT(id) AS count FROM incidencias WHERE archivado=0 GROUP BY month ORDER BY month DESC LIMIT 6");
    $monthly_data = [];
    if ($monthly_res) while ($row = $monthly_res->fetch_assoc()) $monthly_data[] = $row;

    $general_res = $conn->query("SELECT urgencia,estado,afectacion,COUNT(id) AS count FROM incidencias WHERE archivado=0 GROUP BY urgencia,estado,afectacion");
    $urgency_dist = []; $afectacion_dist = []; $total = 0;
    if ($general_res) {
        while ($row = $general_res->fetch_assoc()) {
            $c = (int)$row['count'];
            $total += $c;
            $urgency_dist[$row['urgencia']]   = ($urgency_dist[$row['urgencia']]   ?? 0) + $c;
            $urgency_dist[$row['estado']]     = ($urgency_dist[$row['estado']]     ?? 0) + $c;
            $afectacion_dist[$row['afectacion']] = ($afectacion_dist[$row['afectacion']] ?? 0) + $c;
        }
    }

    $weekly_sql = "SELECT DATE(d) AS date,
                   COALESCE(SUM(CASE WHEN action='created'  THEN count ELSE 0 END),0) AS created,
                   COALESCE(SUM(CASE WHEN action='resolved' THEN count ELSE 0 END),0) AS resolved
                   FROM (
                       SELECT DATE(created_at) AS d,'created' AS action,COUNT(id) AS count FROM incidencias WHERE archivado=0 AND created_at>=DATE_SUB(CURDATE(),INTERVAL 6 DAY) GROUP BY d
                       UNION ALL
                       SELECT DATE(updated_at) AS d,'resolved' AS action,COUNT(id) AS count FROM incidencias WHERE archivado=0 AND estado='resuelto' AND updated_at>=DATE_SUB(CURDATE(),INTERVAL 6 DAY) GROUP BY d
                   ) AS combined GROUP BY date ORDER BY date ASC";
    $weekly_res  = @$conn->query($weekly_sql);
    $weekly_flow = [];
    if ($weekly_res) while ($row = $weekly_res->fetch_assoc())
        $weekly_flow[] = ['date' => $row['date'], 'created' => (int)$row['created'], 'resolved' => (int)$row['resolved']];

    sendResponse(["status" => "success", "data" => [
        "total_incidents"      => $total,
        "monthly_trend"        => $monthly_data,
        "urgency_distribution" => $urgency_dist,
        "afectacion_distribution" => $afectacion_dist,
        "weekly_status_flow"   => $weekly_flow,
    ]]);
}

// ── Update status (+ email) ───────────────────────────────────────────────────
function handleUpdateStatus(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);
    requireCsrf();

    $id         = filter_var($_POST['id']     ?? null, FILTER_VALIDATE_INT);
    $new_status = $_POST['estado'] ?? '';
    // Sanitize comment: strip HTML tags, trim whitespace, cap at 500 chars
    $comentario = trim(strip_tags($_POST['comentario'] ?? ''));
    $comentario = $comentario !== '' ? mb_substr($comentario, 0, 500, 'UTF-8') : null;

    if (!$id || !in_array($new_status, ['pendiente', 'proceso', 'resuelto', 'denegado'], true))
        sendResponse(["status" => "error", "message" => "ID o estat no vàlid."], 400);

    // Read old status for history log (prepared statement)
    $prevStmt = $conn->prepare("SELECT estado FROM incidencias WHERE id=?");
    $old_status = null;
    if ($prevStmt) {
        $prevStmt->bind_param("i", $id);
        $prevStmt->execute();
        $prevRow = $prevStmt->get_result()->fetch_assoc();
        $old_status = $prevRow['estado'] ?? null;
    }

    $stmt = $conn->prepare("UPDATE incidencias SET estado=?, updated_at=NOW() WHERE id=?");
    if ($stmt === false) sendResponse(["status" => "error", "message" => "Error preparant query."], 500);
    $stmt->bind_param("si", $new_status, $id);

    if (!$stmt->execute()) {
        error_log('[BadaVeu] Error actualitzant estat: ' . $stmt->error);
        sendResponse(["status" => "error", "message" => "Error intern en actualitzar l'estat."], 500);
    }

    // Insert history record
    $admin_user = $_SESSION['admin_user'] ?? null;
    $hStmt = $conn->prepare(
        "INSERT INTO historial_incidencias (incidencia_id, estado_anterior, estado_nuevo, comentario_admin, admin_usuario)
         VALUES (?, ?, ?, ?, ?)"
    );
    if ($hStmt) {
        $hStmt->bind_param("issss", $id, $old_status, $new_status, $comentario, $admin_user);
        $hStmt->execute();
    }

    // Email only when the incident is resolved (avoid spam on every status change)
    if ($new_status === 'resuelto') {
        sendStatusEmail($conn, (int)$id, $new_status, $comentario);
    }
    sendResponse(["status" => "success", "message" => "Estat actualitzat."]);
}

// ── Update urgency/priority ───────────────────────────────────────────────────
function handleUpdateUrgencia(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);
    requireCsrf();

    $id       = filter_var($_POST['id']      ?? null, FILTER_VALIDATE_INT);
    $urgencia = $_POST['urgencia'] ?? '';

    if (!$id || !in_array($urgencia, ['baja', 'media', 'alta'], true))
        sendResponse(["status" => "error", "message" => "ID o urgència no vàlid."], 400);

    $stmt = $conn->prepare("UPDATE incidencias SET urgencia=?, updated_at=NOW() WHERE id=? AND archivado=0");
    if (!$stmt) sendResponse(["status" => "error", "message" => "Error preparant query."], 500);
    $stmt->bind_param("si", $urgencia, $id);

    if (!$stmt->execute() || $stmt->affected_rows === 0)
        sendResponse(["status" => "error", "message" => "Incidència no trobada."], 404);

    sendResponse(["status" => "success", "message" => "Urgència actualitzada.", "urgencia" => $urgencia]);
}

// ── Archive incident (soft delete) ───────────────────────────────────────────
function handleArchiveIncident(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);
    requireCsrf();

    $id    = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
    // 'restore' param allows superadmin to un-archive; default is archive (1)
    $value = ($_POST['restore'] ?? '0') === '1' ? 0 : 1;

    // Only superadmin can restore archived incidents
    if ($value === 0 && ($_SESSION['admin_role'] ?? '') !== 'superadmin')
        sendResponse(["status" => "error", "message" => "Permisos insuficients per restaurar."], 403);

    if (!$id) sendResponse(["status" => "error", "message" => "ID no vàlid."], 400);

    $stmt = $conn->prepare("UPDATE incidencias SET archivado=? WHERE id=?");
    if (!$stmt) sendResponse(["status" => "error", "message" => "Error preparant query."], 500);
    $stmt->bind_param("ii", $value, $id);

    if (!$stmt->execute() || $stmt->affected_rows === 0)
        sendResponse(["status" => "error", "message" => "Incidència no trobada o ja en l'estat demanat."], 404);

    $msg = $value === 1 ? "Incidència arxivada." : "Incidència restaurada.";
    sendResponse(["status" => "success", "message" => $msg]);
}

function getIncidentHistory(mysqli $conn): never {
    $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
    if (!$id) sendResponse(["status" => "error", "message" => "ID no vàlid."], 400);

    $stmt = $conn->prepare(
        "SELECT estado_anterior, estado_nuevo, comentario_admin, admin_usuario, fecha
         FROM historial_incidencias WHERE incidencia_id = ? ORDER BY fecha DESC"
    );
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    sendResponse(["status" => "success", "data" => $rows]);
}

function sendStatusEmail(mysqli $conn, int $id, string $status, ?string $comentario = null): void {
    // Prepared statement — no inline concatenation
    $eStmt = $conn->prepare("SELECT titulo, email FROM incidencias WHERE id=?");
    if (!$eStmt) return;
    $eStmt->bind_param("i", $id);
    $eStmt->execute();
    $inc = $eStmt->get_result()->fetch_assoc();
    if (!$inc || empty($inc['email'])) return;

    $to     = filter_var($inc['email'], FILTER_SANITIZE_EMAIL);
    $titulo = htmlspecialchars($inc['titulo'], ENT_QUOTES, 'UTF-8');
    $url    = defined('APP_URL') ? APP_URL : 'https://badaveu.cat';

    $labels = [
        'pendiente' => ['⏳', 'Pendent',    '#f59e0b'],
        'proceso'   => ['🔄', 'En Procés',  '#3b82f6'],
        'resuelto'  => ['✅', 'Solucionat', '#10b981'],
    ];
    [$emoji, $label, $color] = $labels[$status] ?? ['ℹ️', $status, '#6b7280'];

    $comentariBlock = '';
    if ($comentario !== null && $comentario !== '') {
        $safeComment = htmlspecialchars($comentario, ENT_QUOTES, 'UTF-8');
        $comentariBlock = <<<HTML
      <div style="background:#fffbeb;border-radius:8px;padding:16px;border-left:4px solid #FFC107;margin-bottom:24px;">
        <p style="margin:0 0 4px;color:#6b7280;font-size:.75rem;text-transform:uppercase;">Missatge de l'administrador</p>
        <p style="margin:0;color:#1f2937;line-height:1.6;">$safeComment</p>
      </div>
HTML;
    }

    $subject = "El teu report a BadaVeu ha canviat d'estat";
    $body    = <<<HTML
<!DOCTYPE html><html lang="ca"><head><meta charset="UTF-8"></head>
<body style="background:#f1f5f9;font-family:system-ui,sans-serif;padding:40px 20px;margin:0;">
  <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 15px rgba(0,0,0,.08);">
    <div style="background:#002D5A;padding:24px 32px;">
      <p style="margin:0;color:#FFC107;font-size:1.2rem;font-weight:800;">🏛️ BadaVeu – La Voz de Badalona</p>
    </div>
    <div style="padding:32px;">
      <p style="margin:0 0 6px;color:#6b7280;font-size:.8rem;text-transform:uppercase;letter-spacing:.05em;">Actualització del teu report</p>
      <h1 style="margin:0 0 24px;color:#0f172a;font-size:1.3rem;font-weight:700;">$titulo</h1>
      <div style="background:#f8fafc;border-radius:8px;padding:18px;border-left:4px solid $color;margin-bottom:24px;">
        <p style="margin:0 0 4px;color:#6b7280;font-size:.75rem;text-transform:uppercase;">Nou estat</p>
        <p style="margin:0;font-size:1.25rem;font-weight:700;color:$color;">$emoji $label</p>
      </div>
      $comentariBlock
      <p style="color:#374151;line-height:1.7;margin-bottom:24px;">Gràcies per contribuir a millorar Badalona. Pots seguir el procés al mapa.</p>
      <a href="$url/index.html" style="background:#002D5A;color:#FFC107;text-decoration:none;padding:12px 22px;border-radius:8px;font-weight:600;display:inline-block;">Veure el mapa →</a>
    </div>
    <div style="padding:16px 32px;border-top:1px solid #e5e7eb;">
      <p style="margin:0;color:#9ca3af;font-size:.75rem;">Has rebut aquest email per haver proporcionat el teu correu al crear el report.</p>
    </div>
  </div>
</body></html>
HTML;

    $headers  = "MIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n";
    $headers .= "From: BadaVeu <" . MAIL_FROM . ">\r\n";
    if (!@mail($to, $subject, $body, $headers)) {
        error_log('[BadaVeu] Fallo enviant email de notificació a ' . $to);
    }
}

// ── Export CSV ────────────────────────────────────────────────────────────────
function exportCsv(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);

    $where  = ["archivado=0"]; $params = []; $types = '';
    $s      = $_GET['status']   ?? 'all';
    $c      = $_GET['category'] ?? 'all';

    if ($s !== 'all' && in_array($s, ['pendiente', 'proceso', 'resuelto'], true)) {
        $where[] = "estado=?"; $params[] = $s; $types .= 's';
    }
    if ($c !== 'all' && in_array($c, ['infraestructura', 'denuncia'], true)) {
        $where[] = "categoria=?"; $params[] = $c; $types .= 's';
    }

    $stmt = $conn->prepare(
        "SELECT id,titulo,descripcion,categoria,tipo_problema,barri,districte,
                direccion,estado,urgencia,afectacion,COALESCE(votos,0) AS votos,
                created_at,updated_at
         FROM incidencias WHERE " . implode(' AND ', $where) . " ORDER BY created_at DESC"
    );
    if ($types) $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    // Output CSV (not JSON for this endpoint)
    header_remove('Content-Type');
    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="incidents_' . date('Y-m-d') . '.csv"');
    header('Cache-Control: no-cache, no-store');

    $out = fopen('php://output', 'w');
    fprintf($out, chr(0xEF) . chr(0xBB) . chr(0xBF)); // UTF-8 BOM for Excel
    fputcsv($out, ['ID', 'Títol', 'Descripció', 'Categoria', 'Tipus', 'Barri', 'Districte',
                   'Adreça', 'Estat', 'Urgència', 'Afectació', 'Vots', 'Data creació', 'Data actualització'], ';');
    while ($row = $result->fetch_assoc()) fputcsv($out, array_values($row), ';');
    fclose($out);
    exit;
}

// ── Admin CRUD ────────────────────────────────────────────────────────────────
function handleCreateAdmin(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']) || ($_SESSION['admin_role'] ?? '') !== 'superadmin')
        sendResponse(["status" => "error", "message" => "Permisos insuficients."], 403);
    requireCsrf();

    $usuario        = $_POST['usuario']        ?? '';
    $password       = $_POST['password']       ?? '';
    $role           = $_POST['role']           ?? 'moderator';
    $access_type    = $_POST['access_type']    ?? 'all';
    $district_access = $_POST['district_access'] ?? '';

    if (empty($usuario) || empty($password) || strlen($password) < 8)
        sendResponse(["status" => "error", "message" => "Usuari, email i contrasenya (mín. 8 caràcters) obligatoris."], 400);
    if (!filter_var($usuario, FILTER_VALIDATE_EMAIL))
        sendResponse(["status" => "error", "message" => "L'usuari ha de ser un email vàlid."], 400);

    $hash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $conn->prepare("INSERT INTO admins (usuario,password,role,access_type,district_access) VALUES (?,?,?,?,?)");
    if (!$stmt) sendResponse(["status" => "error", "message" => "Error DB."], 500);
    $stmt->bind_param("sssss", $usuario, $hash, $role, $access_type, $district_access);

    if ($stmt->execute()) sendResponse(["status" => "success", "message" => "Administrador creat."]);
    elseif ($stmt->errno === 1062) sendResponse(["status" => "error", "message" => "L'usuari (email) ja existeix."], 409);
    else {
        error_log('[BadaVeu] Error creant administrador: ' . $stmt->error);
        sendResponse(["status" => "error", "message" => "Error intern en crear l'administrador."], 500);
    }
}

function handleUpdateAdmin(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']) || ($_SESSION['admin_role'] ?? '') !== 'superadmin')
        sendResponse(["status" => "error", "message" => "Permisos insuficients."], 403);
    requireCsrf();

    $id              = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
    $usuario         = $_POST['usuario']         ?? '';
    $password        = $_POST['password']        ?? '';
    $role            = $_POST['role']            ?? 'moderator';
    $access_type     = $_POST['access_type']     ?? 'all';
    $district_access = $_POST['district_access'] ?? '';

    if (!$id || empty($usuario)) sendResponse(["status" => "error", "message" => "ID i usuari obligatoris."], 400);
    if (!filter_var($usuario, FILTER_VALIDATE_EMAIL)) sendResponse(["status" => "error", "message" => "Email no vàlid."], 400);

    if (!empty($password)) {
        if (strlen($password) < 8) sendResponse(["status" => "error", "message" => "Contrasenya mín. 8 caràcters."], 400);
        $hash = password_hash($password, PASSWORD_DEFAULT);
        $stmt = $conn->prepare("UPDATE admins SET usuario=?,password=?,role=?,access_type=?,district_access=? WHERE id=?");
        if (!$stmt) sendResponse(["status" => "error", "message" => "Error DB."], 500);
        $stmt->bind_param("sssssi", $usuario, $hash, $role, $access_type, $district_access, $id);
    } else {
        $stmt = $conn->prepare("UPDATE admins SET usuario=?,role=?,access_type=?,district_access=? WHERE id=?");
        if (!$stmt) sendResponse(["status" => "error", "message" => "Error DB."], 500);
        $stmt->bind_param("ssssi", $usuario, $role, $access_type, $district_access, $id);
    }

    if ($stmt->execute()) {
        if ($id === (int)($_SESSION['user_id'] ?? 0)) {
            $_SESSION['admin_role']     = $role;
            $_SESSION['access_type']    = $access_type;
            $_SESSION['district_access'] = $district_access;
        }
        sendResponse(["status" => "success", "message" => "Administrador actualitzat."]);
    } else {
        error_log('[BadaVeu] Error actualitzant administrador: ' . $stmt->error);
        sendResponse(["status" => "error", "message" => "Error intern en actualitzar l'administrador."], 500);
    }
}

function handleUserManagement(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']) || ($_SESSION['admin_role'] ?? '') !== 'superadmin')
        sendResponse(["status" => "error", "message" => "Permisos insuficients."], 403);

    $action = $_REQUEST['action'] ?? 'get_admins';

    if ($action === 'get_admins') {
        $result = $conn->query("SELECT id,usuario,role,COALESCE(access_type,'all') AS access_type,COALESCE(district_access,'all') AS district_access FROM admins ORDER BY id DESC");
        if (!$result) {
            error_log('[BadaVeu] Error obtenint llista d\'admins: ' . $conn->error);
            sendResponse(["status" => "error", "message" => "Error intern en obtenir la llista."], 500);
        }
        $users = [];
        while ($row = $result->fetch_assoc()) $users[] = $row;
        sendResponse(["status" => "success", "data" => $users]);
    }

    if ($action === 'delete_admin' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        requireCsrf();
        $id = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id) sendResponse(["status" => "error", "message" => "ID no vàlid."], 400);

        $stmt = $conn->prepare("SELECT id,role FROM admins WHERE id=?");
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $user = $stmt->get_result()->fetch_assoc();
        if (!$user) sendResponse(["status" => "error", "message" => "Usuari no trobat."], 404);
        if ((int)$user['id'] === (int)($_SESSION['user_id'] ?? 0))
            sendResponse(["status" => "error", "message" => "No pots eliminar el teu propi compte."], 403);
        if ($user['role'] === 'superadmin') {
            $cnt = $conn->query("SELECT COUNT(id) FROM admins WHERE role='superadmin'")->fetch_row()[0];
            if ($cnt <= 1) sendResponse(["status" => "error", "message" => "No es pot eliminar l'últim Superadmin."], 403);
        }

        $stmt = $conn->prepare("DELETE FROM admins WHERE id=?");
        $stmt->bind_param("i", $id);
        if ($stmt->execute() && $stmt->affected_rows > 0) sendResponse(["status" => "success", "message" => "Usuari eliminat."]);
        else sendResponse(["status" => "error", "message" => "Usuari no trobat o ja eliminat."], 404);
    }
    sendResponse(["status" => "error", "message" => "Acció desconeguda."], 400);
}

// ── Auth ──────────────────────────────────────────────────────────────────────
function checkAuth(): never {
    // Always include a fresh CSRF token in the check_auth response so the
    // frontend can use it directly — no extra round-trip needed, and the token
    // is always tied to the current live session.
    $csrf = generateCsrfToken();

    if (isset($_SESSION['admin_logged_in']) && $_SESSION['admin_logged_in'] === true)
        sendResponse([
            'logged_in'       => true,
            'admin_role'      => $_SESSION['admin_role']      ?? 'admin',
            'access_type'     => $_SESSION['access_type']     ?? 'all',
            'district_access' => $_SESSION['district_access'] ?? null,
            'csrf_token'      => $csrf,
        ]);
    else
        sendResponse(['logged_in' => false, 'csrf_token' => $csrf]);
}

function handleLogin(mysqli $conn): never {
    $rl = new RateLimiter();
    $rl->enforce('login', 10, 900, 1800);
    // Login does not require a pre-existing CSRF token — the session hasn't been
    // authenticated yet so there is no state worth protecting via CSRF here.
    // CSRF protection is enforced on all mutating endpoints post-login.

    $usuario  = $_POST['usuario']  ?? '';
    $password = $_POST['password'] ?? '';
    if (empty($usuario) || empty($password))
        sendResponse(["status" => "error", "message" => "Falten credencials."], 400);

    $stmt = $conn->prepare(
        "SELECT id,password,role,COALESCE(access_type,'all') AS access_type,COALESCE(district_access,'all') AS district_access
         FROM admins WHERE usuario=?"
    );
    if ($stmt === false) sendResponse(["status" => "error", "message" => "Error DB login."], 500);
    $stmt->bind_param("s", $usuario);
    if (!$stmt->execute()) sendResponse(["status" => "error", "message" => "Error executant login."], 500);

    $user = $stmt->get_result()->fetch_assoc();

    // Si l'usuari no existeix, verifiquem igualment contra un hash fals perque
    // la resposta trigui el mateix. Sense aixo, el temps de resposta delata
    // quins noms d'usuari existeixen (enumeracio d'usuaris).
    $hash = $user['password'] ?? '$2y$12$usesomesillystringfooooooooooooooooooooooooooooooooooooo';
    $ok   = password_verify($password, $hash) && $user;

    if ($ok) {
        session_regenerate_id(true);
        $_SESSION['admin_logged_in']  = true;
        $_SESSION['user_id']          = $user['id'];
        $_SESSION['username']         = $usuario;
        // Mateix valor amb la clau que llegeix el registre d'historial. Sense
        // aixo, historial_incidencias.admin_usuario es desava sempre NULL i el
        // rastre d'auditoria no deia qui havia canviat cada incidencia.
        $_SESSION['admin_user']       = $usuario;
        $_SESSION['admin_role']       = $user['role'];
        $_SESSION['access_type']      = $user['access_type'];
        $_SESSION['district_access']  = $user['district_access'];
        sendResponse(["status" => "success", "message" => "Login correcte.", "role" => $user['role']]);
    }

    // Missatge UNIC per a usuari inexistent i contrasenya incorrecta: distingir
    // els dos casos permet a un atacant confirmar noms d'usuari valids abans
    // de provar contrasenyes.
    sendResponse(["status" => "error", "message" => "Credencials incorrectes."], 401);
}

function handleLogout(): never {
    session_unset();
    session_destroy();
    sendResponse(["status" => "success", "message" => "Logout correcte."]);
}

// ── Bulk Update Status ────────────────────────────────────────────────────────
function handleBulkUpdateStatus(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);
    requireCsrf();

    $ids_raw    = $_POST['ids'] ?? [];
    $new_status = $_POST['estado'] ?? '';
    $comentario = trim(strip_tags($_POST['comentario'] ?? ''));
    $comentario = $comentario !== '' ? mb_substr($comentario, 0, 500, 'UTF-8') : null;

    if (!is_array($ids_raw) || empty($ids_raw))
        sendResponse(["status" => "error", "message" => "Cap incidència seleccionada."], 400);
    if (!in_array($new_status, ['pendiente', 'proceso', 'resuelto', 'denegado'], true))
        sendResponse(["status" => "error", "message" => "Estat no vàlid."], 400);

    $ids = array_values(array_filter(array_map('intval', $ids_raw), fn($id) => $id > 0));
    if (count($ids) === 0 || count($ids) > 100)
        sendResponse(["status" => "error", "message" => "Nombre d'IDs no vàlid (1-100)."], 400);

    $admin_user   = $_SESSION['admin_user'] ?? null;
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $affected = 0;

    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare("UPDATE incidencias SET estado=?, updated_at=NOW() WHERE id IN ($placeholders) AND archivado=0");
        if (!$stmt) throw new \RuntimeException("Error preparant UPDATE.");
        $params = array_merge([$new_status], $ids);
        $types  = 's' . str_repeat('i', count($ids));
        $stmt->bind_param($types, ...$params);
        if (!$stmt->execute()) throw new \RuntimeException('UPDATE: ' . $stmt->error);
        $affected = $stmt->affected_rows;

        $hStmt = $conn->prepare(
            "INSERT INTO historial_incidencias (incidencia_id, estado_nuevo, comentario_admin, admin_usuario) VALUES (?, ?, ?, ?)"
        );
        if (!$hStmt) throw new \RuntimeException("Error preparant historial.");
        foreach ($ids as $id) {
            $hStmt->bind_param("isss", $id, $new_status, $comentario, $admin_user);
            if (!$hStmt->execute()) throw new \RuntimeException("Error inserint historial per ID $id.");
        }

        $conn->commit();
    } catch (\RuntimeException $e) {
        $conn->rollback();
        error_log('[BadaVeu] Error en transacció massiva: ' . $e->getMessage());
        sendResponse(["status" => "error", "message" => "Error intern en processar l'acció massiva."], 500);
    }
    sendResponse([
        "status"   => "success",
        "message"  => "$affected incidències actualitzades.",
        "affected" => $affected,
        "meta"     => ["total_requested" => count($ids), "total_updated" => $affected],
    ]);
}

// ── Activity Log ──────────────────────────────────────────────────────────────
function getActivityLog(mysqli $conn): never {
    if (!isset($_SESSION['admin_logged_in']))
        sendResponse(["status" => "error", "message" => "No autoritzat."], 401);

    $page   = max(1, (int)($_GET['page'] ?? 1));
    $limit  = 30;
    $offset = ($page - 1) * $limit;

    $totalRes = $conn->query("SELECT COUNT(id) FROM historial_incidencias");
    $total = $totalRes ? (int)$totalRes->fetch_row()[0] : 0;

    $stmt = $conn->prepare(
        "SELECT h.id, h.incidencia_id, i.titulo, h.estado_anterior, h.estado_nuevo,
                h.comentario_admin, h.admin_usuario, h.fecha
         FROM historial_incidencias h
         LEFT JOIN incidencias i ON i.id = h.incidencia_id
         ORDER BY h.fecha DESC LIMIT ? OFFSET ?"
    );
    if (!$stmt) sendResponse(["status" => "error", "message" => "Error DB."], 500);
    $stmt->bind_param("ii", $limit, $offset);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    sendResponse([
        "status" => "success",
        "data"   => $rows,
        "total"  => $total,
        "page"   => $page,
        "pages"  => max(1, (int)ceil($total / $limit)),
    ]);
}

// ── Router ────────────────────────────────────────────────────────────────────
$conn = connectDB();
if (!$conn) sendResponse(["status" => "error", "message" => "Error de connexió a BD."], 503);

// Run RateLimiter cleanup occasionally
(new RateLimiter())->cleanup();

$action = $_REQUEST['action'] ?? '';

switch ($action) {
    case 'get_csrf':
        sendResponse(['csrf_token' => generateCsrfToken()]);
        break;

    case 'public_data':
        getPublicData($conn);
        break;

    case 'public_stats':
        getPublicStats($conn);
        break;

    case 'public_incident':
        getPublicIncident($conn);
        break;

    case 'reverse_geocode':
        handleReverseGeocode();
        break;

    case 'new_incident':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleNewIncident($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'vote':
    case 'unvote':
        $id = filter_var($_REQUEST['id'] ?? null, FILTER_VALIDATE_INT);
        handleVote($conn, $id, $action);
        break;

    case 'check_auth':
        checkAuth();
        break;

    case 'login':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleLogin($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'logout':
        handleLogout();
        break;

    case 'admin_data':
        getAdminData($conn);
        break;

    case 'update_status':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleUpdateStatus($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'update_urgencia':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleUpdateUrgencia($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'archive_incident':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleArchiveIncident($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'get_incident_history':
        getIncidentHistory($conn);
        break;

    case 'admin_stats':
        getAdminStats($conn);
        break;

    case 'export_csv':
        exportCsv($conn);
        break;

    case 'get_admins':
    case 'delete_admin':
        handleUserManagement($conn);
        break;

    case 'create_admin':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleCreateAdmin($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'update_admin':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleUpdateAdmin($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'bulk_update_status':
        if ($_SERVER['REQUEST_METHOD'] === 'POST') handleBulkUpdateStatus($conn);
        else sendResponse(["status" => "error", "message" => "Mètode no permès."], 405);
        break;

    case 'get_activity_log':
        getActivityLog($conn);
        break;

    default:
        sendResponse(["status" => "error", "message" => "Acció desconeguda: $action"], 404);
}

$conn->close();
