<?php

use PHPUnit\Framework\TestCase;

/**
 * NoSecretsTest - Que la clave de ingesta de PhishLab (y los configs reales)
 * no vuelvan a colarse en el repositorio, que es PUBLICO.
 *
 * Solo lee ficheros como texto y pregunta a git que esta versionado: no
 * carga auth.php/http.php/db.php (ver bootstrap.php).
 */
final class NoSecretsTest extends TestCase
{
    private const ROOT = __DIR__ . '/../../';
    private const EXAMPLE = 'public/projects/phishlab/assets/telemetry.config.example.json';
    private const SCAN_EXTENSIONS = ['json', 'php', 'js', 'ts', 'md', 'yml'];

    /**
     * Pares JSON "apiKey": "<64 hex>" encontrados en un texto (la clave de
     * una app se genera como 32 bytes aleatorios en hexadecimal).
     *
     * @return list<string> las claves encontradas
     */
    public static function findApiKeyLeaks(string $text): array
    {
        preg_match_all('/"api_?key"\s*:\s*"([0-9a-f]{64})"/i', $text, $m);
        return $m[1];
    }

    // --- El propio detector, con entradas falsas ----------------------------

    public function testElDetectorEncuentraUnaClaveFalsa(): void
    {
        $fake = str_repeat('ab12', 16); // 64 hex, inventada
        $this->assertSame([$fake], self::findApiKeyLeaks('{"apiKey": "' . $fake . '"}'));
        $upper = strtoupper($fake);
        $this->assertSame([$upper], self::findApiKeyLeaks("{\n  \"apiKey\":\"" . $upper . "\"\n}"));
        $this->assertCount(2, self::findApiKeyLeaks('{"apiKey":"' . $fake . '"} {"api_key": "' . $fake . '"}'));
    }

    public function testElDetectorIgnoraPlaceholdersYCadenasQueNoSonClaves(): void
    {
        $this->assertSame([], self::findApiKeyLeaks('{"apiKey": "PEGA_AQUI_LA_CLAVE_GENERADA_UNA_VEZ_DESDE_ADMIN"}'));
        $this->assertSame([], self::findApiKeyLeaks('{"apiKey": "' . str_repeat('a', 63) . '"}'));
        $this->assertSame([], self::findApiKeyLeaks('{"apiKey": "' . str_repeat('g', 64) . '"}'));
        $this->assertSame([], self::findApiKeyLeaks('{"hash": "' . str_repeat('a', 64) . '"}'));
    }

    // --- El repositorio -------------------------------------------------------

    public function testElEjemploDeTelemetriaLlevaElPlaceholder(): void
    {
        $raw = file_get_contents(self::ROOT . self::EXAMPLE);
        $this->assertIsString($raw, 'no se pudo leer ' . self::EXAMPLE);
        $json = json_decode($raw, true);
        $this->assertIsArray($json, self::EXAMPLE . ' no es JSON valido');
        $key = (string) ($json['apiKey'] ?? '');
        $this->assertNotSame('', $key, 'el ejemplo debe tener un apiKey de muestra');
        $this->assertDoesNotMatchRegularExpression('/^[0-9a-f]{64}$/i', $key, 'el ejemplo lleva una clave real');
    }

    public function testLosConfigsRealesNoEstanVersionados(): void
    {
        $tracked = $this->git(['ls-files', '--', 'server/config.php', 'public/projects/phishlab/assets/telemetry.config.json']);
        $this->assertSame([], $tracked);
    }

    public function testNingunArchivoVersionadoLlevaUnaClave(): void
    {
        $files = $this->git(['ls-files', '--', 'public', 'server']);
        $this->assertNotEmpty($files, 'git ls-files no devolvio nada');

        $scanned = 0;
        $leaks = [];
        foreach ($files as $file) {
            if (str_starts_with($file, 'server/tests/') || str_starts_with($file, 'database/')) {
                continue;
            }
            if (!in_array(strtolower(pathinfo($file, PATHINFO_EXTENSION)), self::SCAN_EXTENSIONS, true)) {
                continue;
            }
            $text = @file_get_contents(self::ROOT . $file);
            if (!is_string($text)) {
                continue; // borrado en el arbol de trabajo pero aun en el indice
            }
            $scanned++;
            if (self::findApiKeyLeaks($text)) {
                $leaks[] = $file;
            }
        }
        $this->assertGreaterThan(0, $scanned, 'no se ha escaneado ningun archivo');
        $this->assertSame([], $leaks, 'clave de API (64 hex) en archivos versionados');
    }

    /**
     * Ejecuta git en la raiz del repo y devuelve las lineas de salida. Si no
     * hay exec() o git (p.ej. un tarball sin .git), el test se salta.
     *
     * @param list<string> $args
     * @return list<string>
     */
    private function git(array $args): array
    {
        if (!function_exists('exec')) {
            $this->markTestSkipped('exec() no disponible');
        }
        $root = realpath(self::ROOT);
        // quotepath=off: rutas con acentos tal cual, no como "\303\241".
        $base = 'git -C ' . escapeshellarg((string) $root) . ' -c core.quotepath=off ';
        exec($base . 'rev-parse --is-inside-work-tree 2>&1', $probe, $rc);
        if ($rc !== 0 || trim((string) ($probe[0] ?? '')) !== 'true') {
            $this->markTestSkipped('git no disponible o no es un repositorio');
        }
        $out = [];
        exec($base . implode(' ', array_map('escapeshellarg', $args)) . ' 2>&1', $out, $rc);
        $this->assertSame(0, $rc, 'git ' . implode(' ', $args) . ' fallo: ' . implode("\n", $out));
        return array_values(array_filter(array_map('trim', $out), static fn(string $l): bool => $l !== ''));
    }
}
