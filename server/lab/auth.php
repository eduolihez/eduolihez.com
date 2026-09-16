<?php
/**
 * auth.php - Autenticacion de lab.eduolihez.com (PhishLab completo, marca
 * real). Incluir AL PRINCIPIO de public/lab-app/index.php, login.php y
 * logout.php.
 *
 * Sustituye al HTTP Basic Auth original (public/lab-app/.htaccess +
 * .htpasswd) para poder tener cuentas individuales gestionadas desde
 * /admin (server/admin/lab-users.php) con bloqueo por fuerza bruta real --
 * Apache Basic Auth no sabe contar intentos fallidos, asi que ese bloqueo
 * solo es posible pasando el gate por PHP, igual que ya hace el panel
 * (server/admin/auth.php, del que este archivo es un espejo deliberado).
 *
 * Nombres de funcion con prefijo lab_ (o current_lab_user/require_lab_login/
 * is_lab_logged_in) para no chocar si algun dia algo llegase a incluir esto
 * junto a server/admin/auth.php en el mismo proceso -- hoy nunca ocurre (son
 * dos entradas HTTP separadas), pero es gratis evitarlo.
 */

require_once __DIR__ . '/../lib/http.php'; // aporta bootstrap + client_ip()

// --- CSP del gate: solo lo imprescindible para el propio PhishLab estatico,
// mas api.eduolihez.com para su telemetria (assets/js/core/telemetry.js) ---
if (!headers_sent()) {
    header(
        "Content-Security-Policy: default-src 'self'; script-src 'self'; "
        . "style-src 'self' 'unsafe-inline'; img-src 'self' data:; "
        . "connect-src 'self' https://api.eduolihez.com; "
        . "base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'"
    );
    send_security_headers(true); // nosniff + DENY + noindex
}

// --- Sesion segura (mismo tratamiento que server/admin/auth.php) ---
if (session_status() === PHP_SESSION_NONE) {
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (int) ($_SERVER['SERVER_PORT'] ?? 0) === 443;
    if (!$https && !empty(config()['security']['trust_proxy'])) {
        $https = strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
    }
    // 'domain' vacio escopa la cookie al host exacto: el navegador solo ve
    // lab.eduolihez.com (el Worker de Cloudflare es transparente, ver
    // CLOUDFLARE.md), asi que no hace falta mas.
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'domain'   => '',
        'httponly' => true,
        'secure'   => $https,
        'samesite' => 'Lax',
    ]);
    session_name('PHISHLAB_LAB');
    session_start();
}

/** Escapa una cadena para imprimirla en HTML de forma segura. */
function lab_e($value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Redirige dentro de lab-app y termina. */
function lab_redirect(string $to): void
{
    header('Location: ' . $to);
    exit;
}

/** True si hay una sesion de usuario de lab iniciada. */
function is_lab_logged_in(): bool
{
    return !empty($_SESSION['lab_user_id']);
}

/** Protege una pagina: si no hay sesion, va al login preservando la URL pedida. */
function require_lab_login(): void
{
    if (!is_lab_logged_in()) {
        $next = (string) ($_SERVER['REQUEST_URI'] ?? '');
        lab_redirect('login.php' . ($next !== '' ? '?next=' . rawurlencode($next) : ''));
    }
}

/** Nombre del usuario de lab logueado. */
function current_lab_user(): string
{
    return $_SESSION['lab_username'] ?? '';
}

/**
 * Cuenta los intentos fallidos recientes de una IP, ventana fija de 15 min
 * (no configurable via server/config.php a proposito: esta superficie es
 * mas pequena que el panel, no hace falta el mismo nivel de ajuste fino).
 */
const LAB_LOGIN_MAX_ATTEMPTS    = 5;
const LAB_LOGIN_LOCKOUT_MINUTES = 15;

function lab_login_recent_failures(string $ip): int
{
    try {
        $stmt = db()->prepare(
            'SELECT COUNT(*) FROM lab_login_attempts
             WHERE ip_address = ? AND success = 0
               AND attempted_at > (NOW() - INTERVAL ' . LAB_LOGIN_LOCKOUT_MINUTES . ' MINUTE)'
        );
        $stmt->execute([$ip]);
        return (int) $stmt->fetchColumn();
    } catch (Throwable $e) {
        return 0; // tabla aun no migrada: no bloqueamos
    }
}

function lab_login_recent_failures_by_username(string $username): int
{
    try {
        $stmt = db()->prepare(
            'SELECT COUNT(*) FROM lab_login_attempts
             WHERE username = ? AND success = 0
               AND attempted_at > (NOW() - INTERVAL ' . LAB_LOGIN_LOCKOUT_MINUTES . ' MINUTE)'
        );
        $stmt->execute([$username]);
        return (int) $stmt->fetchColumn();
    } catch (Throwable $e) {
        return 0;
    }
}

/** True si ESE usuario concreto tiene el bloqueo por fuerza bruta activado (por defecto, si). */
function lab_user_lockout_enabled(string $username): bool
{
    try {
        $stmt = db()->prepare('SELECT lockout_enabled FROM lab_users WHERE username = ? LIMIT 1');
        $stmt->execute([$username]);
        $value = $stmt->fetchColumn();
        return $value === false ? true : (bool) $value;
    } catch (Throwable $e) {
        return true;
    }
}

/**
 * True si la IP o el usuario estan bloqueados. El bloqueo por IP siempre se
 * aplica (frena fuerza bruta contra cualquier cuenta desde el mismo origen);
 * el bloqueo por USUARIO solo cuenta si esa cuenta concreta lo tiene
 * activado (lab_users.lockout_enabled) -- el interruptor que se gestiona
 * desde /admin -> lab-users.php.
 */
function lab_login_is_locked(string $ip, string $username = ''): bool
{
    if (lab_login_recent_failures($ip) >= LAB_LOGIN_MAX_ATTEMPTS) {
        return true;
    }
    if ($username === '') {
        return false;
    }
    if (!lab_user_lockout_enabled($username)) {
        return false;
    }
    return lab_login_recent_failures_by_username($username) >= LAB_LOGIN_MAX_ATTEMPTS;
}

/** Registra un intento de login de lab (para el control de fuerza bruta). */
function lab_login_record(string $ip, string $username, bool $success): void
{
    try {
        db()->prepare(
            'INSERT INTO lab_login_attempts (ip_address, username, success, attempted_at)
             VALUES (?, ?, ?, NOW())'
        )->execute([$ip, mb_substr($username, 0, 60), $success ? 1 : 0]);

        if ($success) {
            db()->prepare('DELETE FROM lab_login_attempts WHERE ip_address = ? AND success = 0')
                ->execute([$ip]);
        }
    } catch (Throwable $e) {
        // no bloqueamos el flujo si el registro falla
    }
}

/** Verifica usuario/contrasena contra lab_users y abre sesion si es correcto. */
function lab_login_user(string $username, string $password): bool
{
    $ip = client_ip();

    if (lab_login_is_locked($ip, $username)) {
        return false; // no distingue "bloqueado" de "credenciales malas" de cara al mensaje
    }

    $stmt = db()->prepare(
        'SELECT id, username, password_hash, active FROM lab_users WHERE username = ? LIMIT 1'
    );
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if (!$user || !(int) $user['active']) {
        // Mismo tratamiento anti-enumeracion que server/admin/auth.php: un
        // usuario inexistente o desactivado tarda lo mismo que uno valido.
        password_verify($password, '$2y$12$usesomesillystringfooooooooooooooooooooooooooooooooooooo');
        lab_login_record($ip, $username, false);
        return false;
    }
    if (!password_verify($password, $user['password_hash'])) {
        lab_login_record($ip, $username, false);
        return false;
    }

    if (password_needs_rehash($user['password_hash'], PASSWORD_DEFAULT)) {
        db()->prepare('UPDATE lab_users SET password_hash = ? WHERE id = ?')
            ->execute([password_hash($password, PASSWORD_DEFAULT), (int) $user['id']]);
    }

    session_regenerate_id(true);
    $_SESSION['lab_user_id']  = (int) $user['id'];
    $_SESSION['lab_username'] = $user['username'];
    $_SESSION['lab_csrf']     = bin2hex(random_bytes(32));

    db()->prepare('UPDATE lab_users SET last_login = NOW() WHERE id = ?')->execute([(int) $user['id']]);
    lab_login_record($ip, $username, true);

    return true;
}

/** Cierra la sesion de lab. */
function lab_logout_user(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
    }
    session_destroy();
}

/** Token CSRF de la sesion de lab (creandolo si hace falta). */
function lab_csrf_token(): string
{
    if (empty($_SESSION['lab_csrf'])) {
        $_SESSION['lab_csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['lab_csrf'];
}

function lab_csrf_field(): string
{
    return '<input type="hidden" name="csrf" value="' . lab_e(lab_csrf_token()) . '">';
}

function lab_csrf_check(): void
{
    $expected = $_SESSION['lab_csrf'] ?? '';
    $sent     = $_POST['csrf'] ?? '';

    $valid = is_string($expected) && $expected !== ''
        && is_string($sent) && $sent !== ''
        && hash_equals($expected, $sent);

    if (!$valid) {
        http_response_code(419);
        exit('Token de seguridad invalido. Recarga la pagina e intentalo de nuevo.');
    }
}
