<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class ChartSeriesTest extends TestCase
{
    public function testBounceRateDivisionPorCero(): void
    {
        $this->assertNull(bounce_rate(0, 0));
        $this->assertSame(50.0, bounce_rate(1, 2));
    }

    public function testMetricDeltaSinPeriodoPrevio(): void
    {
        $this->assertSame('', metric_delta_badge(40.0, null));
        $this->assertSame('', metric_delta_badge(null, 40.0));
        $this->assertSame('', metric_delta_badge(40.0, 0.0));
    }

    public function testMetricDeltaSentidoNormal(): void
    {
        $this->assertSame('<span class="delta up">+50%</span>', metric_delta_badge(60.0, 40.0));
        $this->assertSame('<span class="delta down">-50%</span>', metric_delta_badge(20.0, 40.0));
        $this->assertSame('<span class="delta flat">0%</span>', metric_delta_badge(40.0, 40.0));
    }

    public function testMetricDeltaReboteMenosEsMejor(): void
    {
        $this->assertSame('<span class="delta up">-50%</span>', metric_delta_badge(20.0, 40.0, true));
        $this->assertSame('<span class="delta down">+50%</span>', metric_delta_badge(60.0, 40.0, true));
        $this->assertSame('<span class="delta up">-100%</span>', metric_delta_badge(0.0, 40.0, true));
    }

    public function testChartUsesWeeks(): void
    {
        $this->assertFalse(chart_uses_weeks(30));
        $this->assertFalse(chart_uses_weeks(60));
        $this->assertTrue(chart_uses_weeks(90));
        $this->assertTrue(chart_uses_weeks(365));
    }

    public function testBuildChartSeriesVacio(): void
    {
        $this->assertSame([], build_chart_series([], [], [], []));
        $s = build_chart_series(['2026-11-15', '2026-11-16'], ['15/11', '16/11'], [], []);
        $this->assertSame([
            ['k' => '2026-11-15', 'label' => '15/11', 'c' => 0, 'u' => 0, 'p' => 0],
            ['k' => '2026-11-16', 'label' => '16/11', 'c' => 0, 'u' => 0, 'p' => 0],
        ], $s);
    }

    public function testBuildChartSeriesConPrevioYHuecos(): void
    {
        $s = build_chart_series(
            [2, 1, 0],
            ['01/11', '08/11', '15/11'],
            [['k' => '0', 'c' => '5', 'u' => '3'], ['k' => 2, 'c' => 1, 'u' => 1], ['k' => 9, 'c' => 99, 'u' => 9]],
            [['k' => '1', 'c' => '4']]
        );
        $this->assertSame([1, 0, 5], array_column($s, 'c'));
        $this->assertSame([1, 0, 3], array_column($s, 'u'));
        $this->assertSame([0, 4, 0], array_column($s, 'p'));
        $this->assertSame('08/11', $s[1]['label']);
    }

    public function testBuildChartSeriesSinUniquesNiLabel(): void
    {
        $s = build_chart_series(['a'], [], [['k' => 'a', 'c' => 2]], []);
        $this->assertSame(['k' => 'a', 'label' => 'a', 'c' => 2, 'u' => 0, 'p' => 0], $s[0]);
    }

    public function testWeekBuckets(): void
    {
        [$keys, $labels] = week_buckets(90, '2026-11-16');
        $this->assertCount(13, $keys);
        $this->assertSame(12, $keys[0]);
        $this->assertSame(0, end($keys));
        $this->assertSame('10/11', end($labels));
        [$keys] = week_buckets(365, '2026-11-16');
        $this->assertCount(53, $keys);
        [$keys] = week_buckets(0, '2026-11-16');
        $this->assertSame([0], $keys);
    }

    public function testChartSeriesMax(): void
    {
        $this->assertSame(1, chart_series_max([]));
        $this->assertSame(1, chart_series_max([['c' => 0, 'p' => 0]]));
        $this->assertSame(7, chart_series_max([['c' => 3, 'p' => 7], ['c' => 5, 'p' => 0]]));
    }

    public function testChartAriaLabelPeriodoAnterior(): void
    {
        $this->assertSame(
            'X: 1.234 visitas en total; periodo anterior: 1.000 visitas.',
            chart_aria_label('X', 1234, null, 1000)
        );
        $this->assertSame('X: 0 visitas en total.', chart_aria_label('X', 0, null));
    }

    public function testWeekWindowDays(): void
    {
        $this->assertSame(91, week_window_days(90));
        $this->assertSame(371, week_window_days(365));
        $this->assertSame(7, week_window_days(0));
    }

    public function testWeekBucketKeyCoincideConWeekBuckets(): void
    {
        [$keys] = week_buckets(365, '2026-11-16');
        $expected = [0 => 0, 6 => 0, 7 => 1, 363 => 51, 364 => 52, 365 => 52];
        foreach ($expected as $daysAgo => $k) {
            $this->assertSame($k, week_bucket_key($daysAgo), "DATEDIFF $daysAgo");
            $this->assertContains(week_bucket_key($daysAgo), $keys);
        }
        // El dia mas antiguo de la ventana alineada cae en el ultimo tramo, no en uno parcial extra.
        $this->assertContains(week_bucket_key(week_window_days(365) - 1), $keys);
        $this->assertNotContains(week_bucket_key(week_window_days(365)), $keys);
        $this->assertSame(0, week_bucket_key(-3));
    }

    public function testMetricDeltaActualCeroConPrevio(): void
    {
        $this->assertSame('<span class="delta down">-100%</span>', metric_delta_badge(0.0, 40.0));
    }
}
