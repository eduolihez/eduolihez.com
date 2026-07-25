<?php
/**
 * POST /api/contact.php
 * Recibe el formulario de contacto (JSON), lo valida, lo guarda en MySQL
 * y (opcional) envia un email de aviso. Incluye honeypot + rate-limit por IP.
 *
 * Cuerpo esperado (JSON):
 *   { "name": "...", "email": "...", "subject": "...", "message": "...", "website": "" }
 * "website" es el honeypot: si viene relleno, es un bot.
 */
require_once __DIR__ . '/../lib/http.php';

apply_cors();
require_method('POST');

/**
 * Verifica un token de Cloudflare Turnstile contra su API.
 * Usa cURL si esta disponible; si no, file_get_contents. Devuelve bool.
 */
function turnstile_verify(string $secret, string $token, string $ip): bool
{
    $url = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
    $data = ['secret' => $secret, 'response' => $token, 'remoteip' => $ip];

    $body = null;
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => http_build_query($data),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 8,
        ]);
        $body = curl_exec($ch);
        curl_close($ch);
    } elseif (ini_get('allow_url_fopen')) {
        $ctx = stream_context_create([
            'http' => [
                'method'  => 'POST',
                'header'  => 'Content-Type: application/x-www-form-urlencoded',
                'content' => http_build_query($data),
                'timeout' => 8,
            ],
        ]);
        $body = @file_get_contents($url, false, $ctx);
    }

    if (!$body) {
        return false;
    }
    $json = json_decode($body, true);
    return is_array($json) && !empty($json['success']);
}

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
    if ($token === '' || !turnstile_verify($ts['secret_key'], $token, $ip)) {
        json(['error' => 'Verificacion anti-bot fallida. Recarga e intentalo de nuevo.'], 403);
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
    $stmt->execute([
        $name,
        $email,
        $subject,
        $message,
        $ip,
        mb_substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255),
    ]);
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
        $mailSubject = $subjPre . ($subject !== '' ? $subject : 'Nuevo mensaje de contacto');
        $body = "Nuevo mensaje desde el portfolio:\n\n"
            . "Nombre:  {$name}\n"
            . "Email:   {$email}\n"
            . "Asunto:  {$subject}\n"
            . "IP:      {$ip}\n"
            . "-----------------------------------------\n\n"
            . $message . "\n";

        // Cabeceras. Reply-To apunta al remitente para que puedas responderle
        // directo. $email ya paso FILTER_VALIDATE_EMAIL + strip_ctl, asi que no
        // puede contener saltos de linea (anti inyeccion de cabeceras).
        $headers  = 'From: ' . strip_ctl($from) . "\r\n";
        $headers .= "Reply-To: {$email}\r\n";
        $headers .= "Content-Type: text/plain; charset=utf-8\r\n";
        $headers .= 'X-Mailer: PHP/' . phpversion();

        // @ para que un fallo de mail() no genere warning ni rompa la respuesta.
        @mail($to, '=?UTF-8?B?' . base64_encode($mailSubject) . '?=', $body, $headers);
    }
}

json(['ok' => true]);
