<?php
/**
 * GET /api/projects.php?lang=es|en|ca
 * Devuelve los proyectos PUBLICADOS, ya localizados. Incluye la descripcion
 * larga para el modal de detalle. En catalan cae a espanol (no hay campos ca).
 * Ordena: primero los destacados, luego por sort_order.
 */
require_once __DIR__ . '/../lib/http.php';

apply_cors();
require_method('GET');

// Solo el ingles tiene campos propios; es y ca usan los campos en espanol.
$isEn = ($_GET['lang'] ?? 'es') === 'en';

try {
    $stmt = db()->query(
        "SELECT id, title_es, title_en, summary_es, summary_en,
                description_es, description_en, image_url,
                stack, repo_url, demo_url, store_url, featured, sort_order
         FROM projects
         WHERE status = 'published'
         ORDER BY featured DESC, sort_order ASC, id DESC"
    );
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    json(['error' => 'Error al leer proyectos'], 500);
}

$items = array_map(function (array $r) use ($isEn) {
    $stack = [];
    if (!empty($r['stack'])) {
        $decoded = json_decode($r['stack'], true);
        if (is_array($decoded)) {
            $stack = $decoded;
        }
    }
    // Para ingles usa el campo _en si existe; si esta vacio, cae al _es.
    $pick = function (string $es, string $en) use ($isEn, $r) {
        if ($isEn) {
            return ($r[$en] ?? '') !== '' ? $r[$en] : ($r[$es] ?? '');
        }
        return $r[$es] ?? '';
    };

    return [
        'id'          => (int) $r['id'],
        'title'       => $pick('title_es', 'title_en'),
        'summary'     => $pick('summary_es', 'summary_en'),
        'description' => $pick('description_es', 'description_en'),
        'image_url'   => $r['image_url'],
        'stack'       => $stack,
        'repo_url'    => $r['repo_url'],
        'demo_url'    => $r['demo_url'],
        'store_url'   => $r['store_url'],
        'featured'    => (int) $r['featured'],
    ];
}, $rows);

json($items);
