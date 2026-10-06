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
    /** Extensiones de texto que se escanean (ademas de cualquier fichero llamado .env*). */
    private const SCAN_EXTENSIONS = [
        'json', 'php', 'js', 'cjs', 'mjs', 'ts', 'tsx', 'astro', 'md', 'yml', 'yaml',
        'html', 'txt', 'env', 'ini', 'sh', 'css', 'xml',
    ];
    /** Rutas con fixtures o dumps que no se escanean. */
    private const SKIP_PREFIXES = ['server/tests/', 'e2e/tests/', 'database/'];
    /** Mas de esto no es codigo escrito a mano (lockfiles, bundles, binarios). */
    private const MAX_BYTES = 1048576;

    /**
     * Asignaciones api_key = "<64 hex>" encontradas en un texto (la clave de
     * una app se genera como 32 bytes aleatorios en hexadecimal). Cubre JSON
     * ("apiKey": "..."), objetos JS (apiKey: '...'), arrays PHP
     * ('api_key' => '...') y estilo .env (API_KEY="..."), con la clave entre
     * comillas dobles, simples o sin ellas, y el hex en mayusculas o minusculas.
     *
     * @return list<string> las claves encontradas
     */
    public static function findApiKeyLeaks(string $text): array
    {
        preg_match_all('/api[_-]?key["\']?\s*(?::|=>|=)\s*["\']([0-9a-f]{64})["\']/i', $text, $m);
        return $m[1];
    }

    /** Si un fichero versionado entra en el escaneo (por ruta y extension). */
    public static function shouldScan(string $file): bool
    {
        foreach (self::SKIP_PREFIXES as $prefix) {
            if (str_starts_with($file, $prefix)) {
                return false;
            }
        }
        if (str_starts_with(strtolower(basename($file)), '.env')) {
            return true;
        }
        return in_array(strtolower(pathinfo($file, PATHINFO_EXTENSION)), self::SCAN_EXTENSIONS, true);
    }

    public function testQueFicherosSeEscanean(): void
    {
        foreach (['src/a.ts', 'public/x/app.cjs', 'README.md', '.github/workflows/a.yml', '.env', '.env.local', 'e2e/playwright.config.cjs', 'scripts/pack.sh', 'src/p.astro'] as $f) {
            $this->assertTrue(self::shouldScan($f), $f);
        }
        foreach (['server/tests/X.php', 'e2e/tests/a.cjs', 'database/schema.sql', 'package-lock.lock', 'img/a.png', 'fonts/a.woff2'] as $f) {
            $this->assertFalse(self::shouldScan($f), $f);
        }
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

    public function testElDetectorCubreCadaEstiloDeAsignacion(): void
    {
        $k = str_repeat('0f', 32);
        $K = strtoupper($k);
        $casos = [
            'par JSON' => '{"apiKey": "' . $k . '"}',
            'objeto JS con comillas simples' => "const c = { apiKey: '$k' };",
            'objeto JS con valor entre comillas dobles' => 'cfg = { apiKey: "' . $k . '" }',
            'array PHP' => "return ['api_key' => '$k'];",
            'array PHP, comillas dobles' => 'return ["apikey" => "' . $k . '"];',
            '.env' => 'API_KEY="' . $K . '"',
            '.env, comillas simples' => "API_KEY='$k'",
            'guion' => '"api-key": "' . $k . '"',
            'YAML' => "apiKey: '$k'",
            'hex en mayusculas' => '{"apiKey":"' . $K . '"}',
        ];
        foreach ($casos as $nombre => $texto) {
            $this->assertCount(1, self::findApiKeyLeaks($texto), $nombre);
        }
    }

    public function testElDetectorNoMarcaCasosBenignos(): void
    {
        $k = str_repeat('0f', 32);
        $this->assertSame([], self::findApiKeyLeaks('{"apiKey": "0f0f0f"}'), 'hex corto');
        $this->assertSame([], self::findApiKeyLeaks('const sha = "' . $k . '";'), '64 hex sin nombre de clave');
        $this->assertSame([], self::findApiKeyLeaks('integrity: sha256-' . base64_encode(random_bytes(32))), 'integrity base64');
        $this->assertSame([], self::findApiKeyLeaks('"integrity": "sha512-' . str_repeat('A1b2', 20) . '=="'), 'integrity sha512');
        $this->assertSame([], self::findApiKeyLeaks('apiKey: process.env.API_KEY'), 'lee del entorno');
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
        $files = $this->git(['ls-files']);
        $this->assertNotEmpty($files, 'git ls-files no devolvio nada');

        $scanned = 0;
        $leaks = [];
        foreach ($files as $file) {
            if (!self::shouldScan($file)) {
                continue;
            }
            $size = @filesize(self::ROOT . $file);
            if ($size === false || $size > self::MAX_BYTES) {
                continue; // borrado en el arbol de trabajo, o demasiado grande
            }
            $text = @file_get_contents(self::ROOT . $file);
            if (!is_string($text)) {
                continue;
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
