<?php
/**
 * apps.php - Registro de apps para admin.eduolihez.com
 * (docs/designs/admin-dashboard.md). Cada fila es un proyecto con su propio
 * sub-dashboard (eduolihez.com hoy, BloomGram y los que vengan despues) y su
 * propia clave de API para reportar a server/api/events.php.
 *
 * La clave se genera/rota aqui y se ensena UNA SOLA VEZ, justo tras
 * generarla, en su propia tarjeta con copiado automatico al portapapeles
 * (ver $newApiKey mas abajo) -- misma idea de un solo uso que el flash de
 * sesion normal (set_flash()/show_flash()), pero fuera de ese mecanismo
 * porque el flash se imprime escapado como texto plano, sin boton de copiar.
 * Nunca se guarda en claro en la base de datos -- solo su SHA-256 en
 * apps.api_key_hash.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_login();

/** Genera una clave de API nueva (32 bytes aleatorios en hex) y su hash SHA-256. */
function generate_api_key(): array
{
    $raw = bin2hex(random_bytes(32));
    return [$raw, hash('sha256', $raw)];
}

// --- Acciones (POST) --------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');
    $id     = (int) ($_POST['id'] ?? 0);

    if ($id > 0) {
        $st = db()->prepare('SELECT * FROM apps WHERE id = ?');
        $st->execute([$id]);
        $row = $st->fetch();

        if ($row) {
            switch ($action) {
                case 'delete':
                    // No borra app_events asociados a proposito: son datos
                    // historicos de telemetria, no metadatos de la app en si.
                    // Si hace falta limpiarlos, es una accion aparte y
                    // deliberada, no un efecto secundario de borrar el registro.
                    db()->prepare('DELETE FROM apps WHERE id = ?')->execute([$id]);
                    log_activity('delete', 'app', $id, 'App: ' . $row['display_name']);
                    set_flash('ok', 'App eliminada. Los eventos ya recibidos se conservan.');
                    break;

                case 'generate_key':
                    [$rawKey, $hash] = generate_api_key();
                    db()->prepare('UPDATE apps SET api_key_hash = ?, key_rotated_at = NOW() WHERE id = ?')
                        ->execute([$hash, $id]);
                    log_activity('update', 'app', $id, 'Clave de API generada/rotada para: ' . $row['display_name']);
                    // La clave en claro NO va en el flash normal (se imprime
                    // escapada como texto plano ahi, sin boton de copiar).
                    // Va en su propia variable de sesion, de un solo uso, para
                    // poder pintarla en una tarjeta con copia automatica.
                    $_SESSION['new_api_key'] = ['app' => $row['display_name'], 'key' => $rawKey];
                    set_flash('ok', 'Nueva clave generada para "' . $row['display_name'] . '".');
                    break;
            }
        }
    }
    redirect('apps.php');
}

// --- Listado ------------------------------------------------------------
$rows = db()->query(
    'SELECT id, slug, display_name, has_content, api_key_hash, allowed_origins, key_rotated_at, created_at
     FROM apps ORDER BY created_at ASC'
)->fetchAll();

admin_header('Apps', 'apps.php');
show_flash();

// Revelado de un solo uso: se lee y se borra de sesion en la misma peticion
// que la pinta, igual que el flash normal (ver set_flash()/show_flash()) --
// un F5 despues de verla ya no la vuelve a mostrar.
$newApiKey = $_SESSION['new_api_key'] ?? null;
unset($_SESSION['new_api_key']);
if ($newApiKey):
?>
<div class="card" style="border-color: var(--warn); background: var(--warn-soft);">
  <h3 style="color: var(--warn); margin-bottom: .5rem;">Clave de API para "<?= e($newApiKey['app']) ?>"</h3>
  <p class="hint" style="margin-top: 0;">Cópiala ahora: no se volverá a mostrar. Se copia sola al portapapeles.</p>
  <div class="copy-row">
    <input type="text" id="new-api-key-value" readonly value="<?= e($newApiKey['key']) ?>"
           data-autocopy onclick="this.select()">
    <button type="button" class="btn sm" data-copy="#new-api-key-value">Copiar</button>
  </div>
</div>
<?php endif; ?>
<?php page_header('Apps', '', '<a class="btn" href="app-edit.php">+ Nueva app</a>', '(' . count($rows) . ')'); ?>
<p class="hint" style="margin-top:-1rem; margin-bottom:1.5rem;">
  Cada app tiene su propio sub-dashboard en <code>admin.eduolihez.com</code> y su propia
  clave para reportar eventos a <code>api.eduolihez.com</code>.
  Ver <code>docs/designs/admin-dashboard.md</code>.
</p>

<div class="card p-0">
  <div class="scroll-x">
    <table>
      <thead>
        <tr>
          <th>App</th>
          <th>Slug</th>
          <th>Contenido</th>
          <th>Clave de API</th>
          <th>Orígenes permitidos</th>
          <th>Creada</th>
          <th class="text-right">Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (!$rows): ?>
          <tr><td colspan="7" class="empty">Aún no hay apps registradas.</td></tr>
        <?php endif; ?>
        <?php foreach ($rows as $a): ?>
          <?php $origins = json_decode((string) ($a['allowed_origins'] ?? '[]'), true) ?: []; ?>
          <tr>
            <td><strong><?= e($a['display_name']) ?></strong></td>
            <td class="mono faint"><?= e($a['slug']) ?></td>
            <td><span class="pill <?= $a['has_content'] ? 'on' : '' ?>"><?= $a['has_content'] ? 'Sí' : 'Solo analítica' ?></span></td>
            <td>
              <?php if ($a['api_key_hash']): ?>
                <span class="pill on">Configurada</span>
                <?php if ($a['key_rotated_at']): ?>
                  <div class="faint" style="font-size:.75rem;">rotada <?= e(ago($a['key_rotated_at'])) ?></div>
                <?php endif; ?>
              <?php else: ?>
                <span class="pill warn">Sin generar</span>
              <?php endif; ?>
            </td>
            <td class="faint"><?= $origins ? (string) count($origins) : '—' ?></td>
            <td class="faint nowrap"><?= e(fdate($a['created_at'])) ?></td>
            <td>
              <div class="actions justify-end">
                <a class="btn ghost sm" href="analytics.php?space=<?= e(urlencode(space_for_app_slug((string) $a['slug']))) ?>">Analitica</a>
                <a class="btn ghost sm" href="app-edit.php?id=<?= (int) $a['id'] ?>">Editar</a>
                <form method="post"
                      data-confirm="<?= e($a['api_key_hash'] ? '¿Rotar la clave? La anterior dejará de funcionar al instante.' : '¿Generar clave de API para esta app?') ?>"
                      class="d-inline">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="generate_key">
                  <input type="hidden" name="id" value="<?= (int) $a['id'] ?>">
                  <button type="submit" class="btn ghost sm"><?= $a['api_key_hash'] ? 'Rotar clave' : 'Generar clave' ?></button>
                </form>
                <form method="post" data-confirm="¿Eliminar esta app? Los eventos ya recibidos se conservan." class="d-inline">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="delete">
                  <input type="hidden" name="id" value="<?= (int) $a['id'] ?>">
                  <button type="submit" class="btn danger sm">Borrar</button>
                </form>
              </div>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>

<?php admin_footer(); ?>
