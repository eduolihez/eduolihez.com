<?php

use PHPUnit\Framework\TestCase;

/**
 * MailTemplateTest - Cubre server/lib/mail_template.php, el aviso por email
 * que recibe Eduardo cuando alguien escribe desde el formulario.
 *
 * Todo lo que escribe el visitante acaba dentro de un email HTML: lo que hay
 * que demostrar es que se escapa, que no puede inyectar cabeceras y que los
 * datos (idioma, IP, navegador) salen donde deben.
 */
final class MailTemplateTest extends TestCase
{
    /** @return array<string,mixed> */
    private function data(array $override = []): array
    {
        return array_merge([
            'name'       => 'Ana Pérez',
            'email'      => 'ana@example.com',
            'subject'    => 'Propuesta de trabajo',
            'message'    => "Hola Eduardo,\nme gustaría hablar contigo.",
            'ip'         => '203.0.113.7',
            'user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
            'lang'       => 'ca',
            'received_at' => new DateTimeImmutable('2026-10-26 21:41:00', new DateTimeZone('UTC')),
            'message_id' => 42,
            'site_origin' => 'https://eduolihez.com',
        ], $override);
    }

    public function testElAsuntoLlevaNombreYAsunto(): void
    {
        $mail = contact_email_build($this->data(), '[Portfolio] ');

        $this->assertSame('[Portfolio] Ana Pérez — Propuesta de trabajo', $mail['subject']);
    }

    public function testSinAsuntoUsaUnoPorDefecto(): void
    {
        $mail = contact_email_build($this->data(['subject' => '']), '[Portfolio] ');

        $this->assertSame('[Portfolio] Ana Pérez — Nuevo mensaje de contacto', $mail['subject']);
    }

    public function testElAsuntoNoPuedeLlevarSaltosDeLinea(): void
    {
        $mail = contact_email_build($this->data(['name' => "Ana\r\nBcc: x@y.z", 'subject' => "Hola\nBcc: a@b.c"]), '');

        $this->assertStringNotContainsString("\n", $mail['subject']);
        $this->assertStringNotContainsString("\r", $mail['subject']);
    }

    public function testEscapaElHtmlDelVisitante(): void
    {
        $mail = contact_email_build($this->data([
            'name'    => '<script>alert(1)</script>',
            'subject' => '<img src=x onerror=alert(1)>',
            'message' => '<a href="https://evil.example">clic</a><script>x()</script>',
        ]), '');

        $this->assertStringNotContainsString('<script>', $mail['html']);
        $this->assertStringNotContainsString('<img src=x', $mail['html']);
        $this->assertStringNotContainsString('<a href="https://evil.example">', $mail['html']);
        $this->assertStringContainsString('&lt;script&gt;', $mail['html']);
    }

    public function testElEmailNoPuedeRomperElAtributo(): void
    {
        $mail = contact_email_build($this->data(['email' => 'o\'brien"x@example.com']), '');

        $this->assertStringNotContainsString('"x@example.com', $mail['html']);
        $this->assertStringNotContainsString("o'brien", $mail['html']);
    }

    public function testLosSaltosDeLineaDelMensajeSeConservan(): void
    {
        $mail = contact_email_build($this->data(), '');

        $this->assertStringContainsString('Hola Eduardo,<br />', $mail['html']);
        $this->assertStringContainsString("Hola Eduardo,\nme gustaría hablar contigo.", $mail['text']);
    }

    public function testIndicaElIdiomaDesdeElQueSeEnvio(): void
    {
        $this->assertStringContainsString('Catalán', contact_email_build($this->data(['lang' => 'ca']), '')['html']);
        $this->assertStringContainsString('Inglés', contact_email_build($this->data(['lang' => 'en']), '')['text']);
        $this->assertStringContainsString('Español', contact_email_build($this->data(['lang' => 'es']), '')['text']);
    }

    public function testUnIdiomaDesconocidoNoSeMuestraTalCual(): void
    {
        $mail = contact_email_build($this->data(['lang' => '<b>xx</b>']), '');

        $this->assertStringContainsString('No indicado', $mail['text']);
        $this->assertStringNotContainsString('<b>xx</b>', $mail['html']);
    }

    public function testIncluyeIpYNavegador(): void
    {
        $mail = contact_email_build($this->data(), '');

        $this->assertStringContainsString('203.0.113.7', $mail['html']);
        $this->assertStringContainsString('Chrome', $mail['html']);
        $this->assertStringContainsString('Windows', $mail['html']);
        $this->assertStringContainsString('203.0.113.7', $mail['text']);
        $this->assertStringContainsString('Chrome', $mail['text']);
    }

    public function testLaFechaVaEnHoraDeMadrid(): void
    {
        // 21:41 UTC del 26 de octubre de 2026 = 22:41 en Madrid (CET, UTC+1).
        $mail = contact_email_build($this->data(), '');

        $this->assertStringContainsString('26 oct 2026, 22:41', $mail['text']);
    }

    public function testElBotonResponderCodificaElAsunto(): void
    {
        $mail = contact_email_build($this->data(['subject' => 'Oferta & "prueba"']), '');

        $this->assertStringContainsString(
            'mailto:ana@example.com?subject=Re%3A%20Oferta%20%26%20%22prueba%22',
            $mail['html']
        );
    }

    public function testElBotonDelPanelSoloSiHayId(): void
    {
        $con = contact_email_build($this->data(), '');
        $sin = contact_email_build($this->data(['message_id' => null]), '');

        $this->assertStringContainsString('https://eduolihez.com/admin/messages.php?id=42', $con['html']);
        $this->assertStringContainsString('https://eduolihez.com/admin/messages.php?id=42', $con['text']);
        $this->assertStringNotContainsString('admin/messages.php', $sin['html']);
    }

    public function testLaVersionHtmlNoCargaRecursosRemotos(): void
    {
        $mail = contact_email_build($this->data(), '');

        // Sin imagenes ni hojas externas: nada que rastree la apertura.
        $this->assertStringNotContainsString('<img', $mail['html']);
        $this->assertStringNotContainsString('<link', $mail['html']);
        $this->assertStringNotContainsString('src=', $mail['html']);
    }

    public function testMimeEsMultipartConAmbasVersiones(): void
    {
        $mail = contact_email_build($this->data(), '[P] ');
        $mime = contact_email_mime($mail, 'no-reply@eduolihez.com', 'ana@example.com');

        $this->assertStringContainsString('multipart/alternative; boundary="', $mime['headers']);
        $this->assertStringContainsString('Reply-To: ana@example.com', $mime['headers']);
        $this->assertStringContainsString('MIME-Version: 1.0', $mime['headers']);
        $this->assertStringContainsString('Content-Type: text/plain; charset=utf-8', $mime['body']);
        $this->assertStringContainsString('Content-Type: text/html; charset=utf-8', $mime['body']);
    }

    public function testMimePartesDecodificanAlContenidoOriginal(): void
    {
        $mail = contact_email_build($this->data(), '');
        $mime = contact_email_mime($mail, 'no-reply@eduolihez.com', 'ana@example.com');

        preg_match_all('/Content-Transfer-Encoding: base64\r\n\r\n(.*?)\r\n--/s', $mime['body'], $m);
        $decoded = array_map(static fn ($b) => base64_decode(str_replace("\r\n", '', $b)), $m[1]);

        $this->assertSame($mail['text'], $decoded[0]);
        $this->assertSame($mail['html'], $decoded[1]);
    }

    public function testMimeNoPermiteInyectarCabeceras(): void
    {
        $mail = contact_email_build($this->data(), '');
        $mime = contact_email_mime($mail, "no-reply@eduolihez.com\r\nBcc: x@y.z", "ana@example.com\r\nBcc: q@w.e");

        $this->assertStringNotContainsString("\r\nBcc:", $mime['headers']);
    }
}
