<?php
use PHPUnit\Framework\TestCase;

/**
 * db_connect_with_retry() sin MySQL real: $connect y $sleep son closures.
 * Ver server/lib/db_retry.php para el porque (500 intermitentes por el limite
 * de conexiones simultaneas del hosting compartido).
 */
final class DbRetryTest extends TestCase
{
    private static function pdoError(int $mysqlCode, string $msg = 'fallo'): PDOException
    {
        return new PDOException("SQLSTATE[HY000] [$mysqlCode] $msg", $mysqlCode);
    }

    public function testDevuelveLaConexionAlPrimerIntentoSinEsperar(): void
    {
        $sleeps = [];
        $result = db_connect_with_retry(fn () => 'conexion', 3, function (int $us) use (&$sleeps) {
            $sleeps[] = $us;
        });

        $this->assertSame('conexion', $result);
        $this->assertSame([], $sleeps);
    }

    public function testReintentaElLimiteDeConexionesPorUsuarioYAcabaConectando(): void
    {
        $calls = 0;
        $sleeps = [];
        $result = db_connect_with_retry(function () use (&$calls) {
            $calls++;
            if ($calls < 3) {
                throw self::pdoError(1203, "User already has more than 'max_user_connections' active connections");
            }
            return 'conexion';
        }, 3, function (int $us) use (&$sleeps) {
            $sleeps[] = $us;
        });

        $this->assertSame('conexion', $result);
        $this->assertSame(3, $calls);
        $this->assertCount(2, $sleeps);
        $this->assertGreaterThan($sleeps[0], $sleeps[1] + 100000, 'la espera crece entre intentos');
    }

    public function testNoReintentaCredencialesIncorrectas(): void
    {
        $calls = 0;
        try {
            db_connect_with_retry(function () use (&$calls) {
                $calls++;
                throw self::pdoError(1045, "Access denied for user");
            }, 3, function (int $us) {
            });
            $this->fail('Debia propagar la excepcion');
        } catch (PDOException $e) {
            $this->assertSame(1, $calls, 'un 1045 no se arregla esperando');
        }
    }

    public function testSeRindeTrasElUltimoIntentoYPropagaElError(): void
    {
        $calls = 0;
        $this->expectException(PDOException::class);
        db_connect_with_retry(function () use (&$calls) {
            $calls++;
            throw self::pdoError(1040, 'Too many connections');
        }, 3, function (int $us) {
        });
    }

    public function testLeeElCodigoDesdeElMensajeSiGetCodeNoEsNumerico(): void
    {
        $e = new PDOException('SQLSTATE[HY000] [1203] User already has more than ...');
        $this->assertSame(1203, db_error_code($e));
    }
}
