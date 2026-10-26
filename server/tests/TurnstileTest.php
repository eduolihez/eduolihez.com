<?php

use PHPUnit\Framework\TestCase;

/**
 * TurnstileTest - Cubre turnstile_parse_response() (server/lib/turnstile.php).
 *
 * Antes la verificacion devolvia solo true/false: cualquier fallo (clave
 * secreta mal puesta, token caducado, el servidor sin salida a Cloudflare)
 * acababa en el mismo "Verificacion anti-bot fallida" y no habia forma de
 * saber cual era. Ahora cada fallo trae un codigo que se puede leer.
 */
final class TurnstileTest extends TestCase
{
    public function testRespuestaCorrectaEsValida(): void
    {
        $r = turnstile_parse_response('{"success":true,"error-codes":[],"hostname":"eduolihez.com"}');

        $this->assertSame(true, $r['ok']);
        $this->assertSame([], $r['codes']);
    }

    public function testClaveSecretaInvalidaDevuelveSuCodigo(): void
    {
        $r = turnstile_parse_response('{"success":false,"error-codes":["invalid-input-secret"]}');

        $this->assertSame(false, $r['ok']);
        $this->assertSame(['invalid-input-secret'], $r['codes']);
    }

    public function testTokenRepetidoDevuelveTimeoutOrDuplicate(): void
    {
        $r = turnstile_parse_response('{"success":false,"error-codes":["timeout-or-duplicate"]}');

        $this->assertSame(['timeout-or-duplicate'], $r['codes']);
    }

    public function testSinRespuestaDeCloudflareSeIndica(): void
    {
        $this->assertSame(['no-response'], turnstile_parse_response(false)['codes']);
        $this->assertSame(['no-response'], turnstile_parse_response('')['codes']);
        $this->assertSame(false, turnstile_parse_response(false)['ok']);
    }

    public function testRespuestaQueNoEsJsonSeIndica(): void
    {
        $r = turnstile_parse_response('<html>502 Bad Gateway</html>');

        $this->assertSame(false, $r['ok']);
        $this->assertSame(['invalid-json'], $r['codes']);
    }

    public function testFalloSinCodigosSeMarcaComoDesconocido(): void
    {
        $r = turnstile_parse_response('{"success":false}');

        $this->assertSame(false, $r['ok']);
        $this->assertSame(['unknown'], $r['codes']);
    }

    public function testSoloSeAceptanCodigosConFormaDeCodigo(): void
    {
        // Lo que devuelve un tercero no se refleja tal cual en la respuesta ni en el log.
        $r = turnstile_parse_response('{"success":false,"error-codes":["bad-request","<script>x</script>","a\r\nb",42]}');

        $this->assertSame(['bad-request'], $r['codes']);
    }

    public function testSuccessSoloVale_siEsTrueDeVerdad(): void
    {
        $this->assertSame(false, turnstile_parse_response('{"success":"false"}')['ok']);
        $this->assertSame(false, turnstile_parse_response('{"success":1}')['ok']);
    }
}
