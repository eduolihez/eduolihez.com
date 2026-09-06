<?php
/**
 * security.php - Centro de seguridad del panel.
 *
 *   - Estado de la configuracion (revision automatica).
 *   - Cambio de contrasena del administrador.
 *   - IPs bloqueadas ahora mismo por fuerza bruta (con desbloqueo manual).
 *   - Historial de intentos de acceso.
 *   - Registro de auditoria completo de las acciones del panel.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_login();

$maxAttempts = (int) (config()['security']['login_max_attempts'] ?? 5);
$lockMinutes = (int) (config()['security']['login_lockout_minutes'] ?? 15);
$pwErrors = [];

/** SELECT tolerante a fallos. */
function s_rows(string $sql, array $params = []): array
{
    try {
        $st = db()->prepare($sql);
        $st->execute($params);
        return $st->fetchAll();
    } catch (Throwable $e) {
        return [];
    }
}

// --- Acciones (POST) --------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');

    // Cambio de contrasena.
    if ($action === 'password') {
        $current = (string) ($_POST['current_password'] ?? '');
        $new     = (string) ($_POST['new_password'] ?? '');
        $confirm = (string) ($_POST['confirm_password'] ?? '');

        $st = db()->prepare('SELECT password_hash FROM admin_users WHERE id = ?');
        $st->execute([(int) $_SESSION['admin_id']]);
        $hash = (string) $st->fetchColumn();

        if (!password_verify($current, $hash)) {
            $pwErrors[] = 'La contrasena actual no es correcta.';
        }
        if (mb_strlen($new) < 12) {
            $pwErrors[] = 'La nueva contrasena debe tener al menos 12 caracteres.';
        }
        if ($new !== $confirm) {
            $pwErrors[] = 'La confirmacion no coincide.';
        }
        if ($new !== '' && $new === $current) {
            $pwErrors[] = 'La nueva contrasena debe ser distinta de la actual.';
        }

        if (!$pwErrors) {
            db()->prepare('UPDATE admin_users SET password_hash = ? WHERE id = ?')
                ->execute([password_hash($new, PASSWORD_DEFAULT), (int) $_SESSION['admin_id']]);

            // Renovamos el identificador de sesion: si alguien te habia robado
            // la cookie, deja de servirle.
            session_regenerate_id(true);
            log_activity('password_change', 'admin_user', (int) $_SESSION['admin_id'], 'Contrasena actualizada');
            set_flash('ok', 'Contrasena actualizada correctamente.');
            redirect('security.php');
        }
    }

    // Desbloquear una IP (borra sus intentos fallidos).
    if ($action === 'unblock') {
        $ip = (string) ($_POST['ip'] ?? '');
        if (filter_var($ip, FILTER_VALIDATE_IP)) {
            db()->prepare('DELETE FROM login_attempts WHERE ip_address = ? AND success = 0')->execute([$ip]);
            log_activity('unblock', 'ip', null, 'IP desbloqueada: ' . $ip);
            set_flash('ok', 'IP desbloqueada: ' . $ip);
        }
        redirect('security.php');
    }

    // Vaciar el historial de intentos de acceso.
    if ($action === 'clear_attempts') {
        db()->query('DELETE FROM login_attempts');
        log_activity('delete', 'login_attempts', null, 'Historial de accesos vaciado');
        set_flash('ok', 'Historial de intentos de acceso vaciado.');
        redirect('security.php');
    }
}

// --- Datos ------------------------------------------------------------------
$blocked = s_rows(
    "SELECT ip_address, COUNT(*) AS fails, MAX(attempted_at) AS last_try
     FROM login_attempts
     WHERE success = 0 AND attempted_at > (NOW() - INTERVAL ? MINUTE)
     GROUP BY ip_address
     HAVING fails >= ?
     ORDER BY last_try DESC",
    [$lockMinutes, $maxAttempts]
);

$attempts = s_rows(
    'SELECT ip_address, username, success, attempted_at
     FROM login_attempts ORDER BY attempted_at DESC LIMIT 40'
);

$activity = s_rows(
    'SELECT action, entity, entity_id, details, username, ip_address, created_at
     FROM activity_log ORDER BY created_at DESC LIMIT 60'
);

$stats = [
    'fails_24h'  => (int) (s_rows('SELECT COUNT(*) AS c FROM login_attempts WHERE success=0 AND attempted_at > (NOW() - INTERVAL 1 DAY)')[0]['c'] ?? 0),
    'fails_7d'   => (int) (s_rows('SELECT COUNT(*) AS c FROM login_attempts WHERE success=0 AND attempted_at > (NOW() - INTERVAL 7 DAY)')[0]['c'] ?? 0),
    'ok_30d'     => (int) (s_rows('SELECT COUNT(*) AS c FROM login_attempts WHERE success=1 AND attempted_at > (NOW() - INTERVAL 30 DAY)')[0]['c'] ?? 0),
];

$admin = s_rows('SELECT username, last_login, created_at FROM admin_users WHERE id = ?', [(int) $_SESSION['admin_id']])[0] ?? [];

// --- Revision automatica de la configuracion --------------------------------
$cfg = config();
$isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
    || strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
$salt = (string) ($cfg['security']['ip_salt'] ?? '');

$checks = [
    ['Modo debug desactivado', empty($cfg['debug']),
     'Con debug activo, cualquier error muestra rutas internas del servidor.'],
    ['Panel servido por HTTPS', $isHttps,
     'Sin HTTPS, tu usuario y contrasena viajan en texto plano.'],
    ['setup.php eliminado del servidor', !is_file(__DIR__ . '/setup.php'),
     'Ya no puede crear usuarios, pero es un archivo innecesario expuesto.'],
    ['Sal de hasheo de IPs personalizada', $salt !== '' && !str_starts_with($salt, 'CAMBIA_ESTO') && strlen($salt) >= 24,
     'La sal debe ser larga y unica: protege las IPs de tus visitantes.'],
    ['Bloqueo por fuerza bruta activo', $maxAttempts > 0 && $maxAttempts <= 10,
     'Limita los intentos de acceso desde una misma IP.'],
    ['Version de PHP soportada', version_compare(PHP_VERSION, '8.1', '>='),
     'Las versiones antiguas dejan de recibir parches de seguridad.'],
    ['Confianza en proxy coherente con Cloudflare', !empty($cfg['security']['trust_proxy']),
     'Con Cloudflare delante, trust_proxy debe estar a true para ver la IP real del visitante.'],
    ['Turnstile configurado (opcional)', !empty($cfg['turnstile']['secret_key']),
     'Es opcional: el honeypot y el rate-limit ya frenan la mayoria del spam.'],
];

admin_header('Seguridad', 'security.php');
show_flash();
?>
<h1>Seguridad</h1>

<div class="grid4">
  <div class="card stat">
    <div class="num <?= count($blocked) > 0 ? 'danger' : '' ?>"><?= count($blocked) ?></div>
    <div class="lbl">IPs bloqueadas ahora<br><span class="faint">ventana de <?= $lockMinutes ?> min</span></div>
  </div>
  <div class="card stat">
    <div class="num warn"><?= number_format($stats['fails_24h']) ?></div>
    <div class="lbl">Intentos fallidos (24 h)</div>
  </div>
  <div class="card stat">
    <div class="num warn"><?= number_format($stats['fails_7d']) ?></div>
    <div class="lbl">Intentos fallidos (7 dias)</div>
  </div>
  <div class="card stat">
    <div class="num"><?= number_format($stats['ok_30d']) ?></div>
    <div class="lbl">Accesos correctos (30 d)<br><span class="faint">ultimo: <?= e(ago($admin['last_login'] ?? null)) ?></span></div>
  </div>
</div>

<h2>Revision de la configuracion</h2>
<div class="card" style="padding:0;">
  <table>
    <tbody>
      <?php foreach ($checks as [$label, $ok, $why]): ?>
        <tr>
          <td style="width:90px;">
            <span class="pill <?= $ok ? 'on' : 'warn' ?>"><?= $ok ? 'OK' : 'Revisar' ?></span>
          </td>
          <td>
            <strong><?= e($label) ?></strong>
            <?php if (!$ok): ?><div class="faint"><?= e($why) ?></div><?php endif; ?>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>
<p class="hint">Estas comprobaciones leen <code>server/config.php</code> y el entorno del servidor.
  Los valores se cambian en ese archivo por FTP.</p>

<h2>Cambiar contrasena</h2>
<?php if ($pwErrors): ?>
  <div class="flash err"><?= e(implode(' ', $pwErrors)) ?></div>
<?php endif; ?>
<form method="post" class="card" style="max-width:520px;" autocomplete="off">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="password">

  <label for="current_password">Contrasena actual</label>
  <input type="password" id="current_password" name="current_password" required autocomplete="current-password">

  <label for="new_password">Nueva contrasena</label>
  <input type="password" id="new_password" name="new_password" required minlength="12" autocomplete="new-password">
  <div class="hint">Minimo 12 caracteres. Usa una frase larga o un gestor de contrasenas.</div>

  <label for="confirm_password">Repite la nueva contrasena</label>
  <input type="password" id="confirm_password" name="confirm_password" required minlength="12" autocomplete="new-password">

  <div style="margin-top:1.4rem;">
    <button type="submit" class="btn">Actualizar contrasena</button>
  </div>
</form>

<h2>IPs bloqueadas ahora mismo</h2>
<div class="card" style="padding:0;">
  <table>
    <thead><tr><th>IP</th><th>Fallos</th><th>Ultimo intento</th><th style="text-align:right;">Accion</th></tr></thead>
    <tbody>
      <?php if (!$blocked): ?>
        <tr><td colspan="4" class="empty">Ninguna IP bloqueada. Todo tranquilo.</td></tr>
      <?php endif; ?>
      <?php foreach ($blocked as $b): ?>
        <tr>
          <td class="mono"><?= e($b['ip_address']) ?></td>
          <td><span class="pill danger"><?= (int) $b['fails'] ?></span></td>
          <td class="faint"><?= e(fdate($b['last_try'])) ?> · <?= e(ago($b['last_try'])) ?></td>
          <td>
            <div class="actions" style="justify-content:flex-end;">
              <form method="post" data-confirm="¿Desbloquear esta IP?" style="display:inline;">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="unblock">
                <input type="hidden" name="ip" value="<?= e($b['ip_address']) ?>">
                <button type="submit" class="btn ghost sm">Desbloquear</button>
              </form>
            </div>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>
<p class="hint">Una IP se bloquea tras <?= $maxAttempts ?> intentos fallidos y se libera
  sola pasados <?= $lockMinutes ?> minutos. Si te has bloqueado tu mismo desde otra red,
  puedes desbloquearte aqui.</p>

<div class="toolbar" style="margin-top:1.75rem;">
  <h2 style="margin:0;">Intentos de acceso recientes</h2>
  <form method="post" data-confirm="¿Vaciar todo el historial de intentos de acceso?" style="display:inline;">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="clear_attempts">
    <button type="submit" class="btn ghost sm">Vaciar historial</button>
  </form>
</div>
<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead><tr><th>Resultado</th><th>Usuario probado</th><th>IP</th><th>Cuando</th></tr></thead>
      <tbody>
        <?php if (!$attempts): ?>
          <tr><td colspan="4" class="empty">Sin registros.</td></tr>
        <?php endif; ?>
        <?php foreach ($attempts as $a): ?>
          <tr>
            <td><span class="pill <?= $a['success'] ? 'on' : 'danger' ?>"><?= $a['success'] ? 'Correcto' : 'Fallido' ?></span></td>
            <td class="mono"><?= e($a['username'] !== '' ? $a['username'] : '—') ?></td>
            <td class="mono faint"><?= e($a['ip_address']) ?></td>
            <td class="faint nowrap"><?= e(fdate($a['attempted_at'])) ?> · <?= e(ago($a['attempted_at'])) ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>

<h2>Registro de auditoria</h2>
<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead><tr><th>Accion</th><th>Detalle</th><th>Usuario</th><th>IP</th><th>Cuando</th></tr></thead>
      <tbody>
        <?php if (!$activity): ?>
          <tr><td colspan="5" class="empty">Aun no hay acciones registradas. Se anotan a partir de ahora.</td></tr>
        <?php endif; ?>
        <?php foreach ($activity as $a): ?>
          <tr>
            <td><span class="pill"><?= e($a['action']) ?></span></td>
            <td>
              <?= e($a['details'] !== '' ? $a['details'] : '—') ?>
              <?php if ($a['entity']): ?>
                <div class="faint"><?= e($a['entity']) ?><?= $a['entity_id'] ? ' #' . (int) $a['entity_id'] : '' ?></div>
              <?php endif; ?>
            </td>
            <td class="mono faint"><?= e($a['username'] ?? '—') ?></td>
            <td class="mono faint"><?= e($a['ip_address'] ?? '—') ?></td>
            <td class="faint nowrap"><?= e(fdate($a['created_at'])) ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<p class="hint">Los registros de auditoria se conservan 365 dias y los intentos de
  acceso 90; despues se purgan solos.</p>

<?php admin_footer(); ?>
