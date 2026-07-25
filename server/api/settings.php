<?php
/**
 * GET /api/settings.php[?lang=es|en|ca]
 * Devuelve los ajustes PUBLICOS del sitio. El frontend estatico los consulta
 * al cargar, asi que puedes cambiarlos desde /admin SIN recompilar la web.
 *
 * Expone:
 *   open_to_work    "1"|"0"  -> badge "Disponible" del hero
 *   contact_enabled "1"|"0"  -> formulario de contacto activo
 *   announcement    {on,text,url} -> banner superior (texto ya localizado)
 *
 * SEGURIDAD: lista blanca explicita. Nunca se vuelca la tabla `settings`
 * entera, para que un ajuste privado que anadas manana no se filtre solo.
 */
require_once __DIR__ . '/../lib/http.php';

apply_cors();
require_method('GET');

$lang = $_GET['lang'] ?? 'es';
if (!in_array($lang, ['es', 'en', 'ca'], true)) {
    $lang = 'es';
}

$announcementOn = setting_on('announcement_on', false);
// Texto del banner en el idioma pedido, con respaldo al espanol.
$text = setting_get('announcement_' . $lang, '');
if ($text === '') {
    $text = setting_get('announcement_es', '');
}
// Solo aceptamos enlaces internos o https (nada de javascript:).
$url = setting_get('announcement_url', '');
if ($url !== '' && !preg_match('#^(https://|/)#i', $url)) {
    $url = '';
}

json([
    'open_to_work'    => setting_on('open_to_work', true) ? '1' : '0',
    'contact_enabled' => setting_on('contact_enabled', true) ? '1' : '0',
    'announcement'    => [
        'on'   => ($announcementOn && $text !== '') ? '1' : '0',
        'text' => $text,
        'url'  => $url,
    ],
]);
