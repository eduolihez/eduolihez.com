<?php
/**
 * GET /api/post.php?slug=ejemplo-slug
 * Devuelve el contenido completo de una entrada publicada, buscada por slug.
 *
 * Manda tambien `updated_at`: el detalle lo usa para el dateModified de
 * Schema.org, que es lo que distingue un articulo revisado de uno abandonado.
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/post.php';

apply_cors();
require_method('GET');

$slug = trim((string) ($_GET['slug'] ?? ''));

if ($slug === '') {
    json(['error' => 'Parámetro slug es obligatorio'], 400);
}

try {
    $stmt = db()->prepare(
        'SELECT id, title, slug, summary, content, cover_url, tags, lang,
                COALESCE(published_at, created_at) AS published_at,
                updated_at
         FROM posts
         WHERE visible = 1 AND slug = ?
         LIMIT 1'
    );
    $stmt->execute([$slug]);
    $row = $stmt->fetch();
} catch (Throwable $e) {
    json(['error' => 'Error al leer entrada del blog'], 500);
}

if (!$row) {
    json(['error' => 'Entrada no encontrada o no publicada'], 404);
}

json([
    'id'           => (int) $row['id'],
    'title'        => $row['title'],
    'slug'         => $row['slug'],
    'summary'      => $row['summary'],
    'content'      => $row['content'],
    'cover_url'    => $row['cover_url'],
    'tags'         => post_tags($row['tags']),
    'lang'         => $row['lang'],
    'published_at' => $row['published_at'],
    'updated_at'   => $row['updated_at'],
    'read_minutes' => post_read_minutes(mb_strlen((string) $row['content'])),
]);
