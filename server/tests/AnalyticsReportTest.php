<?php
use PHPUnit\Framework\TestCase;

require_once __DIR__ . '/../lib/analytics_report.php';

/** Agregacion pura de la lectura por post (reading_summary). */
final class AnalyticsReportTest extends TestCase
{
    public function testNoDataAtAll(): void
    {
        $r = reading_summary(0, 0, 0, null, null);
        $this->assertTrue($r['few']);
        $this->assertNull($r['deep_pct']);
        $this->assertNull($r['avg_duration']);
        $this->assertNull($r['avg_scroll']);
    }

    public function testFewVisitsHidesPercentage(): void
    {
        $r = reading_summary(4, 4, 4, 30.4, 95.0);
        $this->assertTrue($r['few']);
        $this->assertNull($r['deep_pct']);
        $this->assertSame(30, $r['avg_duration']);
        $this->assertSame(95, $r['avg_scroll']);
    }

    public function testEnoughVisitsGivesDeepPercentage(): void
    {
        $r = reading_summary(10, 8, 2, 61.6, 54.4);
        $this->assertFalse($r['few']);
        $this->assertSame(25, $r['deep_pct']);
        $this->assertSame(62, $r['avg_duration']);
        $this->assertSame(54, $r['avg_scroll']);
    }

    public function testAllReachNinetyPercent(): void
    {
        $this->assertSame(100, reading_summary(5, 5, 5, 10.0, 99.0)['deep_pct']);
    }

    public function testEnoughVisitsButNoScrollMeasured(): void
    {
        $r = reading_summary(20, 0, 0, 12.0, null);
        $this->assertFalse($r['few']);
        $this->assertNull($r['deep_pct']);
    }

    /** @dataProvider readingPathProvider */
    public function testReadingPathRegexp(string $path, bool $isPost): void
    {
        $this->assertSame($isPost, (bool) preg_match('#' . READING_PATH_REGEXP . '#', $path));
    }

    public static function readingPathProvider(): array
    {
        return [
            'post es' => ['/blog/post/a-b/', true],
            'post en' => ['/en/blog/post/x/', true],
            'post ca sin barra' => ['/ca/blog/post/x', true],
            'indice' => ['/blog/', false],
            'indice en' => ['/en/blog/', false],
            'molde legacy' => ['/blog/post/', false],
            'rss' => ['/blog/rss.xml', false],
            'translations' => ['/blog/translations.json', false],
            'portada' => ['/blog/covers/x.png', false],
            'otro idioma' => ['/fr/blog/post/x/', false],
        ];
    }

    public function testMissingTableByErrorInfo(): void
    {
        $e = new PDOException('x');
        $e->errorInfo = ['42S02', 1146, "Table 'site_events' doesn't exist"];
        $this->assertTrue(is_missing_table($e));
        $e2 = new PDOException('x');
        $e2->errorInfo = ['HY000', 1146, ''];
        $this->assertTrue(is_missing_table($e2));
    }

    public function testOtherErrorsAreNotMissingTable(): void
    {
        $e = new PDOException('x');
        $e->errorInfo = ['42S22', 1054, 'Unknown column'];
        $this->assertFalse(is_missing_table($e));
        $this->assertFalse(is_missing_table(new PDOException('sin info')));
        $this->assertFalse(is_missing_table(new RuntimeException('x', 0)));
    }
}
