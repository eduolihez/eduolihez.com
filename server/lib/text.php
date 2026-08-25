<?php
/**
 * text.php - Utilidades de transformacion de texto sin dependencias (sin DB,
 * sin sesion). Extraido de llms-blog.php para poder testear la logica real
 * (limpieza de HTML, colapso de espacios) sin arrastrar una conexion a MySQL.
 */

/** HTML del panel -> texto plano legible, conservando los saltos de parrafo. */
function to_plain_text(string $html): string
{
    // El panel permite HTML crudo en el contenido (ver post-edit.php). strip_tags()
    // quita las ETIQUETAS <script>/<style> pero no el texto que envuelven, asi que
    // sin este paso, JS o CSS pegado por accidente en un articulo se colaria como
    // texto visible en el feed publico para IAs.
    $html = preg_replace('#<(script|style)\b[^>]*>.*?</\1>#is', '', $html) ?? $html;

    // Los bloques se convierten en salto de linea ANTES de quitar etiquetas,
    // si no el articulo entero queda como un unico parrafo ilegible.
    $text = preg_replace('#<(br|/p|/h[1-6]|/li|/div|/tr)[^>]*>#i', "\n", $html) ?? $html;
    $text = preg_replace('#<li[^>]*>#i', '- ', $text) ?? $text;
    $text = strip_tags($text);
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    // Espacios y saltos sobrantes: como maximo una linea en blanco seguida.
    $text = preg_replace('/[ \t]+/', ' ', $text) ?? $text;
    $text = preg_replace('/\n[ \t]*/', "\n", $text) ?? $text;
    $text = preg_replace('/\n{3,}/', "\n\n", $text) ?? $text;
    return trim($text);
}
