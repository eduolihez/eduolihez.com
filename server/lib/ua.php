<?php
/**
 * ua.php - Analisis del User-Agent SIN librerias externas.
 * ---------------------------------------------------------------------------
 * Devuelve dispositivo, navegador, sistema operativo y si parece un bot.
 * Se ejecuta UNA vez, al registrar la visita, y el resultado se guarda en
 * columnas de la tabla `visits`. Asi el panel de analitica no tiene que
 * reprocesar cadenas en cada consulta (mucho mas rapido).
 *
 * No pretende ser exhaustivo: cubre lo que realmente vera un portfolio.
 */

/**
 * @return array{device:string,browser:string,os:string,is_bot:bool}
 */
function ua_parse(string $ua): array
{
    $u = $ua;

    // --- Bots y rastreadores (incluidos los de IA) ---------------------------
    $botPatterns = '/(bot|crawler|spider|crawling|slurp|curl|wget|python-requests|'
        . 'http-client|headlesschrome|phantomjs|monitoring|pingdom|uptime|'
        . 'lighthouse|gptbot|claudebot|claude-web|anthropic|perplexity|ccbot|'
        . 'oai-searchbot|chatgpt|google-extended|bytespider|amazonbot|applebot|'
        . 'facebookexternalhit|whatsapp|telegrambot|linkedinbot|twitterbot|'
        . 'discordbot|semrush|ahrefs|mj12bot|dotbot|petalbot|yandex|baidu)/i';
    $isBot = $u === '' || (bool) preg_match($botPatterns, $u);

    // --- Sistema operativo ---------------------------------------------------
    $os = 'Otro';
    if (preg_match('/windows nt/i', $u))            $os = 'Windows';
    elseif (preg_match('/android/i', $u))           $os = 'Android';
    elseif (preg_match('/(iphone|ipad|ipod)/i', $u)) $os = 'iOS';
    elseif (preg_match('/mac os x/i', $u))          $os = 'macOS';
    elseif (preg_match('/cros/i', $u))              $os = 'ChromeOS';
    elseif (preg_match('/(ubuntu|debian|fedora|linux)/i', $u)) $os = 'Linux';

    // --- Navegador -----------------------------------------------------------
    // El orden importa: casi todos los navegadores mienten diciendo "Chrome"
    // y "Safari", asi que comprobamos primero los mas especificos.
    $browser = 'Otro';
    if (preg_match('/edg(e|a|ios)?\//i', $u))       $browser = 'Edge';
    elseif (preg_match('/opr\/|opera/i', $u))       $browser = 'Opera';
    elseif (preg_match('/samsungbrowser/i', $u))    $browser = 'Samsung Internet';
    elseif (preg_match('/vivaldi/i', $u))           $browser = 'Vivaldi';
    elseif (preg_match('/brave/i', $u))             $browser = 'Brave';
    elseif (preg_match('/duckduckgo/i', $u))        $browser = 'DuckDuckGo';
    elseif (preg_match('/firefox|fxios/i', $u))     $browser = 'Firefox';
    elseif (preg_match('/chrome|crios/i', $u))      $browser = 'Chrome';
    elseif (preg_match('/safari/i', $u))            $browser = 'Safari';
    elseif (preg_match('/msie|trident/i', $u))      $browser = 'Internet Explorer';

    // --- Tipo de dispositivo -------------------------------------------------
    $device = 'desktop';
    if (preg_match('/(ipad|tablet|playbook|silk)|(android(?!.*mobi))/i', $u)) {
        $device = 'tablet';
    } elseif (preg_match('/(mobi|iphone|ipod|opera mini|iemobile|windows phone)/i', $u)) {
        $device = 'mobile';
    }

    return [
        'device'  => $device,
        'browser' => $browser,
        'os'      => $os,
        'is_bot'  => $isBot,
    ];
}

/**
 * Clasifica un referrer en un canal de trafico legible.
 * Devuelve: 'Busqueda', 'Redes sociales', 'IA / Chatbots', 'Referencia' o 'Directo'.
 */
function referrer_channel(?string $referrer): string
{
    $r = trim((string) $referrer);
    if ($r === '') {
        return 'Directo';
    }
    $host = strtolower((string) parse_url($r, PHP_URL_HOST));
    if ($host === '') {
        return 'Referencia';
    }

    $search = ['google.', 'bing.', 'duckduckgo.', 'yahoo.', 'ecosia.', 'brave.com',
               'startpage.', 'qwant.', 'baidu.', 'yandex.'];
    $social = ['linkedin.', 'lnkd.in', 'twitter.', 'x.com', 't.co', 'facebook.',
               'instagram.', 'reddit.', 'mastodon', 'bsky.', 'youtube.', 'tiktok.',
               'whatsapp', 'telegram', 'discord'];
    $ai     = ['chatgpt.com', 'openai.com', 'claude.ai', 'anthropic.com',
               'perplexity.ai', 'gemini.google.com', 'bard.google.com',
               'copilot.microsoft.com', 'you.com', 'phind.com'];

    foreach ($ai as $needle)     if (str_contains($host, $needle)) return 'IA / Chatbots';
    foreach ($search as $needle) if (str_contains($host, $needle)) return 'Busqueda';
    foreach ($social as $needle) if (str_contains($host, $needle)) return 'Redes sociales';

    return 'Referencia';
}

/** Nombre del pais a partir de su codigo ISO de 2 letras (los mas probables). */
function country_name(?string $code): string
{
    $c = strtoupper(trim((string) $code));
    $map = [
        'ES' => 'Espana',        'FR' => 'Francia',       'PT' => 'Portugal',
        'IT' => 'Italia',        'DE' => 'Alemania',      'GB' => 'Reino Unido',
        'IE' => 'Irlanda',       'NL' => 'Paises Bajos',  'BE' => 'Belgica',
        'CH' => 'Suiza',         'AT' => 'Austria',       'SE' => 'Suecia',
        'NO' => 'Noruega',       'DK' => 'Dinamarca',     'FI' => 'Finlandia',
        'PL' => 'Polonia',       'RO' => 'Rumania',       'CZ' => 'Chequia',
        'US' => 'Estados Unidos', 'CA' => 'Canada',       'MX' => 'Mexico',
        'AR' => 'Argentina',     'CL' => 'Chile',         'CO' => 'Colombia',
        'PE' => 'Peru',          'BR' => 'Brasil',        'UY' => 'Uruguay',
        'VE' => 'Venezuela',     'EC' => 'Ecuador',       'MA' => 'Marruecos',
        'IN' => 'India',         'CN' => 'China',         'JP' => 'Japon',
        'KR' => 'Corea del Sur', 'AU' => 'Australia',     'NZ' => 'Nueva Zelanda',
        'RU' => 'Rusia',         'UA' => 'Ucrania',       'TR' => 'Turquia',
        'IL' => 'Israel',        'AE' => 'Emiratos Arabes', 'ZA' => 'Sudafrica',
    ];
    if ($c === '') {
        return 'Desconocido';
    }
    return $map[$c] ?? $c;
}

/** Convierte un codigo de pais ISO-3166 en su emoji de bandera. */
function country_flag(?string $code): string
{
    $c = strtoupper(trim((string) $code));
    if (strlen($c) !== 2 || !ctype_alpha($c)) {
        return '🏳';
    }
    // Los emoji de bandera son dos "Regional Indicator Symbols" (U+1F1E6 = 'A').
    $out = '';
    for ($i = 0; $i < 2; $i++) {
        $out .= mb_chr(0x1F1E6 + (ord($c[$i]) - 65), 'UTF-8');
    }
    return $out;
}
