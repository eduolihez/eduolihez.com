<?php
/**
 * project-edit.php - Crear o editar un proyecto.
 * ?id=N  -> edita el proyecto N. Sin id -> crea uno nuevo.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/upload.php';
require_login();

$id = (int) ($_GET['id'] ?? 0);
$isEdit = $id > 0;

// Valores por defecto (proyecto nuevo).
$p = [
    'title_es' => '', 'title_en' => '',
    'summary_es' => '', 'summary_en' => '',
    'description_es' => '', 'description_en' => '',
    'image_url' => '', 'stack' => '',
    'badges' => [],
    'repo_url' => '', 'demo_url' => '', 'store_url' => '',
    'featured' => 0, 'sort_order' => 0, 'status' => 'published',
];

// Si editamos, cargamos el proyecto.
if ($isEdit) {
    $stmt = db()->prepare('SELECT * FROM projects WHERE id = ?');
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    if (!$row) {
        set_flash('err', 'Proyecto no encontrado.');
        redirect('projects.php');
    }
    // "stack" es JSON en la DB -> lo mostramos como lista separada por comas.
    $stackArr = json_decode($row['stack'] ?? '[]', true);
    $row['stack'] = is_array($stackArr) ? implode(', ', $stackArr) : '';
    
    // Decodificar badges
    $badgesArr = json_decode($row['badges'] ?? '[]', true);
    $row['badges'] = is_array($badgesArr) ? $badgesArr : [];
    
    $p = array_merge($p, $row);
}

// --- Guardar (POST) ---
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();

    // Recogemos y saneamos.
    $p['title_es']       = trim((string) ($_POST['title_es'] ?? ''));
    $p['title_en']       = trim((string) ($_POST['title_en'] ?? ''));
    $p['summary_es']     = trim((string) ($_POST['summary_es'] ?? ''));
    $p['summary_en']     = trim((string) ($_POST['summary_en'] ?? ''));
    $p['description_es'] = trim((string) ($_POST['description_es'] ?? ''));
    $p['description_en'] = trim((string) ($_POST['description_en'] ?? ''));
    $p['image_url']      = trim((string) ($_POST['image_url'] ?? ''));
    $p['stack']          = trim((string) ($_POST['stack'] ?? ''));
    $p['repo_url']       = trim((string) ($_POST['repo_url'] ?? ''));
    $p['demo_url']       = trim((string) ($_POST['demo_url'] ?? ''));
    $p['store_url']      = trim((string) ($_POST['store_url'] ?? ''));
    $p['featured']       = isset($_POST['featured']) ? 1 : 0;
    $p['sort_order']     = (int) ($_POST['sort_order'] ?? 0);
    $p['status']         = ($_POST['status'] ?? 'published') === 'draft' ? 'draft' : 'published';

    // Recogemos badges seleccionados para que no se pierdan en caso de error de validación
    $p['badges'] = [];
    if (isset($_POST['badge_open_source'])) {
        $p['badges'][] = 'open-source';
    }
    if (isset($_POST['badge_in_development'])) {
        $p['badges'][] = 'in-development';
    }
    if (isset($_POST['badge_private_code'])) {
        $p['badges'][] = 'private-code';
    }

    $errors = [];
    if ($p['title_es'] === '') $errors[] = 'El titulo en espanol es obligatorio.';
    if ($p['summary_es'] === '') $errors[] = 'El resumen en espanol es obligatorio.';

    // Si se ha subido una imagen, sustituye a la URL escrita a mano.
    $oldImage = $isEdit ? (string) ($row['image_url'] ?? '') : '';
    try {
        $uploaded = handle_upload('image_file', 'projects');
        if ($uploaded !== null) {
            $p['image_url'] = $uploaded;
        }
    } catch (Throwable $ex) {
        $errors[] = $ex->getMessage();
    }

    if (!$errors) {
        // Convertimos "PHP, MySQL, Astro" -> ["PHP","MySQL","Astro"] -> JSON.
        $stackJson = json_encode(
            array_values(array_filter(array_map('trim', explode(',', $p['stack'])))),
            JSON_UNESCAPED_UNICODE
        );

        $badgesJson = json_encode($p['badges'], JSON_UNESCAPED_UNICODE);

        if ($isEdit) {
            $sql = 'UPDATE projects SET title_es=?, title_en=?, summary_es=?, summary_en=?,
                    description_es=?, description_en=?, image_url=?, stack=?, badges=?, repo_url=?,
                    demo_url=?, store_url=?, featured=?, sort_order=?, status=?, updated_at=NOW()
                    WHERE id=?';
            $params = [
                $p['title_es'], $p['title_en'], $p['summary_es'], $p['summary_en'],
                $p['description_es'], $p['description_en'], $p['image_url'], $stackJson, $badgesJson,
                $p['repo_url'], $p['demo_url'], $p['store_url'], $p['featured'],
                $p['sort_order'], $p['status'], $id,
            ];
        } else {
            $sql = 'INSERT INTO projects (title_es, title_en, summary_es, summary_en,
                    description_es, description_en, image_url, stack, badges, repo_url, demo_url,
                    store_url, featured, sort_order, status, created_at, updated_at)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW())';
            $params = [
                $p['title_es'], $p['title_en'], $p['summary_es'], $p['summary_en'],
                $p['description_es'], $p['description_en'], $p['image_url'], $stackJson, $badgesJson,
                $p['repo_url'], $p['demo_url'], $p['store_url'], $p['featured'],
                $p['sort_order'], $p['status'],
            ];
        }
        db()->prepare($sql)->execute($params);
        $savedId = $isEdit ? $id : (int) db()->lastInsertId();

        // Si la imagen ha cambiado, borramos la anterior para no acumular
        // archivos huerfanos en /uploads.
        if ($oldImage !== '' && $oldImage !== $p['image_url']) {
            delete_upload($oldImage);
        }

        log_activity($isEdit ? 'update' : 'create', 'project', $savedId, 'Proyecto: ' . $p['title_es']);
        set_flash('ok', $isEdit ? 'Proyecto actualizado.' : 'Proyecto creado.');
        redirect('projects.php');
    }
}

admin_header($isEdit ? 'Editar proyecto' : 'Nuevo proyecto', 'projects.php');
show_flash();
if (!empty($errors)) {
    echo '<div class="flash err">' . e(implode(' ', $errors)) . '</div>';
}
?>
<div class="toolbar">
  <h1 style="margin:0;"><?= $isEdit ? 'Editar proyecto' : 'Nuevo proyecto' ?></h1>
  <a class="btn ghost" href="projects.php">&larr; Volver</a>
</div>

<form method="post" enctype="multipart/form-data" class="card">
  <?= csrf_field() ?>

  <div class="row2">
    <div>
      <label for="title_es">Titulo (ES) *</label>
      <input type="text" id="title_es" name="title_es" required maxlength="150" value="<?= e($p['title_es']) ?>">
    </div>
    <div>
      <label for="title_en">Titulo (EN)</label>
      <input type="text" id="title_en" name="title_en" maxlength="150" value="<?= e($p['title_en']) ?>">
    </div>
  </div>

  <div class="row2">
    <div>
      <label for="summary_es">Resumen corto (ES) *</label>
      <textarea id="summary_es" name="summary_es" required maxlength="400"><?= e($p['summary_es']) ?></textarea>
    </div>
    <div>
      <label for="summary_en">Resumen corto (EN)</label>
      <textarea id="summary_en" name="summary_en" maxlength="400"><?= e($p['summary_en']) ?></textarea>
    </div>
  </div>

  <div class="row2">
    <div>
      <label for="description_es">Descripcion larga (ES) <span class="faint">(opcional)</span></label>
      <textarea id="description_es" name="description_es"><?= e($p['description_es']) ?></textarea>
    </div>
    <div>
      <label for="description_en">Descripcion larga (EN) <span class="faint">(opcional)</span></label>
      <textarea id="description_en" name="description_en"><?= e($p['description_en']) ?></textarea>
    </div>
  </div>

  <label for="image_file">Imagen del proyecto</label>
  <input type="file" id="image_file" name="image_file" accept="image/png,image/jpeg,image/webp,image/gif">
  <div class="hint">Sube una imagen (JPG/PNG/WEBP/GIF, max. 3 MB). Se guarda en /uploads/projects.</div>
  <?php if (!empty($p['image_url'])): ?>
    <div class="hint" style="margin-top:.5rem;">
      Imagen actual: <a href="<?= e($p['image_url']) ?>" target="_blank"><?= e($p['image_url']) ?></a>
    </div>
  <?php endif; ?>

  <label for="image_url" style="margin-top:1rem;">...o URL de imagen (opcional)</label>
  <input type="text" id="image_url" name="image_url" maxlength="255" value="<?= e($p['image_url']) ?>" placeholder="/uploads/projects/mi-imagen.jpg">
  <div class="hint">Si subes un archivo arriba, este campo se rellena solo. Tambien puedes pegar una URL externa (https://...).</div>

  <label for="stack">Stack tecnologico</label>
  <input type="text" id="stack" name="stack" value="<?= e($p['stack']) ?>" placeholder="Next.js, TypeScript, Tailwind">
  <div class="hint">Separa las tecnologias por comas.</div>

  <label style="margin-top:1rem; display:block;">Etiquetas especiales (Badges)</label>
  <div style="display:flex; flex-wrap:wrap; gap:1.5rem; margin-top:.3rem; margin-bottom:1rem;">
    <label style="display:flex; align-items:center; gap:.4rem; font-weight:normal; cursor:pointer;">
      <input type="checkbox" name="badge_open_source" value="1" style="width:auto; margin:0;" <?= in_array('open-source', $p['badges']) ? 'checked' : '' ?>>
      <span>Open Source</span>
    </label>
    <label style="display:flex; align-items:center; gap:.4rem; font-weight:normal; cursor:pointer;">
      <input type="checkbox" name="badge_in_development" value="1" style="width:auto; margin:0;" <?= in_array('in-development', $p['badges']) ? 'checked' : '' ?>>
      <span>En Desarrollo</span>
    </label>
    <label style="display:flex; align-items:center; gap:.4rem; font-weight:normal; cursor:pointer;">
      <input type="checkbox" name="badge_private_code" value="1" style="width:auto; margin:0;" <?= in_array('private-code', $p['badges']) ? 'checked' : '' ?>>
      <span>Código Privado</span>
    </label>
  </div>

  <div class="row2">
    <div>
      <label for="repo_url">URL del repositorio</label>
      <input type="url" id="repo_url" name="repo_url" maxlength="255" value="<?= e($p['repo_url']) ?>" placeholder="https://github.com/...">
    </div>
    <div>
      <label for="demo_url">URL de la página del proyecto <span class="faint">(sustituye a Demo)</span></label>
      <input type="url" id="demo_url" name="demo_url" maxlength="255" value="<?= e($p['demo_url']) ?>" placeholder="https://...">
    </div>
  </div>

  <input type="hidden" id="store_url" name="store_url" value="<?= e($p['store_url']) ?>">

  <div class="row2">
    <div>
      <label for="sort_order">Orden de aparicion</label>
      <input type="number" id="sort_order" name="sort_order" value="<?= (int) $p['sort_order'] ?>">
      <div class="hint">Menor numero = aparece antes.</div>
    </div>
    <div>
      <label for="status">Estado</label>
      <select id="status" name="status">
        <option value="published" <?= $p['status'] === 'published' ? 'selected' : '' ?>>Publicado</option>
        <option value="draft" <?= $p['status'] === 'draft' ? 'selected' : '' ?>>Borrador</option>
      </select>
    </div>
  </div>

  <label style="display:flex; align-items:center; gap:.5rem; margin-top:1.1rem;">
    <input type="checkbox" name="featured" value="1" style="width:auto;" <?= $p['featured'] ? 'checked' : '' ?>>
    Marcar como destacado (aparece primero con etiqueta)
  </label>

  <div style="margin-top:1.5rem;">
    <button type="submit" class="btn"><?= $isEdit ? 'Guardar cambios' : 'Crear proyecto' ?></button>
    <a class="btn ghost" href="projects.php">Cancelar</a>
  </div>
</form>

<?php admin_footer(); ?>
