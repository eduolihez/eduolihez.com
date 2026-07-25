<?php

$candidates = [
    __DIR__ . '/../.env',    // raíz del proyecto (caso habitual en hosting compartido)
    __DIR__ . '/../../.env', // si api/ está un nivel más profundo
    __DIR__ . '/.env',       // si .env se coloca dentro de api/
];
$envFile = null;
foreach ($candidates as $candidate) {
    if (file_exists($candidate)) {
        $envFile = $candidate;
        break;
    }
}
if ($envFile === null) {
    error_log('[BadaVeu] Fitxer .env no trobat. Rutes provades: ' . implode(', ', $candidates));
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Error de configuració del servidor."]);
    exit;
}

$lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
foreach ($lines as $line) {
    $line = trim($line);
    if ($line === '' || str_starts_with($line, '#')) continue;
    if (strpos($line, '=') === false) continue;
    [$key, $value] = explode('=', $line, 2);
    $key   = trim($key);
    $value = trim($value);
    if (!defined($key)) {
        define($key, $value);
    }
}

if (!defined('DB_HOST') || !defined('DB_USER') || !defined('DB_PASS') || !defined('DB_NAME')) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Configuració de base de dades incompleta."]);
    exit;
}
