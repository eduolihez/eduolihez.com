<?php
use PHPUnit\Framework\TestCase;

/** Validacion de visitor_id y deteccion de "columna desconocida" (tarea 11). */
final class VisitorTest extends TestCase
{
    public function testAcceptsSixteenLowercaseHex(): void
    {
        $this->assertSame('0123456789abcdef', clean_visitor_id('0123456789abcdef'));
    }

    /** @dataProvider invalidProvider */
    public function testRejectsInvalid(mixed $v): void
    {
        $this->assertNull(clean_visitor_id($v));
    }

    public static function invalidProvider(): array
    {
        return [
            'mayusculas' => ['0123456789ABCDEF'],
            '15 chars' => ['0123456789abcde'],
            '17 chars' => ['0123456789abcdef0'],
            'no hex' => ['0123456789abcdeg'],
            'salto de linea' => ["0123456789abcdef\n"],
            'entero' => [1234567890123456],
            'array' => [['0123456789abcdef']],
            'null' => [null],
            'vacio' => [''],
        ];
    }

    public function testUnknownColumnByErrorInfo(): void
    {
        $e = new PDOException("Unknown column 'visitor_id'");
        $e->errorInfo = ['42S22', 1054, "Unknown column 'visitor_id' in 'field list'"];
        $this->assertTrue(is_unknown_column($e));

        $e2 = new PDOException('x');
        $e2->errorInfo = ['HY000', 1054, 'x'];
        $this->assertTrue(is_unknown_column($e2));
    }

    public function testOtherErrorsAreNotUnknownColumn(): void
    {
        $e = new PDOException('Duplicate entry');
        $e->errorInfo = ['23000', 1062, 'Duplicate entry'];
        $this->assertFalse(is_unknown_column($e));
        $this->assertFalse(is_unknown_column(new PDOException('sin info')));
        $this->assertFalse(is_unknown_column(new RuntimeException('42S22', 0)));
    }
}
