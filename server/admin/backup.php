<?php
/**
 * backup.php - Copia de seguridad del contenido.
 *
 * Exporta proyectos, certificaciones y ajustes a un archivo JSON, y permite
 * restaurarlos. Es la red de seguridad ante un error al editar o una perdida
 * de la base de datos.
 *
 * NO incluye mensajes (datos personales de terceros: se exportan aparte desde
 * el buzon) ni usuarios/contrasenas (nunca deben salir del servidor).
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_login();

$errors = [];

/**
 * Claves de ajustes que se aceptan al importar (las mismas que gestiona
 * settings.php). Lista blanca: una copia manipulada no puede inyectar ajustes
 * arbitrarios en la tabla `settings`.
 */
const MANAGED_SETTINGS = [
    'open_to_work', 'contact_enabled', 'analytics_enabled',
    'announcement_on', 'announcement_es', 'announcement_en',
    'announcement_ca', 'announcement_url',
];

/** Lee una tabla completa (tolerante a fallos). */
function dump_table(string $sql): array
{
    try {
        return db()->query($sql)->fetchAll();
    } catch (Throwable $e) {
        return [];
    }
}

// --- Exportar ---------------------------------------------------------------
if (($_GET['export'] ?? '') === 'json') {
    $data = [
        'format'         => 'portfolio-backup',
        'version'        => 2,
        'exported_at'    => date('c'),
        'site'           => $_SERVER['HTTP_HOST'] ?? '',
        'projects'       => dump_table(
            'SELECT title_es, title_en, summary_es, summary_en, description_es, description_en,
                    image_url, stack, repo_url, demo_url, store_url, featured, sort_order, status
             FROM projects ORDER BY sort_order ASC, id ASC'
        ),
        'certifications' => dump_table(
            'SELECT name, issuer, issue_date, credential_url, logo_url, category, visible, sort_order
             FROM certifications ORDER BY sort_order ASC, id ASC'
        ),
        'settings'       => dump_table('SELECT `key`, `value` FROM settings ORDER BY `key`'),
    ];

    log_activity('export', 'backup', null, sprintf(
        'Backup JSON: %d proyectos, %d certificaciones',
        count($data['projects']),
        count($data['certifications'])
    ));

    header('Content-Type: application/json; charset=utf-8');
    header('Content-Disposition: attachment; filename="portfolio-backup-' . date('Y-m-d-Hi') . '.json"');
    header('X-Content-Type-Options: nosniff');
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

// --- Importar ---------------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');

    if ($action === 'import') {
        $mode = ($_POST['mode'] ?? 'add') === 'replace' ? 'replace' : 'add';

        // Segundo factor server-side para el modo destructivo (auditoria
        // VibeSec del 2026-08-25): el CSRF + confirm() de JS protegen contra
        // un envio ajeno, pero no contra un click propio sin querer -- borrar
        // TODOS los proyectos/certificaciones es irreversible salvo que
        // tengas backup, y hoy nada pedia una segunda confirmacion explicita.
        if ($mode === 'replace' && trim((string) ($_POST['confirm_replace'] ?? '')) !== 'BORRAR') {
            $errors[] = 'Para el modo "reemplazar" escribe BORRAR (en mayusculas) en el campo de confirmacion.';
        }

        // El chequeo de arriba solo ANADE a $errors -- sin este guard, un
        // confirm_replace incorrecto no impedia que el codigo de mas abajo
        // (que SI borra la tabla) se ejecutara igualmente.
        if ($errors) {
            // no hacer nada: cae directo al render de abajo con el error visible
        } elseif (empty($_FILES['backup']) || ($_FILES['backup']['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
            $errors[] = 'Selecciona un archivo .json de copia de seguridad.';
        } elseif ($_FILES['backup']['size'] > 5 * 1024 * 1024) {
            $errors[] = 'El archivo es demasiado grande (maximo 5 MB).';
        } else {
            $raw  = (string) file_get_contents($_FILES['backup']['tmp_name']);
            $data = json_decode($raw, true);

            if (!is_array($data) || ($data['format'] ?? '') !== 'portfolio-backup') {
                $errors[] = 'El archivo no es una copia de seguridad valida de este portfolio.';
            } else {
                $counts = ['projects' => 0, 'certifications' => 0, 'settings' => 0];

                try {
                    db()->beginTransaction();

                    if ($mode === 'replace') {
                        db()->exec('DELETE FROM projects');
                        db()->exec('DELETE FROM certifications');
                    }

                    // --- Proyectos ---
                    $ins = db()->prepare(
                        'INSERT INTO projects (title_es, title_en, summary_es, summary_en,
                            description_es, description_en, image_url, stack, repo_url, demo_url,
                            store_url, featured, sort_order, status, created_at, updated_at)
                         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW())'
                    );
                    foreach ((array) ($data['projects'] ?? []) as $p) {
                        if (!is_array($p) || trim((string) ($p['title_es'] ?? '')) === '') {
                            continue; // fila corrupta: la saltamos
                        }
                        $ins->execute([
                            mb_substr((string) $p['title_es'], 0, 150),
                            mb_substr((string) ($p['title_en'] ?? ''), 0, 150),
                            mb_substr((string) ($p['summary_es'] ?? ''), 0, 400),
                            mb_substr((string) ($p['summary_en'] ?? ''), 0, 400),
                            (string) ($p['description_es'] ?? ''),
                            (string) ($p['description_en'] ?? ''),
                            mb_substr((string) ($p['image_url'] ?? ''), 0, 255),
                            (string) ($p['stack'] ?? '[]'),
                            mb_substr((string) ($p['repo_url'] ?? ''), 0, 255),
                            mb_substr((string) ($p['demo_url'] ?? ''), 0, 255),
                            mb_substr((string) ($p['store_url'] ?? ''), 0, 255),
                            !empty($p['featured']) ? 1 : 0,
                            (int) ($p['sort_order'] ?? 0),
                            ($p['status'] ?? 'published') === 'draft' ? 'draft' : 'published',
                        ]);
                        $counts['projects']++;
                    }

                    // --- Certificaciones ---
                    $insC = db()->prepare(
                        'INSERT INTO certifications (name, issuer, issue_date, credential_url,
                            logo_url, category, visible, sort_order, created_at)
                         VALUES (?,?,?,?,?,?,?,?,NOW())'
                    );
                    foreach ((array) ($data['certifications'] ?? []) as $c) {
                        if (!is_array($c) || trim((string) ($c['name'] ?? '')) === '') {
                            continue;
                        }
                        $insC->execute([
                            mb_substr((string) $c['name'], 0, 200),
                            mb_substr((string) ($c['issuer'] ?? ''), 0, 120),
                            mb_substr((string) ($c['issue_date'] ?? ''), 0, 20),
                            mb_substr((string) ($c['credential_url'] ?? ''), 0, 255),
                            mb_substr((string) ($c['logo_url'] ?? ''), 0, 255),
                            mb_substr((string) ($c['category'] ?? ''), 0, 60),
                            isset($c['visible']) && !$c['visible'] ? 0 : 1,
                            (int) ($c['sort_order'] ?? 0),
                        ]);
                        $counts['certifications']++;
                    }

                    // --- Ajustes (solo las claves conocidas) ---
                    foreach ((array) ($data['settings'] ?? []) as $s) {
                        $key = (string) ($s['key'] ?? '');
                        if (!in_array($key, MANAGED_SETTINGS, true)) {
                            continue;
                        }
                        setting_set($key, mb_substr((string) ($s['value'] ?? ''), 0, 300));
                        $counts['settings']++;
                    }

                    db()->commit();

                    log_activity('import', 'backup', null, sprintf(
                        'Restauracion (%s): %d proyectos, %d certificaciones, %d ajustes',
                        $mode, $counts['projects'], $counts['certifications'], $counts['settings']
                    ));
                    set_flash('ok', sprintf(
                        'Copia restaurada: %d proyectos, %d certificaciones y %d ajustes.',
                        $counts['projects'], $counts['certifications'], $counts['settings']
                    ));
                    redirect('backup.php');
                } catch (Throwable $ex) {
                    if (db()->inTransaction()) {
                        db()->rollBack();
                    }
                    $errors[] = 'No se pudo restaurar la copia: ' . $ex->getMessage();
                }
            }
        }
    }
}

$nProjects = (int) db()->query('SELECT COUNT(*) FROM projects')->fetchColumn();
$nCerts    = (int) db()->query('SELECT COUNT(*) FROM certifications')->fetchColumn();
$nMessages = (int) db()->query('SELECT COUNT(*) FROM messages')->fetchColumn();

admin_header('Backup', 'backup.php');
show_flash();
?>
<h1>Copia de seguridad</h1>

<?php if ($errors): ?>
  <div class="flash err"><?= e(implode(' ', $errors)) ?></div>
<?php endif; ?>

<div class="grid4">
  <?php stat_card((string) $nProjects, 'Proyectos'); ?>
  <?php stat_card((string) $nCerts, 'Certificaciones', 'cyan'); ?>
  <?php stat_card((string) $nMessages, 'Mensajes', 'violet', 'se exportan desde el buzon'); ?>
  <?php stat_card(date('d/m/Y'), 'Fecha de hoy', '', 'guarda una copia al mes'); ?>
</div>

<h2>Descargar copia</h2>
<div class="card">
  <p class="muted" style="margin-top:0;">
    Genera un archivo <code>.json</code> con tus <strong>proyectos</strong>,
    <strong>certificaciones</strong> y <strong>ajustes</strong>. Guardalo en tu ordenador
    o en la nube: si algo va mal en la base de datos, restauras desde aqui en 10 segundos.
  </p>
  <p class="hint">
    No incluye mensajes de contacto (datos personales de terceros: exportalos aparte
    desde <a href="messages.php">Mensajes → Exportar CSV</a>) ni usuarios ni contrasenas.
    Las imagenes tampoco: esas viven en <code>/uploads</code> y se copian por FTP.
  </p>
  <div class="actions" style="margin-top:1rem;">
    <a class="btn" href="?export=json">Descargar backup JSON</a>
    <a class="btn ghost" href="messages.php?export=csv">Exportar mensajes (CSV)</a>
    <a class="btn ghost" href="analytics.php?days=365&amp;export=csv">Exportar visitas (CSV)</a>
  </div>
</div>

<h2>Restaurar copia</h2>
<div class="card">
  <div class="flash warn" style="margin-bottom:1rem;">
    <strong>Cuidado:</strong> el modo "reemplazar" <u>borra</u> todos los proyectos y
    certificaciones actuales antes de importar. Descarga primero una copia de lo que
    tienes ahora, por si acaso.
  </div>

  <form method="post" enctype="multipart/form-data"
        data-confirm="¿Restaurar esta copia de seguridad? Revisa el modo seleccionado.">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="import">

    <label for="backup">Archivo de copia (.json)</label>
    <input type="file" id="backup" name="backup" accept="application/json,.json" required>

    <label for="mode">Modo de restauracion</label>
    <select id="mode" name="mode">
      <option value="add">Anadir — conserva lo actual y suma el contenido de la copia</option>
      <option value="replace">Reemplazar — borra proyectos y certificaciones actuales</option>
    </select>
    <div class="hint">Los ajustes siempre se sobrescriben con los de la copia.</div>

    <label for="confirm_replace" style="margin-top:1rem;">Confirmacion (solo si eliges "Reemplazar")</label>
    <input type="text" id="confirm_replace" name="confirm_replace" maxlength="20" placeholder="BORRAR" autocomplete="off">
    <div class="hint">Si el modo es "Reemplazar", escribe <code>BORRAR</code> aqui para confirmar. En modo "Anadir" este campo no hace nada.</div>

    <div style="margin-top:1.4rem;">
      <button type="submit" class="btn">Restaurar copia</button>
    </div>
  </form>
</div>

<h2>Que copiar tu manualmente</h2>
<div class="card">
  <table>
    <tr>
      <th style="width:230px;">Imagenes subidas</th>
      <td class="muted">Carpeta <code>/uploads</code> del servidor. Descargala por FTP de vez en cuando.</td>
    </tr>
    <tr>
      <th>Base de datos completa</th>
      <td class="muted">phpMyAdmin de CDMON → pestana <strong>Exportar</strong> → formato SQL.
        Es la copia mas completa (incluye mensajes y analitica).</td>
    </tr>
    <tr>
      <th>Codigo fuente</th>
      <td class="muted">La carpeta del proyecto en tu PC. Subela a un repositorio privado
        de GitHub (<code>server/config.php</code> ya esta en <code>.gitignore</code>).</td>
    </tr>
  </table>
</div>

<?php admin_footer(); ?>
