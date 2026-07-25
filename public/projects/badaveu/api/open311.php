<?php
// ============================================================
//  BadaVeu — Open311 GeoReport v2 (Read-Only)
//  Endpoint públic per a interoperabilitat amb sistemes
//  municipals i plataformes de Smart City.
//
//  Especificació: https://wiki.open311.org/GeoReport_v2/
//  Mètodes implementats (GET only):
//    GET /api/open311.php/services.json
//    GET /api/open311.php/requests.json
//    GET /api/open311.php/requests/<id>.json
// ============================================================

header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('Access-Control-Allow-Origin: ' . (defined('APP_URL') ? APP_URL : '*'));
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Cache-Control: public, max-age=120');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method Not Allowed. This is a read-only endpoint.']);
    exit;
}

require_once __DIR__ . '/config.php';

// ── Helpers ───────────────────────────────────────────────────────────────────

function open311Json(mixed $data, int $code = 200): never {
    http_response_code($code);
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

function connectDB311(): mysqli {
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($conn->connect_error) {
        open311Json(['error' => 'Service temporarily unavailable.'], 503);
    }
    $conn->set_charset('utf8mb4');
    return $conn;
}

// ── Service type catalogue ────────────────────────────────────────────────────
// Maps BadaVeu tipo_problema → Open311 service_code / group / keywords

const SERVICE_CATALOGUE = [
    'Il·luminació'           => ['code' => 'LLUM',   'group' => 'infraestructura', 'keywords' => 'llum,fanal,il·luminació,alumbrado'],
    'Voreres'                => ['code' => 'VORE',   'group' => 'infraestructura', 'keywords' => 'vorera,sidewalk,acera'],
    'Neteja'                 => ['code' => 'NET',    'group' => 'infraestructura', 'keywords' => 'neteja,brossa,escombraries,limpieza'],
    'Parcs i Jardins'        => ['code' => 'PARC',   'group' => 'infraestructura', 'keywords' => 'parc,jardí,zona verda'],
    'Mobiliari Urbà'         => ['code' => 'MOB',    'group' => 'infraestructura', 'keywords' => 'banc,contenidor,mobiliari'],
    'Barrera Arquitectònica' => ['code' => 'BARR',   'group' => 'infraestructura', 'keywords' => 'accessibilitat,rampa,wheelchair'],
    'Vandalisme'             => ['code' => 'VAND',   'group' => 'denuncia',        'keywords' => 'vandalisme,grafiti,pintada'],
    'Soroll'                 => ['code' => 'SOR',    'group' => 'denuncia',        'keywords' => 'soroll,ruido,noise'],
    'Seguretat'              => ['code' => 'SEG',    'group' => 'denuncia',        'keywords' => 'seguretat,seguridad,policia'],
    'Altres'                 => ['code' => 'ALTRES', 'group' => 'infraestructura', 'keywords' => 'other,autres,otros'],
];

// ── Status mapping ────────────────────────────────────────────────────────────
// BadaVeu estado → Open311 status
function mapStatus(string $estado): string {
    return match($estado) {
        'resuelto' => 'closed',
        'proceso'  => 'open',      // "in progress" maps to open per spec
        default    => 'open',
    };
}

// ── Route parser ─────────────────────────────────────────────────────────────
// Supports both PATH_INFO (/services.json, /requests/42.json)
// and query param (?endpoint=requests&id=42) for servers without PATH_INFO.

$pathInfo = $_SERVER['PATH_INFO'] ?? '';
$endpoint = '';
$requestId = null;

if ($pathInfo !== '') {
    // PATH_INFO mode: /services.json  or  /requests.json  or  /requests/42.json
    $clean = ltrim($pathInfo, '/');
    if (preg_match('#^requests/(\d+)\.json$#', $clean, $m)) {
        $endpoint  = 'request_detail';
        $requestId = (int)$m[1];
    } elseif ($clean === 'services.json') {
        $endpoint = 'services';
    } elseif ($clean === 'requests.json') {
        $endpoint = 'requests';
    }
} else {
    // Query-string mode: ?endpoint=services|requests|request_detail&id=N
    $endpoint  = $_GET['endpoint'] ?? '';
    $requestId = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT) ?: null;
}

// ── GET /services.json ────────────────────────────────────────────────────────
if ($endpoint === 'services') {
    $services = [];
    foreach (SERVICE_CATALOGUE as $name => $meta) {
        $services[] = [
            'service_code' => $meta['code'],
            'service_name' => $name,
            'description'  => "Incidència del tipus: {$name}",
            'metadata'     => false,
            'type'         => 'realtime',
            'keywords'     => $meta['keywords'],
            'group'        => $meta['group'],
        ];
    }
    open311Json($services);
}

// ── GET /requests.json ────────────────────────────────────────────────────────
if ($endpoint === 'requests') {
    $conn = connectDB311();

    // Optional filters (GeoReport v2 compliant)
    $where  = ['archivado = 0'];
    $params = [];
    $types  = '';

    if (!empty($_GET['service_request_id'])) {
        $id = filter_var($_GET['service_request_id'], FILTER_VALIDATE_INT);
        if ($id) { $where[] = 'id = ?'; $params[] = $id; $types .= 'i'; }
    }

    if (!empty($_GET['service_code'])) {
        // Reverse-map service_code → tipo_problema
        $code = strtoupper(trim($_GET['service_code']));
        $tipo = null;
        foreach (SERVICE_CATALOGUE as $name => $meta) {
            if ($meta['code'] === $code) { $tipo = $name; break; }
        }
        if ($tipo) { $where[] = 'tipo_problema = ?'; $params[] = $tipo; $types .= 's'; }
    }

    if (!empty($_GET['status'])) {
        $s = $_GET['status'];
        if ($s === 'closed') {
            $where[] = "estado = 'resuelto'";
        } elseif ($s === 'open') {
            $where[] = "estado IN ('pendiente','proceso')";
        }
    }

    // start_date / end_date  (ISO 8601 — e.g. 2025-01-01T00:00:00Z)
    // Uses strict parsing via DateTimeImmutable to reject ambiguous strings like "+1 year".
    foreach (['start_date' => '>=', 'end_date' => '<='] as $param => $op) {
        if (empty($_GET[$param])) continue;
        $dt = DateTimeImmutable::createFromFormat(DateTimeInterface::ATOM, $_GET[$param])
           ?: DateTimeImmutable::createFromFormat('Y-m-d', $_GET[$param]);
        if (!$dt) continue;
        $where[]  = "created_at $op ?";
        $params[] = $dt->format('Y-m-d H:i:s');
        $types   .= 's';
    }

    $page  = max(1, (int)($_GET['page']    ?? 1));
    $limit = min(100, max(1, (int)($_GET['page_size'] ?? 50)));
    $offset = ($page - 1) * $limit;

    $sql = 'SELECT id, titulo, descripcion, categoria, tipo_problema,
                   lat, lng, direccion, barri, districte, cp,
                   estado, urgencia, created_at, updated_at
            FROM incidencias
            WHERE ' . implode(' AND ', $where) . '
            ORDER BY created_at DESC LIMIT ? OFFSET ?';

    $params[] = $limit;  $types .= 'i';
    $params[] = $offset; $types .= 'i';

    $stmt = $conn->prepare($sql);
    if (!$stmt) open311Json(['error' => 'Query error.'], 500);

    if ($types) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $requests = array_map(fn($r) => rowToRequest($r), $rows);
    open311Json($requests);
}

// ── GET /requests/<id>.json ───────────────────────────────────────────────────
if ($endpoint === 'request_detail') {
    if (!$requestId) open311Json(['error' => 'Invalid service_request_id.'], 400);

    $conn = connectDB311();
    $stmt = $conn->prepare(
        'SELECT id, titulo, descripcion, categoria, tipo_problema,
                lat, lng, direccion, barri, districte, cp,
                estado, urgencia, created_at, updated_at
         FROM incidencias WHERE id = ? AND archivado = 0 LIMIT 1'
    );
    if (!$stmt) open311Json(['error' => 'Query error.'], 500);
    $stmt->bind_param('i', $requestId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();

    if (!$row) open311Json(['error' => 'Service request not found.'], 404);

    open311Json([rowToRequest($row)]);
}

// ── No matching route ─────────────────────────────────────────────────────────
open311Json([
    'error'   => 'Unknown endpoint.',
    'hint'    => 'Available: /services.json, /requests.json, /requests/{id}.json',
    'docs'    => 'https://wiki.open311.org/GeoReport_v2/',
], 404);

// ── Row → Open311 Service Request object ─────────────────────────────────────
function rowToRequest(array $r): array {
    $tipo  = $r['tipo_problema'] ?? '';
    $meta  = SERVICE_CATALOGUE[$tipo] ?? ['code' => 'ALTRES', 'group' => $r['categoria'] ?? 'infraestructura'];

    // RFC 3339 timestamps
    $createdAt  = $r['created_at']  ? (new DateTimeImmutable($r['created_at']))->format(DateTimeInterface::RFC3339)  : null;
    $updatedAt  = $r['updated_at']  ? (new DateTimeImmutable($r['updated_at']))->format(DateTimeInterface::RFC3339)  : null;

    return [
        'service_request_id' => (string)$r['id'],
        'status'             => mapStatus($r['estado']),
        'status_notes'       => null,
        'service_name'       => $tipo ?: ($r['categoria'] ?? 'Altres'),
        'service_code'       => $meta['code'],
        'description'        => $r['descripcion'] ?? null,
        'agency_responsible' => 'Ajuntament de Badalona',
        'service_notice'     => null,
        'requested_datetime' => $createdAt,
        'updated_datetime'   => $updatedAt,
        'expected_datetime'  => null,
        'address'            => $r['direccion'] ?? null,
        'address_id'         => null,
        'zipcode'            => $r['cp'] ?? null,
        'lat'                => $r['lat'] !== null ? (float)$r['lat'] : null,
        'long'               => $r['lng'] !== null ? (float)$r['lng'] : null,
        'media_url'          => null,
        // BadaVeu-specific extensions (prefixed with x_)
        'x_barri'            => $r['barri']    ?? null,
        'x_districte'        => $r['districte'] ?? null,
        'x_urgencia'         => $r['urgencia']  ?? null,
        'x_categoria'        => $r['categoria'] ?? null,
    ];
}
