<?php

use PHPUnit\Framework\TestCase;

/**
 * SpacesTest - Cubre la logica pura de espacios del panel admin
 * (server/admin/partials/spaces.php) y nav_icon() (partials/icons.php).
 */
final class SpacesTest extends TestCase
{
    private const APPS = ['eduolihez', 'phishlab', 'nowait'];

    /** Devuelve las paginas (href sin query) de todos los items de un espacio. */
    private function navPages(string $space, array $counts = []): array
    {
        $pages = [];
        foreach (space_nav($space, $counts) as $group) {
            foreach ($group['items'] as $item) {
                $pages[] = $item['page'];
            }
        }
        return $pages;
    }

    private function navItem(string $space, string $page, array $counts = []): ?array
    {
        foreach (space_nav($space, $counts) as $group) {
            foreach ($group['items'] as $item) {
                if ($item['page'] === $page) {
                    return $item;
                }
            }
        }
        return null;
    }

    public function testNormalizeAceptaEspaciosFijos(): void
    {
        $this->assertSame('global', normalize_space('global', self::APPS));
        $this->assertSame('site', normalize_space('site', self::APPS));
        $this->assertSame('phishlab', normalize_space('phishlab', self::APPS));
    }

    public function testNormalizeAliasDeAppSinPrefijo(): void
    {
        $this->assertSame('site', normalize_space('eduolihez', self::APPS));
        $this->assertSame('phishlab', normalize_space('phishlab', self::APPS));
        $this->assertSame('app:nowait', normalize_space('nowait', self::APPS));
    }

    public function testNormalizeRechazaBasura(): void
    {
        foreach (['', '../etc', 'app:', 'app:borrada', 'GLOBAL '] as $raw) {
            $this->assertNull(normalize_space($raw, self::APPS), "raw: '$raw'");
        }
    }

    public function testNormalizeAliasesFijosSinEstarEnApps(): void
    {
        $this->assertSame('site', normalize_space('eduolihez', []));
        $this->assertSame('phishlab', normalize_space('phishlab', []));
        $this->assertNull(normalize_space('app:eduolihez', self::APPS));
        $this->assertNull(normalize_space('app:phishlab', self::APPS));
        $this->assertSame('app:nowait', normalize_space('app:nowait', self::APPS));
    }

    public function testSpaceAppSlug(): void
    {
        $this->assertSame('eduolihez', space_app_slug('site'));
        $this->assertSame('phishlab', space_app_slug('phishlab'));
        $this->assertSame('x', space_app_slug('app:x'));
        $this->assertNull(space_app_slug('global'));
    }

    public function testResolveSinNadaUsaOrigenDePagina(): void
    {
        $this->assertSame('site', resolve_space([], [], self::APPS, 'projects.php'));
        $this->assertSame('phishlab', resolve_space([], [], self::APPS, 'lab-users.php'));
        $this->assertSame('global', resolve_space([], [], self::APPS, 'index.php'));
        $this->assertSame('global', resolve_space([], [], self::APPS, 'inventada.php'));
    }

    public function testResolveGetGanaASesion(): void
    {
        $this->assertSame(
            'phishlab',
            resolve_space(['space' => 'phishlab'], ['admin_space' => 'site'], self::APPS, 'analytics.php')
        );
    }

    public function testResolveAliasApp(): void
    {
        $this->assertSame('app:nowait', resolve_space(['app' => 'nowait'], [], self::APPS, 'analytics.php'));
    }

    public function testResolveSesionSoloSiLaPaginaLaAdmite(): void
    {
        $this->assertSame('site', resolve_space([], ['admin_space' => 'phishlab'], self::APPS, 'projects.php'));
        $this->assertSame('site', resolve_space([], ['admin_space' => 'site'], self::APPS, 'analytics.php'));
    }

    public function testResolveIgnoraEntradaInvalida(): void
    {
        $this->assertSame('site', resolve_space(['space' => '../x'], [], self::APPS, 'projects.php'));
        $this->assertSame('site', resolve_space(['space' => ['x']], [], self::APPS, 'projects.php'));
        $this->assertSame('global', resolve_space(['space' => ['x']], [], self::APPS, 'index.php'));
    }

    public function testResolveGetNoAdmitidoPorLaPagina(): void
    {
        $this->assertSame('site', resolve_space(['space' => 'phishlab'], [], self::APPS, 'projects.php'));
    }

    public function testResolveSesionNoStringSeIgnora(): void
    {
        $this->assertSame('site', resolve_space([], ['admin_space' => ['x']], self::APPS, 'projects.php'));
    }

    public function testPageSpaces(): void
    {
        $this->assertSame(['global', 'site'], page_spaces('messages.php'));
        $this->assertSame(['global', 'site', 'phishlab', '*'], page_spaces('analytics.php'));
        $this->assertSame(['global'], page_spaces('security.php'));
    }

    public function testResolveAnaliticaAdmiteCualquierApp(): void
    {
        $this->assertSame(
            'app:nowait',
            resolve_space([], ['admin_space' => 'app:nowait'], self::APPS, 'analytics.php')
        );
    }

    public function testSpaceOptionsSinApps(): void
    {
        $opts = space_options([]);
        $this->assertCount(3, $opts);
        $this->assertSame(['global', 'site', 'phishlab'], array_column($opts, 'id'));
        $this->assertSame('eduolihez.com', $opts[1]['label']);
    }

    public function testSpaceOptionsConApps(): void
    {
        $opts = space_options([
            ['slug' => 'eduolihez', 'display_name' => 'eduolihez.com'],
            ['slug' => 'phishlab', 'display_name' => 'PhishLab'],
            ['slug' => 'nowait', 'display_name' => 'NoWait'],
        ]);
        $this->assertCount(4, $opts);
        $this->assertSame(['id' => 'app:nowait', 'label' => 'NoWait'], $opts[3]);
    }

    public function testSpaceNavGlobalIncluyeSistema(): void
    {
        $pages = $this->navPages('global');
        foreach (['index.php', 'messages.php', 'analytics.php', 'security.php', 'settings.php', 'backup.php', 'integrations.php', 'apps.php'] as $p) {
            $this->assertContains($p, $pages);
        }
        $this->assertNotContains('projects.php', $pages);
    }

    public function testSpaceNavSiteContieneContenido(): void
    {
        $pages = $this->navPages('site');
        foreach (['projects.php', 'certifications.php', 'posts.php'] as $p) {
            $this->assertContains($p, $pages);
        }
        $this->assertNotContains('security.php', $pages);
    }

    public function testSpaceNavPhishlabYApp(): void
    {
        $this->assertSame(['analytics.php', 'lab-users.php'], $this->navPages('phishlab'));
        $this->assertSame(['analytics.php'], $this->navPages('app:nowait'));
    }

    public function testSpaceNavBadges(): void
    {
        $item = $this->navItem('global', 'messages.php', ['unread' => 3]);
        $this->assertSame('3', $item['badge']);
        $this->assertSame('alert', $item['badge_type']);
        $this->assertSame('', $this->navItem('global', 'messages.php', ['unread' => 0])['badge']);
        $this->assertSame('', $this->navItem('global', 'messages.php')['badge']);
    }

    public function testSpaceNavBadgesDeConteo(): void
    {
        $counts = ['projects' => 4, 'certs' => 5, 'posts' => 6, 'apps' => 7, 'lab_users' => 8];
        $this->assertSame('4', $this->navItem('site', 'projects.php', $counts)['badge']);
        $this->assertSame('5', $this->navItem('site', 'certifications.php', $counts)['badge']);
        $this->assertSame('6', $this->navItem('site', 'posts.php', $counts)['badge']);
        $this->assertSame('7', $this->navItem('global', 'apps.php', $counts)['badge']);
        $this->assertSame('8', $this->navItem('phishlab', 'lab-users.php', $counts)['badge']);
        $this->assertSame('count', $this->navItem('site', 'projects.php', $counts)['badge_type']);
    }

    public function testSpaceNavHrefLlevaElEspacio(): void
    {
        $this->assertSame('lab-users.php?space=phishlab', $this->navItem('phishlab', 'lab-users.php')['href']);
        $this->assertSame('analytics.php?space=app%3Anowait', $this->navItem('app:nowait', 'analytics.php')['href']);
    }

    public function testNavIconDesconocidaDevuelveVacio(): void
    {
        $this->assertSame('', nav_icon('nope'));
        $this->assertStringStartsWith('<svg', nav_icon('grid'));
    }

    public function testNavIconTodasLasClaves(): void
    {
        foreach (['grid', 'briefcase', 'award', 'edit', 'mail', 'chart', 'activity', 'shield', 'settings', 'database', 'link', 'users'] as $k) {
            $this->assertStringStartsWith('<svg', nav_icon($k), $k);
        }
    }

    public function testSpaceNavNoDevuelveGruposVacios(): void
    {
        foreach (['global', 'site', 'phishlab', 'app:nowait'] as $space) {
            foreach (space_nav($space, []) as $group) {
                $this->assertNotEmpty($group['items']);
            }
        }
    }
}
