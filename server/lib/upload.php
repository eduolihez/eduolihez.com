<?php
/**
 * upload.php - Subida segura de imagenes desde el panel.
 * ---------------------------------------------------------------------------
 * Valida: tipo MIME real (no solo la extension), tamano y extension permitida.
 * Guarda con nombre aleatorio en /uploads/<subdir> y devuelve la URL publica.
 * La carpeta /uploads tiene un .htaccess que impide ejecutar codigo (defensa).
 */

require_once __DIR__ . '/bootstrap.php';

/**
 * Procesa un campo de archivo del formulario.
 * @return string|null  URL publica de la imagen, o null si no se subio nada.
 * @throws RuntimeException con un mensaje claro si el archivo no es valido.
 */
function handle_upload(string $field, string $subdir = ''): ?string
{
    // Sin archivo: no es un error, simplemente no se cambia la imagen.
    if (empty($_FILES[$field]) || ($_FILES[$field]['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
        return null;
    }

    $f = $_FILES[$field];
    if ($f['error'] !== UPLOAD_ERR_OK) {
        throw new RuntimeException('Error al subir el archivo (codigo ' . (int) $f['error'] . ').');
    }

    $cfg = config()['uploads'];

    if ($f['size'] <= 0 || $f['size'] > (int) $cfg['max_bytes']) {
        $mb = round(((int) $cfg['max_bytes']) / 1048576, 1);
        throw new RuntimeException("La imagen debe pesar menos de {$mb} MB.");
    }

    // Tipo MIME REAL (leyendo el contenido, no la extension que envia el cliente).
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = (string) $finfo->file($f['tmp_name']);
    $mimeToExt = [
        'image/jpeg' => 'jpg',
        'image/png'  => 'png',
        'image/webp' => 'webp',
        'image/gif'  => 'gif',
    ];
    if (!isset($mimeToExt[$mime])) {
        throw new RuntimeException('Formato no permitido. Sube JPG, PNG, WEBP o GIF.');
    }
    $ext = $mimeToExt[$mime];
    if (!in_array($ext, $cfg['allowed_ext'], true)) {
        throw new RuntimeException('Extension de imagen no permitida.');
    }

    // Segunda verificacion: getimagesize() solo reconoce imagenes REALES.
    // Un archivo con cabecera de imagen falsificada (polyglot GIF/PHP) supera
    // finfo pero falla aqui. Ademas ponemos un tope de dimensiones para que
    // nadie tumbe el servidor con una "decompression bomb" de 30000x30000 px.
    $size = @getimagesize($f['tmp_name']);
    if ($size === false || empty($size[0]) || empty($size[1])) {
        throw new RuntimeException('El archivo no es una imagen valida.');
    }
    $maxSide = (int) ($cfg['max_dimension'] ?? 6000);
    if ($size[0] > $maxSide || $size[1] > $maxSide) {
        throw new RuntimeException("La imagen es demasiado grande ({$size[0]}x{$size[1]}). Maximo {$maxSide}px por lado.");
    }

    // Carpeta destino (crea el subdirectorio si no existe).
    $subdir = trim(preg_replace('/[^a-z0-9_-]/i', '', $subdir), '/');
    $dir = rtrim($cfg['dir'], '/\\') . ($subdir !== '' ? '/' . $subdir : '');
    if (!is_dir($dir) && !@mkdir($dir, 0755, true) && !is_dir($dir)) {
        throw new RuntimeException('No se pudo crear la carpeta de subidas. Revisa permisos.');
    }

    // Nombre aleatorio (evita colisiones y adivinar rutas).
    $name = bin2hex(random_bytes(8)) . '.' . $ext;
    $dest = $dir . '/' . $name;

    if (!move_uploaded_file($f['tmp_name'], $dest)) {
        throw new RuntimeException('No se pudo guardar la imagen en el servidor.');
    }
    @chmod($dest, 0644);

    // URL publica.
    $urlBase = rtrim($cfg['url_base'], '/') . ($subdir !== '' ? '/' . $subdir : '');
    return $urlBase . '/' . $name;
}

/**
 * Borra un archivo subido previamente a partir de su URL publica.
 * Se usa al eliminar un proyecto/certificacion para no dejar huerfanos.
 *
 * SEGURIDAD: solo borra dentro de la carpeta de subidas y solo archivos con
 * el patron de nombre que genera handle_upload() (16 hex + extension), asi
 * que un valor manipulado en la BD no puede provocar el borrado de otro
 * archivo del servidor (path traversal).
 */
function delete_upload(?string $url): bool
{
    $url = trim((string) $url);
    if ($url === '') {
        return false;
    }
    $cfg     = config()['uploads'];
    $urlBase = rtrim($cfg['url_base'], '/');

    if (!str_starts_with($url, $urlBase . '/')) {
        return false; // imagen externa (https://...) o ruta ajena: no la tocamos
    }
    $rel = substr($url, strlen($urlBase) + 1);
    if (!preg_match('#^(?:[a-z0-9_-]+/)?[0-9a-f]{16}\.(jpg|png|webp|gif)$#i', $rel)) {
        return false;
    }

    $path = rtrim($cfg['dir'], '/\\') . '/' . $rel;
    $real = realpath($path);
    $root = realpath(rtrim($cfg['dir'], '/\\'));
    if ($real === false || $root === false || !str_starts_with($real, $root)) {
        return false;
    }
    return @unlink($real);
}
