<?php
/**
 * apps.php - Registro de apps para admin.eduolihez.com
 * (docs/designs/admin-dashboard.md). Cada fila es un proyecto con su propio
 * sub-dashboard (eduolihez.com hoy, BloomGram y los que vengan despues) y su
 * propia clave de API para reportar a server/api/events.php.
 *
 * La clave se genera/rota aqui y se ensena UNA SOLA VEZ, justo tras
 * generarla, via el flash de sesion normal (mismo mecanismo que cualquier
 * otro aviso de esta pagina: se lee y se borra de $_SESSION en la misma
 * peticion que la pinta). Nunca se guarda en claro en la base de datos --
 * solo su SHA-256 en apps.api_key_hash.
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
                    set_flash('ok', 'Nueva clave para "' . $row['display_name'] . '": '
                        . $rawKey . ' — cópiala ahora, no se volverá a mostrar.');
                    break;
            }
        }
    }
    redirect('apps.php');
}

// --- Listado ------------------------------------------------------------
$rows = db()->query(
    'SELECT id, slug, display_name, api_key_hash, allowed_origins, key_rotated_at, created_at
     FROM apps ORDER BY created_at ASC'
)->fetchAll();

admin_header('Apps', 'apps.php');
show_flash();
?>
<div class="subdash">
<div class="toolbar">
  <h1 style="margin:0;">Apps <span class="faint" style="font-size:1rem;">(<?= count($rows) ?>)</span></h1>
  <a class="btn" href="app-edit.php">+ Nueva app</a>
</div>
<p class="hint" style="margin-top:-1rem; margin-bottom:1.5rem;">
  Cada app tiene su propio sub-dashboard en <code>admin.eduolihez.com</code> y su propia
  clave para reportar eventos a <code>api.eduolihez.com</code>.
  Ver <code>docs/designs/admin-dashboard.md</code>.
</p>

<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead>
        <tr>
          <th>App</th>
          <th>Slug</th>
          <th>Clave de API</th>
          <th>Orígenes permitidos</th>
          <th>Creada</th>
          <th style="text-align:right;">Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (!$rows): ?>
          <tr><td colspan="6" class="empty">Aún no hay apps registradas.</td></tr>
        <?php endif; ?>
        <?php foreach ($rows as $a): ?>
          <?php $origins = json_decode((string) ($a['allowed_origins'] ?? '[]'), true) ?: []; ?>
          <tr>
            <td><strong><?= e($a['display_name']) ?></strong></td>
            <td class="mono faint"><?= e($a['slug']) ?></td>
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
              <div class="actions" style="justify-content:flex-end;">
                <a class="btn ghost sm" href="analytics.php?app=<?= rawurlencode($a['slug']) ?>">Analitica</a>
                <a class="btn ghost sm" href="app-edit.php?id=<?= (int) $a['id'] ?>">Editar</a>
                <form method="post"
                      data-confirm="<?= e($a['api_key_hash'] ? '¿Rotar la clave? La anterior dejará de funcionar al instante.' : '¿Generar clave de API para esta app?') ?>"
                      style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="generate_key">
                  <input type="hidden" name="id" value="<?= (int) $a['id'] ?>">
                  <button type="submit" class="btn ghost sm"><?= $a['api_key_hash'] ? 'Rotar clave' : 'Generar clave' ?></button>
                </form>
                <form method="post" data-confirm="¿Eliminar esta app? Los eventos ya recibidos se conservan." style="display:inline;">
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

</div><!-- /.subdash -->
<?php admin_footer(); ?>
