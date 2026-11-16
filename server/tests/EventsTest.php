<?php
use PHPUnit\Framework\TestCase;

require_once __DIR__ . '/../lib/events.php';

/** Validacion pura de eventos de analitica (normalize_event). */
final class EventsTest extends TestCase
{
    /** @dataProvider validNamesProvider */
    public function testEachValidName(string $name, ?string $target): void
    {
        $r = normalize_event(['name' => $name, 'target' => $target, 'path' => '/blog/post-1/', 'session_id' => '0123456789abcdef']);
        $this->assertSame(
            ['name' => $name, 'target' => $target, 'path' => '/blog/post-1/', 'session_id' => '0123456789abcdef'],
            $r
        );
    }

    public static function validNamesProvider(): array
    {
        return [
            'cv_download' => ['cv_download', null],
            'outbound' => ['outbound', 'github.com'],
            'lang_switch' => ['lang_switch', 'ca'],
            'theme_toggle' => ['theme_toggle', 'dark'],
            'contact_submit' => ['contact_submit', null],
            'not_found' => ['not_found', null],
        ];
    }

    public function testInvalidName(): void
    {
        $this->assertNull(normalize_event(['name' => 'hack', 'path' => '/']));
        $this->assertNull(normalize_event(['name' => 'CV_DOWNLOAD', 'path' => '/']));
        $this->assertNull(normalize_event(['path' => '/']));
    }

    public function testEmptyTargetBecomesNull(): void
    {
        $this->assertNull(normalize_event(['name' => 'cv_download', 'target' => '', 'path' => '/'])['target']);
        $this->assertNull(normalize_event(['name' => 'theme_toggle', 'path' => '/'])['target']);
        $this->assertNull(normalize_event(['name' => 'theme_toggle', 'target' => '', 'path' => '/'])['target']);
    }

    /** @dataProvider badTargetProvider */
    public function testBadTargets(string $name, mixed $target): void
    {
        $this->assertNull(normalize_event(['name' => $name, 'target' => $target, 'path' => '/']));
    }

    public static function badTargetProvider(): array
    {
        return [
            'outbound esquema' => ['outbound', 'https://github.com'],
            'outbound ruta' => ['outbound', 'github.com/x'],
            'outbound mayusculas' => ['outbound', 'GitHub.com'],
            'outbound raro' => ['outbound', 'git hub.com'],
            'outbound 81' => ['outbound', str_repeat('a', 81)],
            'outbound vacio' => ['outbound', null],
            'outbound salto de linea' => ['outbound', "github.com\n"],
            'lang fuera' => ['lang_switch', 'fr'],
            'lang vacio' => ['lang_switch', ''],
            'lang mayus' => ['lang_switch', 'EN'],
            'theme fuera' => ['theme_toggle', 'blue'],
            'cv con target' => ['cv_download', 'x'],
            'contact con target' => ['contact_submit', 'x'],
            'not_found con target' => ['not_found', 'x'],
            'target array' => ['outbound', ['a.com']],
            'target int' => ['lang_switch', 1],
        ];
    }

    public function testTargetLengthLimit(): void
    {
        $host = str_repeat('a', 80);
        $this->assertSame($host, normalize_event(['name' => 'outbound', 'target' => $host, 'path' => '/'])['target']);
        $this->assertSame('a', normalize_event(['name' => 'outbound', 'target' => 'a', 'path' => '/'])['target']);
        $this->assertSame('a-b.c1', normalize_event(['name' => 'outbound', 'target' => 'a-b.c1', 'path' => '/'])['target']);
    }

    /** @dataProvider badPathProvider */
    public function testBadPaths(mixed $path): void
    {
        $this->assertNull(normalize_event(['name' => 'not_found', 'path' => $path]));
    }

    public static function badPathProvider(): array
    {
        return [
            'sin barra' => ['blog'],
            'esquema' => ['https://x.com/'],
            'query' => ['/a?b=1'],
            'espacio' => ['/a b'],
            'vacio' => [''],
            '121' => ['/' . str_repeat('a', 120)],
            'salto de linea' => ["/a\n"],
            'array' => [['/']],
            'int' => [5],
        ];
    }

    public function testPathLimitsAndDefault(): void
    {
        $p = '/' . str_repeat('a', 119);
        $this->assertSame($p, normalize_event(['name' => 'not_found', 'path' => $p])['path']);
        $this->assertSame('/', normalize_event(['name' => 'not_found', 'path' => '/'])['path']);
        $this->assertSame('/', normalize_event(['name' => 'not_found'])['path']);
        $this->assertSame('/en/a_b-c.d/', normalize_event(['name' => 'not_found', 'path' => '/en/a_b-c.d/'])['path']);
    }

    public function testSessionId(): void
    {
        $this->assertNull(normalize_event(['name' => 'not_found', 'path' => '/'])['session_id']);
        $this->assertNull(normalize_event(['name' => 'not_found', 'path' => '/', 'session_id' => 'XYZ'])['session_id']);
        $this->assertNull(normalize_event(['name' => 'not_found', 'path' => '/', 'session_id' => 123])['session_id']);
    }

    public function testWeirdNameTypes(): void
    {
        $this->assertNull(normalize_event(['name' => ['outbound']]));
        $this->assertNull(normalize_event(['name' => 1]));
        $this->assertNull(normalize_event(['name' => null]));
        $this->assertNull(normalize_event([]));
    }
}
