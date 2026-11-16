<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * Helpers puros de partials/layout.php (filter_bar, section_nav, card_open,
 * card_close). layout.php hace require de auth.php (sesion + db.php con exit),
 * asi que no se puede cargar en esta suite (ver bootstrap.php): se extrae el
 * codigo de esas cuatro funciones con el tokenizer y se evalua aparte, con un
 * e() identico al de auth.php.
 */
final class LayoutHelpersTest extends TestCase
{
    private const HELPERS = ['filter_bar', 'section_nav', 'card_open', 'card_close'];

    public static function setUpBeforeClass(): void
    {
        if (!function_exists('e')) {
            eval('function e($value): string { return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8"); }');
        }
        if (function_exists('section_nav')) {
            return;
        }
        $tokens = token_get_all((string) file_get_contents(__DIR__ . '/../admin/partials/layout.php'));
        $n = count($tokens);
        for ($i = 0; $i < $n; $i++) {
            if (!is_array($tokens[$i]) || $tokens[$i][0] !== T_FUNCTION) {
                continue;
            }
            $j = $i + 1;
            while ($j < $n && is_array($tokens[$j]) && $tokens[$j][0] === T_WHITESPACE) {
                $j++;
            }
            if (!is_array($tokens[$j]) || !in_array($tokens[$j][1], self::HELPERS, true)) {
                continue;
            }
            $code = '';
            $depth = 0;
            $opened = false;
            for ($k = $i; $k < $n; $k++) {
                $t = $tokens[$k];
                $code .= is_array($t) ? $t[1] : $t;
                if ($t === '{' || (is_array($t) && in_array($t[0], [T_CURLY_OPEN, T_DOLLAR_OPEN_CURLY_BRACES], true))) {
                    $depth++;
                    $opened = true;
                } elseif ($t === '}') {
                    $depth--;
                    if ($opened && $depth === 0) {
                        break;
                    }
                }
            }
            eval($code);
            $i = $k;
        }
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
        $this->assertSame('<div class="card"><h3>A &amp; B</h3>', card_open('A & B'));
        $this->assertSame(
            '<div class="card"><h3>Top &lt;10&gt; <small>30 &quot;d&quot;</small></h3>',
            card_open('Top <10>', '30 "d"')
        );
    }

    public function testCardCloseCierraLaTarjeta(): void
    {
        $this->assertSame('</div>', card_close());
    }
}
