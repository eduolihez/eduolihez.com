<?php
/**
 * lab-users.php - Gestion de cuentas de acceso a lab.eduolihez.com
 * (PhishLab completo, marca real). Ver server/lab/auth.php y
 * public/lab-app/index.php para el gate que usa esta tabla.
 *
 * lockout_enabled es el interruptor "bloqueo por fuerza bruta" por cuenta:
 * activado por defecto, pensado para poder desactivarlo en una cuenta
 * concreta de confianza (p.ej. si algun dia esto vive en una intranet).
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_login();

// No requerimos server/lab/auth.php aqui: ese archivo arranca su PROPIA
// sesion (PHISHLAB_LAB) y su propia CSP, pensadas para lab.eduolihez.com --
// incluirlo en una peticion que ya tiene la sesion/CSP del panel de admin
// abierta chocaria con las dos. Se duplican las constantes (mismo valor,
// comentario cruzado) en vez de compartir el archivo.
const LAB_MIN_PASSWORD = 12;
const LAB_LOGIN_MAX_ATTEMPTS    = 5;  // debe coincidir con server/lab/auth.php
const LAB_LOGIN_LOCKOUT_MINUTES = 15; // debe coincidir con server/lab/auth.php

// --- Acciones (POST) --------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');

    if ($action === 'create') {
        $username = trim((string) ($_POST['username'] ?? ''));
        $password = (string) ($_POST['password'] ?? '');
        $errors   = [];

        if ($username === '' || !preg_match('/^[a-zA-Z0-9_.-]{3,60}$/', $username)) {
            $errors[] = 'Usuario inválido: 3-60 caracteres, solo letras, números, punto, guion o guion bajo.';
        }
        if (mb_strlen($password) < LAB_MIN_PASSWORD) {
            $errors[] = 'La contraseña debe tener al menos ' . LAB_MIN_PASSWORD . ' caracteres.';
        }

        if (!$errors) {
            try {
                db()->prepare(
                    'INSERT INTO lab_users (username, password_hash, active, lockout_enabled) VALUES (?, ?, 1, 1)'
                )->execute([$username, password_hash($password, PASSWORD_DEFAULT)]);
                log_activity('create', 'lab_user', (int) db()->lastInsertId(), 'Usuario lab creado: ' . $username);
                set_flash('ok', 'Usuario "' . $username . '" creado.');
            } catch (Throwable $e) {
                set_flash('err', 'No se pudo crear el usuario. ¿Ese nombre ya existe?');
            }
        } else {
            set_flash('err', implode(' ', $errors));
        }
        redirect('lab-users.php');
    }

    $id = (int) ($_POST['id'] ?? 0);
    if ($id > 0) {
        $st = db()->prepare('SELECT * FROM lab_users WHERE id = ?');
        $st->execute([$id]);
        $row = $st->fetch();

        if ($row) {
            switch ($action) {
                case 'toggle_active':
                    $newValue = $row['active'] ? 0 : 1;
                    db()->prepare('UPDATE lab_users SET active = ? WHERE id = ?')->execute([$newValue, $id]);
                    log_activity('update', 'lab_user', $id, ($newValue ? 'Activado' : 'Desactivado') . ': ' . $row['username']);
                    set_flash('ok', 'Usuario ' . ($newValue ? 'activado' : 'desactivado') . '.');
                    break;

                case 'toggle_lockout':
                    $newValue = $row['lockout_enabled'] ? 0 : 1;
                    db()->prepare('UPDATE lab_users SET lockout_enabled = ? WHERE id = ?')->execute([$newValue, $id]);
                    log_activity('update', 'lab_user', $id, 'Bloqueo por intentos ' . ($newValue ? 'activado' : 'desactivado') . ': ' . $row['username']);
                    set_flash('ok', 'Bloqueo por fuerza bruta ' . ($newValue ? 'activado' : 'desactivado') . ' para "' . $row['username'] . '".');
                    break;

                case 'reset_password':
                    $newPass = (string) ($_POST['password'] ?? '');
                    if (mb_strlen($newPass) < LAB_MIN_PASSWORD) {
                        set_flash('err', 'La nueva contraseña debe tener al menos ' . LAB_MIN_PASSWORD . ' caracteres.');
                    } else {
                        db()->prepare('UPDATE lab_users SET password_hash = ? WHERE id = ?')
                            ->execute([password_hash($newPass, PASSWORD_DEFAULT), $id]);
                        log_activity('update', 'lab_user', $id, 'Contraseña restablecida: ' . $row['username']);
                        set_flash('ok', 'Contraseña actualizada para "' . $row['username'] . '".');
                    }
                    break;

                case 'unlock':
                    db()->prepare('DELETE FROM lab_login_attempts WHERE username = ? AND success = 0')
                        ->execute([$row['username']]);
                    log_activity('unblock', 'lab_user', $id, 'Desbloqueado manualmente: ' . $row['username']);
                    set_flash('ok', 'Cuenta "' . $row['username'] . '" desbloqueada.');
                    break;

                case 'delete':
                    db()->prepare('DELETE FROM lab_users WHERE id = ?')->execute([$id]);
                    log_activity('delete', 'lab_user', $id, 'Usuario lab eliminado: ' . $row['username']);
                    set_flash('ok', 'Usuario eliminado.');
                    break;
            }
        }
        redirect('lab-users.php');
    }
}

// --- Datos --------------------------------------------------------------
try {
    $users = db()->query('SELECT * FROM lab_users ORDER BY created_at ASC')->fetchAll();
} catch (Throwable $e) {
    $users = [];
}

// Cuentas bloqueadas AHORA MISMO por fallos recientes (independiente de si
// lockout_enabled las libra o no: se muestra el dato igual, pero el aviso
// deja claro cuando ese bloqueo no está aplicando).
$lockedNow = [];
try {
    $rows = db()->query(
        'SELECT username, COUNT(*) AS fails FROM lab_login_attempts
         WHERE success = 0 AND attempted_at > (NOW() - INTERVAL ' . LAB_LOGIN_LOCKOUT_MINUTES . ' MINUTE)
         GROUP BY username HAVING fails >= ' . LAB_LOGIN_MAX_ATTEMPTS
    )->fetchAll();
    foreach ($rows as $r) {
        $lockedNow[$r['username']] = (int) $r['fails'];
    }
} catch (Throwable $e) {
    // tabla aun no migrada: se ve todo como no bloqueado
}

admin_header('PhishLab · Usuarios', 'lab-users.php');
show_flash();
?>
<div class="toolbar">
  <h1 style="margin:0;">PhishLab · Usuarios de <code>lab.eduolihez.com</code>
    <span class="faint" style="font-size:1rem;">(<?= count($users) ?>)</span></h1>
</div>
<p class="hint" style="margin-top:-1rem; margin-bottom:1.5rem;">
  Cuentas con acceso a la herramienta completa de PhishLab (marca real, exportación
  activa). Bloqueo automático tras <?= LAB_LOGIN_MAX_ATTEMPTS ?> intentos fallidos en
  <?= LAB_LOGIN_LOCKOUT_MINUTES ?> minutos — desactivable por cuenta con el interruptor
  "Bloqueo".
</p>

<h2>Nuevo usuario</h2>
<form method="post" class="card" style="max-width:520px;" autocomplete="off">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="create">

  <label for="username">Usuario</label>
  <input type="text" id="username" name="username" required pattern="[a-zA-Z0-9_.-]{3,60}"
         placeholder="p.ej. cliente-acme">

  <label for="password">Contraseña</label>
  <input type="password" id="password" name="password" required minlength="<?= LAB_MIN_PASSWORD ?>"
         autocomplete="new-password">
  <div class="hint">Mínimo <?= LAB_MIN_PASSWORD ?> caracteres. Compártela por un canal
    aparte de este panel.</div>

  <div style="margin-top:1.4rem;">
    <button type="submit" class="btn">Crear usuario</button>
  </div>
</form>

<h2 style="margin-top:2rem;">Cuentas</h2>
<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead>
        <tr>
          <th>Usuario</th>
          <th>Estado</th>
          <th>Bloqueo</th>
          <th>Último acceso</th>
          <th>Creado</th>
          <th style="text-align:right;">Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (!$users): ?>
          <tr><td colspan="6" class="empty">Aún no hay cuentas de PhishLab lab.</td></tr>
        <?php endif; ?>
        <?php foreach ($users as $u): ?>
          <?php $blocked = ($lockedNow[$u['username']] ?? 0) >= LAB_LOGIN_MAX_ATTEMPTS; ?>
          <tr>
            <td class="mono"><strong><?= e($u['username']) ?></strong></td>
            <td>
              <span class="pill <?= $u['active'] ? 'on' : 'danger' ?>">
                <?= $u['active'] ? 'Activa' : 'Desactivada' ?>
              </span>
              <?php if ($blocked): ?>
                <div class="faint" style="font-size:.75rem;">
                  <span class="pill danger" style="margin-top:.25rem;">Bloqueada ahora</span>
                  <?= $u['lockout_enabled'] ? '' : ' (el interruptor está apagado, así que no le afecta)' ?>
                </div>
              <?php endif; ?>
            </td>
            <td>
              <span class="pill <?= $u['lockout_enabled'] ? 'on' : '' ?>">
                <?= $u['lockout_enabled'] ? 'Activado' : 'Desactivado' ?>
              </span>
            </td>
            <td class="faint nowrap"><?= e(ago($u['last_login'])) ?></td>
            <td class="faint nowrap"><?= e(fdate($u['created_at'])) ?></td>
            <td>
              <div class="actions" style="justify-content:flex-end; flex-wrap:wrap;">
                <form method="post" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="toggle_active">
                  <input type="hidden" name="id" value="<?= (int) $u['id'] ?>">
                  <button type="submit" class="btn ghost sm"><?= $u['active'] ? 'Desactivar' : 'Activar' ?></button>
                </form>
                <form method="post" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="toggle_lockout">
                  <input type="hidden" name="id" value="<?= (int) $u['id'] ?>">
                  <button type="submit" class="btn ghost sm">
                    <?= $u['lockout_enabled'] ? 'Desactivar bloqueo' : 'Activar bloqueo' ?>
                  </button>
                </form>
                <?php if ($blocked): ?>
                  <form method="post" data-confirm="¿Desbloquear a &quot;<?= e($u['username']) ?>&quot; ahora?" style="display:inline;">
                    <?= csrf_field() ?>
                    <input type="hidden" name="action" value="unlock">
                    <input type="hidden" name="id" value="<?= (int) $u['id'] ?>">
                    <button type="submit" class="btn ghost sm">Desbloquear</button>
                  </form>
                <?php endif; ?>
                <button type="button" class="btn ghost sm" onclick="document.getElementById('pw-<?= (int) $u['id'] ?>').hidden = !document.getElementById('pw-<?= (int) $u['id'] ?>').hidden;">
                  Cambiar contraseña
                </button>
                <form method="post" data-confirm="¿Eliminar a &quot;<?= e($u['username']) ?>&quot;? No se puede deshacer." style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="delete">
                  <input type="hidden" name="id" value="<?= (int) $u['id'] ?>">
                  <button type="submit" class="btn danger sm">Borrar</button>
                </form>
              </div>
              <form method="post" id="pw-<?= (int) $u['id'] ?>" hidden style="margin-top:.6rem; text-align:right;">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="reset_password">
                <input type="hidden" name="id" value="<?= (int) $u['id'] ?>">
                <input type="password" name="password" placeholder="Nueva contraseña (mín. <?= LAB_MIN_PASSWORD ?>)"
                       minlength="<?= LAB_MIN_PASSWORD ?>" autocomplete="new-password" style="width:220px;">
                <button type="submit" class="btn ghost sm">Guardar</button>
              </form>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<p class="hint">El bloqueo por fuerza bruta también cuenta por IP, aunque el
  interruptor de una cuenta esté apagado — sigue frenando ataques automatizados
  desde un mismo origen contra cualquier usuario.</p>

<?php admin_footer(); ?>
