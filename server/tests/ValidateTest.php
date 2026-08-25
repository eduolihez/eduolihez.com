<?php

use PHPUnit\Framework\TestCase;

/**
 * ValidateTest - Cubre validate_public_url() (server/lib/validate.php),
 * la regla de esquema de URL compartida por settings.php (announcement_url),
 * project-edit.php (image_url) y cert-edit.php (logo_url): bloquea
 * javascript:/data:/vbscript: en un campo que un admin autenticado podria
 * rellenar a mano, sin depender solo del escape en cada vista publica.
 */
final class ValidateTest extends TestCase
{
    public function testCadenaVaciaEsValida(): void
    {
        // Los tres campos que usan esta funcion son opcionales.
        $this->assertNull(validate_public_url('', 'La URL'));
    }

    public function testHttpsEsValida(): void
    {
        $this->assertNull(validate_public_url('https://example.com/img.png', 'La URL'));
    }

    public function testRutaInternaEsValida(): void
    {
        $this->assertNull(validate_public_url('/uploads/projects/foo.jpg', 'La URL'));
    }

    public function testHttpsEnMayusculasEsValida(): void
    {
        // El check es case-insensitive (flag /i): un admin pegando una URL
        // con el esquema en mayusculas no debe verse bloqueado sin motivo.
        $this->assertNull(validate_public_url('HTTPS://EXAMPLE.COM', 'La URL'));
    }

    public function testJavascriptEsInvalida(): void
    {
        $error = validate_public_url('javascript:alert(1)', 'La URL de la imagen');

        $this->assertNotNull($error);
        $this->assertStringContainsString('debe empezar por https:// o por /', $error);
    }

    public function testDataUriEsInvalida(): void
    {
        $this->assertNotNull(validate_public_url('data:text/html,<script>alert(1)</script>', 'La URL'));
    }

    public function testHttpSinLaSNoEsValida(): void
    {
        // Deliberado: solo https, no http. Coherente con que el resto del
        // sitio fuerza HTTPS (ver server/.htaccess).
        $this->assertNotNull(validate_public_url('http://example.com', 'La URL'));
    }

    public function testElMensajeDeErrorIncluyeElNombreDelCampo(): void
    {
        $error = validate_public_url('javascript:x', 'El enlace del aviso');

        $this->assertStringStartsWith('El enlace del aviso', (string) $error);
    }

    public function testBloqueaElBypassDeBarraInvertidaTrasLaBarraInicial(): void
    {
        // Regresion (auditoria de seguridad 2026-08-25): los navegadores
        // tratan "\" como "/" al parsear un esquema especial, asi que
        // "/\evil.example/x" pasaria el check ingenuo de "empieza por /"
        // pero el navegador lo resuelve como "//evil.example/x" -- dominio
        // externo, no ruta interna.
        $this->assertNotNull(validate_public_url('/\\evil.example/x.jpg', 'La URL'));
        $this->assertNotNull(validate_public_url('\\evil.example/x.jpg', 'La URL'));
        $this->assertNotNull(validate_public_url('/foo\\bar', 'La URL'));
    }

    public function testBloqueaBarraDobleInicial(): void
    {
        $this->assertNotNull(validate_public_url('//evil.example/x.jpg', 'La URL'));
    }

    public function testSigueAceptandoUnaRutaInternaNormalSinBarraInvertida(): void
    {
        $this->assertNull(validate_public_url('/uploads/projects/foo.jpg', 'La URL'));
    }

    public function testBloqueaTabuladorSaltoDeLineaYRetornoDeCarroIncrustados(): void
    {
        // Regresion (auditoria de seguridad 2026-08-25, segunda ronda): el
        // parser WHATWG quita \t/\n/\r de CUALQUIER posicion de la URL antes
        // de interpretarla, no solo de los extremos (trim() ya cubre eso).
        // "/\t/evil.example/x" no tiene "\" literal ni empieza por "//" tal
        // cual, pero el navegador lo colapsa a "//evil.example/x" igual que
        // el bypass de barra invertida.
        $this->assertNotNull(validate_public_url("/\t/evil.example/x", 'La URL'));
        $this->assertNotNull(validate_public_url("/\n/evil.example/x", 'La URL'));
        $this->assertNotNull(validate_public_url("/\r/evil.example/x", 'La URL'));
        $this->assertNotNull(validate_public_url("/foo\tbar", 'La URL'));
    }
}
