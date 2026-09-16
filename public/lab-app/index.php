<?php
/**
 * Front controller de lab.eduolihez.com. Todo lo que no sea login.php o
 * logout.php llega aquí (ver .htaccess): exige sesión y, si la hay, sirve el
 * archivo pedido desde _content/ (el build estático de PhishLab, generado
 * por tools/build-lab.js en el repo de PhishLab).
 *
 * Streaming manual en vez de dejar que Apache sirva _content/ directamente:
 * _content/.htaccess bloquea el acceso HTTP a ese directorio (Require all
 * denied), así que la única puerta de entrada es este script leyendo el
 * archivo por filesystem (PHP sí puede, Apache-vía-HTTP no).
 */
require_once __DIR__ . '/../lab/auth.php';

require_lab_login();

$uri  = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?? '/';
$path = preg_replace('#^/lab-app/?#', '', (string) $uri);
if ($path === '' || $path === false) {
    $path = 'index.html';
}

$base = realpath(__DIR__ . '/_content');
if ($base === false) {
    http_response_code(500);
    exit('Contenido no disponible.');
}

$target = realpath($base . '/' . $path);

// Fuera de _content/ (path traversal) o no existe.
if ($target === false || ($target !== $base && !str_starts_with($target, $base . DIRECTORY_SEPARATOR))) {
    http_response_code(404);
    exit('No encontrado.');
}

if (is_dir($target)) {
    $target = rtrim($target, '/\\') . '/index.html';
    if (!is_file($target)) {
        http_response_code(404);
        exit('No encontrado.');
    }
}

$ext = strtolower(pathinfo($target, PATHINFO_EXTENSION));
$mimes = [
    'html'  => 'text/html; charset=utf-8',
    'js'    => 'application/javascript; charset=utf-8',
    'css'   => 'text/css; charset=utf-8',
    'json'  => 'application/json; charset=utf-8',
    'svg'   => 'image/svg+xml',
    'woff2' => 'font/woff2',
    'txt'   => 'text/plain; charset=utf-8',
];

header('Content-Type: ' . ($mimes[$ext] ?? 'application/octet-stream'));
// Contenido autenticado: nunca en una cache compartida (ni la de Cloudflare
// ni la de un proxy intermedio) -- cada usuario lleva su propia sesión.
header('Cache-Control: private, no-store');
header('X-Robots-Tag: noindex, nofollow');

readfile($target);
