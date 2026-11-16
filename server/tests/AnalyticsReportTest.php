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
}
