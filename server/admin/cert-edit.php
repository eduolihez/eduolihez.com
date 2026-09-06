<?php
/**
 * cert-edit.php - Crear o editar una certificacion.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/upload.php';
require_once __DIR__ . '/../lib/validate.php';
require_login();

$id = (int) ($_GET['id'] ?? 0);
$isEdit = $id > 0;

$c = [
    'name' => '', 'issuer' => '', 'issue_date' => '',
    'credential_url' => '', 'logo_url' => '', 'category' => '',
    'visible' => 1, 'sort_order' => 0,
];

if ($isEdit) {
    $stmt = db()->prepare('SELECT * FROM certifications WHERE id = ?');
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    if (!$row) {
        set_flash('err', 'Certificacion no encontrada.');
        redirect('certifications.php');
    }
    $c = array_merge($c, $row);
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $c['name']           = trim((string) ($_POST['name'] ?? ''));
    $c['issuer']         = trim((string) ($_POST['issuer'] ?? ''));
    $c['issue_date']     = trim((string) ($_POST['issue_date'] ?? ''));
    $c['credential_url'] = trim((string) ($_POST['credential_url'] ?? ''));
    $c['logo_url']       = trim((string) ($_POST['logo_url'] ?? ''));
    $c['category']       = trim((string) ($_POST['category'] ?? ''));
    $c['visible']        = isset($_POST['visible']) ? 1 : 0;
    $c['sort_order']     = (int) ($_POST['sort_order'] ?? 0);

    $errors = [];
    if ($c['name'] === '') $errors[] = 'El nombre es obligatorio.';

    $oldLogo = $isEdit ? (string) ($row['logo_url'] ?? '') : '';
    try {
        $uploaded = handle_upload('logo_file', 'certs');
        if ($uploaded !== null) {
            $c['logo_url'] = $uploaded;
        }
    } catch (Throwable $ex) {
        $errors[] = $ex->getMessage();
    }

    // Mismo esquema que announcement_url en settings.php (server/lib/validate.php):
    // solo https:// o ruta interna. Sin esto, un campo de texto libre
    // admitiria un javascript:... (auditoria VibeSec del 2026-08-25; hoy no
    // era explotable porque e() escapa el valor, pero esto lo cierra en
    // origen en vez de depender solo del escape en cada sitio donde se
    // imprime). Los dos campos de URL del formulario pasan por aqui, no
    // solo logo_url -- si alguno se te olvida, deja de ser cierto que esto
    // "se cierra en origen".
    foreach ([
        'logo_url'       => 'La URL del logo',
        'credential_url' => 'La URL de verificacion',
    ] as $field => $label) {
        if ($err = validate_public_url($c[$field], $label)) {
            $errors[] = $err;
        }
    }

    if (!$errors) {
        if ($isEdit) {
            $sql = 'UPDATE certifications SET name=?, issuer=?, issue_date=?, credential_url=?,
                    logo_url=?, category=?, visible=?, sort_order=? WHERE id=?';
            $params = [
                $c['name'], $c['issuer'], $c['issue_date'], $c['credential_url'],
                $c['logo_url'], $c['category'], $c['visible'], $c['sort_order'], $id,
            ];
        } else {
            $sql = 'INSERT INTO certifications (name, issuer, issue_date, credential_url,
                    logo_url, category, visible, sort_order, created_at)
                    VALUES (?,?,?,?,?,?,?,?,NOW())';
            $params = [
                $c['name'], $c['issuer'], $c['issue_date'], $c['credential_url'],
                $c['logo_url'], $c['category'], $c['visible'], $c['sort_order'],
            ];
        }
        db()->prepare($sql)->execute($params);
        $savedId = $isEdit ? $id : (int) db()->lastInsertId();

        if ($oldLogo !== '' && $oldLogo !== $c['logo_url']) {
            delete_upload($oldLogo);
        }

        log_activity($isEdit ? 'update' : 'create', 'certification', $savedId, 'Certificacion: ' . $c['name']);
        set_flash('ok', $isEdit ? 'Certificacion actualizada.' : 'Certificacion creada.');
        redirect('certifications.php');
    }
}

admin_header($isEdit ? 'Editar certificacion' : 'Nueva certificacion', 'certifications.php');
show_flash();
if (!empty($errors)) {
    echo '<div class="flash err">' . e(implode(' ', $errors)) . '</div>';
}
?>
<div class="subdash">
<div class="toolbar">
  <h1 style="margin:0;"><?= $isEdit ? 'Editar certificacion' : 'Nueva certificacion' ?></h1>
  <a class="btn ghost" href="certifications.php">&larr; Volver</a>
</div>

<form method="post" enctype="multipart/form-data" class="card">
  <?= csrf_field() ?>

  <label for="name">Nombre *</label>
  <input type="text" id="name" name="name" required maxlength="200" value="<?= e($c['name']) ?>" placeholder="Fortinet NSE 4">

  <div class="row2">
    <div>
      <label for="issuer">Emisor</label>
      <input type="text" id="issuer" name="issuer" maxlength="120" value="<?= e($c['issuer']) ?>" placeholder="Fortinet">
    </div>
    <div>
      <label for="issue_date">Fecha</label>
      <input type="text" id="issue_date" name="issue_date" maxlength="20" value="<?= e($c['issue_date']) ?>" placeholder="2026 o Mar 2026">
      <div class="hint">Texto libre: puedes poner solo el ano.</div>
    </div>
  </div>

  <label for="credential_url">URL de verificacion</label>
  <input type="url" id="credential_url" name="credential_url" maxlength="255" value="<?= e($c['credential_url']) ?>" placeholder="https://www.credly.com/...">

  <label for="logo_file">Logo (imagen)</label>
  <input type="file" id="logo_file" name="logo_file" accept="image/png,image/jpeg,image/webp,image/gif">
  <div class="hint">Sube el logo del emisor (JPG/PNG/WEBP, max. 3 MB). Se guarda en /uploads/certs.</div>
  <?php if (!empty($c['logo_url'])): ?>
    <div class="hint" style="margin-top:.5rem;">
      Logo actual: <a href="<?= e($c['logo_url']) ?>" target="_blank"><?= e($c['logo_url']) ?></a>
    </div>
  <?php endif; ?>

  <label for="logo_url" style="margin-top:1rem;">...o URL del logo (opcional)</label>
  <input type="text" id="logo_url" name="logo_url" maxlength="255" value="<?= e($c['logo_url']) ?>" placeholder="/uploads/certs/logo.png">
  <div class="hint">Si lo dejas vacio se muestra la inicial del emisor. Si pegas una URL externa,
  debe empezar por <code>https://</code> o por <code>/</code> (ruta interna).</div>

  <div class="row2">
    <div>
      <label for="category">Categoria <span class="faint">(opcional)</span></label>
      <input type="text" id="category" name="category" maxlength="60" value="<?= e($c['category']) ?>" placeholder="Cloud Security">
    </div>
    <div>
      <label for="sort_order">Orden de aparicion</label>
      <input type="number" id="sort_order" name="sort_order" value="<?= (int) $c['sort_order'] ?>">
    </div>
  </div>

  <label style="display:flex; align-items:center; gap:.5rem; margin-top:1.1rem;">
    <input type="checkbox" name="visible" value="1" style="width:auto;" <?= $c['visible'] ? 'checked' : '' ?>>
    Visible en la web
  </label>

  <div style="margin-top:1.5rem;">
    <button type="submit" class="btn"><?= $isEdit ? 'Guardar cambios' : 'Crear certificacion' ?></button>
    <a class="btn ghost" href="certifications.php">Cancelar</a>
  </div>
</form>

</div><!-- /.subdash -->
<?php admin_footer(); ?>
