<?php
/**
 * login.php - Formulario de acceso a lab.eduolihez.com.
 * Verifica credenciales contra lab_users (ver server/lab/auth.php).
 *
 * Sin fuentes/CSS externos a proposito: esta pagina se sirve ANTES de tener
 * sesion, y _content/ (donde vive el CSS de PhishLab) esta bloqueado sin
 * sesion -- referenciarlo aqui seria un 404 encadenado. Estilo minimo
 * autonomo, con las fuentes del sistema.
 */
require_once __DIR__ . '/../lab/auth.php';

if (is_lab_logged_in()) {
    lab_redirect('index.php');
}

$error = '';
// $next ya viene SIN el prefijo /lab-app (require_lab_login() lo quita antes
// de mandarlo al navegador, ver server/lab/auth.php) -- validar que empiece
// por una sola barra (ruta relativa al propio host) y no por "//", que un
// navegador interpretaria como protocol-relative hacia OTRO dominio.
$next = (string) ($_GET['next'] ?? $_POST['next'] ?? '');
if ($next !== '' && (!str_starts_with($next, '/') || str_starts_with($next, '//'))) {
    $next = ''; // no seguir redirects fuera de este host
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    lab_csrf_check();

    $username = trim((string) ($_POST['username'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');

    // Pequena pausa para ralentizar la fuerza bruta, igual que /admin.
    usleep(300000);

    if ($username !== '' && $password !== '' && lab_login_user($username, $password)) {
        lab_redirect($next !== '' ? $next : 'index.php');
    }
    $error = 'Usuario o contraseña incorrectos, o cuenta bloqueada temporalmente.';
}
?>
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>PhishLab — acceso</title>
<style>
  :root {
    --bg:#0a0e14; --surface:#141a24; --border:#1f2733;
    --text:#e6edf3; --muted:#9aa7b8; --accent:#4ade80; --danger:#fbbf24;
  }
  * { box-sizing:border-box; }
  body { margin:0; min-height:100vh; display:grid; place-items:center;
    background:var(--bg); color:var(--text);
    font-family:Inter,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
  .box { width:100%; max-width:360px; padding:2.25rem 2rem 2rem; margin:1rem;
    background:var(--surface); border:1px solid var(--border); border-radius:.9rem; }
  .brand { font-family:ui-monospace,"JetBrains Mono",monospace; font-weight:700;
    text-align:center; margin-bottom:1.5rem; font-size:1.1rem; }
  .brand span { color:var(--accent); }
  label { display:block; margin:.9rem 0 .3rem; font-weight:600; font-size:.85rem; color:var(--muted); }
  input { width:100%; padding:.65rem .75rem; background:var(--bg); color:var(--text);
    border:1px solid var(--border); border-radius:.5rem; font-size:.95rem; font-family:inherit; }
  input:focus { outline:none; border-color:var(--accent); }
  button { width:100%; margin-top:1.4rem; padding:.7rem; border:none; border-radius:.5rem;
    background:var(--accent); color:#0a0e14; font-weight:700; font-size:.95rem; cursor:pointer; }
  .err { background:#3a2a12; color:var(--danger); padding:.6rem .8rem; border-radius:.5rem;
    font-size:.88rem; margin-bottom:1rem; }
</style>
</head>
<body>
  <form class="box" method="post" autocomplete="off">
    <div class="brand">&gt;_ <span>PhishLab</span></div>
    <?php if ($error): ?><div class="err"><?= lab_e($error) ?></div><?php endif; ?>
    <?= lab_csrf_field() ?>
    <input type="hidden" name="next" value="<?= lab_e($next) ?>">
    <label for="username">Usuario</label>
    <input type="text" id="username" name="username" required autofocus>
    <label for="password">Contraseña</label>
    <input type="password" id="password" name="password" required>
    <button type="submit">Entrar</button>
  </form>
</body>
</html>
