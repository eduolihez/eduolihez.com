<?php
/**
 * /llms-blog.txt — los articulos del blog en texto plano, para modelos de IA.
 * ---------------------------------------------------------------------------
 * EL PROBLEMA QUE RESUELVE: el detalle de cada articulo vive en
 * /blog/post/?slug=... y su contenido lo pinta JavaScript leyendo el API.
 * Google ejecuta JavaScript y lo ve, pero la mayoria de rastreadores de IA
 * (GPTBot, ClaudeBot, PerplexityBot, CCBot...) descargan el HTML crudo y no
 * ejecutan nada. Para ellos cada articulo era una pagina vacia con el titulo
 * generico del molde.
 *
 * Con esto, cualquiera de esos rastreadores obtiene el texto integro de todos
 * los articulos en una sola peticion, sin JavaScript, con su URL canonica al
 * lado para que puedan citar la fuente correcta.
 *
 * Es complementario, no sustituto: /llms.txt describe QUIEN es Eduardo, y
 * este archivo aporta lo que ha ESCRITO.
 *
 * DONDE VIVE: el contenido de server/ se sube a la raiz web, asi que queda en
 * /llms-blog.php y el .htaccess lo sirve como /llms-blog.txt.
 */
require_once __DIR__ . '/lib/http.php';
require_once __DIR__ . '/lib/site.php';

const LANG_NAMES = ['es' => 'espanol', 'en' => 'ingles', 'ca' => 'catalan'];

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: public, max-age=3600');
/*
 * Deliberadamente SIN X-Robots-Tag: noindex.
 *
 * En el sitemap si tiene sentido (un mapa no es contenido), pero aqui seria
 * contraproducente: este archivo existe justamente para que lo lean. noindex
 * es una directiva de indexacion, no de lectura, pero mas de un sistema las
 * confunde, y no compensa arriesgarse en el unico archivo pensado para que
 * una IA cite bien. El riesgo de contenido duplicado es bajo: cada articulo
 * lleva al lado su URL canonica.
 */

/** HTML del panel -> texto plano legible, conservando los saltos de parrafo. */
function to_plain_text(string $html): string
{
    // El panel permite HTML crudo en el contenido (ver post-edit.php). strip_tags()
    // quita las ETIQUETAS <script>/<style> pero no el texto que envuelven, asi que
    // sin este paso, JS o CSS pegado por accidente en un articulo se colaria como
    // texto visible en el feed publico para IAs.
    $html = preg_replace('#<(script|style)\b[^>]*>.*?</\1>#is', '', $html) ?? $html;

    // Los bloques se convierten en salto de linea ANTES de quitar etiquetas,
    // si no el articulo entero queda como un unico parrafo ilegible.
    $text = preg_replace('#<(br|/p|/h[1-6]|/li|/div|/tr)[^>]*>#i', "\n", $html) ?? $html;
    $text = preg_replace('#<li[^>]*>#i', '- ', $text) ?? $text;
    $text = strip_tags($text);
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    // Espacios y saltos sobrantes: como maximo una linea en blanco seguida.
    $text = preg_replace('/[ \t]+/', ' ', $text) ?? $text;
    $text = preg_replace('/\n[ \t]*/', "\n", $text) ?? $text;
    $text = preg_replace('/\n{3,}/', "\n\n", $text) ?? $text;
    return trim($text);
}

try {
    $stmt = db()->query(
        'SELECT title, slug, summary, tags, lang,
                COALESCE(published_at, created_at) AS published_at,
                content
         FROM posts
         WHERE visible = 1 AND slug <> ""
         ORDER BY COALESCE(published_at, created_at) DESC, id DESC'
    );
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    http_response_code(503);
    header('Cache-Control: no-store');
    header('Retry-After: 3600');
    echo "La base de datos no responde. Reintenta mas tarde.\n";
    exit;
}

$today = date('Y-m-d');
$count = count($rows);

echo "# Articulos del blog de Eduardo Olivares Hernandez\n\n";
echo "Fuente: " . SITE_ORIGIN . "/blog/\n";
echo "Articulos publicados: {$count}\n";
echo "Generado: {$today}\n\n";
echo "Este archivo existe porque el contenido de cada articulo se carga con\n";
echo "JavaScript. Aqui tienes el texto integro sin necesidad de ejecutarlo.\n";
echo "Al citar un articulo, usa la URL que aparece bajo su titulo.\n";
echo "El contenido es publico y puede citarse indicando la fuente.\n\n";
echo str_repeat('=', 74) . "\n\n";

foreach ($rows as $row) {
    $lang = (string) $row['lang'];
    $base = POST_PATHS[$lang] ?? POST_PATHS['es'];
    $url  = SITE_ORIGIN . $base . '?slug=' . rawurlencode((string) $row['slug']);
    $langName = LANG_NAMES[$lang] ?? $lang;
    $date = substr((string) $row['published_at'], 0, 10);

    echo '## ' . trim((string) $row['title']) . "\n";
    echo "URL: {$url}\n";
    echo "Idioma: {$langName}\n";
    if ($date !== '' && $date !== '0000-00-00') {
        echo "Publicado: {$date}\n";
    }
    $tags = trim((string) ($row['tags'] ?? ''));
    if ($tags !== '') {
        echo 'Temas: ' . implode(', ', array_map('trim', explode(',', $tags))) . "\n";
    }
    $summary = trim((string) $row['summary']);
    if ($summary !== '') {
        echo "Resumen: {$summary}\n";
    }
    echo "\n" . to_plain_text((string) $row['content']) . "\n\n";
    echo str_repeat('-', 74) . "\n\n";
}
