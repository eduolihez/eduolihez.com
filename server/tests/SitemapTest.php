<?php

use PHPUnit\Framework\TestCase;

/**
 * SitemapTest - Cubre server/lib/sitemap.php (construccion de /sitemap-posts.xml).
 *
 * El sitemap de articulos no declaraba la relacion ES <-> CA, asi que Google
 * solo la conocia por el <head> de cada pagina. Ahora cada articulo con
 * traduccion publicada lleva sus xhtml:link, con el mismo juego de hreflang
 * que la pagina (es-ES, es, ca-ES, ca, x-default -> castellano).
 */
final class SitemapTest extends TestCase
{
    private const MAP = ['spf-dkim' => 'spf-dkim-ca', 'solo-es' => 'solo-es-ca'];

    public function testArticuloConTraduccionPublicadaDevuelveAmbasUrls(): void
    {
        $alt = sitemap_post_alternates('es', 'spf-dkim', self::MAP, ['spf-dkim-ca']);

        $this->assertSame([
            'es' => 'https://eduolihez.com/blog/post/spf-dkim/',
            'ca' => 'https://eduolihez.com/ca/blog/post/spf-dkim-ca/',
        ], $alt);
    }

    public function testDesdeLaVersionCatalanaSeEncuentraLaCastellana(): void
    {
        $alt = sitemap_post_alternates('ca', 'spf-dkim-ca', self::MAP, ['spf-dkim-ca']);

        $this->assertSame('https://eduolihez.com/blog/post/spf-dkim/', $alt['es']);
    }

    public function testTraduccionAunNoPublicadaNoSeAnuncia(): void
    {
        // El mapa dice que existe, pero la fila catalana no esta visible:
        // un hreflang a una pagina que no existe es peor que no ponerlo.
        $this->assertSame([], sitemap_post_alternates('es', 'solo-es', self::MAP, []));
    }

    public function testArticuloSinTraduccionNoTieneAlternos(): void
    {
        $this->assertSame([], sitemap_post_alternates('es', 'otro', self::MAP, ['spf-dkim-ca']));
        $this->assertSame([], sitemap_post_alternates('en', 'spf-dkim', self::MAP, ['spf-dkim-ca']));
    }

    public function testEntradaIncluyeLosCincoHreflangComoElHead(): void
    {
        $xml = sitemap_post_entry('es', 'spf-dkim', '2026-10-29 10:00:00', [
            'es' => 'https://eduolihez.com/blog/post/spf-dkim/',
            'ca' => 'https://eduolihez.com/ca/blog/post/spf-dkim-ca/',
        ]);

        $this->assertStringContainsString('<loc>https://eduolihez.com/blog/post/spf-dkim/</loc>', $xml);
        $this->assertStringContainsString('<lastmod>2026-10-29</lastmod>', $xml);
        foreach (['es-ES', 'es', 'x-default'] as $lang) {
            $this->assertStringContainsString(
                "<xhtml:link rel=\"alternate\" hreflang=\"{$lang}\" href=\"https://eduolihez.com/blog/post/spf-dkim/\"/>",
                $xml
            );
        }
        foreach (['ca-ES', 'ca'] as $lang) {
            $this->assertStringContainsString(
                "<xhtml:link rel=\"alternate\" hreflang=\"{$lang}\" href=\"https://eduolihez.com/ca/blog/post/spf-dkim-ca/\"/>",
                $xml
            );
        }
    }

    public function testEntradaSinAlternosNiFechaQuedaMinima(): void
    {
        $xml = sitemap_post_entry('ca', 'algo', '0000-00-00 00:00:00', []);

        $this->assertSame("  <url>\n    <loc>https://eduolihez.com/ca/blog/post/algo/</loc>\n  </url>\n", $xml);
    }

    public function testSlugSeCodificaYEscapa(): void
    {
        $xml = sitemap_post_entry('es', 'a&b c', '', []);

        $this->assertStringContainsString('<loc>https://eduolihez.com/blog/post/a%26b%20c/</loc>', $xml);
    }

    public function testMapaDeTraduccionesInvalidoOAusenteDaArrayVacio(): void
    {
        $this->assertSame([], sitemap_load_translations(__DIR__ . '/no-existe.json'));

        $tmp = tempnam(sys_get_temp_dir(), 'tr');
        file_put_contents($tmp, '{"es-1":"ca-1","malo":5}');
        $this->assertSame(['es-1' => 'ca-1'], sitemap_load_translations($tmp));

        file_put_contents($tmp, 'no es json');
        $this->assertSame([], sitemap_load_translations($tmp));
        unlink($tmp);
    }
}
