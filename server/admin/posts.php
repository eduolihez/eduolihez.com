<?php
/**
 * posts.php - Listado de artículos del Blog.
 * 
 * Permite gestionar las entradas del blog: crear, editar, buscar, duplicar, 
 * cambiar visibilidad en caliente y eliminar artículos con limpieza de portada.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/upload.php';
require_once __DIR__ . '/../lib/post.php';
require_login();

$search = mb_substr(trim((string) ($_GET['q'] ?? '')), 0, 80);
$back   = 'posts.php' . ($search !== '' ? '?q=' . urlencode($search) : '');

// --- Acciones (POST) --------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');
    $id     = (int) ($_POST['id'] ?? 0);

    if ($id > 0) {
        $st = db()->prepare('SELECT * FROM posts WHERE id = ?');
        $st->execute([$id]);
        $row = $st->fetch();

        if ($row) {
            switch ($action) {
                case 'delete':
                    db()->prepare('DELETE FROM posts WHERE id = ?')->execute([$id]);
                    delete_upload($row['cover_url'] ?? null); // Eliminar imagen de portada
                    log_activity('delete', 'post', $id, 'Artículo: ' . $row['title']);
                    set_flash('ok', 'Artículo eliminado con éxito.');
                    break;

                case 'toggle_visible':
                    $new = ((int) $row['visible']) === 1 ? 0 : 1;
                    db()->prepare('UPDATE posts SET visible = ? WHERE id = ?')->execute([$new, $id]);
                    log_activity('update', 'post', $id, $new ? 'Visible' : 'Oculto');
                    set_flash('ok', $new ? 'Artículo publicado y visible.' : 'Artículo pasado a borrador (oculto).');
                    break;

                case 'duplicate':
                    $uniqueSlug = $row['slug'] . '-' . bin2hex(random_bytes(3));
                    // La copia nace como borrador y SIN fecha de publicacion:
                    // heredar la del original la colocaria entre los articulos
                    // ya publicados en cuanto se marcara visible.
                    db()->prepare(
                        'INSERT INTO posts (title, slug, summary, content, cover_url, tags, category, lang, visible, published_at, created_at, updated_at)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, NOW(), NOW())'
                    )->execute([
                        $row['title'] . ' (copia)',
                        $uniqueSlug,
                        $row['summary'],
                        $row['content'],
                        $row['cover_url'],
                        $row['tags'] ?? null,
                        $row['category'] ?? null,
                        $row['lang']
                    ]);
                    $newId = (int) db()->lastInsertId();
                    log_activity('create', 'post', $newId, 'Duplicado de: ' . $row['title']);
                    set_flash('ok', 'Artículo duplicado como borrador.');
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
    $where  = 'WHERE title LIKE ? OR summary LIKE ? OR content LIKE ?';
    $like   = '%' . str_replace(['%', '_'], ['\%', '\_'], $search) . '%';
    $params = [$like, $like, $like];
}

$st = db()->prepare(
    "SELECT id, title, slug, summary, cover_url, tags, category, lang, visible,
            COALESCE(published_at, created_at) AS created_at
     FROM posts $where ORDER BY COALESCE(published_at, created_at) DESC, id DESC"
);
$st->execute($params);
$rows = $st->fetchAll();

$totalAll = (int) db()->query('SELECT COUNT(*) FROM posts')->fetchColumn();
$visible  = (int) db()->query('SELECT COUNT(*) FROM posts WHERE visible=1')->fetchColumn();

admin_header('Blog - Entradas', 'posts.php');
show_flash();
?>
<?php page_header('Artículos del Blog', '', '<a class="btn" href="post-edit.php">+ Nuevo artículo</a>', '(' . $visible . ' visibles de ' . $totalAll . ')'); ?>

<form method="get" class="card search-bar">
  <input type="search" name="q" value="<?= e($search) ?>" placeholder="Buscar por título, resumen o contenido…">
  <button class="btn sm" type="submit">Buscar</button>
  <?php if ($search !== ''): ?><a class="btn ghost sm" href="posts.php">Limpiar</a><?php endif; ?>
</form>

<div class="card p-0">
  <div class="scroll-x">
    <table class="stack" role="table">
      <thead role="rowgroup">
        <tr role="row">
          <th role="columnheader" class="col-w60">Portada</th>
          <th role="columnheader">Título</th>
          <th role="columnheader">Categoría</th>
          <th role="columnheader">Idioma</th>
          <th role="columnheader">Slug / Enlace</th>
          <th role="columnheader">Estado</th>
          <th role="columnheader">Fecha</th>
          <th role="columnheader" class="col-w220 text-right">Acciones</th>
        </tr>
      </thead>
      <tbody role="rowgroup">
        <?php if (!$rows): ?>
          <tr role="row">
            <td role="cell" colspan="8" class="empty">
              <?= $search !== '' ? 'Ningún artículo coincide con la búsqueda.' : 'Aún no hay artículos publicados.' ?>
            </td>
          </tr>
        <?php endif; ?>
        <?php foreach ($rows as $c): ?>
          <tr role="row">
            <td role="cell" data-label="Portada">
              <?php if (!empty($c['cover_url'])): ?>
                <img src="<?= e($c['cover_url']) ?>" alt="" width="48" height="32" class="soft-box"
                     class="thumb-sm">
              <?php else: ?>
                <div class="soft-box thumb-sm thumb-empty">NO IMG</div>
              <?php endif; ?>
            </td>
            <td role="cell" data-label="Título">
              <a href="post-edit.php?id=<?= $c['id'] ?>" class="fw-600">
                <?= e($c['title']) ?>
              </a>
              <br>
              <span class="faint cell-summary"><?= e($c['summary']) ?></span>
            </td>
            <td role="cell" data-label="Categoría">
              <?php $categoryLabel = post_category_label($c['category']); ?>
              <?= $categoryLabel !== null ? '<span class="pill">' . e($categoryLabel) . '</span>' : '<span class="faint">—</span>' ?>
            </td>
            <td role="cell" data-label="Idioma">
              <span class="pill pill-code">
                <?= e($c['lang']) ?>
              </span>
            </td>
            <td role="cell" data-label="Enlace" class="mono faint fs-12">
              /blog/<?= e($c['slug']) ?>
            </td>
            <td role="cell" data-label="Estado">
              <form method="post" class="d-inline">
                <?= csrf_field() ?>
                <input type="hidden" name="id" value="<?= $c['id'] ?>">
                <input type="hidden" name="action" value="toggle_visible">
                <button type="submit" class="pill pill-btn <?= ((int) $c['visible']) === 1 ? 'on' : 'off' ?>">
                  <?= ((int) $c['visible']) === 1 ? 'Publicado' : 'Borrador' ?>
                </button>
              </form>
            </td>
            <td role="cell" data-label="Fecha" class="nowrap faint">
              <?= fdate($c['created_at'], 'd/m/Y H:i') ?>
            </td>
            <td role="cell" data-label="Acciones" class="text-right">
              <div class="actions justify-end gap-sm">
                <a class="btn ghost sm icon" href="post-edit.php?id=<?= $c['id'] ?>" title="Editar" aria-label="Editar artículo">
                  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                </a>
                
                <form method="post" class="d-inline" data-confirm="¿Seguro que quieres duplicar este artículo?">
                  <?= csrf_field() ?>
                  <input type="hidden" name="id" value="<?= $c['id'] ?>">
                  <input type="hidden" name="action" value="duplicate">
                  <button type="submit" class="btn ghost sm icon" title="Duplicar" aria-label="Duplicar artículo">
                    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2h-2M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2" /></svg>
                  </button>
                </form>

                <form method="post" class="d-inline" data-confirm="¿Seguro que quieres eliminar este artículo definitivamente?">
                  <?= csrf_field() ?>
                  <input type="hidden" name="id" value="<?= $c['id'] ?>">
                  <input type="hidden" name="action" value="delete">
                  <button type="submit" class="btn danger sm icon" title="Eliminar" aria-label="Eliminar artículo">
                    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                  </button>
                </form>
              </div>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<?php
admin_footer();
?>
