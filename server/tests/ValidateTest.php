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

    // --- origin_is_allowed() (server/api/events.php) -------------------------

    public function testOrigenExactoEnLaListaEsPermitido(): void
    {
        $this->assertTrue(origin_is_allowed('https://eduolihez.com', ['https://eduolihez.com']));
    }

    public function testOrigenQueNoEstaEnLaListaEsRechazado(): void
    {
        $this->assertFalse(origin_is_allowed('https://evil.example', ['https://eduolihez.com']));
    }

    public function testOrigenConSubcadenaCoincidenteNoBasta(): void
    {
        // "https://eduolihez.com" es subcadena de este origen, pero no es
        // una coincidencia EXACTA -- un check por substring/prefijo dejaria
        // pasar cualquier dominio que empiece igual.
        $this->assertFalse(origin_is_allowed('https://eduolihez.com.evil.example', ['https://eduolihez.com']));
    }

    public function testSoportaEsquemaDeExtensionDeNavegador(): void
    {
        $this->assertTrue(origin_is_allowed(
            'chrome-extension://abcdefghijklmnop',
            ['chrome-extension://abcdefghijklmnop']
        ));
    }

    public function testListaVaciaRechazaCualquierOrigen(): void
    {
        $this->assertFalse(origin_is_allowed('https://eduolihez.com', []));
    }

    public function testEntradaNoStringEnLaListaSeIgnoraSinError(): void
    {
        // apps.allowed_origins es JSON de forma libre editado a mano en la
        // BD; un valor no-string en el array no debe romper la comparacion.
        $this->assertFalse(origin_is_allowed('https://eduolihez.com', [123, null, ['x']]));
    }

    // --- validate_event_body() (server/api/events.php) -----------------------

    public function testBodyValidoConPayloadDevuelveNull(): void
    {
        $this->assertNull(validate_event_body([
            'event_id' => 'abc-123',
            'type'     => 'install',
            'payload'  => ['version' => '1.0'],
        ]));
    }

    public function testBodyValidoSinPayloadDevuelveNull(): void
    {
        $this->assertNull(validate_event_body(['event_id' => 'abc-123', 'type' => 'install']));
    }

    public function testBodyQueNoEsArrayEsInvalido(): void
    {
        $this->assertNotNull(validate_event_body(null));
        $this->assertNotNull(validate_event_body('no-json-object'));
        $this->assertNotNull(validate_event_body(42));
    }

    public function testFaltaEventIdEsInvalido(): void
    {
        $this->assertNotNull(validate_event_body(['type' => 'install']));
    }

    public function testFaltaTypeEsInvalido(): void
    {
        $this->assertNotNull(validate_event_body(['event_id' => 'abc-123']));
    }

    public function testEventIdVacioEsInvalido(): void
    {
        $this->assertNotNull(validate_event_body(['event_id' => '', 'type' => 'install']));
    }

    public function testEventIdNoStringEsInvalido(): void
    {
        // Un numero, bool o array en event_id/type debe rechazarse, no
        // coaccionarse a texto en silencio (ver comentario en validate.php).
        $this->assertNotNull(validate_event_body(['event_id' => 123, 'type' => 'install']));
        $this->assertNotNull(validate_event_body(['event_id' => ['x'], 'type' => 'install']));
        $this->assertNotNull(validate_event_body(['event_id' => true, 'type' => 'install']));
    }

    public function testTypeNoStringEsInvalido(): void
    {
        $this->assertNotNull(validate_event_body(['event_id' => 'abc', 'type' => 123]));
    }

    public function testPayloadQueNoEsObjetoEsInvalido(): void
    {
        // payload debe ser un objeto JSON (array asociativo en PHP), no un
        // escalar ni una lista suelta.
        $this->assertNotNull(validate_event_body(['event_id' => 'x', 'type' => 'y', 'payload' => 'texto']));
        $this->assertNotNull(validate_event_body(['event_id' => 'x', 'type' => 'y', 'payload' => 123]));
    }

    public function testPayloadNuloEsValido(): void
    {
        $this->assertNull(validate_event_body(['event_id' => 'x', 'type' => 'y', 'payload' => null]));
    }

    public function testPayloadQueEsUnaListaJsonEsInvalido(): void
    {
        // json_decode(..., true) no distingue {} de [] -- ambos son array en
        // PHP. Sin array_is_list(), un payload de lista ([1,2,3]) pasaria el
        // check de is_array() aunque el diseno exige un objeto.
        $this->assertNotNull(validate_event_body(['event_id' => 'x', 'type' => 'y', 'payload' => [1, 2, 3]]));
    }

    public function testPayloadObjetoVacioEsValido(): void
    {
        // {} y [] decodifican igual (array vacio) -- caso ambiguo que se
        // acepta a proposito en vez de rechazar un payload vacio legitimo.
        $this->assertNull(validate_event_body(['event_id' => 'x', 'type' => 'y', 'payload' => []]));
    }
}
