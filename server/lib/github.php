<?php
/**
 * github.php - Datos de perfil de GitHub para las tarjetas SVG animadas
 * usadas en el README de perfil (github.com/eduolihez/eduolihez).
 * ---------------------------------------------------------------------------
 * Por que existe: el README dependia antes de github-readme-stats.vercel.app
 * (instancia publica compartida) y esa instancia cae con 503 de vez en
 * cuando (ver commit 1b6c10c del repo eduolihez). Alojando esto en nuestro
 * propio dominio, la disponibilidad depende solo de nuestro hosting.
 *
 * Requiere un token de GitHub (Settings -> Developer settings -> Personal
 * access tokens -> classic, sin scopes, solo para leer datos publicos via
 * GraphQL: la API GraphQL de GitHub exige *algun* token autenticado incluso
 * para datos publicos). Editable desde /admin/integrations.php (tabla
 * `settings`, claves `github_stats_*`) -- asi se puede rotar el token o
 * cambiar el TTL de cache sin tocar FTP. `config.php`, seccion 'github', se
 * lee solo como FALLBACK si el ajuste correspondiente esta vacio: cubre el
 * momento entre desplegar este cambio y rellenar los ajustes desde el panel,
 * y a quien prefiera seguir gestionandolo por config.php sin usar el panel.
 *
 * Los resultados se cachean en la tabla `settings` (ya existente) para no
 * gastar la cuota de la API de GitHub en cada visita al README.
 */
require_once __DIR__ . '/bootstrap.php';

const GITHUB_GRAPHQL_URL = 'https://api.github.com/graphql';
const GITHUB_CACHE_KEY   = 'gh_profile_cache_json';
const GITHUB_CACHE_AT    = 'gh_profile_cache_at';

/**
 * Lee un ajuste `github_stats_<$key>` de la tabla `settings`; si esta vacio,
 * cae a `config()['github'][$key]` (ver cabecera del archivo); si tampoco
 * hay nada ahi, usa $default.
 */
function github_setting(string $key, string $default = ''): string
{
    $fromSettings = trim(setting_get('github_stats_' . $key, ''));
    if ($fromSettings !== '') {
        return $fromSettings;
    }
    $fromConfig = trim((string) (config()['github'][$key] ?? ''));
    return $fromConfig !== '' ? $fromConfig : $default;
}

/** True si hay un token configurado (si no, las tarjetas muestran un aviso). */
function github_configured(): bool
{
    return github_setting('token') !== '';
}

/** Usuario de GitHub cuyo perfil se representa (por defecto: eduolihez). */
function github_username(): string
{
    return github_setting('username', 'eduolihez');
}

/**
 * Ejecuta una query GraphQL contra la API de GitHub.
 * Lanza RuntimeException en cualquier fallo (red, HTTP, errores GraphQL).
 */
function github_graphql(string $query, array $variables = []): array
{
    $token = github_setting('token');
    if ($token === '') {
        throw new RuntimeException('Falta el token de GitHub (ver /admin/integrations.php o config.php).');
    }

    $payload = json_encode(['query' => $query, 'variables' => $variables], JSON_UNESCAPED_UNICODE);
    $headers = [
        'Authorization: Bearer ' . $token,
        'Content-Type: application/json',
        'User-Agent: eduolihez.com-github-stats',
        'Accept: application/vnd.github+json',
    ];

    $body = null;
    if (function_exists('curl_init')) {
        $ch = curl_init(GITHUB_GRAPHQL_URL);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);
        $body = curl_exec($ch);
        $errno = curl_errno($ch);
        $err   = curl_error($ch);
        curl_close($ch);
        if ($body === false) {
            throw new RuntimeException('Error de red hacia GitHub: ' . $err, $errno);
        }
    } elseif (ini_get('allow_url_fopen')) {
        $ctx = stream_context_create([
            'http' => [
                'method'  => 'POST',
                'header'  => implode("\r\n", $headers),
                'content' => $payload,
                'timeout' => 10,
                'ignore_errors' => true,
            ],
        ]);
        $body = @file_get_contents(GITHUB_GRAPHQL_URL, false, $ctx);
        if ($body === false) {
            throw new RuntimeException('Error de red hacia GitHub (file_get_contents).');
        }
    } else {
        throw new RuntimeException('Ni curl ni allow_url_fopen disponibles en este hosting.');
    }

    $json = json_decode($body, true);
    if (!is_array($json)) {
        throw new RuntimeException('Respuesta invalida de la API de GitHub.');
    }
    if (!empty($json['errors'])) {
        $msg = $json['errors'][0]['message'] ?? 'error desconocido';
        throw new RuntimeException('GitHub GraphQL: ' . $msg);
    }
    return $json['data'] ?? [];
}

/**
 * Construye y ejecuta la query principal + una query auxiliar (una por cada
 * ano anterior al actual) para sumar los commits de TODOS los anos: la
 * coleccion de contribuciones de GraphQL solo cubre un rango de 1 ano por
 * llamada, asi que "commits totales" exige una llamada por ano de vida de
 * la cuenta. Se agrupan como alias en una unica peticion HTTP.
 */
function github_fetch_profile(string $username): array
{
    $mainQuery = <<<'GQL'
    query($login: String!) {
      user(login: $login) {
        name
        createdAt
        followers { totalCount }
        pullRequests(states: [OPEN, MERGED, CLOSED]) { totalCount }
        issues { totalCount }
        repositoriesContributedTo(contributionTypes: [COMMIT, ISSUE, PULL_REQUEST]) { totalCount }
        repositories(first: 100, ownerAffiliations: OWNER, isFork: false, privacy: PUBLIC) {
          totalCount
          nodes {
            name
            stargazerCount
            languages(first: 8, orderBy: {field: SIZE, direction: DESC}) {
              edges { size node { name color } }
            }
          }
        }
        contributionsCollection {
          totalCommitContributions
          contributionCalendar {
            totalContributions
            weeks { contributionDays { date contributionCount } }
          }
        }
      }
    }
    GQL;

    $data = github_graphql($mainQuery, ['login' => $username]);
    $user = $data['user'] ?? null;
    if (!$user) {
        throw new RuntimeException("Usuario de GitHub '$username' no encontrado.");
    }

    // --- Commits de TODOS los anos, con rangos alineados al calendario ---
    //
    // OJO: el campo contributionsCollection del query principal (sin from/to)
    // cubre una ventana movil de "ultimos 365 dias", NO el ano natural. Si
    // sumaramos ese valor ademas de anos naturales completos, los meses que
    // caen en ambos rangos se contarian dos veces. Por eso el total de
    // commits se calcula AQUI, por separado, sumando anos naturales
    // (1 ene - 1 ene) desde la creacion de la cuenta hasta hoy inclusive; el
    // contributionsCollection del query principal solo se usa para el
    // calendario de racha (streak), que es un dato distinto.
    $createdYear = (int) substr((string) $user['createdAt'], 0, 4);
    $currentYear = (int) date('Y');
    $commitsAllTime = 0;

    $aliasParts = [];
    for ($y = $createdYear; $y <= $currentYear; $y++) {
        $aliasParts[] = sprintf(
            'y%d: contributionsCollection(from: "%d-01-01T00:00:00Z", to: "%d-01-01T00:00:00Z") { totalCommitContributions }',
            $y,
            $y,
            $y + 1
        );
    }
    $yearsQuery = 'query($login: String!) { user(login: $login) { ' . implode(' ', $aliasParts) . ' } }';
    $yearsData = github_graphql($yearsQuery, ['login' => $username]);
    foreach ((array) ($yearsData['user'] ?? []) as $value) {
        $commitsAllTime += (int) ($value['totalCommitContributions'] ?? 0);
    }

    // --- Estrellas y lenguajes agregados de todos los repos propios ---
    //
    // Los forks "manuales" (copia de codigo ajeno sin usar el boton Fork de
    // GitHub, asi que isFork=false no los filtra) inflan el recuento de
    // bytes por lenguaje sin representar nada del trabajo propio: p.ej.
    // northgate-browser trae el arbol fuente entero de Firefox/Mullvad
    // (~1 GB de C++/JS/HTML/C), que taparia por completo Python -- el
    // lenguaje que de verdad usa a diario (ver About Me del README). Se
    // excluyen de LENGUAJES via el ajuste `github_stats_exclude_repos` (CSV;
    // ver /admin/integrations.php), pero SI cuentan para las estrellas (esas
    // si son merito real). Si el ajuste esta vacio, cae a config.php --
    // ahi el formato historico es un array PHP, no CSV, asi que este caso
    // concreto no puede reutilizar github_setting() (que solo sabe leer
    // valores de config.php como texto).
    $excludedCsv = trim(setting_get('github_stats_exclude_repos', ''));
    if ($excludedCsv !== '') {
        $excludedList = explode(',', $excludedCsv);
    } else {
        $excludedList = (array) (config()['github']['exclude_from_languages'] ?? []);
    }
    $excluded = array_filter(array_map(static fn($r) => strtolower(trim((string) $r)), $excludedList));
    $totalStars = 0;
    $languageBytes = []; // name => ['bytes' => int, 'color' => string]
    foreach ((array) ($user['repositories']['nodes'] ?? []) as $repo) {
        $totalStars += (int) ($repo['stargazerCount'] ?? 0);
        if (in_array(strtolower((string) ($repo['name'] ?? '')), $excluded, true)) {
            continue;
        }
        foreach ((array) ($repo['languages']['edges'] ?? []) as $edge) {
            $name  = $edge['node']['name'] ?? null;
            if (!$name) {
                continue;
            }
            $color = $edge['node']['color'] ?? '#8b8b8b';
            $size  = (int) ($edge['size'] ?? 0);
            if (!isset($languageBytes[$name])) {
                $languageBytes[$name] = ['bytes' => 0, 'color' => $color];
            }
            $languageBytes[$name]['bytes'] += $size;
        }
    }
    arsort_by_bytes($languageBytes);
    $topLanguages = array_slice($languageBytes, 0, 5, true);
    $totalLangBytes = array_sum(array_column($topLanguages, 'bytes')) ?: 1;
    $languages = [];
    foreach ($topLanguages as $name => $info) {
        $languages[] = [
            'name'    => $name,
            'color'   => $info['color'],
            'percent' => round($info['bytes'] / $totalLangBytes * 100, 1),
        ];
    }

    // --- Racha de contribuciones (ultimos 12 meses, que es lo que cubre el calendario) ---
    $days = [];
    foreach ((array) ($user['contributionsCollection']['contributionCalendar']['weeks'] ?? []) as $week) {
        foreach ((array) ($week['contributionDays'] ?? []) as $day) {
            $days[] = ['date' => $day['date'], 'count' => (int) $day['contributionCount']];
        }
    }
    [$currentStreak, $longestStreak] = github_calc_streaks($days);
    $totalContributionsYear = (int) ($user['contributionsCollection']['contributionCalendar']['totalContributions'] ?? 0);
    $activeDays = count(array_filter($days, fn($d) => $d['count'] > 0));
    $activeDaysPercent = count($days) > 0 ? round($activeDays / count($days) * 100, 1) : 0.0;

    $stats = [
        'stars'            => $totalStars,
        'commits'          => $commitsAllTime,
        'prs'              => (int) ($user['pullRequests']['totalCount'] ?? 0),
        'issues'           => (int) ($user['issues']['totalCount'] ?? 0),
        'followers'        => (int) ($user['followers']['totalCount'] ?? 0),
        'contributed_to'   => (int) ($user['repositoriesContributedTo']['totalCount'] ?? 0),
        'repos'            => (int) ($user['repositories']['totalCount'] ?? 0),
    ];

    return [
        'generated_at'              => date('c'),
        'stats'                     => $stats,
        // % de dias con actividad en los ultimos 12 meses. Se prefiere a un
        // "rank"/nota de letra tipo github-readme-stats: ese calculo compara
        // contra el perfil de un mantenedor de OSS muy activo (cientos de
        // PRs, miles de commits) y en un perfil personal centrado en
        // seguridad -- no en OSS -- da notas bajas ("C") que no reflejan
        // nada real sobre el trabajo del usuario. Un dato propio (dias
        // activos) no compara con nadie y no puede salir "mal".
        'active_days_percent'      => $activeDaysPercent,
        'languages'                 => $languages,
        'current_streak'           => $currentStreak,
        'longest_streak'           => $longestStreak,
        'total_contributions_year' => $totalContributionsYear,
    ];
}

/** Ordena un mapa name => ['bytes'=>int,...] de mayor a menor por 'bytes'. */
function arsort_by_bytes(array &$map): void
{
    uasort($map, fn($a, $b) => $b['bytes'] <=> $a['bytes']);
}

/**
 * Racha actual y racha mas larga a partir de una lista de dias ordenada
 * cronologicamente ({date, count}). Un dia con count=0 rompe la racha.
 * La racha "actual" ignora que hoy mismo aun no tenga contribuciones (se
 * cuenta desde el ultimo dia con actividad hacia atras).
 */
function github_calc_streaks(array $days): array
{
    $longest = 0;
    $running = 0;
    foreach ($days as $day) {
        if ($day['count'] > 0) {
            $running++;
            $longest = max($longest, $running);
        } else {
            $running = 0;
        }
    }

    // Racha actual: desde el final de la lista hacia atras, saltando el dia
    // de hoy si todavia esta a 0 (el dia no ha terminado).
    $current = 0;
    $i = count($days) - 1;
    if ($i >= 0 && $days[$i]['count'] === 0) {
        $i--; // hoy sin actividad aun: no cuenta como ruptura
    }
    for (; $i >= 0; $i--) {
        if ($days[$i]['count'] > 0) {
            $current++;
        } else {
            break;
        }
    }

    return [$current, $longest];
}

/**
 * Devuelve los datos de perfil, usando la cache de `settings` si todavia es
 * valida. $ttlMinutes viene del ajuste `github_stats_cache_ttl_minutes`.
 */
function github_profile_cached(): array
{
    $username    = github_username();
    $ttlMinutes  = (int) github_setting('cache_ttl_minutes', '360');
    $cachedAt    = setting_get(GITHUB_CACHE_AT, '');
    $cachedJson  = setting_get(GITHUB_CACHE_KEY, '');

    if ($cachedAt !== '' && $cachedJson !== '') {
        $age = time() - strtotime($cachedAt);
        if ($age < $ttlMinutes * 60) {
            $decoded = json_decode($cachedJson, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }
    }

    try {
        $fresh = github_fetch_profile($username);
        setting_set(GITHUB_CACHE_KEY, json_encode($fresh, JSON_UNESCAPED_UNICODE));
        setting_set(GITHUB_CACHE_AT, date('c'));
        return $fresh;
    } catch (Throwable $e) {
        // Si GitHub falla (rate limit, red...) y hay una cache vieja, se sirve
        // esa antes que romper la imagen del README.
        if ($cachedJson !== '') {
            $decoded = json_decode($cachedJson, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }
        throw $e;
    }
}
