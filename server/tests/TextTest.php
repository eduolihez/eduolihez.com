<?php

use PHPUnit\Framework\TestCase;

/**
 * TextTest - Cubre to_plain_text() (server/lib/text.php), la pieza real de
 * transformacion de llms-blog.php: convierte el HTML crudo que se escribe
 * desde /admin en texto plano para que un rastreador de IA sin JavaScript
 * pueda leer el articulo. Es la logica con mas superficie de fallo del
 * archivo (regex encadenadas) y hasta ahora no tenia ninguna red de
 * seguridad -- un cambio aqui podia romper el feed en silencio.
 */
final class TextTest extends TestCase
{
    public function testCadenaVaciaDaCadenaVacia(): void
    {
        $this->assertSame('', to_plain_text(''));
    }

    public function testTextoPlanoSinHtmlNoCambia(): void
    {
        $this->assertSame('Hola mundo', to_plain_text('Hola mundo'));
    }

    public function testQuitaScriptYStyleEnteros(): void
    {
        // No solo la etiqueta: el CONTENIDO tambien, o JS/CSS pegado por
        // accidente en un articulo se colaria como texto visible.
        $result = to_plain_text('Antes<script>maliciousCode()</script>Despues');

        $this->assertSame('AntesDespues', $result);
        $this->assertStringNotContainsString('maliciousCode', $result);
    }

    public function testQuitaStyleEntero(): void
    {
        $result = to_plain_text('<style>body{color:red}</style>Texto');

        $this->assertSame('Texto', $result);
        $this->assertStringNotContainsString('color:red', $result);
    }

    public function testBrYCierreDeParrafoSeConviertenEnSaltoDeLinea(): void
    {
        $result = to_plain_text('<p>Primero</p><p>Segundo<br>Tercero</p>');

        $this->assertSame("Primero\nSegundo\nTercero", $result);
    }

    public function testElementosDeListaSeConviertenEnGuion(): void
    {
        $result = to_plain_text('<ul><li>Uno</li><li>Dos</li></ul>');

        $this->assertSame("- Uno\n- Dos", $result);
    }

    public function testDecodificaEntidadesHtml(): void
    {
        $result = to_plain_text('Tom &amp; Jerry &#39;s show');

        $this->assertSame("Tom & Jerry 's show", $result);
    }

    public function testColapsaLineasEnBlancoSeguidasAUnaSola(): void
    {
        $result = to_plain_text("A   B\n\n\n\nC");

        // Como maximo una linea en blanco (dos \n seguidos), nunca mas.
        $this->assertSame("A B\n\nC", $result);
    }

    public function testRecortaEspacioYSaltosSobrantesAlPrincipioYFinal(): void
    {
        $result = to_plain_text("   \n  Hola  \n   ");

        $this->assertSame('Hola', $result);
    }

    public function testUnArticuloRealNoRompeConEncabezadosYListas(): void
    {
        // Forma real de lo que se guarda desde /admin (post-edit.php permite
        // HTML crudo): encabezados, parrafos y una lista mezclados.
        $html = '<h2>Introduccion</h2><p>Texto de ejemplo con &amp; una entidad.</p>'
            . '<ul><li>Primer punto</li><li>Segundo punto</li></ul>'
            . '<p>Cierre.</p>';

        $result = to_plain_text($html);

        $this->assertStringNotContainsString('<', $result, 'no debe quedar ninguna etiqueta HTML sin quitar');
        $this->assertStringContainsString("Introduccion\n", $result);
        $this->assertStringContainsString('Texto de ejemplo con & una entidad.', $result);
        $this->assertStringContainsString("- Primer punto\n- Segundo punto", $result);
        $this->assertStringContainsString('Cierre.', $result);
    }

    public function testContenidoVacioTrasCastDeNullNoRompe(): void
    {
        // El sitio de llamada real (llms-blog.php) siempre hace
        // to_plain_text((string) $row['content']) -- (string) null da '',
        // nunca pasa null crudo a esta funcion. Este test cubre exactamente
        // ese camino: una fila con content NULL en la base de datos.
        $castNull = (string) null;

        $this->assertSame('', to_plain_text($castNull));
    }
}
