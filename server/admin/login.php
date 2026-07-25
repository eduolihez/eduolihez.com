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

    // Bloqueo por fuerza bruta: demasiados fallos recientes desde esta IP.
    if (login_is_locked($ip)) {
        $error = "Demasiados intentos fallidos. Espera {$lockMinutes} minutos e intentalo de nuevo.";
    } else {
        $username = trim((string) ($_POST['username'] ?? ''));
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
<style>
  body { margin:0; min-height:100vh; display:grid; place-items:center;
    background:#0a0e14; color:#e6edf3;
    font-family:Inter,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
  .box { width:100%; max-width:360px; padding:2rem;
    background:#141a24; border:1px solid #1f2733; border-radius:.9rem; margin:1rem; }
  .brand { font-family:ui-monospace,"JetBrains Mono",monospace; font-weight:700;
    text-align:center; margin-bottom:1.5rem; font-size:1.1rem; }
  .brand span { color:#4ade80; }
  label { display:block; margin:.9rem 0 .3rem; font-weight:600; font-size:.9rem; }
  input { width:100%; padding:.65rem .75rem; background:#0a0e14; color:#e6edf3;
    border:1px solid #1f2733; border-radius:.5rem; font-size:.95rem; box-sizing:border-box; }
  input:focus { outline:none; border-color:#4ade80; }
  button { width:100%; margin-top:1.4rem; padding:.7rem; border:none; border-radius:.5rem;
    background:#4ade80; color:#0a0e14; font-weight:700; font-size:.95rem; cursor:pointer; }
  button:hover { background:#22c55e; }
  .err { background:rgba(248,113,113,.12); color:#f87171; border:1px solid rgba(248,113,113,.3);
    padding:.6rem .8rem; border-radius:.5rem; font-size:.88rem; margin-bottom:1rem; }
  .back { display:block; text-align:center; margin-top:1.2rem; color:#6b7688; font-size:.85rem; text-decoration:none; }
</style>
</head>
<body>
  <form class="box" method="post" autocomplete="off">
    <div class="brand">&gt;_ <span>admin</span></div>
    <?php if ($error): ?><div class="err"><?= e($error) ?></div><?php endif; ?>
    <?= csrf_field() ?>
    <label for="username">Usuario</label>
    <input type="text" id="username" name="username" required autofocus>
    <label for="password">Contrasena</label>
    <input type="password" id="password" name="password" required>
    <button type="submit">Entrar</button>
    <a class="back" href="/">&larr; Volver a la web</a>
  </form>
</body>
</html>
