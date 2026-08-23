<?php
/**
 * Constantes de sitio compartidas por los endpoints publicos de solo lectura
 * (llms-blog.php, sitemap-posts.php). Antes vivian duplicadas en cada
 * archivo; un cambio de dominio o de idiomas exigia editar los dos a la vez
 * y podian desincronizarse en silencio.
 */

/**
 * Dominio canonico, fijo a proposito.
 *
 * NO se deriva de $_SERVER['HTTP_HOST']: esa cabecera la controla quien hace
 * la peticion, asi que cualquiera podria pedir estos archivos con otro Host y
 * obtener contenido apuntando a su dominio. Debe coincidir con SITE.domain de
 * src/config.ts.
 */
const SITE_ORIGIN = 'https://eduolihez.com';

/** Prefijo de ruta del detalle de articulo por idioma. */
const POST_PATHS = [
    'es' => '/blog/post/',
    'en' => '/en/blog/post/',
    'ca' => '/ca/blog/post/',
];
