<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * AnalyticsViewTest - Helpers puros de presentacion de analytics.php
 * (server/admin/partials/analytics_view.php).
 */
final class AnalyticsViewTest extends TestCase
{
    private const THEAD = '<tr><th>Ruta</th><th>Veces</th></tr>';

    /** @return list<array{path:string,c:int}> */
    private static function rows(int $n): array
    {
        $out = [];
        for ($i = 1; $i <= $n; $i++) {
            $out[] = ['path' => '/p' . $i, 'c' => $i];
        }
        return $out;
    }

    private static function rowHtml(array $r): string
    {
        return '<tr><td>' . e($r['path']) . '</td><td>' . (int) $r['c'] . '</td></tr>';
    }

    private static function table(array $rows): string
    {
        return long_table(self::THEAD, $rows, static fn(array $r): string => self::rowHtml($r),'<tr><td colspan="2" class="empty">Vacío</td></tr>');
    }

    public function testLongTableSinFilasPintaLaFilaVacia(): void
    {
        $this->assertSame(
            '<div class="scroll-x"><table><thead>' . self::THEAD . '</thead><tbody>'
            . '<tr><td colspan="2" class="empty">Vacío</td></tr></tbody></table></div>',
            self::table([])
        );
    }

    public function testLongTableConDiezFilasNoPliegaNada(): void
    {
        $html = self::table(self::rows(10));
        $this->assertSame(10, substr_count($html, '<tr><td>'));
        $this->assertStringNotContainsString('<details', $html);
        $this->assertStringNotContainsString('Vacío', $html);
    }

    public function testLongTableConOnceFilasPliegaLaUltima(): void
    {
        $html = self::table(self::rows(11));
        $this->assertSame(11, substr_count($html, '<tr><td>'));
        $this->assertStringContainsString('<details class="more-rows"><summary>Ver todo (11)</summary>', $html);
        [$visible, $folded] = explode('<details', $html, 2);
        $this->assertSame(10, substr_count($visible, '<tr><td>'));
        $this->assertSame(1, substr_count($folded, '<tr><td>'));
        $this->assertStringContainsString('<td>/p11</td>', $folded);
        $this->assertSame(2, substr_count($html, '<thead>' . self::THEAD . '</thead>'));
    }

    public function testLongTableElSummaryCuentaTodasLasFilas(): void
    {
        $this->assertStringContainsString('<summary>Ver todo (25)</summary>', self::table(self::rows(25)));
    }

    public function testLongTableEscapaLoQueEscapaElCallback(): void
    {
        $html = self::table([['path' => '/<script>alert("x")</script>', 'c' => 1]]);
        $this->assertStringNotContainsString('<script>', $html);
        $this->assertStringContainsString('/&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;', $html);
    }

    public function testChartTickStep(): void
    {
        $this->assertSame(1, chart_tick_step(7));
        $this->assertSame(1, chart_tick_step(8));
        $this->assertSame(2, chart_tick_step(14));
        $this->assertSame(4, chart_tick_step(30));
        $this->assertSame(8, chart_tick_step(60));
        $this->assertSame(1, chart_tick_step(30, 0));
    }

    public function testChartAriaLabelConMejorTramo(): void
    {
        $this->assertSame(
            'Visitas por día: 1.234 visitas en total; mejor: 03/11 (210).',
            chart_aria_label('Visitas por día', 1234, ['label' => '03/11', 'c' => 210])
        );
    }

    public function testChartAriaLabelSinMejorTramo(): void
    {
        $this->assertSame('Franja horaria: 0 visitas en total.', chart_aria_label('Franja horaria', 0, null));
        $this->assertSame('X: 0 visitas en total.', chart_aria_label('X', 0, ['label' => '01/01', 'c' => 0]));
    }
}
