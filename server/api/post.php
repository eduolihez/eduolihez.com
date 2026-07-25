<?php
/**
 * GET /api/post.php?slug=ejemplo-slug
 * Devuelve el contenido completo de una entrada de blog publicada según su slug.
 */
require_once __DIR__ . '/../lib/http.php';

apply_cors();
require_method('GET');

$slug = trim((string) ($_GET['slug'] ?? ''));

if ($slug === '') {
    json(['error' => 'Parámetro slug es obligatorio'], 400);
}

try {
    $stmt = db()->prepare(
        "SELECT id, title, slug, summary, content, cover_url, lang, created_at
         FROM posts
         WHERE visible = 1 AND slug = ?
         LIMIT 1"
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
    'id'         => (int) $row['id'],
    'title'      => $row['title'],
    'slug'       => $row['slug'],
    'summary'    => $row['summary'],
    'content'    => $row['content'],
    'cover_url'  => $row['cover_url'],
    'lang'       => $row['lang'],
    'created_at' => $row['created_at'],
]);
