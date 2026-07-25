<?php
/**
 * Generador d'icones PWA per a BadaVeu.
 * Executa una vegada des del servidor: https://dominio.com/generate-icons.php
 * S'elimina sol després de generar els arxius.
 */

if (!extension_loaded('gd')) {
    http_response_code(500);
    die('ERROR: La extensió GD de PHP no està disponible en aquest servidor.');
}

$imgDir = __DIR__ . '/assets/img';
if (!is_dir($imgDir) && !mkdir($imgDir, 0755, true)) {
    http_response_code(500);
    die('ERROR: No es pot crear el directori assets/img/');
}

function generateIcon(string $path, int $size): bool {
    $img = imagecreatetruecolor($size, $size);

    // Fons #002D5A (blau corporatiu BadaVeu)
    $bg = imagecolorallocate($img, 0, 45, 90);
    imagefill($img, 0, 0, $bg);

    // Text "BV" centrat en blanc
    $white = imagecolorallocate($img, 255, 255, 255);
    $font  = 5; // font integrada de GD
    $char  = 'BV';
    $tw    = imagefontwidth($font) * strlen($char);
    $th    = imagefontheight($font);
    $x     = (int)(($size - $tw) / 2);
    $y     = (int)(($size - $th) / 2);
    imagestring($img, $font, $x, $y, $char, $white);

    $ok = imagepng($img, $path);
    imagedestroy($img);
    return $ok;
}

$icons = [
    $imgDir . '/icon-192.png' => 192,
    $imgDir . '/icon-512.png' => 512,
];

$results = [];
foreach ($icons as $path => $size) {
    $results[] = generateIcon($path, $size)
        ? "OK: " . basename($path) . " ({$size}x{$size}px) creat."
        : "ERROR: No s'ha pogut crear " . basename($path);
}

// Auto-eliminació
@unlink(__FILE__);

header('Content-Type: text/plain; charset=utf-8');
echo implode("\n", $results) . "\n";
echo "\nIcones generades a assets/img/\n";
echo "Aquest script s'ha eliminat automàticament.\n";
echo "IMPORTANT: Substitueix els iconos placeholder per la imatge real de la marca.\n";
