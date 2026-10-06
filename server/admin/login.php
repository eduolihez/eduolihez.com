<?php
/**
 * login.php - Formulario de acceso al panel.
 * Verifica credenciales contra admin_users (password_hash / password_verify).
 */
require_once __DIR__ . '/auth.php';

// Si ya hay sesion, al panel directamente.
if (is_logged_in()) {
    redirect('index.php');
}

$error = '';
$ip = client_ip();
$lockMinutes = (int) (config()['security']['login_lockout_minutes'] ?? 15);

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();

    $username = trim((string) ($_POST['username'] ?? ''));

    // Bloqueo por fuerza bruta: demasiados fallos recientes desde esta IP o
    // contra esta cuenta (lo que salte primero — ver login_is_locked()).
    if (login_is_locked($ip, $username)) {
        $error = "Demasiados intentos fallidos. Espera {$lockMinutes} minutos e intentalo de nuevo.";
    } else {
        $password = (string) ($_POST['password'] ?? '');

        // Pequena pausa para ralentizar la fuerza bruta.
        usleep(300000); // 0.3s

        $ok = $username !== '' && $password !== '' && login_user($username, $password);
        login_record($ip, $username, $ok);

        if ($ok) {
            redirect('index.php');
        }
        $error = 'Usuario o contrasena incorrectos.';
    }
} elseif (login_is_locked($ip)) {
    $error = "Demasiados intentos fallidos. Espera {$lockMinutes} minutos.";
}
?>
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Acceso · Admin</title>
<link rel="icon" type="image/svg+xml" href="assets/favicon.svg">
<link rel="stylesheet" href="assets/auth.css">
</head>
<body class="login">
  <form class="box" method="post" autocomplete="off">
    <div class="brand">&gt;_ <span>admin</span></div>
    <?php if ($error): ?><div class="err"><?= e($error) ?></div><?php endif; ?>
    <?= csrf_field() ?>
    <label for="username">Usuario</label>
    <input type="text" id="username" name="username" required autofocus>
    <label for="password">Contrasena</label>
    <input type="password" id="password" name="password" required>
    <button type="submit">Entrar</button>
    <?php /* Absoluta a proposito: en admin.eduolihez.com (Worker de
            enrutado, ver CLOUDFLARE.md), "/" relativo volveria a este mismo
            panel en vez de al portfolio publico. */ ?>
    <a class="back" href="https://eduolihez.com/">&larr; Volver a la web</a>
  </form>
</body>
</html>
