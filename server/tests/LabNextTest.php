<?php

use PHPUnit\Framework\TestCase;

/**
 * LabNextTest - Cubre lab_safe_next() (server/lab/next.php): el "next" del
 * login de lab.eduolihez.com solo puede ser una ruta del propio host.
 *
 * El caso que motivo la funcion: un navegador trata "/\evil.com" como
 * "//evil.com" (convierte la barra invertida en barra), asi que comprobar solo
 * que no empiece por "//" dejaba una redireccion abierta tras el login.
 */
final class LabNextTest extends TestCase
{
    public function testRutasDelPropioHostSePermiten(): void
    {
        $this->assertSame('/', lab_safe_next('/'));
        $this->assertSame('/index.php', lab_safe_next('/index.php'));
        $this->assertSame('/_content/app.js?v=3#x', lab_safe_next('/_content/app.js?v=3#x'));
        $this->assertSame('/a%20b/%5Cc', lab_safe_next('/a%20b/%5Cc'), 'lo codificado en porcentaje no cambia de host');
    }

    public function testVacioSeQuedaVacio(): void
    {
        $this->assertSame('', lab_safe_next(''));
    }

    /** @return array<string, array{string}> */
    public static function redireccionesAjenas(): array
    {
        return [
            'protocol-relative'        => ['//evil.com'],
            'barra y barra invertida'  => ['/\\evil.com'],
            'dos barras invertidas'    => ['/\\\\evil.com'],
            'barra invertida suelta'   => ['/a\\b'],
            'esquema absoluto'         => ['https://evil.com/x'],
            'esquema javascript'       => ['javascript:alert(1)'],
            'sin barra inicial'        => ['evil.com'],
            'tabulador (se descarta)'  => ["/\t/evil.com"],
            'salto de linea'           => ["/ok\r\nSet-Cookie: x=1"],
            'nul'                      => ["/ok\0/x"],
            'espacio'                  => ['/ok path'],
            'caracter DEL'             => ["/ok\x7f"],
        ];
    }

    /** @dataProvider redireccionesAjenas */
    public function testSeRechazaLoQuePuedaSalirDelHost(string $next): void
    {
        $this->assertSame('', lab_safe_next($next));
    }

    public function testRutaDemasiadoLargaSeRechaza(): void
    {
        $this->assertSame('', lab_safe_next('/' . str_repeat('a', 2048)));
    }
}
