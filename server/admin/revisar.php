<?php
/**
 * revisar.php - Cola de revision (solo lectura): datos reales que piden un
 * vistazo. Hoy: certificaciones sin enlace de verificacion y mensajes sin leer.
 * No modifica nada; cada fila enlaza a la pantalla donde se arregla.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_login();

$LIMIT = 50;

$certs = db()->prepare(
    "SELECT id, name, issuer, issue_date, visible FROM certifications
     WHERE credential_url IS NULL OR credential_url = ''
     ORDER BY visible DESC, sort_order ASC, id DESC LIMIT ?"
);
$certs->bindValue(1, $LIMIT, PDO::PARAM_INT);
$certs->execute();
$certRows  = $certs->fetchAll();
$certTotal = (int) db()->query("SELECT COUNT(*) FROM certifications WHERE credential_url IS NULL OR credential_url = ''")->fetchColumn();

$msgs = db()->prepare(
    'SELECT id, name, subject, created_at FROM messages
     WHERE is_read = 0 AND is_archived = 0 ORDER BY created_at DESC LIMIT ?'
);
$msgs->bindValue(1, $LIMIT, PDO::PARAM_INT);
$msgs->execute();
$msgRows  = $msgs->fetchAll();
$msgTotal = (int) db()->query('SELECT COUNT(*) FROM messages WHERE is_read = 0 AND is_archived = 0')->fetchColumn();

admin_header('Revisar', 'revisar.php');
show_flash();
page_header('Revisar', 'Lo que conviene mirar: solo lectura, cada fila te lleva a donde se arregla.');
?>

<div class="row2">
  <section aria-labelledby="rev-certs">
    <h2 id="rev-certs">Certificaciones sin enlace de verificación <span class="faint">(<?= $certTotal ?>)</span></h2>
    <div class="card p-0">
      <?php if (!$certRows): ?>
        <p class="today-ok">Todas las certificaciones tienen enlace de verificación. No hay nada que añadir.</p>
      <?php else: ?>
        <ul class="today-list">
          <?php foreach ($certRows as $c): ?>
            <li class="today-item">
              <span class="today-text">
                <strong><?= e($c['name']) ?></strong>
                <span><?= e(trim(((string) $c['issuer']) . ((string) $c['issue_date'] !== '' ? ' · ' . $c['issue_date'] : ''), ' ·')) ?: 'Sin emisor ni fecha' ?> · <?= $c['visible'] ? 'visible en la web' : 'oculta' ?></span>
              </span>
              <a class="today-action" href="cert-edit.php?id=<?= (int) $c['id'] ?>&amp;space=site">Añadir enlace</a>
            </li>
          <?php endforeach; ?>
        </ul>
        <?php if ($certTotal > $LIMIT): ?>
          <p class="today-ok">Se muestran las primeras <?= $LIMIT ?>; el resto está en <a href="certifications.php?space=site">Certificaciones</a>.</p>
        <?php endif; ?>
      <?php endif; ?>
    </div>
  </section>

  <section aria-labelledby="rev-msgs">
    <h2 id="rev-msgs">Mensajes sin leer <span class="faint">(<?= $msgTotal ?>)</span></h2>
    <div class="card p-0">
      <?php if (!$msgRows): ?>
        <p class="today-ok">Buzón al día: no hay mensajes sin leer.</p>
      <?php else: ?>
        <ul class="today-list">
          <?php foreach ($msgRows as $m): ?>
            <li class="today-item">
              <span class="today-text">
                <strong><?= e($m['name']) ?></strong>
                <span><?= e((string) $m['subject'] !== '' ? $m['subject'] : '(sin asunto)') ?> · <?= e(substr((string) $m['created_at'], 0, 10)) ?></span>
              </span>
              <a class="today-action" href="messages.php?id=<?= (int) $m['id'] ?>&amp;space=site">Leer</a>
            </li>
          <?php endforeach; ?>
        </ul>
        <?php if ($msgTotal > $LIMIT): ?>
          <p class="today-ok">Se muestran los últimos <?= $LIMIT ?>; el resto está en <a href="messages.php?space=site">Mensajes</a>.</p>
        <?php endif; ?>
      <?php endif; ?>
    </div>
  </section>
</div>

<?php admin_footer(); ?>
