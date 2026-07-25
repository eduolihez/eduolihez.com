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
  body { margin:0; min-height:100vh; display:grid; place-items:center;
    background:#0a0e14; color:#e6edf3; font-family:Inter,system-ui,sans-serif; }
  .box { width:100%; max-width:400px; padding:2rem; margin:1rem;
    background:#141a24; border:1px solid #1f2733; border-radius:.9rem; }
  h1 { font-size:1.2rem; margin:0 0 .5rem; }
  p.sub { color:#9aa7b8; font-size:.9rem; margin:0 0 1.2rem; }
  label { display:block; margin:.9rem 0 .3rem; font-weight:600; font-size:.9rem; }
  input { width:100%; padding:.65rem .75rem; background:#0a0e14; color:#e6edf3;
    border:1px solid #1f2733; border-radius:.5rem; box-sizing:border-box; }
  input:focus { outline:none; border-color:#4ade80; }
  button { width:100%; margin-top:1.4rem; padding:.7rem; border:none; border-radius:.5rem;
    background:#4ade80; color:#0a0e14; font-weight:700; cursor:pointer; }
  .err { background:rgba(248,113,113,.12); color:#f87171; border:1px solid rgba(248,113,113,.3);
    padding:.6rem .8rem; border-radius:.5rem; font-size:.88rem; margin-bottom:1rem; }
  .ok { background:rgba(74,222,128,.12); color:#4ade80; border:1px solid rgba(74,222,128,.3);
    padding:.9rem 1rem; border-radius:.5rem; font-size:.9rem; }
  a { color:#4ade80; }
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
