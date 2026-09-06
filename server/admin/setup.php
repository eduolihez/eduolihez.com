<?php
/**
 * setup.php - Creacion del PRIMER usuario administrador.
 * ---------------------------------------------------------------------------
 * Por seguridad, SOLO funciona si aun no existe ningun administrador.
 * Una vez creado tu usuario, este script queda inutilizado.
 *
 * >>> IMPORTANTE: BORRA este archivo del servidor despues de usarlo. <<<
 *
 * Pasos:
 *   1. Importa database/schema.sql y configura server/config.php.
 *   2. Visita https://TU-DOMINIO/admin/setup.php
 *   3. Crea tu usuario y contrasena.
 *   4. Elimina setup.php por FTP.
 */
require_once __DIR__ . '/auth.php';

// Si ya hay algun admin, este script se desactiva.
$existing = (int) db()->query('SELECT COUNT(*) FROM admin_users')->fetchColumn();
if ($existing > 0) {
    http_response_code(403);
    exit('Ya existe un administrador. Borra este archivo (setup.php) por seguridad.');
}

$error = '';
$done = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $username = trim((string) ($_POST['username'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');
    $confirm  = (string) ($_POST['confirm'] ?? '');

    if ($username === '' || mb_strlen($username) < 3) {
        $error = 'El usuario debe tener al menos 3 caracteres.';
    } elseif (mb_strlen($password) < 8) {
        $error = 'La contrasena debe tener al menos 8 caracteres.';
    } elseif ($password !== $confirm) {
        $error = 'Las contrasenas no coinciden.';
    } else {
        $hash = password_hash($password, PASSWORD_DEFAULT);
        db()->prepare('INSERT INTO admin_users (username, password_hash, created_at) VALUES (?, ?, NOW())')
            ->execute([$username, $hash]);
        $done = true;
    }
}
?>
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Configuracion inicial · Admin</title>
<style>
  @font-face {
    font-family: 'Inter';
    font-style: normal;
    font-weight: 100 900;
    font-display: swap;
    src: url('assets/fonts/inter-latin-wght-normal.woff2') format('woff2-variations');
  }
  :root {
    --bg: #fbfbfa; --surface: #ffffff; --border: #ececea; --border-strong: #dbdad6;
    --text: #16151a; --muted: #6b6b74;
    --accent: #5b5bd6; --accent-soft: #eeeefc;
    --danger: #b3261e; --danger-soft: #fbe9e8;
    --green: #17794f; --green-soft: #e6f6ee;
  }
  * { box-sizing: border-box; }
  body { margin:0; min-height:100vh; display:grid; place-items:center;
    background:var(--bg); color:var(--text); font-family:'Inter',system-ui,sans-serif; }
  .box { width:100%; max-width:400px; padding:2.25rem 2rem 2rem; margin:1rem;
    background:var(--surface); border:1px solid var(--border); border-radius:.9rem;
    box-shadow: 0 1px 2px rgba(20,20,30,.04), 0 12px 32px -16px rgba(20,20,30,.12);
    position: relative; overflow: hidden; }
  .box::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px; background: var(--accent); }
  h1 { font-size:1.2rem; margin:0 0 .5rem; letter-spacing: -0.02em; }
  p.sub { color:var(--muted); font-size:.9rem; margin:0 0 1.2rem; }
  label { display:block; margin:.9rem 0 .3rem; font-weight:600; font-size:.85rem; color: var(--muted); }
  input { width:100%; padding:.65rem .75rem; background:var(--surface); color:var(--text);
    border:1px solid var(--border-strong); border-radius:.5rem; box-sizing:border-box; font-family: inherit;
    transition: border-color .15s, box-shadow .15s; }
  input:focus { outline:none; border-color:var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
  button { width:100%; margin-top:1.4rem; padding:.7rem; border:none; border-radius:.5rem;
    background:var(--text); color:var(--surface); font-weight:700; cursor:pointer; font-family: inherit; }
  button:hover { background:#000; }
  .err { background:var(--danger-soft); color:var(--danger); border:1px solid transparent;
    padding:.6rem .8rem; border-radius:.5rem; font-size:.88rem; margin-bottom:1rem; }
  .ok { background:var(--green-soft); color:var(--green); border:1px solid transparent;
    padding:.9rem 1rem; border-radius:.5rem; font-size:.9rem; }
  a { color:var(--accent); }
</style>
</head>
<body>
  <div class="box">
    <?php if ($done): ?>
      <h1>✅ Administrador creado</h1>
      <div class="ok">
        <p style="margin:0 0 .6rem;"><strong>Ahora BORRA este archivo</strong> (server/admin/setup.php)
        del servidor por seguridad.</p>
        <p style="margin:0;">Despues accede en <a href="login.php">login.php</a>.</p>
      </div>
    <?php else: ?>
      <h1>Configuracion inicial</h1>
      <p class="sub">Crea tu usuario administrador. Este formulario se desactiva
      automaticamente despues.</p>
      <?php if ($error): ?><div class="err"><?= e($error) ?></div><?php endif; ?>
      <form method="post" autocomplete="off">
        <?= csrf_field() ?>
        <label for="username">Usuario</label>
        <input type="text" id="username" name="username" required minlength="3" autofocus>
        <label for="password">Contrasena (min. 8)</label>
        <input type="password" id="password" name="password" required minlength="8">
        <label for="confirm">Repite la contrasena</label>
        <input type="password" id="confirm" name="confirm" required minlength="8">
        <button type="submit">Crear administrador</button>
      </form>
    <?php endif; ?>
  </div>
</body>
</html>
