<?php

use PHPUnit\Framework\TestCase;

/**
 * AdminCspTest - Regresion a nivel de codigo fuente de la CSP del panel.
 * Lee los PHP como TEXTO (no los incluye: auth.php abre sesion y toca la BD).
 *
 * La CSP del panel lleva style-src-elem 'self', asi que un <style> en linea
 * se bloquea: las pantallas con chrome propio deben usar assets/auth.css.
 */
final class AdminCspTest extends TestCase
{
    private const ADMIN = __DIR__ . '/../admin/';

    private function source(string $file): string
    {
        $src = file_get_contents(self::ADMIN . $file);
        $this->assertIsString($src, "no se pudo leer $file");
        return $src;
    }

    public function testAuthPhpDeclaraStyleSrcElemSoloSelf(): void
    {
        $src = $this->source('auth.php');
        $this->assertStringContainsString("style-src-elem 'self';", $src);
        $this->assertStringContainsString("style-src-attr 'unsafe-inline';", $src);
    }

    public function testAuthPhpNoTraeStyleEnLinea(): void
    {
        $this->assertStringNotContainsString('<style', $this->source('auth.php'));
    }

    /** @return array<string, array{string}> */
    public static function pantallasConChromePropio(): array
    {
        return ['login' => ['login.php'], 'setup' => ['setup.php'], 'layout' => ['partials/layout.php']];
    }

    /** @dataProvider pantallasConChromePropio */
    public function testSinBloquesStyleEnLinea(string $file): void
    {
        $this->assertStringNotContainsString('<style', $this->source($file));
    }

    public function testLoginYSetupEnlazanAuthCss(): void
    {
        foreach (['login.php', 'setup.php'] as $file) {
            $this->assertStringContainsString('href="assets/auth.css"', $this->source($file));
        }
        $this->assertFileExists(self::ADMIN . 'assets/auth.css');
    }

    /**
     * Manejadores en linea (onclick=...) de un fuente PHP/HTML. Primero se
     * quitan los bloques PHP: un `?>` dentro de la etiqueta (value="<?= e($x) ?>")
     * cortaba la busqueda antes de llegar al onclick y daba un falso negativo.
     *
     * @return list<string> los fragmentos encontrados (inicio de etiqueta hasta el manejador)
     */
    public static function findInlineHandlers(string $src): array
    {
        $src = (string) preg_replace('/<\?(?:php|=).*?\?>/s', '', $src);
        $src = (string) preg_replace('/<\?(?:php|=).*$/s', '', $src); // bloque sin cerrar al final
        preg_match_all('/<[a-z][^>]*\son[a-z]+\s*=\s*["\']/i', $src, $m);
        return $m[0];
    }

    public function testElDetectorVeManejadoresTrasUnBloquePhpEnLaMismaEtiqueta(): void
    {
        // Forma real de apps.php en f6272b2: el cierre de PHP dentro del value cegaba la regex vieja.
        $apps = '<input type="text" value="<?= e($x) ?>" readonly onclick="this.select()">';
        $this->assertCount(1, self::findInlineHandlers($apps));
        $this->assertCount(1, self::findInlineHandlers("<?php if (\$a): ?>\n<button <?= \$c ?> onsubmit=\"return confirm('x')\">"));
        $this->assertCount(1, self::findInlineHandlers("<a href=\"#\">x</a>\n<?php echo 1;\n?><a onclick='f()'>"));
    }

    public function testElDetectorNoSeEnganaConPhpLimpio(): void
    {
        $this->assertSame([], self::findInlineHandlers('<input value="<?= e($x) ?>" data-copy="1" class="<?= $c ?>">'));
        $this->assertSame([], self::findInlineHandlers('<a data-onclick-foo="x" href="#">button on click="x"</a>'));
        $this->assertSame([], self::findInlineHandlers('<p>pulsa on click para seguir</p> <?php $y = "<a onclick=\"x\">"; ?>'));
        $this->assertSame([], self::findInlineHandlers('<?php // sin cerrar: <a onclick="x">'));
    }

    public function testElDetectorNoDistingueMayusculasNiComillas(): void
    {
        $this->assertCount(1, self::findInlineHandlers('<BUTTON ONCLICK="x">'));
        $this->assertCount(1, self::findInlineHandlers("<button onClick='x'>"));
        $this->assertCount(1, self::findInlineHandlers('<form  onsubmit = "return false">'));
    }

    /**
     * script-src 'self' bloquea tambien los manejadores en linea (onclick=,
     * onsubmit=...). No dan error visible: el boton simplemente no hace nada
     * o, peor, un onsubmit="return confirm(...)" deja de preguntar y el
     * formulario se envia igual (pasaba al borrar articulos en posts.php).
     */
    public function testSinManejadoresDeEventosEnLinea(): void
    {
        $files = array_merge(glob(self::ADMIN . '*.php') ?: [], glob(self::ADMIN . 'partials/*.php') ?: []);
        $this->assertNotEmpty($files);
        $hits = [];
        foreach ($files as $file) {
            $found = self::findInlineHandlers((string) file_get_contents($file));
            if ($found) {
                $hits[] = basename($file) . ': ' . trim($found[0]);
            }
        }
        $this->assertSame([], $hits, 'Manejadores en linea (bloqueados por la CSP): usa data-* + assets/admin.js');
    }
}
