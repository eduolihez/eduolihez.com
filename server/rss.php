<?php
/**
 * /blog/rss.xml — feed RSS 2.0 de los articulos del blog en espanol.
 * ---------------------------------------------------------------------------
 * POR QUE EXISTE: el resto de "salidas" del blog para maquinas
 * (sitemap-posts.php, llms-blog.php) llevaron a la misma conclusion de la
 * auditoria de diseno: el contenido vive en MySQL y se publica desde /admin
 * sin recompilar, asi que cualquier archivo generado en build-time (Astro) se
 * queda obsoleto el mismo dia que publicas. Un feed RSS es la forma estandar
 * en la que un lector tecnico sigue un blog sin visitarlo a diario, y para un
 * blog de seguridad es una ausencia que se nota. Este archivo lee la tabla en
 * cada peticion, igual que sitemap-posts.php: publicas y ya esta dentro.
 *
 * DONDE VIVE: el contenido de server/ se sube a la raiz web, asi que este
 * archivo queda en /rss.php, y el .htaccess lo sirve como /blog/rss.xml.
 *
 * Solo espanol por ahora: EN y CA no tienen articulos todavia (ver
 * src/lib/posts.ts). Cuando los tengan, el patron para anadir sus feeds es
 * el mismo con WHERE lang = 'en' / 'ca' y su propio POST_PATHS.
 */
require_once __DIR__ . '/lib/http.php';
require_once __DIR__ . '/lib/site.php';

header('Content-Type: application/rss+xml; charset=utf-8');
// Una hora: igual que sitemap-posts.php, no castiga la base de datos y un
// articulo nuevo aparece el mismo dia sin esperar a un rebuild.
header('Cache-Control: public, max-age=3600');

/** Fecha RFC 822, el formato que exige <pubDate> en RSS 2.0. */
function rss_date(string $mysqlDatetime): string
{
    $ts = strtotime($mysqlDatetime);
    return $ts === false ? date('r') : date('r', $ts);
}

/** Escapa para texto XML (fuera de CDATA): titulo, descripcion corta, categorias. */
function rss_escape(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_XML1, 'UTF-8');
}

try {
    $stmt = db()->query(
        "SELECT title, slug, summary, content, tags,
                COALESCE(published_at, created_at) AS published_at
         FROM posts
         WHERE visible = 1 AND slug <> '' AND lang = 'es'
         ORDER BY published_at DESC, id DESC
         LIMIT 30"
    );
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    /*
     * Igual que sitemap-posts.php: un feed valido con cero items le dice a
     * cualquier lector "aqui ya no hay articulos" y puede desuscribirlo en
     * silencio. Un 503 dice "vuelve luego", que es lo que ha pasado de verdad.
     */
    http_response_code(503);
    header('Cache-Control: no-store');
    header('Retry-After: 3600');
    echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
    echo '<!-- La base de datos no responde. Reintenta mas tarde. -->' . "\n";
    exit;
}

$base = POST_PATHS['es'];
$now = date('r');

echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
echo '<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:atom="http://www.w3.org/2005/Atom">' . "\n";
echo "  <channel>\n";
echo '    <title>' . rss_escape('Blog de Eduardo Olivares Hernández') . "</title>\n";
echo '    <link>' . SITE_ORIGIN . "/blog/</link>\n";
echo '    <atom:link href="' . SITE_ORIGIN . '/blog/rss.xml" rel="self" type="application/rss+xml"/>' . "\n";
echo '    <description>' . rss_escape('Artículos sobre ciberseguridad, respuesta a incidentes y automatización.') . "</description>\n";
echo "    <language>es</language>\n";
echo "    <lastBuildDate>{$now}</lastBuildDate>\n";

foreach ($rows as $row) {
    $slug = (string) $row['slug'];
    $url = SITE_ORIGIN . $base . rawurlencode($slug) . '/';
    $title = trim((string) $row['title']);
    $summary = trim((string) $row['summary']);

    // El cuerpo del articulo permite HTML crudo (se redacta desde /admin,
    // zona autenticada), pero un feed no lo ejecuta nunca: strip solo por
    // higiene, igual que to_plain_text() en text.php, sin aplanarlo a texto
    // plano (aqui SI queremos las etiquetas para que el lector RSS lo pinte).
    $content = (string) $row['content'];
    $content = preg_replace('#<(script|style)\b[^>]*>.*?</\1>#is', '', $content) ?? $content;
    // "]]>" cierra una seccion CDATA aunque aparezca dentro del texto: sin
    // esto, un articulo cuyo HTML contuviera esa secuencia literal rompe el
    // XML del feed entero, no solo ese item.
    $content = str_replace(']]>', ']]&gt;', $content);

    echo "    <item>\n";
    echo '      <title>' . rss_escape($title) . "</title>\n";
    echo "      <link>{$url}</link>\n";
    echo '      <guid isPermaLink="true">' . $url . "</guid>\n";
    echo '      <pubDate>' . rss_date((string) $row['published_at']) . "</pubDate>\n";
    if ($summary !== '') {
        echo '      <description>' . rss_escape($summary) . "</description>\n";
    }
    $tags = trim((string) ($row['tags'] ?? ''));
    if ($tags !== '') {
        foreach (array_map('trim', explode(',', $tags)) as $tag) {
            if ($tag !== '') {
                echo '      <category>' . rss_escape($tag) . "</category>\n";
            }
        }
    }
    echo '      <content:encoded><![CDATA[' . $content . ']]></content:encoded>' . "\n";
    echo "    </item>\n";
}

echo "  </channel>\n";
echo "</rss>\n";
