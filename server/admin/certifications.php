<?php
/**
 * certifications.php - Listado de certificaciones.
 * Mismas comodidades que el listado de proyectos: buscar, mostrar/ocultar de
 * un clic, reordenar, duplicar y borrar (limpiando el logo subido).
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/upload.php';
require_login();

$search = mb_substr(trim((string) ($_GET['q'] ?? '')), 0, 80);
$back   = 'certifications.php' . ($search !== '' ? '?q=' . urlencode($search) : '');

// --- Acciones (POST) --------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');
    $id     = (int) ($_POST['id'] ?? 0);

    if ($id > 0) {
        $st = db()->prepare('SELECT * FROM certifications WHERE id = ?');
        $st->execute([$id]);
        $row = $st->fetch();

        if ($row) {
            switch ($action) {
                case 'delete':
                    db()->prepare('DELETE FROM certifications WHERE id = ?')->execute([$id]);
                    delete_upload($row['logo_url'] ?? null);
                    log_activity('delete', 'certification', $id, 'Certificacion: ' . $row['name']);
                    set_flash('ok', 'Certificacion eliminada.');
                    break;

                case 'toggle_visible':
                    $new = ((int) $row['visible']) === 1 ? 0 : 1;
                    db()->prepare('UPDATE certifications SET visible = ? WHERE id = ?')->execute([$new, $id]);
                    log_activity('update', 'certification', $id, $new ? 'Visible' : 'Oculta');
                    set_flash('ok', $new ? 'Certificacion visible en la web.' : 'Certificacion oculta.');
                    break;

                case 'move_up':
                case 'move_down':
                    normalize_sort_order('certifications');
                    // Con placeholder, como el resto del archivo. El cast a
                    // entero que habia antes ya impedia la inyeccion, pero era
                    // el unico sitio que concatenaba dentro del SQL.
                    $stCur = db()->prepare('SELECT sort_order FROM certifications WHERE id = ?');
                    $stCur->execute([$id]);
                    $cur = (int) $stCur->fetchColumn();

                    $up = $action === 'move_up';
                    $nb = db()->prepare(
                        'SELECT id, sort_order FROM certifications WHERE sort_order ' . ($up ? '<' : '>') . ' ?
                         ORDER BY sort_order ' . ($up ? 'DESC' : 'ASC') . ' LIMIT 1'
                    );
                    $nb->execute([$cur]);
                    $neighbour = $nb->fetch();

                    if ($neighbour) {
                        $upd = db()->prepare('UPDATE certifications SET sort_order = ? WHERE id = ?');
                        $upd->execute([(int) $neighbour['sort_order'], $id]);
                        $upd->execute([$cur, (int) $neighbour['id']]);
                        set_flash('ok', 'Orden actualizado.');
                    } else {
                        set_flash('warn', 'Ya esta en el extremo de la lista.');
                    }
                    break;

                case 'duplicate':
                    db()->prepare(
                        'INSERT INTO certifications (name, issuer, issue_date, credential_url,
                            logo_url, category, visible, sort_order, created_at)
                         SELECT CONCAT(name, " (copia)"), issuer, issue_date, credential_url,
                            logo_url, category, 0, sort_order + 1, NOW()
                         FROM certifications WHERE id = ?'
                    )->execute([$id]);
                    log_activity('create', 'certification', (int) db()->lastInsertId(),
                        'Duplicado de: ' . $row['name']);
                    set_flash('ok', 'Certificacion duplicada (oculta). Editala para ajustarla.');
                    break;
            }
        }
    }
    redirect($back);
}

// --- Listado ----------------------------------------------------------------
$params = [];
$where  = '';
if ($search !== '') {
    $where  = 'WHERE name LIKE ? OR issuer LIKE ? OR category LIKE ?';
    $like   = '%' . str_replace(['%', '_'], ['\%', '\_'], $search) . '%';
    $params = [$like, $like, $like];
}

$st = db()->prepare(
    "SELECT id, name, issuer, issue_date, logo_url, category, credential_url, visible, sort_order
     FROM certifications $where ORDER BY sort_order ASC, id DESC"
);
$st->execute($params);
$rows = $st->fetchAll();

$totalAll = (int) db()->query('SELECT COUNT(*) FROM certifications')->fetchColumn();
$visible  = (int) db()->query('SELECT COUNT(*) FROM certifications WHERE visible=1')->fetchColumn();
$last = count($rows) - 1;

admin_header('Certificaciones', 'certifications.php');
show_flash();
?>
<div class="toolbar">
  <h1 style="margin:0;">Certificaciones <span class="faint" style="font-size:1rem;">(<?= $visible ?> visibles de <?= $totalAll ?>)</span></h1>
  <a class="btn" href="cert-edit.php">+ Nueva certificacion</a>
</div>

<form method="get" class="card" style="display:flex; gap:.6rem; align-items:center; padding:.75rem 1rem;">
  <input type="search" name="q" value="<?= e($search) ?>" placeholder="Buscar por nombre, emisor o categoria..." style="flex:1;">
  <button class="btn sm" type="submit">Buscar</button>
  <?php if ($search !== ''): ?><a class="btn ghost sm" href="certifications.php">Limpiar</a><?php endif; ?>
</form>

<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead>
        <tr>
          <th style="width:44px;"></th>
          <th>Nombre</th>
          <th>Emisor</th>
          <th>Fecha</th>
          <th>Visible</th>
          <th>Orden</th>
          <th style="text-align:right;">Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (!$rows): ?>
          <tr><td colspan="7" class="empty">
            <?= $search !== '' ? 'Ninguna certificacion coincide con la busqueda.' : 'Aun no hay certificaciones.' ?>
          </td></tr>
        <?php endif; ?>
        <?php foreach ($rows as $i => $c): ?>
          <tr>
            <td>
              <?php if (!empty($c['logo_url'])): ?>
                <img src="<?= e($c['logo_url']) ?>" alt="" width="32" height="32" class="soft-box"
                     style="width:32px; height:32px; object-fit:contain; border-radius:.3rem; border:1px solid var(--border);">
              <?php else: ?>
                <span class="faint">—</span>
              <?php endif; ?>
            </td>
            <td>
              <strong><?= e($c['name']) ?></strong>
              <?php if (!empty($c['category'])): ?>
                <div><span class="pill"><?= e($c['category']) ?></span></div>
              <?php endif; ?>
              <?php if (!empty($c['credential_url'])): ?>
                <div class="faint" style="font-size:.75rem;">Con enlace de verificacion</div>
              <?php endif; ?>
            </td>
            <td class="muted"><?= e($c['issuer']) ?></td>
            <td class="faint"><?= e($c['issue_date']) ?></td>
            <td>
              <form method="post" style="display:inline;">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="toggle_visible">
                <input type="hidden" name="id" value="<?= (int) $c['id'] ?>">
                <button type="submit" class="pill <?= $c['visible'] ? 'on' : 'off' ?>" style="cursor:pointer;" title="Clic para cambiar">
                  <?= $c['visible'] ? 'Visible' : 'Oculta' ?>
                </button>
              </form>
            </td>
            <td class="faint">
              <div class="actions" style="gap:.2rem;">
                <span class="mono"><?= (int) $c['sort_order'] ?></span>
                <form method="post" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="move_up">
                  <input type="hidden" name="id" value="<?= (int) $c['id'] ?>">
                  <button class="btn icon ghost" type="submit" title="Subir" <?= $i === 0 ? 'disabled' : '' ?>>↑</button>
                </form>
                <form method="post" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="move_down">
                  <input type="hidden" name="id" value="<?= (int) $c['id'] ?>">
                  <button class="btn icon ghost" type="submit" title="Bajar" <?= $i === $last ? 'disabled' : '' ?>>↓</button>
                </form>
              </div>
            </td>
            <td>
              <div class="actions" style="justify-content:flex-end;">
                <a class="btn ghost sm" href="cert-edit.php?id=<?= (int) $c['id'] ?>">Editar</a>
                <form method="post" data-confirm="¿Duplicar esta certificacion?" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="duplicate">
                  <input type="hidden" name="id" value="<?= (int) $c['id'] ?>">
                  <button type="submit" class="btn ghost sm">Duplicar</button>
                </form>
                <form method="post" data-confirm="¿Eliminar esta certificacion? Se borrara tambien su logo." style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="delete">
                  <input type="hidden" name="id" value="<?= (int) $c['id'] ?>">
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
