<?php
/**
 * GET /api/posts.php?lang=es|en|ca
 * Devuelve las entradas del blog PUBLICADAS del idioma pedido, de mas nueva a
 * mas antigua.
 *
 * La fecha que manda es `published_at`, no `created_at`: un articulo puede
 * pasar semanas en borrador, y entonces "cuando se creo la fila" no es
 * "cuando se publico". COALESCE cubre las filas antiguas que aun no la tengan.
 *
 * El tiempo de lectura se estima aqui, en la consulta, para no tener que
 * enviar el cuerpo entero del articulo solo para contarlo en el navegador.
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/post.php';

apply_cors();
require_method('GET');

$lang = trim((string) ($_GET['lang'] ?? 'es'));
if (!in_array($lang, ['es', 'en', 'ca'], true)) {
    $lang = 'es';
}

try {
    $stmt = db()->prepare(
        'SELECT id, title, slug, summary, cover_url, tags, lang,
                COALESCE(published_at, created_at) AS published_at,
                CHAR_LENGTH(content) AS content_length
         FROM posts
         WHERE visible = 1 AND lang = ?
         ORDER BY COALESCE(published_at, created_at) DESC, id DESC'
    );
    $stmt->execute([$lang]);
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    json(['error' => 'Error al leer entradas del blog'], 500);
}

json(array_map(static fn(array $r): array => [
    'id'            => (int) $r['id'],
    'title'         => $r['title'],
    'slug'          => $r['slug'],
    'summary'       => $r['summary'],
    'cover_url'     => $r['cover_url'],
    'tags'          => post_tags($r['tags']),
    'lang'          => $r['lang'],
    'published_at'  => $r['published_at'],
    'read_minutes'  => post_read_minutes((int) $r['content_length']),
], $rows));
