<?php
/**
 * projects.php - Listado de proyectos.
 *
 * Acciones rapidas sin salir de la lista: publicar/despublicar, destacar,
 * subir/bajar en el orden, duplicar y borrar. Busqueda por titulo/stack.
 * Al borrar se elimina tambien la imagen subida (si estaba en /uploads).
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/upload.php';
require_login();

$search = mb_substr(trim((string) ($_GET['q'] ?? '')), 0, 80);
$back   = 'projects.php' . ($search !== '' ? '?q=' . urlencode($search) : '');

// --- Acciones (POST) --------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');
    $id     = (int) ($_POST['id'] ?? 0);

    if ($id > 0) {
        $st = db()->prepare('SELECT * FROM projects WHERE id = ?');
        $st->execute([$id]);
        $row = $st->fetch();

        if ($row) {
            switch ($action) {
                case 'delete':
                    db()->prepare('DELETE FROM projects WHERE id = ?')->execute([$id]);
                    delete_upload($row['image_url'] ?? null); // no dejamos imagenes huerfanas
                    log_activity('delete', 'project', $id, 'Proyecto: ' . $row['title_es']);
                    set_flash('ok', 'Proyecto eliminado.');
                    break;

                case 'toggle_status':
                    $new = $row['status'] === 'published' ? 'draft' : 'published';
                    db()->prepare('UPDATE projects SET status = ?, updated_at = NOW() WHERE id = ?')
                        ->execute([$new, $id]);
                    log_activity('update', 'project', $id, 'Estado -> ' . $new);
                    set_flash('ok', $new === 'published' ? 'Proyecto publicado.' : 'Proyecto pasado a borrador.');
                    break;

                case 'toggle_featured':
                    $new = ((int) $row['featured']) === 1 ? 0 : 1;
                    db()->prepare('UPDATE projects SET featured = ?, updated_at = NOW() WHERE id = ?')
                        ->execute([$new, $id]);
                    log_activity('update', 'project', $id, $new ? 'Destacado' : 'Sin destacar');
                    set_flash('ok', $new ? 'Marcado como destacado.' : 'Ya no es destacado.');
                    break;

                case 'move_up':
                case 'move_down':
                    // Renumeramos 1..N antes de mover. Sin esto, si dos proyectos
                    // comparten el mismo sort_order (p.ej. los dos a 0), el
                    // intercambio no cambiaria nada visible.
                    normalize_sort_order('projects');
                    // Con placeholder, como el resto del archivo. El cast a
                    // entero que habia antes ya impedia la inyeccion, pero era
                    // el unico sitio que concatenaba dentro del SQL.
                    $stCur = db()->prepare('SELECT sort_order FROM projects WHERE id = ?');
                    $stCur->execute([$id]);
                    $cur = (int) $stCur->fetchColumn();

                    $up  = $action === 'move_up';
                    $nb  = db()->prepare(
                        'SELECT id, sort_order FROM projects WHERE sort_order ' . ($up ? '<' : '>') . ' ?
                         ORDER BY sort_order ' . ($up ? 'DESC' : 'ASC') . ' LIMIT 1'
                    );
                    $nb->execute([$cur]);
                    $neighbour = $nb->fetch();

                    if ($neighbour) {
                        $upd = db()->prepare('UPDATE projects SET sort_order = ? WHERE id = ?');
                        $upd->execute([(int) $neighbour['sort_order'], $id]);
                        $upd->execute([$cur, (int) $neighbour['id']]);
                        set_flash('ok', 'Orden actualizado.');
                    } else {
                        set_flash('warn', 'Ya esta en el extremo de la lista.');
                    }
                    break;

                case 'duplicate':
                    db()->prepare(
                        'INSERT INTO projects (title_es, title_en, summary_es, summary_en,
                            description_es, description_en, image_url, stack, repo_url, demo_url,
                            store_url, featured, sort_order, status, created_at, updated_at)
                         SELECT CONCAT(title_es, " (copia)"), title_en, summary_es, summary_en,
                            description_es, description_en, image_url, stack, repo_url, demo_url,
                            store_url, 0, sort_order + 1, "draft", NOW(), NOW()
                         FROM projects WHERE id = ?'
                    )->execute([$id]);
                    $newId = (int) db()->lastInsertId();
                    log_activity('create', 'project', $newId, 'Duplicado de: ' . $row['title_es']);
                    set_flash('ok', 'Proyecto duplicado como borrador. Editalo para ajustarlo.');
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
    $where = 'WHERE title_es LIKE ? OR title_en LIKE ? OR stack LIKE ?';
    $like  = '%' . str_replace(['%', '_'], ['\%', '\_'], $search) . '%';
    $params = [$like, $like, $like];
}

$st = db()->prepare(
    "SELECT id, title_es, image_url, status, featured, sort_order, updated_at
     FROM projects $where
     ORDER BY sort_order ASC, id DESC"
);
$st->execute($params);
$rows = $st->fetchAll();

$totalAll  = (int) db()->query('SELECT COUNT(*) FROM projects')->fetchColumn();
$published = (int) db()->query("SELECT COUNT(*) FROM projects WHERE status='published'")->fetchColumn();
$last = count($rows) - 1;

admin_header('Proyectos', 'projects.php');
show_flash();
?>
<div class="toolbar">
  <h1 style="margin:0;">Proyectos <span class="faint" style="font-size:1rem;">(<?= $published ?> publicados de <?= $totalAll ?>)</span></h1>
  <a class="btn" href="project-edit.php">+ Nuevo proyecto</a>
</div>

<form method="get" class="card" style="display:flex; gap:.6rem; align-items:center; padding:.75rem 1rem;">
  <input type="search" name="q" value="<?= e($search) ?>" placeholder="Buscar por titulo o tecnologia..." style="flex:1;">
  <button class="btn sm" type="submit">Buscar</button>
  <?php if ($search !== ''): ?><a class="btn ghost sm" href="projects.php">Limpiar</a><?php endif; ?>
</form>

<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead>
        <tr>
          <th style="width:56px;"></th>
          <th>Titulo (ES)</th>
          <th>Estado</th>
          <th>Destacado</th>
          <th>Orden</th>
          <th>Actualizado</th>
          <th style="text-align:right;">Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (!$rows): ?>
          <tr><td colspan="7" class="empty">
            <?= $search !== '' ? 'Ningun proyecto coincide con la busqueda.' : 'Aun no hay proyectos. Crea el primero.' ?>
          </td></tr>
        <?php endif; ?>
        <?php foreach ($rows as $i => $p): ?>
          <tr>
            <td>
              <?php if (!empty($p['image_url'])): ?>
                <img src="<?= e($p['image_url']) ?>" alt="" width="48" height="32"
                     style="width:48px; height:32px; object-fit:cover; border-radius:.3rem; border:1px solid var(--border);">
              <?php else: ?>
                <span class="faint">—</span>
              <?php endif; ?>
            </td>
            <td>
              <strong><?= e($p['title_es']) ?></strong>
              <div class="faint">ID <?= (int) $p['id'] ?></div>
            </td>
            <td>
              <form method="post" style="display:inline;">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="toggle_status">
                <input type="hidden" name="id" value="<?= (int) $p['id'] ?>">
                <button type="submit" class="pill <?= $p['status'] === 'published' ? 'on' : 'off' ?>"
                        style="cursor:pointer;" title="Clic para cambiar">
                  <?= $p['status'] === 'published' ? 'Publicado' : 'Borrador' ?>
                </button>
              </form>
            </td>
            <td>
              <form method="post" style="display:inline;">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="toggle_featured">
                <input type="hidden" name="id" value="<?= (int) $p['id'] ?>">
                <button type="submit" class="btn icon ghost" title="Destacar / quitar destacado">
                  <?= $p['featured'] ? '★' : '☆' ?>
                </button>
              </form>
            </td>
            <td class="faint">
              <div class="actions" style="gap:.2rem;">
                <span class="mono"><?= (int) $p['sort_order'] ?></span>
                <form method="post" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="move_up">
                  <input type="hidden" name="id" value="<?= (int) $p['id'] ?>">
                  <button class="btn icon ghost" type="submit" title="Subir" <?= $i === 0 ? 'disabled' : '' ?>>↑</button>
                </form>
                <form method="post" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="move_down">
                  <input type="hidden" name="id" value="<?= (int) $p['id'] ?>">
                  <button class="btn icon ghost" type="submit" title="Bajar" <?= $i === $last ? 'disabled' : '' ?>>↓</button>
                </form>
              </div>
            </td>
            <td class="faint nowrap"><?= e(ago($p['updated_at'])) ?></td>
            <td>
              <div class="actions" style="justify-content:flex-end;">
                <a class="btn ghost sm" href="project-edit.php?id=<?= (int) $p['id'] ?>">Editar</a>
                <form method="post" data-confirm="¿Duplicar este proyecto?" style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="duplicate">
                  <input type="hidden" name="id" value="<?= (int) $p['id'] ?>">
                  <button type="submit" class="btn ghost sm">Duplicar</button>
                </form>
                <form method="post" data-confirm="¿Eliminar este proyecto? Se borrara tambien su imagen." style="display:inline;">
                  <?= csrf_field() ?>
                  <input type="hidden" name="action" value="delete">
                  <input type="hidden" name="id" value="<?= (int) $p['id'] ?>">
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

<p class="hint">
  El orden de la web es: primero los <strong>destacados</strong>, y dentro de cada grupo
  por el numero de <strong>orden</strong> (menor primero). Las flechas ↑ ↓ intercambian
  ese numero con el proyecto vecino.
</p>

<?php admin_footer(); ?>
