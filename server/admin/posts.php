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
<div class="subdash">
<div class="toolbar">
  <h1 style="margin:0;">Artículos del Blog <span class="faint" style="font-size:1rem;">(<?= $visible ?> visibles de <?= $totalAll ?>)</span></h1>
  <a class="btn" href="post-edit.php">+ Nuevo artículo</a>
</div>

<form method="get" class="card" style="display:flex; gap:.6rem; align-items:center; padding:.75rem 1rem;">
  <input type="search" name="q" value="<?= e($search) ?>" placeholder="Buscar por título, resumen o contenido..." style="flex:1;">
  <button class="btn sm" type="submit">Buscar</button>
  <?php if ($search !== ''): ?><a class="btn ghost sm" href="posts.php">Limpiar</a><?php endif; ?>
</form>

<div class="card" style="padding:0;">
  <div class="scroll-x">
    <table>
      <thead>
        <tr>
          <th style="width:60px;">Portada</th>
          <th>Título</th>
          <th>Categoría</th>
          <th>Idioma</th>
          <th>Slug / Enlace</th>
          <th>Estado</th>
          <th>Fecha</th>
          <th style="text-align:right; width:220px;">Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (!$rows): ?>
          <tr>
            <td colspan="8" class="empty">
              <?= $search !== '' ? 'Ningún artículo coincide con la búsqueda.' : 'Aún no hay artículos publicados.' ?>
            </td>
          </tr>
        <?php endif; ?>
        <?php foreach ($rows as $c): ?>
          <tr>
            <td>
              <?php if (!empty($c['cover_url'])): ?>
                <img src="<?= e($c['cover_url']) ?>" alt="" width="48" height="32" class="soft-box"
                     style="width:48px; height:32px; object-fit:cover; border-radius:.3rem; border:1px solid var(--border);">
              <?php else: ?>
                <div class="soft-box" style="width:48px; height:32px; border-radius:.3rem; border:1px solid var(--border); display:flex; align-items:center; justify-content:center; color:var(--faint); font-size:10px; font-weight:700;">NO IMG</div>
              <?php endif; ?>
            </td>
            <td>
              <a href="post-edit.php?id=<?= $c['id'] ?>" style="font-weight:600;">
                <?= e($c['title']) ?>
              </a>
              <br>
              <span class="faint" style="font-size:0.75rem; display:block; max-width: 400px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; margin-top:2px;"><?= e($c['summary']) ?></span>
            </td>
            <td>
              <?php $categoryLabel = post_category_label($c['category']); ?>
              <?= $categoryLabel !== null ? '<span class="pill">' . e($categoryLabel) . '</span>' : '<span class="faint">—</span>' ?>
            </td>
            <td>
              <span class="pill" style="text-transform: uppercase; font-family: 'JetBrains Mono', monospace; font-size:10px;">
                <?= e($c['lang']) ?>
              </span>
            </td>
            <td class="mono faint" style="font-size:12px;">
              /blog/<?= e($c['slug']) ?>
            </td>
            <td>
              <form method="post" style="display:inline;">
                <?= csrf_field() ?>
                <input type="hidden" name="id" value="<?= $c['id'] ?>">
                <input type="hidden" name="action" value="toggle_visible">
                <button type="submit" class="pill <?= ((int) $c['visible']) === 1 ? 'on' : 'off' ?>" style="cursor:pointer; border:1px solid var(--border);">
                  <?= ((int) $c['visible']) === 1 ? 'Publicado' : 'Borrador' ?>
                </button>
              </form>
            </td>
            <td class="nowrap faint">
              <?= fdate($c['created_at'], 'd/m/Y H:i') ?>
            </td>
            <td style="text-align:right;">
              <div class="actions" style="justify-content:flex-end; gap: 0.35rem;">
                <a class="btn ghost sm icon" href="post-edit.php?id=<?= $c['id'] ?>" title="Editar">
                  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                </a>
                
                <form method="post" style="display:inline;" onsubmit="return confirm('¿Seguro que quieres duplicar este artículo?');">
                  <?= csrf_field() ?>
                  <input type="hidden" name="id" value="<?= $c['id'] ?>">
                  <input type="hidden" name="action" value="duplicate">
                  <button type="submit" class="btn ghost sm icon" title="Duplicar">
                    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2h-2M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2" /></svg>
                  </button>
                </form>

                <form method="post" style="display:inline;" onsubmit="return confirm('¿Seguro que quieres eliminar este artículo definitivamente?');">
                  <?= csrf_field() ?>
                  <input type="hidden" name="id" value="<?= $c['id'] ?>">
                  <input type="hidden" name="action" value="delete">
                  <button type="submit" class="btn danger sm icon" title="Eliminar">
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
</div><!-- /.subdash -->
<?php
admin_footer();
?>
