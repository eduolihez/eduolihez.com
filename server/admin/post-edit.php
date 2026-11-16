<?php
/**
 * post-edit.php - Editor de artículos de Blog.
 * 
 * Permite crear o editar un artículo de blog, subir la portada, 
 * autogenerar el slug y validar la entrada.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/upload.php';
require_once __DIR__ . '/../lib/post.php';
require_login();

$id = (int) ($_GET['id'] ?? 0);
$isEdit = $id > 0;

$p = [
    'title'        => '',
    'slug'         => '',
    'summary'      => '',
    'content'      => '',
    'cover_url'    => '',
    'tags'         => '',
    'category'     => '',
    'lang'         => 'es',
    'visible'      => 1,
    // Al crear se propone ahora; se puede cambiar para fechar hacia atras.
    'published_at' => date('Y-m-d\TH:i'),
];

// --- Cargar datos si es edición ---
if ($isEdit) {
    $st = db()->prepare('SELECT * FROM posts WHERE id = ?');
    $st->execute([$id]);
    $row = $st->fetch();
    if (!$row) {
        set_flash('err', 'El artículo no existe.');
        redirect('posts.php');
    }
    $p = array_merge($p, $row);
    // <input type="datetime-local"> espera "Y-m-dTH:i"; MySQL da "Y-m-d H:i:s".
    $stored = $row['published_at'] ?? $row['created_at'] ?? '';
    $p['published_at'] = $stored !== '' ? date('Y-m-d\TH:i', strtotime((string) $stored)) : '';
}

$errors = [];
$fieldErr = []; // mismo texto que $errors, indexado por campo (solo presentacion)
$success = false;

// --- Guardar (POST) ---
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();

    $p['title']        = trim((string) ($_POST['title'] ?? ''));
    $p['slug']         = trim((string) ($_POST['slug'] ?? ''));
    $p['summary']      = trim((string) ($_POST['summary'] ?? ''));
    $p['content']      = trim((string) ($_POST['content'] ?? ''));
    $p['lang']         = trim((string) ($_POST['lang'] ?? 'es'));
    $p['visible']      = isset($_POST['visible']) ? 1 : 0;
    $p['published_at'] = trim((string) ($_POST['published_at'] ?? ''));

    // Etiquetas: se guardan como CSV normalizado (minusculas, sin repetidas ni
    // vacias) para que "SOC", " soc" y "soc" no acaben siendo tres etiquetas.
    $tagList = array_values(array_unique(array_filter(array_map(
        static fn(string $t): string => mb_strtolower(trim($t)),
        explode(',', (string) ($_POST['tags'] ?? ''))
    ), static fn(string $t): bool => $t !== '')));
    $p['tags'] = mb_substr(implode(',', $tagList), 0, 255);

    // Categoria: lista blanca estricta contra POST_CATEGORIES (server/lib/post.php).
    // Vacio es valido -- un articulo sin categoria simplemente no aparece bajo
    // ningun filtro del listado (pero si en "Todos").
    $categoryIn = trim((string) ($_POST['category'] ?? ''));
    $p['category'] = $categoryIn !== '' && isset(POST_CATEGORIES[$categoryIn]) ? $categoryIn : null;

    // El idioma se interpola en las URLs del sitio: lista blanca estricta.
    if (!in_array($p['lang'], ['es', 'en', 'ca'], true)) {
        $p['lang'] = 'es';
    }

    // Normalizar slug
    if ($p['slug'] === '' && $p['title'] !== '') {
        // Generar desde título si está vacío
        $p['slug'] = strtolower(trim(preg_replace('/[^A-Za-z0-9-]+/', '-', $p['title']), '-'));
    } else {
        $p['slug'] = strtolower(trim(preg_replace('/[^A-Za-z0-9-]+/', '-', $p['slug']), '-'));
    }

    if ($p['title'] === '') $errors[] = $fieldErr['title'] = 'El título es obligatorio.';
    if ($p['slug'] === '')  $errors[] = $fieldErr['slug'] = 'El slug (enlace amigable) es obligatorio.';
    if ($p['summary'] === '') $errors[] = $fieldErr['summary'] = 'El resumen (meta descripción) es obligatorio.';
    if ($p['content'] === '') $errors[] = $fieldErr['content'] = 'El contenido del artículo es obligatorio.';

    // Validar slug único
    $dup = db()->prepare('SELECT COUNT(*) FROM posts WHERE slug = ? AND id != ?');
    $dup->execute([$p['slug'], $id]);
    if ((int) $dup->fetchColumn() > 0) {
        $errors[] = $fieldErr['slug'] = 'El slug ya está en uso por otro artículo. Modifica el campo Enlace.';
    }

    // Gestionar eliminación de la imagen de portada
    if (isset($_POST['delete_cover']) && $_POST['delete_cover'] == 1 && !empty($p['cover_url'])) {
        delete_upload($p['cover_url']);
        $p['cover_url'] = '';
    }

    // Subida de imagen
    try {
        $uploaded = handle_upload('cover_file', 'blog');
        if ($uploaded !== null) {
            // Borrar portada anterior si se sube una nueva
            if (!empty($p['cover_url'])) {
                delete_upload($p['cover_url']);
            }
            $p['cover_url'] = $uploaded;
        }
    } catch (Throwable $ex) {
        $errors[] = $fieldErr['cover_file'] = 'Error de imagen: ' . $ex->getMessage();
    }

    if (!$errors) {
        // El campo del formulario llega como "Y-m-dTH:i"; MySQL quiere
        // "Y-m-d H:i:s". Si viene vacio se guarda NULL y las consultas caen a
        // created_at, en vez de escribir una fecha cero que rompe el orden.
        $publishedAt = $p['published_at'] !== ''
            ? date('Y-m-d H:i:s', strtotime($p['published_at']))
            : null;

        if ($isEdit) {
            db()->prepare(
                'UPDATE posts
                    SET title=?, slug=?, summary=?, content=?, cover_url=?, tags=?, category=?,
                        lang=?, visible=?, published_at=?, updated_at=NOW()
                  WHERE id=?'
            )->execute([
                $p['title'], $p['slug'], $p['summary'], $p['content'], $p['cover_url'],
                $p['tags'], $p['category'], $p['lang'], $p['visible'], $publishedAt, $id,
            ]);
            log_activity('update', 'post', $id, 'Artículo: ' . $p['title']);
            set_flash('ok', 'Artículo actualizado con éxito.');
        } else {
            db()->prepare(
                'INSERT INTO posts
                    (title, slug, summary, content, cover_url, tags, category, lang, visible,
                     published_at, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())'
            )->execute([
                $p['title'], $p['slug'], $p['summary'], $p['content'], $p['cover_url'],
                $p['tags'], $p['category'], $p['lang'], $p['visible'], $publishedAt,
            ]);
            $id = (int) db()->lastInsertId();
            log_activity('create', 'post', $id, 'Artículo: ' . $p['title']);
            set_flash('ok', 'Artículo creado con éxito.');
        }
        redirect('posts.php');
    }
}

admin_header($isEdit ? 'Editar Artículo' : 'Nuevo Artículo', 'posts.php');
?>
<?php page_header($isEdit ? 'Editar Artículo' : 'Nuevo Artículo del Blog', '', '<a class="btn ghost" href="posts.php">Volver al listado</a>'); ?>

<?php
/** aria-invalid + aria-describedby de un campo (ayuda y, si falla, error). */
$fa = static function (string $name, bool $hint = false) use (&$fieldErr): string {
    $ids = [];
    if ($hint) $ids[] = e($name) . '-hint';
    if (isset($fieldErr[$name])) $ids[] = e($name) . '-error';
    return ($ids ? ' aria-describedby="' . implode(' ', $ids) . '"' : '')
         . (isset($fieldErr[$name]) ? ' aria-invalid="true"' : '');
};
/** Mensaje de error del servidor junto al campo. */
$fm = static function (string $name) use (&$fieldErr): string {
    return isset($fieldErr[$name])
        ? '<p class="field-error" id="' . e($name) . '-error">' . e($fieldErr[$name]) . '</p>'
        : '';
};
?>
<?php if ($errors): ?>
  <div class="flash err" role="alert">
    <p class="flash-title">No se pudo guardar por los siguientes errores:</p>
    <ul class="flash-list">
      <?php foreach ($errors as $e): ?><li><?= e($e) ?></li><?php endforeach; ?>
    </ul>
  </div>
<?php endif; ?>

<form method="post" enctype="multipart/form-data" class="editor-form" autocomplete="off" id="post-form">
  <?= csrf_field() ?>

  <fieldset class="card form-section">
    <legend>Contenido</legend>
    <label for="title">Título del artículo</label>
    <input type="text" id="title" name="title" value="<?= e($p['title']) ?>" placeholder="Ej. Detección de ransomware en entornos Windows" required autofocus<?= $fa('title') ?>>
    <?= $fm('title') ?>

    <label for="summary">Resumen / Extracto <span class="faint">(meta descripción SEO, máx. 250 caracteres)</span></label>
    <textarea id="summary" name="summary" maxlength="250" placeholder="Escribe un breve resumen atractivo para Google y las listas de artículos..." required class="summary-input"<?= $fa('summary') ?>><?= e($p['summary']) ?></textarea>
    <?= $fm('summary') ?>

    <label for="content">Contenido <span class="faint">(puedes usar HTML o texto plano)</span></label>
    <textarea id="content" name="content" placeholder="Escribe el cuerpo del artículo..." required class="editor-body"<?= $fa('content') ?>><?= e($p['content']) ?></textarea>
    <?= $fm('content') ?>
  </fieldset>

  <fieldset class="card form-section">
    <legend>Metadatos</legend>
    <div class="row2">
      <div>
        <label for="slug">Enlace (slug) <span class="faint">(se genera solo)</span></label>
        <input type="text" id="slug" name="slug" value="<?= e($p['slug']) ?>" placeholder="ej-deteccion-ransomware-windows" required<?= $isEdit ? '' : ' data-slug-auto' ?><?= $fa('slug') ?>>
        <?= $fm('slug') ?>
      </div>
      <div>
        <label for="lang">Idioma del artículo</label>
        <select id="lang" name="lang">
          <option value="es" <?= $p['lang'] === 'es' ? 'selected' : '' ?>>Español (ES)</option>
          <option value="en" <?= $p['lang'] === 'en' ? 'selected' : '' ?>>Inglés (EN)</option>
          <option value="ca" <?= $p['lang'] === 'ca' ? 'selected' : '' ?>>Catalán (CA)</option>
        </select>
      </div>
    </div>

    <div class="row2">
      <div>
        <label for="category">Categoría <span class="faint">(para el filtro del listado)</span></label>
        <select id="category" name="category" aria-describedby="category-hint">
          <option value="">Sin categoría</option>
          <?php foreach (POST_CATEGORIES as $key => $label): ?>
            <option value="<?= e($key) ?>" <?= $p['category'] === $key ? 'selected' : '' ?>><?= e($label) ?></option>
          <?php endforeach; ?>
        </select>
        <p class="hint" id="category-hint">Una sola, a diferencia de las etiquetas: es lo que ve el visitante
           para filtrar <a href="/blog/" target="_blank">/blog/</a>. Con muchas etiquetas
           libres el filtro se llenaba de botones; la categoría se queda en un puñado fijo.</p>
      </div>
      <div>
        <label for="tags">Etiquetas <span class="faint">(separadas por comas)</span></label>
        <input type="text" id="tags" name="tags" value="<?= e($p['tags']) ?>"
               placeholder="python, soc, automatizacion" maxlength="255" aria-describedby="tags-hint">
        <p class="hint" id="tags-hint">Se guardan en minúsculas y sin repetir. Salen en la tarjeta del
           artículo y como <code>keywords</code> en los datos estructurados. No se usan
           para filtrar el listado.</p>
      </div>
    </div>

    <label for="cover_file">Imagen de portada</label>
    <div class="soft-box cover-box">
      <div>
        <?php if (!empty($p['cover_url'])): ?>
          <img id="cover-preview" src="<?= e($p['cover_url']) ?>" alt="Portada" class="cover-thumb">
        <?php else: ?>
          <div id="cover-placeholder" class="cover-thumb cover-empty">Sin portada</div>
        <?php endif; ?>
      </div>
      <div>
        <input type="file" name="cover_file" id="cover_file" accept="image/*" aria-describedby="cover_file-hint<?= isset($fieldErr['cover_file']) ? ' cover_file-error' : '' ?>"<?= isset($fieldErr['cover_file']) ? ' aria-invalid="true"' : '' ?>>
        <p class="hint" id="cover_file-hint">Máximo 3 MB. Se aceptan formatos JPG, PNG, WEBP o GIF.</p>
        <?= $fm('cover_file') ?>
        <?php if (!empty($p['cover_url'])): ?>
          <label class="checkline cover-delete">
            <input type="checkbox" name="delete_cover" value="1">
            <span>Eliminar imagen actual al guardar</span>
          </label>
        <?php endif; ?>
      </div>
    </div>
  </fieldset>

  <fieldset class="card form-section">
    <legend>Publicación</legend>
    <label class="checkline" for="visible">
      <input type="checkbox" id="visible" name="visible" value="1" <?= ((int) $p['visible']) === 1 ? 'checked' : '' ?>>
      <span><strong>Publicado en la web</strong> (si se desmarca, queda como borrador y oculto)</span>
    </label>

    <label for="published_at">Fecha de publicación</label>
    <input type="datetime-local" id="published_at" name="published_at"
           value="<?= e($p['published_at']) ?>" class="date-input" aria-describedby="published_at-hint">
    <p class="hint" id="published_at-hint">Es la fecha que se muestra y la que ve Google. Puedes fecharla
       hacia atrás; no tiene por qué coincidir con cuándo creaste el borrador.</p>
  </fieldset>

  <div class="form-actions">
    <span class="save-state" id="save-state" role="status" aria-live="polite"><?= $errors ? 'No guardado: corrige los errores' : 'Sin cambios' ?></span>
    <a class="btn ghost" href="posts.php">Cancelar</a>
    <button type="submit" class="btn">Guardar artículo</button>
  </div>
</form>

<script src="<?= e(asset_url('post-edit.js')) ?>"></script>
<?php
admin_footer();
?>
