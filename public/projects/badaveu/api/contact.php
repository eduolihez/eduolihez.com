<?php
// ── BadaVeu — B2B Contact endpoint ───────────────────────────────────────────
// Receives institutional contact requests from the landing page form and
// stores them in the DB (and optionally emails them to the admin address).
// ─────────────────────────────────────────────────────────────────────────────

declare(strict_types=1);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/RateLimiter.php';

header('Content-Type: application/json; charset=UTF-8');
header('X-Content-Type-Options: nosniff');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Mètode no permès.']);
    exit;
}

// ── Rate limiting (10 requests / 10 min per IP) ───────────────────────────────
$rl = new RateLimiter(__DIR__ . '/rate_cache', 10, 600);
$ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
if (!$rl->check('contact_' . $ip)) {
    http_response_code(429);
    echo json_encode(['status' => 'error', 'message' => 'Massa sol·licituds. Torna-ho a intentar en uns minuts.']);
    exit;
}

// ── Input validation ─────────────────────────────────────────────────────────
$nom        = trim($_POST['nom']          ?? '');
$ajuntament = trim($_POST['ajuntament']   ?? '');
$email      = trim($_POST['email']        ?? '');
$tel        = trim($_POST['tel']          ?? '');
$size       = trim($_POST['municipi_size'] ?? '');
$missatge   = trim($_POST['missatge']     ?? '');

if (!$nom || !$ajuntament || !$email) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Nom, organisme i correu electrònic són obligatoris.']);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'El correu electrònic no és vàlid.']);
    exit;
}

$allowed_sizes = ['', '<10k', '10k-50k', '50k-200k', '>200k'];
if (!in_array($size, $allowed_sizes, true)) {
    $size = '';
}

// Sanitise free-text fields
$nom        = htmlspecialchars($nom,        ENT_QUOTES, 'UTF-8');
$ajuntament = htmlspecialchars($ajuntament, ENT_QUOTES, 'UTF-8');
$tel        = htmlspecialchars($tel,        ENT_QUOTES, 'UTF-8');
$missatge   = htmlspecialchars($missatge,   ENT_QUOTES, 'UTF-8');

// ── Persist to DB ─────────────────────────────────────────────────────────────
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Error de connexió amb la base de dades.']);
    exit;
}
$conn->set_charset('utf8mb4');

// Create table if it doesn't exist yet (idempotent bootstrap)
$conn->query("CREATE TABLE IF NOT EXISTS b2b_contacts (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom         VARCHAR(200)  NOT NULL,
    ajuntament  VARCHAR(200)  NOT NULL,
    email       VARCHAR(200)  NOT NULL,
    tel         VARCHAR(50)   DEFAULT '',
    municipi_size VARCHAR(20) DEFAULT '',
    missatge    TEXT,
    created_at  DATETIME      DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$stmt = $conn->prepare(
    "INSERT INTO b2b_contacts (nom, ajuntament, email, tel, municipi_size, missatge)
     VALUES (?, ?, ?, ?, ?, ?)"
);
if (!$stmt) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Error intern del servidor.']);
    exit;
}
$stmt->bind_param('ssssss', $nom, $ajuntament, $email, $tel, $size, $missatge);
$stmt->execute();
$stmt->close();
$conn->close();

// ── Optional admin notification email ─────────────────────────────────────────
if (defined('MAIL_FROM') && MAIL_FROM) {
    $subject  = "[BadaVeu B2B] Nova sol·licitud de {$ajuntament}";
    $body     = "Nova sol·licitud de contacte B2B:\n\n"
              . "Nom: {$nom}\nOrganisme: {$ajuntament}\nEmail: {$email}\n"
              . "Telèfon: {$tel}\nMunicipi: {$size}\n\nMissatge:\n{$missatge}";
    $headers  = "From: BadaVeu <" . MAIL_FROM . ">\r\n";
    @mail(MAIL_FROM, $subject, $body, $headers);
}

echo json_encode(['status' => 'success', 'message' => 'Sol·licitud enviada! Us contactarem en breu.']);
