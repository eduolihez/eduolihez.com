<?php
/**
 * /sitemap-posts.xml — mapa del sitio de los ARTICULOS del blog.
 * ---------------------------------------------------------------------------
 * POR QUE EXISTE: el sitemap principal (/sitemap.xml) lo genera Astro al
 * compilar, y en ese momento los articulos no existen: viven en MySQL y se
 * publican desde /admin sin recompilar. Resultado: ningun buscador ni
 * rastreador de IA tenia forma de enumerar los articulos. Solo llegaba a
 * ellos si seguia los enlaces del indice del blog, que a su vez se pinta con
 * JavaScript. Para un rastreador que no ejecuta JS -- que son casi todos los
 * de IA -- el blog entero era invisible.
 *
 * Este archivo lo resuelve leyendo la tabla directamente en cada peticion.
 * No hay que recompilar ni acordarse de nada: publicas y ya esta dentro.
 *
 * DONDE VIVE: el contenido de server/ se sube a la raiz web, asi que este
 * archivo queda en /sitemap-posts.php, y el .htaccess lo sirve como
 * /sitemap-posts.xml. Que este en la RAIZ importa: un sitemap solo puede
 * listar URLs que cuelguen de su propia carpeta o por debajo, asi que uno
 * dentro de /api/ no podria listar /blog/.
 */
require_once __DIR__ . '/lib/http.php';
require_once __DIR__ . '/lib/site.php';

header('Content-Type: application/xml; charset=utf-8');
// Una hora: suficiente para no castigar la base de datos y lo bastante corto
// para que un articulo nuevo aparezca el mismo dia.
header('Cache-Control: public, max-age=3600');
header('X-Robots-Tag: noindex');

try {
    $stmt = db()->query(
        'SELECT slug, lang,
                COALESCE(updated_at, published_at, created_at) AS lastmod
         FROM posts
         WHERE visible = 1 AND slug <> ""
         ORDER BY lastmod DESC, id DESC'
    );
    $rows = $stmt->fetchAll();
} catch (Throwable $e) {
    /*
     * Si la base de datos falla NO devolvemos un sitemap vacio: un sitemap
     * valido con cero URLs le dice al buscador "aqui ya no hay articulos", y
     * eso puede desindexarlos. Un 503 le dice "vuelve luego", que es la
     * verdad.
     */
    http_response_code(503);
    header('Cache-Control: no-store');
    header('Retry-After: 3600');
    echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
    echo '<!-- La base de datos no responde. Reintenta mas tarde. -->' . "\n";
    exit;
}

$entries = '';
foreach ($rows as $row) {
    $lang = (string) $row['lang'];
    $base = POST_PATHS[$lang] ?? POST_PATHS['es'];

    // El slug viaja en la query, asi que se codifica para URL y despues se
    // escapa para XML. Sin lo segundo, un slug con & romperia el documento.
    $loc = SITE_ORIGIN . $base . '?slug=' . rawurlencode((string) $row['slug']);
    $loc = htmlspecialchars($loc, ENT_XML1 | ENT_QUOTES, 'UTF-8');

    $lastmod = substr((string) $row['lastmod'], 0, 10);
    if ($lastmod === '' || $lastmod === '0000-00-00') {
        $lastmod = null;
    }

    $entries .= "  <url>\n";
    $entries .= "    <loc>{$loc}</loc>\n";
    if ($lastmod !== null) {
        $entries .= "    <lastmod>{$lastmod}</lastmod>\n";
    }
    $entries .= "  </url>\n";
}

echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' . "\n";
echo $entries;
echo '</urlset>' . "\n";
