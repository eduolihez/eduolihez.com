<?php
/**
 * Piezas puras de /sitemap-posts.xml (sin db(), testeables en PHPUnit).
 *
 * La relacion "este articulo ES es la traduccion de este CA" no esta en la
 * base de datos: la declara src/lib/postTranslations.ts, y el build de Astro
 * la publica como /blog/translations.json (una sola fuente de verdad). Aqui
 * se lee ese archivo y se anaden los xhtml:link de cada articulo con el mismo
 * juego de hreflang que su <head>.
 */
require_once __DIR__ . '/site.php';

/** hreflang que lleva cada idioma, igual que Seo.astro. */
const SITEMAP_HREFLANGS = [
    'es' => ['es-ES', 'es', 'x-default'],
    'ca' => ['ca-ES', 'ca'],
];

/**
 * Mapa slug ES => slug CA. Archivo ausente o roto = sin alternos (el sitemap
 * sigue saliendo, solo sin hreflang), nunca un error.
 *
 * @return array<string, string>
 */
function sitemap_load_translations(string $path): array
{
    $raw = is_readable($path) ? file_get_contents($path) : false;
    $data = $raw === false ? null : json_decode($raw, true);
    if (!is_array($data)) {
        return [];
    }
    return array_filter($data, static fn ($ca, $es) => is_string($es) && is_string($ca), ARRAY_FILTER_USE_BOTH);
}

function sitemap_post_url(string $lang, string $slug): string
{
    return SITE_ORIGIN . (POST_PATHS[$lang] ?? POST_PATHS['es']) . rawurlencode($slug) . '/';
}

/**
 * URLs ES y CA de un articulo, o [] si no tiene traduccion PUBLICADA.
 *
 * @param array<string, string> $caByEs      slug ES => slug CA
 * @param list<string>          $publishedCa slugs CA visibles ahora mismo
 * @return array{es?: string, ca?: string}
 */
function sitemap_post_alternates(string $lang, string $slug, array $caByEs, array $publishedCa): array
{
    if ($lang === 'es') {
        $es = $slug;
        $ca = $caByEs[$slug] ?? null;
    } elseif ($lang === 'ca') {
        $es = array_search($slug, $caByEs, true);
        $ca = $slug;
    } else {
        return [];
    }
    if (!is_string($es) || $ca === null || !in_array($ca, $publishedCa, true)) {
        return [];
    }
    return ['es' => sitemap_post_url('es', $es), 'ca' => sitemap_post_url('ca', $ca)];
}

/** @param array{es?: string, ca?: string} $alternates */
function sitemap_post_entry(string $lang, string $slug, string $lastmod, array $alternates): string
{
    $esc = static fn (string $s): string => htmlspecialchars($s, ENT_XML1 | ENT_QUOTES, 'UTF-8');

    $xml = "  <url>\n    <loc>" . $esc(sitemap_post_url($lang, $slug)) . "</loc>\n";
    $day = substr($lastmod, 0, 10);
    if ($day !== '' && $day !== '0000-00-00') {
        $xml .= "    <lastmod>{$day}</lastmod>\n";
    }
    foreach ($alternates as $altLang => $href) {
        foreach (SITEMAP_HREFLANGS[$altLang] ?? [] as $hreflang) {
            $xml .= "    <xhtml:link rel=\"alternate\" hreflang=\"{$hreflang}\" href=\"" . $esc($href) . "\"/>\n";
        }
    }
    return $xml . "  </url>\n";
}
