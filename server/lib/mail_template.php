<?php
/**
 * mail_template.php - Aviso por email del formulario de contacto.
 * ---------------------------------------------------------------------------
 * Funciones PURAS (sin DB, sin sesion, sin enviar nada): reciben los datos del
 * mensaje y devuelven asunto, version de texto y version HTML. contact.php las
 * monta en un correo multipart y lo manda con mail().
 *
 * Reglas del HTML (los clientes de correo no son navegadores):
 *   - Maquetado con tablas y estilos en linea; el <style> solo anade el modo
 *     oscuro y el ajuste movil, y el correo se ve bien aunque se ignore.
 *   - Sin imagenes ni hojas externas: nada que cargue desde fuera ni rastree
 *     la apertura del correo.
 *   - TODO lo que viene del visitante pasa por mail_esc(): el contenido llega
 *     de un formulario publico, asi que se trata como no confiable.
 */
require_once __DIR__ . '/ua.php';

/** Idiomas de la web: etiqueta en espanol y ruta de la portada. */
const MAIL_LANGS = [
    'es' => ['label' => 'Español', 'path' => '/'],
    'en' => ['label' => 'Inglés', 'path' => '/en/'],
    'ca' => ['label' => 'Catalán', 'path' => '/ca/'],
];

const MAIL_MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const MAIL_DEVICES = ['desktop' => 'Escritorio', 'mobile' => 'Móvil', 'tablet' => 'Tablet'];
const MAIL_SUBJECT_MAX = 150;
const MAIL_PREHEADER_MAX = 110;

/** Escapa para HTML (contenido y atributos). */
function mail_esc(string $v): string
{
    return htmlspecialchars($v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Quita saltos de linea y caracteres de control (anti inyeccion de cabeceras). */
function mail_strip_ctl(string $v): string
{
    return trim((string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $v));
}

/** "26 oct 2026, 22:41" en hora de Madrid. */
function mail_format_date(DateTimeInterface $at): string
{
    $local = DateTimeImmutable::createFromInterface($at)->setTimezone(new DateTimeZone('Europe/Madrid'));
    return sprintf(
        '%d %s %d, %s',
        (int) $local->format('j'),
        MAIL_MONTHS[(int) $local->format('n') - 1],
        (int) $local->format('Y'),
        $local->format('H:i')
    );
}

/** @return array{label:string,path:string}|null */
function mail_lang(string $lang): ?array
{
    return MAIL_LANGS[$lang] ?? null;
}

/** "Chrome en Windows" / "Desconocido". */
function mail_browser_label(string $userAgent): string
{
    $ua = ua_parse($userAgent);
    if ($ua['is_bot'] || $ua['browser'] === 'Otro') {
        return 'Desconocido';
    }
    return $ua['os'] === 'Otro' ? $ua['browser'] : "{$ua['browser']} en {$ua['os']}";
}

/** @return array<int,array{0:string,1:string}> Pares etiqueta/valor, ya listos para texto plano. */
function mail_meta_rows(array $d): array
{
    $lang = mail_lang((string) ($d['lang'] ?? ''));
    $device = MAIL_DEVICES[ua_parse((string) ($d['user_agent'] ?? ''))['device']] ?? 'Escritorio';
    $rows = [
        ['Recibido', mail_format_date($d['received_at']) . ' (Madrid)'],
        ['Enviado desde', $lang ? "{$lang['label']} · {$lang['path']}" : 'No indicado'],
        ['IP', (string) ($d['ip'] ?? '')],
        ['Navegador', mail_browser_label((string) ($d['user_agent'] ?? ''))],
        ['Dispositivo', $device],
    ];
    if (!empty($d['message_id'])) {
        $rows[] = ['Mensaje nº', '#' . (int) $d['message_id']];
    }
    return $rows;
}

/** URL mailto: con el asunto "Re: ..." ya puesto. */
function mail_reply_url(string $email, string $subject): string
{
    $to = strtr(rawurlencode($email), ['%40' => '@']);
    $re = rawurlencode('Re: ' . ($subject !== '' ? $subject : 'tu mensaje'));
    return "mailto:{$to}?subject={$re}";
}

/**
 * @param array<string,mixed> $d name, email, subject, message, ip, user_agent,
 *        lang, received_at (DateTimeInterface), message_id (int|null), site_origin
 * @return array{subject:string,text:string,html:string}
 */
function contact_email_build(array $d, string $subjectPrefix): array
{
    $name    = mb_substr(mail_strip_ctl((string) $d['name']), 0, 100);
    $email   = mail_strip_ctl((string) $d['email']);
    $subject = mb_substr(mail_strip_ctl((string) ($d['subject'] ?? '')), 0, MAIL_SUBJECT_MAX);
    $message = (string) $d['message'];
    $panel   = !empty($d['message_id'])
        ? rtrim((string) ($d['site_origin'] ?? ''), '/') . '/admin/messages.php?id=' . (int) $d['message_id']
        : '';

    $shown = $subject !== '' ? $subject : 'Nuevo mensaje de contacto';
    $rows  = mail_meta_rows($d);

    return [
        // El prefijo conserva su espacio final ("[Portfolio] "): solo se limpian los saltos de linea.
        'subject' => (string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $subjectPrefix) . "{$name} — {$shown}",
        'text'    => contact_email_text($name, $email, $shown, $message, $rows, $panel),
        'html'    => contact_email_html($name, $email, $subject, $shown, $message, $rows, $panel),
    ];
}

/** Version de texto plano (clientes sin HTML y filtros antispam). */
function contact_email_text(
    string $name,
    string $email,
    string $shown,
    string $message,
    array $rows,
    string $panel
): string {
    $out  = "NUEVO MENSAJE DESDE EL PORTFOLIO\n";
    $out .= str_repeat('=', 40) . "\n\n";
    $out .= "De:      {$name} <{$email}>\n";
    $out .= "Asunto:  {$shown}\n\n";
    $out .= str_repeat('-', 40) . "\n" . $message . "\n" . str_repeat('-', 40) . "\n\n";
    foreach ($rows as [$label, $value]) {
        $out .= $label . ':' . str_repeat(' ', max(1, 15 - mb_strlen($label . ':'))) . $value . "\n";
    }
    $out .= "\nResponder: " . mail_reply_url($email, $shown === 'Nuevo mensaje de contacto' ? '' : $shown) . "\n";
    if ($panel !== '') {
        $out .= "Panel:     {$panel}\n";
    }
    return $out;
}

/** Version HTML: tarjeta con remitente, asunto, mensaje, botones y datos. */
function contact_email_html(
    string $name,
    string $email,
    string $subject,
    string $shown,
    string $message,
    array $rows,
    string $panel
): string {
    $font = "-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
    $mono = "'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace";

    $initial  = mb_strtoupper(mb_substr($name, 0, 1)) ?: '?';
    $first    = mb_substr(preg_split('/\s+/u', $name)[0] ?? $name, 0, 30);
    $preview  = mb_substr(trim((string) preg_replace('/\s+/u', ' ', $message)), 0, MAIL_PREHEADER_MAX);
    $replyUrl = mail_esc(mail_reply_url($email, $subject));
    $body     = nl2br(mail_esc($message), true);

    $metaHtml = '';
    foreach ($rows as [$label, $value]) {
        $metaHtml .= '<tr><td class="muted" style="padding:5px 16px 5px 0;font:12px ' . $mono . ';color:#5b6674;white-space:nowrap">'
            . mail_esc($label) . '</td><td class="main" style="padding:5px 0;font:12px ' . $mono . ';color:#131820">'
            . mail_esc($value) . '</td></tr>';
    }

    // Etiqueta con el idioma de la pagina desde la que se envio (si se conoce).
    $langChip = $rows[1][1] === 'No indicado' ? '' : '<td align="right"><span class="muted bd" style="display:inline-block;padding:3px 10px;border:1px solid #c6ccc4;'
        . 'border-radius:999px;font:11px ' . $mono . ';color:#5b6674">Desde ' . mail_esc($rows[1][1]) . '</span></td>';

    $panelBtn = $panel === '' ? '' : '<td style="padding-left:10px"><a href="' . mail_esc($panel)
        . '" class="btn2" style="display:inline-block;padding:11px 20px;border:1px solid #c6ccc4;border-radius:8px;'
        . 'font:600 14px ' . $font . ';color:#131820;text-decoration:none">Abrir en el panel</a></td>';

    return '<!doctype html><html lang="es"><head><meta charset="utf-8">'
        . '<meta name="viewport" content="width=device-width,initial-scale=1">'
        . '<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">'
        . '<title>' . mail_esc("Nuevo mensaje de {$name}") . '</title>'
        . '<style>@media (prefers-color-scheme:dark){.page{background:#0a0e14!important}.card{background:#141a24!important;border-color:#1f2733!important}'
        . '.main{color:#e6edf3!important}.muted{color:#9aa7b8!important}.quote{background:#0f141c!important;border-color:#4ade80!important}'
        . '.btn2{color:#e6edf3!important;border-color:#2b3543!important}.bd{border-color:#2b3543!important}.accent{color:#4ade80!important}}'
        . '@media (max-width:480px){.pad{padding:20px!important}.stack{display:block!important;width:100%!important;padding:0 0 10px!important}}</style>'
        . '</head><body class="page" style="margin:0;padding:0;background:#f5f6f3">'
        . '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">' . mail_esc($preview) . '</div>'
        . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="page" style="background:#f5f6f3"><tr><td align="center" style="padding:28px 12px">'
        . '<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%">'
        // Cabecera
        . '<tr><td style="padding:0 4px 14px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
        . '<td style="font:600 13px ' . $mono . ';color:#131820" class="main">EO <span class="accent" style="color:#047266">//</span> security</td>'
        . '<td align="right" style="font:12px ' . $mono . ';color:#5b6674" class="muted">' . mail_esc($rows[0][1]) . '</td>'
        . '</tr></table></td></tr>'
        // Tarjeta
        . '<tr><td class="card pad" style="background:#fff;border:1px solid #e0e3de;border-radius:14px;padding:30px">'
        . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 18px"><tr>'
        . '<td class="accent" style="font:600 11px ' . $mono . ';letter-spacing:.18em;text-transform:uppercase;color:#047266">Nuevo mensaje</td>'
        . $langChip . '</tr></table>'
        . '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 22px"><tr>'
        . '<td width="44" height="44" align="center" valign="middle" style="width:44px;height:44px;border-radius:22px;background:#047266;color:#fff;font:700 18px ' . $font . '">' . mail_esc($initial) . '</td>'
        . '<td style="padding-left:14px"><div class="main" style="font:600 16px ' . $font . ';color:#131820">' . mail_esc($name) . '</div>'
        . '<a href="' . $replyUrl . '" class="accent" style="font:13px ' . $mono . ';color:#047266;text-decoration:none">' . mail_esc($email) . '</a></td>'
        . '</tr></table>'
        . '<h1 class="main" style="margin:0 0 18px;font:700 22px/1.25 ' . $font . ';color:#0a0e14">' . mail_esc($shown) . '</h1>'
        . '<div class="quote main" style="margin:0 0 26px;padding:18px 20px;background:#f5f6f3;border-left:3px solid #047266;border-radius:4px;font:15px/1.65 ' . $font . ';color:#131820">' . $body . '</div>'
        // Botones
        . '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 26px"><tr>'
        . '<td class="stack"><a href="' . $replyUrl . '" style="display:inline-block;padding:12px 22px;border-radius:8px;background:#047266;font:600 14px ' . $font . ';color:#fff;text-decoration:none">Responder a ' . mail_esc($first) . '</a></td>'
        . $panelBtn . '</tr></table>'
        // Datos
        . '<div class="bd" style="border-top:1px solid #e0e3de;padding-top:16px"><table role="presentation" cellpadding="0" cellspacing="0">' . $metaHtml . '</table></div>'
        . '</td></tr>'
        // Pie
        . '<tr><td class="muted" style="padding:16px 4px 0;font:12px/1.5 ' . $font . ';color:#5b6674">Aviso automático de eduolihez.com. '
        . 'Si respondes a este correo, tu respuesta va directa a ' . mail_esc($name) . '.</td></tr>'
        . '</table></td></tr></table></body></html>';
}

/**
 * Monta el correo multipart/alternative (texto + HTML en base64).
 *
 * @param array{subject:string,text:string,html:string} $mail
 * @return array{headers:string,body:string}
 */
function contact_email_mime(array $mail, string $from, string $replyTo): array
{
    $boundary = 'b_' . bin2hex(random_bytes(12));
    $headers  = 'From: ' . mail_strip_ctl($from) . "\r\n"
        . 'Reply-To: ' . mail_strip_ctl($replyTo) . "\r\n"
        . "MIME-Version: 1.0\r\n"
        . "Content-Type: multipart/alternative; boundary=\"{$boundary}\"";

    $part = static fn (string $type, string $content): string => "--{$boundary}\r\n"
        . "Content-Type: {$type}; charset=utf-8\r\n"
        . "Content-Transfer-Encoding: base64\r\n\r\n"
        . chunk_split(base64_encode($content), 76, "\r\n");

    return [
        'headers' => $headers,
        'body'    => $part('text/plain', $mail['text']) . $part('text/html', $mail['html']) . "--{$boundary}--\r\n",
    ];
}
