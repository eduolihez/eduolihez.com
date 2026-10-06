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
            $src = (string) file_get_contents($file);
            if (preg_match_all('/<[a-z][^>]*\son[a-z]+\s*=\s*["\']/i', $src, $m)) {
                $hits[] = basename($file) . ': ' . trim($m[0][0]);
            }
        }
        $this->assertSame([], $hits, 'Manejadores en linea (bloqueados por la CSP): usa data-* + assets/admin.js');
    }
}
