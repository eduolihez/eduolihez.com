<?php
/**
 * GET /api/posts.php?lang=es|en|ca
 * Devuelve las entradas del blog PUBLICADAS, filtradas por idioma y ordenadas por fecha.
 */
require_once __DIR__ . '/../lib/http.php';

apply_cors();
require_method('GET');

$lang = trim((string) ($_GET['lang'] ?? 'es'));
if (!in_array($lang, ['es', 'en', 'ca'], true)) {
    $lang = 'es';
}

try {
    $stmt = db()->prepare(
        "SELECT id, title, slug, summary, cover_url, lang, created_at
         FROM posts
         WHERE visible = 1 AND lang = ?
         ORDER BY created_at DESC"
    );
    $stmt->execute([$lang]);
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    json(['error' => 'Error al leer entradas del blog'], 500);
}

$items = array_map(function (array $r) {
    return [
        'id'         => (int) $r['id'],
        'title'      => $r['title'],
        'slug'       => $r['slug'],
        'summary'    => $r['summary'],
        'cover_url'  => $r['cover_url'],
        'lang'       => $r['lang'],
        'created_at' => $r['created_at'],
    ];
}, $rows);

json($items);
