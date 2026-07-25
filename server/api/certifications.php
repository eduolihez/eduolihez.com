<?php
/**
 * GET /api/certifications.php?lang=es|en
 * Devuelve las certificaciones visibles, ordenadas por sort_order.
 * (El nombre de la certificacion no se traduce: son nombres propios.)
 */
require_once __DIR__ . '/../lib/http.php';

apply_cors();
require_method('GET');

try {
    $stmt = db()->query(
        "SELECT id, name, issuer, issue_date, credential_url, logo_url, category
         FROM certifications
         WHERE visible = 1
         ORDER BY sort_order ASC, id DESC"
    );
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    json(['error' => 'Error al leer certificaciones'], 500);
}

$items = array_map(function (array $r) {
    return [
        'id'             => (int) $r['id'],
        'name'           => $r['name'],
        'issuer'         => $r['issuer'],
        'issue_date'     => $r['issue_date'],
        'credential_url' => $r['credential_url'],
        'logo_url'       => $r['logo_url'],
        'category'       => $r['category'],
    ];
}, $rows);

json($items);
