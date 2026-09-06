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
<style>
  @font-face {
    font-family: 'Inter';
    font-style: normal;
    font-weight: 100 900;
    font-display: swap;
    src: url('assets/fonts/inter-latin-wght-normal.woff2') format('woff2-variations');
  }
  @font-face {
    font-family: 'JetBrains Mono';
    font-style: normal;
    font-weight: 100 800;
    font-display: swap;
    src: url('assets/fonts/jetbrains-mono-latin-wght-normal.woff2') format('woff2-variations');
  }
  :root {
    --bg: #fbfbfa; --surface: #ffffff; --border: #ececea; --border-strong: #dbdad6;
    --text: #16151a; --muted: #6b6b74; --faint: #9c9ba3;
    --accent: #5b5bd6; --accent-soft: #eeeefc;
    --danger: #b3261e; --danger-soft: #fbe9e8;
  }
  * { box-sizing: border-box; }
  body { margin:0; min-height:100vh; display:grid; place-items:center;
    background:var(--bg); color:var(--text);
    font-family:'Inter',system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
  .box { width:100%; max-width:360px; padding:2.25rem 2rem 2rem;
    background:var(--surface); border:1px solid var(--border); border-radius:.9rem;
    margin:1rem; box-shadow: 0 1px 2px rgba(20,20,30,.04), 0 12px 32px -16px rgba(20,20,30,.12);
    position: relative; overflow: hidden; }
  .box::before {
    content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px;
    background: var(--accent);
  }
  .brand { font-family:'JetBrains Mono',ui-monospace,monospace; font-weight:700;
    text-align:center; margin-bottom:1.5rem; font-size:1.1rem; letter-spacing: -0.02em; }
  .brand span { color:var(--accent); }
  label { display:block; margin:.9rem 0 .3rem; font-weight:600; font-size:.85rem; color: var(--muted); }
  input { width:100%; padding:.65rem .75rem; background:var(--surface); color:var(--text);
    border:1px solid var(--border-strong); border-radius:.5rem; font-size:.95rem; box-sizing:border-box;
    font-family: inherit; transition: border-color .15s, box-shadow .15s; }
  input:focus { outline:none; border-color:var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
  button { width:100%; margin-top:1.4rem; padding:.7rem; border:none; border-radius:.5rem;
    background:var(--text); color:var(--surface); font-weight:700; font-size:.95rem; cursor:pointer;
    font-family: inherit; transition: background .15s; }
  button:hover { background:#000; }
  .err { background:var(--danger-soft); color:var(--danger); border:1px solid transparent;
    padding:.6rem .8rem; border-radius:.5rem; font-size:.88rem; margin-bottom:1rem; }
  .back { display:block; text-align:center; margin-top:1.2rem; color:var(--faint); font-size:.85rem; text-decoration:none; }
  .back:hover { color: var(--muted); }
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
    <?php /* Absoluta a proposito: en admin.eduolihez.com (Worker de
            enrutado, ver CLOUDFLARE.md), "/" relativo volveria a este mismo
            panel en vez de al portfolio publico. */ ?>
    <a class="back" href="https://eduolihez.com/">&larr; Volver a la web</a>
  </form>
</body>
</html>
