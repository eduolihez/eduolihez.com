<?php
/**
 * app-edit.php - Crear o editar una app (docs/designs/admin-dashboard.md).
 * La clave de API NO se toca aqui: se genera/rota desde apps.php, para que
 * el flujo de "aqui tienes tu clave, cópiala ahora" viva en un solo sitio.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_login();

$id = (int) ($_GET['id'] ?? 0);
$isEdit = $id > 0;

$a = ['slug' => '', 'display_name' => '', 'allowed_origins' => []];

if ($isEdit) {
    $stmt = db()->prepare('SELECT * FROM apps WHERE id = ?');
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    if (!$row) {
        set_flash('err', 'App no encontrada.');
        redirect('apps.php');
    }
    $a['slug'] = $row['slug'];
    $a['display_name'] = $row['display_name'];
    $a['allowed_origins'] = json_decode((string) ($row['allowed_origins'] ?? '[]'), true) ?: [];
}

$errors = [];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $a['display_name'] = trim((string) ($_POST['display_name'] ?? ''));
    $a['slug']          = trim((string) ($_POST['slug'] ?? ''));

    // Un origen por linea en el textarea; se descartan lineas vacias y
    // espacios sueltos. No se valida el ESQUEMA aqui a proposito: a
    // diferencia de validate_public_url() (pensado para un enlace que se va
    // a poner en un href), un Origin legitimo incluye chrome-extension://
    // y moz-extension://, no solo https://.
    $originsRaw = (string) ($_POST['allowed_origins'] ?? '');
    $a['allowed_origins'] = array_values(array_filter(array_map('trim', explode("\n", $originsRaw))));

    if ($a['display_name'] === '') {
        $errors[] = 'El nombre es obligatorio.';
    }
    if ($a['slug'] === '') {
        $errors[] = 'El slug es obligatorio.';
    } elseif (!preg_match('/^[a-z0-9-]+$/', $a['slug'])) {
        $errors[] = 'El slug solo puede tener minusculas, numeros y guiones (p.ej. "bloomgram").';
    }

    if (!$errors) {
        $originsJson = json_encode($a['allowed_origins'], JSON_UNESCAPED_UNICODE);
        try {
            if ($isEdit) {
                db()->prepare('UPDATE apps SET slug = ?, display_name = ?, allowed_origins = ? WHERE id = ?')
                    ->execute([$a['slug'], $a['display_name'], $originsJson, $id]);
            } else {
                db()->prepare('INSERT INTO apps (slug, display_name, allowed_origins, created_at) VALUES (?, ?, ?, NOW())')
                    ->execute([$a['slug'], $a['display_name'], $originsJson]);
            }
            $savedId = $isEdit ? $id : (int) db()->lastInsertId();
            log_activity($isEdit ? 'update' : 'create', 'app', $savedId, 'App: ' . $a['display_name']);
            set_flash('ok', $isEdit ? 'App actualizada.' : 'App creada. Genera su clave de API desde el listado.');
            redirect('apps.php');
        } catch (Throwable $e) {
            // UNIQUE KEY idx_slug: slug duplicado es el unico fallo esperable aqui.
            $errors[] = 'Ya existe una app con ese slug.';
        }
    }
}

admin_header($isEdit ? 'Editar app' : 'Nueva app', 'apps.php');
show_flash();
if ($errors) {
    echo '<div class="flash err">' . e(implode(' ', $errors)) . '</div>';
}
?>
<div class="toolbar">
  <h1 style="margin:0;"><?= $isEdit ? 'Editar app' : 'Nueva app' ?></h1>
  <a class="btn ghost" href="apps.php">&larr; Volver</a>
</div>

<form method="post" class="card">
  <?= csrf_field() ?>

  <label for="display_name">Nombre *</label>
  <input type="text" id="display_name" name="display_name" required maxlength="100"
         value="<?= e($a['display_name']) ?>" placeholder="BloomGram">

  <label for="slug">Slug *</label>
  <input type="text" id="slug" name="slug" required maxlength="60"
         value="<?= e($a['slug']) ?>" placeholder="bloomgram" pattern="[a-z0-9-]+">
  <div class="hint">Solo minusculas, numeros y guiones. Identifica la app en la URL del sub-dashboard.</div>

  <label for="allowed_origins">Orígenes permitidos</label>
  <textarea id="allowed_origins" name="allowed_origins" rows="4"
            placeholder="https://eduolihez.com&#10;chrome-extension://abcdefghijklmnop"><?= e(implode("\n", $a['allowed_origins'])) ?></textarea>
  <div class="hint">
    Uno por línea. Cada evento que esta app mande a <code>api.eduolihez.com</code> se compara
    contra esta lista (comparación exacta) como defensa extra sobre la clave de API — ver
    <code>docs/designs/admin-dashboard.md</code>. Un cliente sin cabecera Origin (un programa
    de escritorio, no un navegador) no necesita estar aquí.
  </div>

  <div style="margin-top:1.5rem;">
    <button type="submit" class="btn"><?= $isEdit ? 'Guardar cambios' : 'Crear app' ?></button>
    <a class="btn ghost" href="apps.php">Cancelar</a>
  </div>
</form>

<?php admin_footer(); ?>
