<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * Helpers puros de partials/layout.php (filter_bar, section_nav, card_open,
 * card_close). layout.php hace require de auth.php (sesion + db.php con exit),
 * asi que no se puede cargar en esta suite (ver bootstrap.php): se extrae el
 * codigo de esas funciones con el tokenizer (tests/support/extract_functions.php)
 * y se evalua aparte; e() lo carga bootstrap.php desde auth.php.
 */
final class LayoutHelpersTest extends TestCase
{
    private const HELPERS = ['filter_bar', 'section_nav', 'card_open', 'card_close'];

    public static function setUpBeforeClass(): void
    {
        // e() ya lo extrae bootstrap.php de auth.php (una sola fuente de verdad).
        extract_php_functions(__DIR__ . '/../admin/partials/layout.php', self::HELPERS);
        foreach (self::HELPERS as $fn) {
            self::assertTrue(function_exists($fn), "No se encontro $fn() en layout.php");
        }
    }

    public function testFilterBarEsGrupoConEtiquetaEscapada(): void
    {
        $html = filter_bar('<a href="?d=7">7d</a>', 'Filtros "x" <y>');
        $this->assertSame(
            '<div class="filter-bar" role="group" aria-label="Filtros &quot;x&quot; &lt;y&gt;"><a href="?d=7">7d</a></div>',
            $html
        );
    }

    public function testFilterBarSinEtiquetaNoPintaAriaLabel(): void
    {
        $this->assertSame('<div class="filter-bar" role="group"></div>', filter_bar(''));
    }

    public function testSectionNavVacioDevuelveCadenaVacia(): void
    {
        $this->assertSame('', section_nav([]));
        $this->assertSame('', section_nav([['id' => '', 'label' => 'Sin id']]));
    }

    public function testSectionNavPintaAnclasEscapadas(): void
    {
        $html = section_nav([
            ['id' => 'resumen', 'label' => 'Resumen'],
            ['id' => 'a"b', 'label' => '<b>Bots</b>'],
        ]);
        $this->assertSame(
            '<nav class="section-nav" aria-label="Secciones de la página">'
            . '<a href="#resumen">Resumen</a>'
            . '<a href="#a&quot;b">&lt;b&gt;Bots&lt;/b&gt;</a>'
            . '</nav>',
            $html
        );
    }

    public function testCardOpenEscapaTituloYMeta(): void
    {
        $this->assertSame('<div class="card"><h3 class="card-title">A &amp; B</h3>', card_open('A & B'));
        $this->assertSame(
            '<div class="card"><h3 class="card-title">Top &lt;10&gt; <small>30 &quot;d&quot;</small></h3>',
            card_open('Top <10>', '30 "d"')
        );
    }

    public function testCardCloseCierraLaTarjeta(): void
    {
        $this->assertSame('</div>', card_close());
    }
}
