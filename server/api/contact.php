<?php
/**
 * POST /api/contact.php
 * Recibe el formulario de contacto (JSON), lo valida, lo guarda en MySQL
 * y (opcional) envia un email de aviso. Incluye honeypot + rate-limit por IP.
 *
 * Cuerpo esperado (JSON):
 *   { "name": "...", "email": "...", "subject": "...", "message": "...", "lang": "es|en|ca", "website": "" }
 * "lang" es el idioma de la pagina desde la que se envia (solo informativo: sale en el email).
 * "website" es el honeypot: si viene relleno, es un bot.
 */
require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/site.php';
require_once __DIR__ . '/../lib/mail_template.php';
require_once __DIR__ . '/../lib/turnstile.php';

apply_cors();
require_method('POST');

$cfg   = config();
$input = read_json_body();

// --- Interruptor desde el panel ---
if (!setting_on('contact_enabled', true)) {
    json(['error' => 'El formulario esta temporalmente desactivado.'], 503);
}

// --- Honeypot anti-bots ---
// Campo oculto que solo rellenan los bots. Fingimos exito y no guardamos nada.
if (!empty($input['website'])) {
    json(['ok' => true]);
}

/**
 * Quita saltos de linea y caracteres de control.
 * Sin esto, un valor con "\r\n" que acabe en una cabecera de email permitiria
 * inyectar cabeceras (Bcc:, Content-Type:...) y usar el formulario para spam.
 */
function strip_ctl(string $v): string
{
    return trim((string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $v));
}

// --- Sanitizado + validacion ---
$name    = strip_ctl((string) ($input['name'] ?? ''));
$email   = strip_ctl((string) ($input['email'] ?? ''));
$subject = strip_ctl((string) ($input['subject'] ?? ''));
$message = trim((string) ($input['message'] ?? '')); // aqui SI permitimos saltos de linea
// Solo los idiomas de la web; cualquier otro valor se descarta (sale como "No indicado").
$langIn  = $input['lang'] ?? '';
$lang    = is_string($langIn) && array_key_exists($langIn, MAIL_LANGS) ? $langIn : '';

if ($name === '' || $email === '' || $message === '') {
    json(['error' => 'Faltan campos obligatorios.'], 422);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json(['error' => 'Email no valido.'], 422);
}
// Limites de longitud (defensa en profundidad; el frontend ya limita).
$name    = mb_substr($name, 0, 100);
$email   = mb_substr($email, 0, 150);
$subject = mb_substr($subject, 0, 150);
$message = mb_substr($message, 0, 3000);

$ip = client_ip();

// --- Cloudflare Turnstile (captcha invisible) - OPCIONAL ---
// Solo se exige si has configurado la clave secreta en config.php.
$ts = $cfg['turnstile'] ?? [];
if (!empty($ts['secret_key'])) {
    $token = (string) ($input['turnstileToken'] ?? '');
    $check = $token === '' ? ['ok' => false, 'codes' => ['missing-input-response']] : turnstile_verify($ts['secret_key'], $token, $ip);
    if (!$check['ok']) {
        // "detail" son codigos de Cloudflare (p. ej. invalid-input-secret): no son
        // sensibles y dicen si el fallo es la clave, el token o el hosting.
        json([
            'error'  => 'Verificacion anti-bot fallida. Recarga e intentalo de nuevo.',
            'detail' => implode(',', $check['codes']),
        ], 403);
    }
}

// --- Rate-limit por IP (anti-spam) ---
$maxPer = (int) ($cfg['security']['contact_max_per_window'] ?? 5);
$window = (int) ($cfg['security']['contact_window_minutes'] ?? 60);
try {
    // $window es un entero de confianza (viene de config), se interpola directo.
    // Asi evitamos placeholders dentro de INTERVAL con prepares reales.
    $rl = db()->prepare(
        "SELECT COUNT(*) FROM messages
         WHERE ip_address = ? AND created_at > (NOW() - INTERVAL {$window} MINUTE)"
    );
    $rl->execute([$ip]);
    if ((int) $rl->fetchColumn() >= $maxPer) {
        json(['error' => 'Demasiados mensajes. Intentalo mas tarde.'], 429);
    }
} catch (Throwable $e) {
    // Si el rate-limit falla, seguimos (no bloqueamos el contacto legitimo).
}

// --- Guardar en MySQL ---
try {
    $stmt = db()->prepare(
        "INSERT INTO messages (name, email, subject, message, ip_address, user_agent, is_read, created_at)
         VALUES (?, ?, ?, ?, ?, ?, 0, NOW())"
    );
    $userAgent = mb_substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255);
    $stmt->execute([$name, $email, $subject, $message, $ip, $userAgent]);
    $messageId = (int) db()->lastInsertId();
} catch (Throwable $e) {
    json(['error' => 'No se pudo guardar el mensaje.'], 500);
}

// --- Notificacion por email (best-effort: si falla, el mensaje ya esta guardado) ---
$mail = $cfg['mail'] ?? [];
if (!empty($mail['enabled'])) {
    $to      = $mail['to'] ?? '';
    $from    = $mail['from'] ?? ('no-reply@' . ($_SERVER['HTTP_HOST'] ?? 'localhost'));
    $subjPre = $mail['subject_prefix'] ?? '';

    if ($to !== '') {
        $built = contact_email_build([
            'name'        => $name,
            'email'       => $email,
            'subject'     => $subject,
            'message'     => $message,
            'ip'          => $ip,
            'user_agent'  => $userAgent,
            'lang'        => $lang,
            'received_at' => new DateTimeImmutable('now', new DateTimeZone('UTC')),
            'message_id'  => $messageId > 0 ? $messageId : null,
            'site_origin' => SITE_ORIGIN,
        ], $subjPre);
        // Reply-To apunta al remitente para responderle directo. $email ya paso
        // FILTER_VALIDATE_EMAIL + strip_ctl; contact_email_mime() vuelve a limpiar
        // las cabeceras (anti inyeccion).
        $mime = contact_email_mime($built, $from, $email);

        // @ para que un fallo de mail() no genere warning ni rompa la respuesta.
        @mail($to, '=?UTF-8?B?' . base64_encode($built['subject']) . '?=', $mime['body'], $mime['headers']);
    }
}

json(['ok' => true]);
