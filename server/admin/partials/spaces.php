<?php
/**
 * Logica pura de "espacios" del panel admin: que espacio se esta viendo y que
 * menu le corresponde. Sin require, sin BD, sin sesion: recibe todo por
 * parametro para poder testearse en la suite PHPUnit (ver tests/bootstrap.php).
 *
 * Ids de espacio: 'global' | 'site' (eduolihez.com) | 'phishlab' | 'app:<slug>'.
 */

const SPACE_GLOBAL   = 'global';
const SPACE_SITE     = 'site';
const SPACE_PHISHLAB = 'phishlab';

/**
 * Normaliza un valor externo a un id de espacio valido, o null.
 * $appSlugs = slugs de la tabla `apps`. 'eduolihez' y 'phishlab' son alias de
 * los espacios fijos 'site' y 'phishlab' aunque no esten en $appSlugs; el
 * resto de slugs (sueltos o como 'app:<slug>') deben estar en $appSlugs.
 */
function normalize_space(string $raw, array $appSlugs): ?string
{
    if ($raw === SPACE_GLOBAL || $raw === SPACE_SITE || $raw === SPACE_PHISHLAB) {
        return $raw;
    }
    if ($raw === 'eduolihez') {
        return SPACE_SITE;
    }
    // 'app:eduolihez' / 'app:phishlab' no son ids validos: esas apps son 'site' / 'phishlab'.
    if (str_starts_with($raw, 'app:')) {
        $slug = substr($raw, 4);
        if ($slug !== '' && $slug !== 'eduolihez' && $slug !== 'phishlab' && in_array($slug, $appSlugs, true)) {
            return 'app:' . $slug;
        }
        return null;
    }
    if ($raw !== '' && in_array($raw, $appSlugs, true)) {
        return 'app:' . $raw;
    }
    return null;
}

/** Slug de la tabla `apps` asociado a un espacio, o null para 'global'. */
function space_app_slug(string $space): ?string
{
    if ($space === SPACE_SITE) {
        return 'eduolihez';
    }
    if ($space === SPACE_PHISHLAB) {
        return 'phishlab';
    }
    if (str_starts_with($space, 'app:')) {
        return substr($space, 4);
    }
    return null;
}

/**
 * Espacios a los que pertenece una pagina; el primero es su espacio de origen.
 * '*' = cualquier 'app:<slug>'. Pagina desconocida -> ['global'].
 */
function page_spaces(string $page): array
{
    static $map = [
        'index.php'          => [SPACE_GLOBAL, SPACE_SITE],
        'messages.php'       => [SPACE_GLOBAL, SPACE_SITE],
        'analytics.php'      => [SPACE_GLOBAL, SPACE_SITE, SPACE_PHISHLAB, '*'],
        'projects.php'       => [SPACE_SITE],
        'certifications.php' => [SPACE_SITE],
        'posts.php'          => [SPACE_SITE],
        'lab-users.php'      => [SPACE_PHISHLAB],
        'apps.php'           => [SPACE_GLOBAL],
        'integrations.php'   => [SPACE_GLOBAL],
        'security.php'       => [SPACE_GLOBAL],
        'settings.php'       => [SPACE_GLOBAL],
        'backup.php'         => [SPACE_GLOBAL],
    ];
    return $map[$page] ?? [SPACE_GLOBAL];
}

/** Indica si la pagina admite el espacio dado (con comodin para 'app:*'). */
function space_page_allows(string $page, string $space): bool
{
    $allowed = page_spaces($page);
    if (in_array($space, $allowed, true)) {
        return true;
    }
    return str_starts_with($space, 'app:') && in_array('*', $allowed, true);
}

/**
 * Resuelve el espacio activo: $get['space'], luego $get['app'] (alias),
 * luego $session['admin_space']; cada uno debe ser string valido y admitido
 * por la pagina. Si ninguno sirve, el espacio de origen de la pagina.
 */
function resolve_space(array $get, array $session, array $appSlugs, string $page): string
{
    $candidates = [$get['space'] ?? null, $get['app'] ?? null, $session['admin_space'] ?? null];
    foreach ($candidates as $raw) {
        if (!is_string($raw)) {
            continue;
        }
        $space = normalize_space($raw, $appSlugs);
        if ($space !== null && space_page_allows($page, $space)) {
            return $space;
        }
    }
    return page_spaces($page)[0];
}

/**
 * Opciones del selector de espacio. $apps = filas ['slug','display_name'].
 * Global, eduolihez.com, PhishLab y despues cada app restante.
 */
function space_options(array $apps): array
{
    $opts = [
        ['id' => SPACE_GLOBAL, 'label' => 'Global'],
        ['id' => SPACE_SITE, 'label' => 'eduolihez.com'],
        ['id' => SPACE_PHISHLAB, 'label' => 'PhishLab'],
    ];
    foreach ($apps as $app) {
        $slug = (string) ($app['slug'] ?? '');
        if ($slug === '' || $slug === 'eduolihez' || $slug === 'phishlab') {
            continue;
        }
        $label = (string) ($app['display_name'] ?? '');
        $opts[] = ['id' => 'app:' . $slug, 'label' => $label !== '' ? $label : $slug];
    }
    return $opts;
}

/**
 * Menu lateral de un espacio. $counts (claves opcionales): unread, projects,
 * certs, posts, apps, lab_users. Devuelve grupos con items
 * ['page','href','label','icon','badge','badge_type'].
 */
function space_nav(string $space, array $counts): array
{
    $qs = '?space=' . urlencode($space);
    $count = static fn(string $key): string => (int) ($counts[$key] ?? 0) > 0 ? (string) (int) $counts[$key] : '';
    $item = static fn(string $page, string $label, string $icon, string $badge = '', string $type = 'count'): array => [
        'page'       => $page,
        'href'       => $page . $qs,
        'label'      => $label,
        'icon'       => $icon,
        'badge'      => $badge,
        'badge_type' => $type,
    ];

    if ($space === SPACE_GLOBAL) {
        return [
            ['label' => '', 'items' => [
                $item('index.php', 'Resumen', 'grid'),
                $item('messages.php', 'Bandeja', 'mail', $count('unread'), 'alert'),
                $item('analytics.php', 'Analítica', 'chart'),
            ]],
            ['label' => 'Sistema', 'items' => [
                $item('security.php', 'Seguridad', 'shield'),
                $item('settings.php', 'Ajustes', 'settings'),
                $item('backup.php', 'Backup', 'database'),
                $item('integrations.php', 'Integraciones', 'link'),
                $item('apps.php', 'Gestionar apps', 'grid', $count('apps')),
            ]],
        ];
    }
    if ($space === SPACE_SITE) {
        return [
            ['label' => '', 'items' => [
                $item('projects.php', 'Proyectos', 'briefcase', $count('projects')),
                $item('certifications.php', 'Certificaciones', 'award', $count('certs')),
                $item('posts.php', 'Blog', 'edit', $count('posts')),
                $item('analytics.php', 'Analítica', 'chart'),
            ]],
        ];
    }
    if ($space === SPACE_PHISHLAB) {
        return [
            ['label' => '', 'items' => [
                $item('analytics.php', 'Resumen', 'grid'),
                $item('lab-users.php', 'Usuarios', 'users', $count('lab_users')),
            ]],
        ];
    }
    // app:<slug>
    return [
        ['label' => '', 'items' => [
            $item('analytics.php', 'Resumen', 'grid'),
        ]],
    ];
}
