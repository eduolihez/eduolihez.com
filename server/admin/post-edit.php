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

    if ($p['title'] === '') $errors[] = 'El título es obligatorio.';
    if ($p['slug'] === '')  $errors[] = 'El slug (enlace amigable) es obligatorio.';
    if ($p['summary'] === '') $errors[] = 'El resumen (meta descripción) es obligatorio.';
    if ($p['content'] === '') $errors[] = 'El contenido del artículo es obligatorio.';

    // Validar slug único
    $dup = db()->prepare('SELECT COUNT(*) FROM posts WHERE slug = ? AND id != ?');
    $dup->execute([$p['slug'], $id]);
    if ((int) $dup->fetchColumn() > 0) {
        $errors[] = 'El slug ya está en uso por otro artículo. Modifica el campo Enlace.';
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
        $errors[] = 'Error de imagen: ' . $ex->getMessage();
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
                    SET title=?, slug=?, summary=?, content=?, cover_url=?, tags=?,
                        lang=?, visible=?, published_at=?, updated_at=NOW()
                  WHERE id=?'
            )->execute([
                $p['title'], $p['slug'], $p['summary'], $p['content'], $p['cover_url'],
                $p['tags'], $p['lang'], $p['visible'], $publishedAt, $id,
            ]);
            log_activity('update', 'post', $id, 'Artículo: ' . $p['title']);
            set_flash('ok', 'Artículo actualizado con éxito.');
        } else {
            db()->prepare(
                'INSERT INTO posts
                    (title, slug, summary, content, cover_url, tags, lang, visible,
                     published_at, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())'
            )->execute([
                $p['title'], $p['slug'], $p['summary'], $p['content'], $p['cover_url'],
                $p['tags'], $p['lang'], $p['visible'], $publishedAt,
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
<div class="subdash">
<div class="toolbar">
  <h1 style="margin:0;"><?= $isEdit ? 'Editar Artículo' : 'Nuevo Artículo del Blog' ?></h1>
  <a class="btn ghost" href="posts.php">Volver al listado</a>
</div>

<?php if ($errors): ?>
  <div class="flash err">
    <p style="margin:0 0 .4rem; font-weight:700;">No se pudo guardar por los siguientes errores:</p>
    <ul style="margin:0; padding-left:1.2rem;">
      <?php foreach ($errors as $e): ?><li><?= e($e) ?></li><?php endforeach; ?>
    </ul>
  </div>
<?php endif; ?>

<form method="post" enctype="multipart/form-data" class="card" autocomplete="off" style="max-width:900px; margin:0 auto;">
  <?= csrf_field() ?>

  <div class="row2">
    <div>
      <label for="title">Título del artículo</label>
      <input type="text" id="title" name="title" value="<?= e($p['title']) ?>" placeholder="Ej. Detección de ransomware en entornos Windows" required autofocus>
    </div>
    <div>
      <label for="slug">Enlace (Slug) <span class="faint">(auto-generado)</span></label>
      <input type="text" id="slug" name="slug" value="<?= e($p['slug']) ?>" placeholder="ej-deteccion-ransomware-windows" required>
    </div>
  </div>

  <div class="row2">
    <div>
      <label for="lang">Idioma del artículo</label>
      <select id="lang" name="lang">
        <option value="es" <?= $p['lang'] === 'es' ? 'selected' : '' ?>>Español (ES)</option>
        <option value="en" <?= $p['lang'] === 'en' ? 'selected' : '' ?>>Inglés (EN)</option>
        <option value="ca" <?= $p['lang'] === 'ca' ? 'selected' : '' ?>>Catalán (CA)</option>
      </select>
    </div>
    <div>
      <label for="visible">Estado de publicación</label>
      <div style="padding-top:0.75rem;">
        <label class="checkline" style="margin:0;">
          <input type="checkbox" id="visible" name="visible" value="1" <?= ((int) $p['visible']) === 1 ? 'checked' : '' ?>>
          <span><strong>Publicado en la web</strong> (si se desmarca, quedará como borrador y oculto)</span>
        </label>
      </div>
    </div>
  </div>

  <div class="row2">
    <div>
      <label for="tags">Etiquetas <span class="faint">(separadas por comas)</span></label>
      <input type="text" id="tags" name="tags" value="<?= e($p['tags']) ?>"
             placeholder="python, soc, automatizacion" maxlength="255">
      <p class="hint">Se guardan en minúsculas y sin repetir. Salen en la tarjeta del
         artículo y como <code>keywords</code> en los datos estructurados.</p>
    </div>
    <div>
      <label for="published_at">Fecha de publicación</label>
      <input type="datetime-local" id="published_at" name="published_at"
             value="<?= e($p['published_at']) ?>">
      <p class="hint">Es la fecha que se muestra y la que ve Google. Puedes fecharla
         hacia atrás; no tiene por qué coincidir con cuándo creaste el borrador.</p>
    </div>
  </div>

  <label for="summary">Resumen / Extracto <span class="faint">(Meta Descripción SEO - máx. 250 caracteres)</span></label>
  <textarea id="summary" name="summary" maxlength="250" placeholder="Escribe un breve resumen atractivo para Google y las listas de artículos..." required style="min-height:70px;"><?= e($p['summary']) ?></textarea>

  <label for="content">Contenido <span class="faint">(Puedes usar HTML o texto plano)</span></label>
  <textarea id="content" name="content" placeholder="Escribe el cuerpo del artículo..." required style="min-height:350px; font-family: inherit;"><?= e($p['content']) ?></textarea>

  <label>Imagen de portada</label>
  <div class="soft-box" style="display:grid; grid-template-columns: auto 1fr; gap:1.5rem; align-items:center; padding:1rem; border-radius:0.5rem; border:1px solid var(--border);">
    <div>
      <?php if (!empty($p['cover_url'])): ?>
        <img id="cover-preview" src="<?= e($p['cover_url']) ?>" alt="Portada" style="width:120px; height:80px; object-fit:cover; border-radius:0.375rem; border:1px solid var(--border);">
      <?php else: ?>
        <div id="cover-placeholder" style="width:120px; height:80px; border-radius:0.375rem; border:1px dashed var(--border); display:flex; align-items:center; justify-content:center; color:var(--faint); font-size:11px; text-align:center; padding:5px;">Sin portada</div>
      <?php endif; ?>
    </div>
    <div>
      <input type="file" name="cover_file" id="cover_file" accept="image/*">
      <p class="hint" style="margin-bottom:0.75rem;">Máximo 3 MB. Se aceptan formatos JPG, PNG, WEBP o GIF.</p>
      <?php if (!empty($p['cover_url'])): ?>
        <label class="checkline" style="margin:0; display:inline-flex; align-items:center;">
          <input type="checkbox" name="delete_cover" value="1">
          <span style="color:var(--danger); font-size:0.8rem;">Eliminar imagen actual al guardar</span>
        </label>
      <?php endif; ?>
    </div>
  </div>

  <div class="actions" style="margin-top:2rem; justify-content:flex-end;">
    <a class="btn ghost" href="posts.php">Cancelar</a>
    <button type="submit" class="btn">Guardar artículo</button>
  </div>
</form>

</div><!-- /.subdash -->
<script>
  // Autogeneración del slug a partir del título en tiempo real (solo al crear)
  document.addEventListener('DOMContentLoaded', () => {
    const titleIn = document.getElementById('title');
    const slugIn = document.getElementById('slug');
    const isEdit = <?= $isEdit ? 'true' : 'false' ?>;

    let manualSlug = isEdit;

    if (slugIn) {
      slugIn.addEventListener('input', () => {
        manualSlug = true;
      });
    }

    if (titleIn && slugIn && !isEdit) {
      titleIn.addEventListener('input', () => {
        if (!manualSlug) {
          slugIn.value = titleIn.value
            .toLowerCase()
            .normalize('NFD') // Quitar acentos
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/[^a-z0-9\s-]/g, '') // Eliminar caracteres especiales
            .trim()
            .replace(/\s+/g, '-') // Cambiar espacios por guiones
            .replace(/-+/g, '-'); // Quitar guiones duplicados
        }
      });
    }
  });
</script>
<?php
admin_footer();
?>
