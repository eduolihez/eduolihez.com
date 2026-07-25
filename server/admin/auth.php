<?php
/**
 * auth.php - Nucleo de autenticacion del panel de administracion.
 * Incluye este archivo AL PRINCIPIO de cada pagina del panel.
 *
 * Funciones:
 *   - inicia la sesion de forma segura
 *   - require_login(): protege una pagina (redirige a login si no hay sesion)
 *   - login_user() / logout_user()
 *   - csrf_token() / csrf_check(): proteccion CSRF de los formularios
 *   - e(): escapa texto para imprimir en HTML (anti-XSS)
 */

require_once __DIR__ . '/../lib/http.php'; // aporta bootstrap + client_ip()

// --- CSP del panel (todo el JS del admin esta en assets/admin.js, 'self') ---
// Se envia antes de cualquier salida (auth.php se incluye al principio).
if (!headers_sent()) {
    header(
        "Content-Security-Policy: default-src 'self'; script-src 'self'; "
        . "style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; "
        . "base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'"
    );
    send_security_headers(true); // nosniff + DENY + noindex
}

// --- Sesion segura ---
if (session_status() === PHP_SESSION_NONE) {
    // Detras de Cloudflare, Apache puede no ver HTTPS: miramos tambien la
    // cabecera del proxy, pero SOLO si la config declara trust_proxy.
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (int) ($_SERVER['SERVER_PORT'] ?? 0) === 443;
    if (!$https && !empty(config()['security']['trust_proxy'])) {
        $https = strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
    }
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'httponly' => true,        // la cookie no es accesible por JS
        'secure'   => $https,      // solo por HTTPS en produccion
        'samesite' => 'Lax',
    ]);
    session_name('PORTFOLIO_ADMIN');
    session_start();
}

/**
 * Caducidad de sesion (S9): cierra sesiones inactivas y limita la duracion
 * absoluta. Evita que un portatil abierto deje el panel accesible para siempre.
 */
(function (): void {
    if (empty($_SESSION['admin_id'])) {
        return;
    }
    $idleMax     = (int) (config()['security']['session_idle_minutes'] ?? 120) * 60;
    $absoluteMax = (int) (config()['security']['session_max_hours'] ?? 12) * 3600;
    $now         = time();

    $lastSeen = (int) ($_SESSION['last_seen'] ?? $now);
    $started  = (int) ($_SESSION['started_at'] ?? $now);

    if (($idleMax > 0 && $now - $lastSeen > $idleMax)
        || ($absoluteMax > 0 && $now - $started > $absoluteMax)) {
        $_SESSION = [];
        session_destroy();
        return;
    }
    $_SESSION['last_seen'] = $now;
})();

/** Escapa una cadena para imprimirla en HTML de forma segura. */
function e($value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Redirige a otra pagina del panel y termina. */
function redirect(string $to): void
{
    header('Location: ' . $to);
    exit;
}

/** True si hay un administrador con sesion iniciada. */
function is_logged_in(): bool
{
    return !empty($_SESSION['admin_id']);
}

/**
 * Protege la pagina: si no hay sesion, va al login.
 * Ademas corta con instrucciones claras si falta aplicar la migracion de la
 * base de datos (asi el panel nunca se queda en blanco por un error de SQL).
 */
function require_login(): void
{
    if (!is_logged_in()) {
        redirect('login.php');
    }

    $missing = migration_pending();
    if ($missing) {
        migration_notice($missing);
    }
}

/** Pantalla de aviso cuando la base de datos aun no esta migrada. */
function migration_notice(array $missing): void
{
    http_response_code(503);
    header('Content-Type: text/html; charset=utf-8');
    $items = implode('', array_map(static fn($m) => '<li>' . e($m) . '</li>', $missing));
    echo <<<HTML
<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Falta actualizar la base de datos</title>
<style>
 body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0a0e14;color:#e6edf3;
   font-family:Inter,system-ui,sans-serif;line-height:1.6;padding:1.5rem}
 .box{max-width:640px;background:#141a24;border:1px solid #1f2733;border-radius:.9rem;padding:2rem}
 h1{font-size:1.25rem;margin:0 0 1rem;color:#fbbf24}
 code{background:#0a0e14;padding:.15rem .4rem;border-radius:.3rem;font-size:.9em;color:#4ade80}
 ol{padding-left:1.2rem} li{margin:.35rem 0}
 ul.miss{color:#9aa7b8;font-size:.9rem;background:#0a0e14;border-radius:.5rem;padding:1rem 1rem 1rem 2rem}
 a{color:#4ade80}
</style></head><body><div class="box">
<h1>⚠ Falta actualizar la base de datos</h1>
<p>El panel se ha actualizado y necesita unas tablas y columnas nuevas que todavia
no existen en tu base de datos. Es un paso de un minuto y no se pierde nada.</p>
<ol>
  <li>Entra en <strong>phpMyAdmin</strong> desde el panel de CDMON.</li>
  <li>Selecciona tu base de datos en la columna izquierda.</li>
  <li>Pestana <strong>Importar</strong> → elige el archivo
      <code>database/schema.sql</code> del proyecto → <strong>Continuar</strong>.</li>
  <li>Recarga esta pagina.</li>
</ol>
<p>Falta por crear:</p>
<ul class="miss">{$items}</ul>
<p style="font-size:.88rem;color:#6b7688;margin-bottom:0;">
  La migracion se puede ejecutar varias veces sin riesgo: comprueba lo que ya existe
  antes de crear nada. Tus proyectos, certificaciones y mensajes no se tocan.
</p>
</div></body></html>
HTML;
    exit;
}

/**
 * Cuenta los intentos de login FALLIDOS de una IP dentro de la ventana
 * de bloqueo configurada. Se usa para frenar ataques de fuerza bruta (S2).
 */
function login_recent_failures(string $ip): int
{
    $window = (int) (config()['security']['login_lockout_minutes'] ?? 15);
    try {
        $stmt = db()->prepare(
            "SELECT COUNT(*) FROM login_attempts
             WHERE ip_address = ? AND success = 0
               AND attempted_at > (NOW() - INTERVAL {$window} MINUTE)"
        );
        $stmt->execute([$ip]);
        return (int) $stmt->fetchColumn();
    } catch (Throwable $e) {
        return 0; // si la tabla no existe aun, no bloqueamos
    }
}

/** True si la IP ha superado el maximo de intentos y esta bloqueada. */
function login_is_locked(string $ip): bool
{
    $max = (int) (config()['security']['login_max_attempts'] ?? 5);
    return login_recent_failures($ip) >= $max;
}

/** Registra un intento de login (para el control de fuerza bruta). */
function login_record(string $ip, string $username, bool $success): void
{
    try {
        db()->prepare(
            'INSERT INTO login_attempts (ip_address, username, success, attempted_at)
             VALUES (?, ?, ?, NOW())'
        )->execute([$ip, mb_substr($username, 0, 60), $success ? 1 : 0]);

        // Al acertar, limpiamos los fallos previos de esa IP.
        if ($success) {
            db()->prepare('DELETE FROM login_attempts WHERE ip_address = ? AND success = 0')
                ->execute([$ip]);
        }
    } catch (Throwable $e) {
        // no bloqueamos el flujo si el registro falla
    }
}

/** Verifica usuario/contrasena contra la tabla admin_users. */
function login_user(string $username, string $password): bool
{
    $stmt = db()->prepare(
        'SELECT id, username, password_hash FROM admin_users WHERE username = ? LIMIT 1'
    );
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if (!$user) {
        // Verificamos contra un hash ficticio para que un usuario inexistente
        // tarde lo mismo que uno real: sin esto se pueden enumerar usuarios
        // midiendo el tiempo de respuesta.
        password_verify($password, '$2y$12$usesomesillystringfooooooooooooooooooooooooooooooooooooo');
        return false;
    }
    if (!password_verify($password, $user['password_hash'])) {
        return false;
    }

    // Si el algoritmo por defecto de PHP ha cambiado (o el coste ha subido),
    // rehasheamos la contrasena de forma transparente.
    if (password_needs_rehash($user['password_hash'], PASSWORD_DEFAULT)) {
        db()->prepare('UPDATE admin_users SET password_hash = ? WHERE id = ?')
            ->execute([password_hash($password, PASSWORD_DEFAULT), (int) $user['id']]);
    }

    // Regenera el ID de sesion tras login (previene fijacion de sesion).
    session_regenerate_id(true);
    $_SESSION['admin_id']       = (int) $user['id'];
    $_SESSION['admin_username'] = $user['username'];
    $_SESSION['started_at']     = time();
    $_SESSION['last_seen']      = time();
    // Token CSRF nuevo para la sesion recien creada.
    $_SESSION['csrf'] = bin2hex(random_bytes(32));

    // Actualiza ultimo acceso.
    db()->prepare('UPDATE admin_users SET last_login = NOW() WHERE id = ?')
        ->execute([(int) $user['id']]);

    log_activity('login', 'admin_user', (int) $user['id'], 'Acceso al panel');

    return true;
}

/** Cierra la sesion. */
function logout_user(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
    }
    session_destroy();
}

/** Devuelve (creando si hace falta) el token CSRF de la sesion. */
function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

/** Imprime el campo oculto con el token CSRF para los formularios. */
function csrf_field(): string
{
    return '<input type="hidden" name="csrf" value="' . e(csrf_token()) . '">';
}

/**
 * Comprueba el token CSRF en peticiones POST; corta si es invalido.
 *
 * IMPORTANTE: exigimos que el token de la SESION exista y no este vacio. Sin
 * esa comprobacion, una peticion que llega sin cookie de sesion crearia una
 * sesion nueva con csrf = '' y `hash_equals('', '')` devolveria TRUE, dejando
 * pasar la peticion (afectaba a login.php y setup.php, que se ejecutan sin
 * sesion previa).
 */
function csrf_check(): void
{
    $expected = $_SESSION['csrf'] ?? '';
    $sent     = $_POST['csrf'] ?? '';

    $valid = is_string($expected) && $expected !== ''
        && is_string($sent) && $sent !== ''
        && hash_equals($expected, $sent);

    if (!$valid) {
        http_response_code(419);
        exit('Token de seguridad invalido. Recarga la pagina e intentalo de nuevo.');
    }
}

/** Nombre del admin logueado (para mostrar en la cabecera). */
function current_admin(): string
{
    return $_SESSION['admin_username'] ?? '';
}
