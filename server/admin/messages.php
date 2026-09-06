<?php
/**
 * messages.php - Buzon de contacto.
 *
 * Lista con busqueda, filtros (sin leer / destacados / archivados), paginacion
 * y acciones en lote. `?id=N` abre el detalle y lo marca como leido.
 * Export a CSV protegido contra inyeccion de formulas.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/ua.php';
require_login();

const PER_PAGE = 25;

// --- Filtros de la URL ------------------------------------------------------
$filter = $_GET['f'] ?? 'inbox';
if (!in_array($filter, ['inbox', 'unread', 'starred', 'archived', 'all'], true)) {
    $filter = 'inbox';
}
$search = trim((string) ($_GET['q' ] ?? ''));
$search = mb_substr($search, 0, 80);
$page   = max(1, (int) ($_GET['p'] ?? 1));

/** Construye el WHERE y sus parametros a partir del filtro y la busqueda. */
function build_where(string $filter, string $search): array
{
    $where  = [];
    $params = [];

    switch ($filter) {
        case 'unread':   $where[] = 'is_read = 0 AND is_archived = 0'; break;
        case 'starred':  $where[] = 'is_starred = 1'; break;
        case 'archived': $where[] = 'is_archived = 1'; break;
        case 'all':      break;                       // todo, sin filtro
        default:         $where[] = 'is_archived = 0'; // bandeja de entrada
    }

    if ($search !== '') {
        // LIKE con placeholders: el termino nunca se concatena en el SQL.
        $where[] = '(name LIKE ? OR email LIKE ? OR subject LIKE ? OR message LIKE ?)';
        $like = '%' . str_replace(['%', '_'], ['\%', '\_'], $search) . '%';
        array_push($params, $like, $like, $like, $like);
    }

    return [$where ? 'WHERE ' . implode(' AND ', $where) : '', $params];
}

// --- Exportacion CSV (respeta el filtro y la busqueda activos) --------------
if (($_GET['export'] ?? '') === 'csv') {
    [$whereSql, $params] = build_where($filter, $search);
    $st = db()->prepare(
        "SELECT id, name, email, subject, message, ip_address, is_read, is_starred, is_archived, created_at
         FROM messages $whereSql ORDER BY created_at DESC"
    );
    $st->execute($params);
    $rows = $st->fetchAll();

    log_activity('export', 'message', null, 'Exportacion CSV del buzon (' . count($rows) . ' filas)');

    csv_download(
        'mensajes-' . date('Y-m-d') . '.csv',
        ['ID', 'Nombre', 'Email', 'Asunto', 'Mensaje', 'IP', 'Leido', 'Destacado', 'Archivado', 'Fecha'],
        array_map(static fn(array $r): array => [
            $r['id'], $r['name'], $r['email'], $r['subject'], $r['message'], $r['ip_address'],
            $r['is_read'] ? 'si' : 'no',
            $r['is_starred'] ? 'si' : 'no',
            $r['is_archived'] ? 'si' : 'no',
            $r['created_at'],
        ], $rows)
    );
}

// --- Acciones (POST) --------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? '');
    $id     = (int) ($_POST['id'] ?? 0);

    // IDs seleccionados en las acciones en lote.
    $ids = array_values(array_filter(array_map('intval', (array) ($_POST['ids'] ?? [])), fn($v) => $v > 0));
    if ($id > 0) {
        $ids = [$id];
    }

    // Vuelve a la misma vista (filtro, busqueda y pagina) tras la accion.
    $back = 'messages.php?f=' . urlencode($filter)
        . ($search !== '' ? '&q=' . urlencode($search) : '')
        . ($page > 1 ? '&p=' . $page : '');

    // Si la accion viene del detalle de un mensaje (la URL lleva ?id=N) y no
    // es un borrado, volvemos al propio mensaje en vez de a la lista: destacar
    // algo y perder de vista lo que estabas leyendo es molesto.
    // 'unread' vuelve tambien a la lista: si volviera al detalle, abrirlo lo
    // marcaria como leido otra vez y el boton no serviria de nada.
    $fromDetail = (int) ($_GET['id'] ?? 0);
    if ($fromDetail > 0 && !in_array($action, ['delete', 'archive', 'unread'], true)) {
        $back = 'messages.php?id=' . $fromDetail;
    }

    if ($action === 'mark_all_read') {
        db()->query('UPDATE messages SET is_read = 1 WHERE is_read = 0 AND is_archived = 0');
        log_activity('update', 'message', null, 'Marcar todo como leido');
        set_flash('ok', 'Todos los mensajes se han marcado como leidos.');
        redirect($back);
    }

    if ($ids) {
        // Lista de placeholders (?, ?, ?) segun cuantos IDs haya.
        $in = implode(',', array_fill(0, count($ids), '?'));
        $n  = count($ids);

        $map = [
            'read'     => ["UPDATE messages SET is_read = 1 WHERE id IN ($in)",    "$n mensaje(s) marcados como leidos."],
            'unread'   => ["UPDATE messages SET is_read = 0 WHERE id IN ($in)",    "$n mensaje(s) marcados como no leidos."],
            'star'     => ["UPDATE messages SET is_starred = 1 WHERE id IN ($in)", "$n mensaje(s) destacados."],
            'unstar'   => ["UPDATE messages SET is_starred = 0 WHERE id IN ($in)", "$n mensaje(s) sin destacar."],
            'archive'  => ["UPDATE messages SET is_archived = 1 WHERE id IN ($in)", "$n mensaje(s) archivados."],
            'unarchive'=> ["UPDATE messages SET is_archived = 0 WHERE id IN ($in)", "$n mensaje(s) devueltos a la bandeja."],
            'delete'   => ["DELETE FROM messages WHERE id IN ($in)",               "$n mensaje(s) eliminados."],
        ];

        if (isset($map[$action])) {
            [$sql, $msg] = $map[$action];
            db()->prepare($sql)->execute($ids);
            log_activity($action === 'delete' ? 'delete' : 'update', 'message', $ids[0] ?? null,
                ucfirst($action) . ' · ' . $n . ' mensaje(s)');
            set_flash('ok', $msg);
            redirect($back);
        }
    }

    set_flash('err', 'No se selecciono ningun mensaje.');
    redirect($back);
}

// ============================================================================
// VISTA DETALLE
// ============================================================================
$viewId = (int) ($_GET['id'] ?? 0);

if ($viewId > 0) {
    $stmt = db()->prepare('SELECT * FROM messages WHERE id = ?');
    $stmt->execute([$viewId]);
    $m = $stmt->fetch();
    if (!$m) {
        set_flash('err', 'Mensaje no encontrado.');
        redirect('messages.php');
    }
    if ((int) $m['is_read'] === 0) {
        db()->prepare('UPDATE messages SET is_read = 1 WHERE id = ?')->execute([$viewId]);
    }

    // Navegacion anterior / siguiente dentro del buzon.
    $prev = db()->prepare('SELECT id FROM messages WHERE created_at > ? ORDER BY created_at ASC LIMIT 1');
    $prev->execute([$m['created_at']]);
    $prevId = (int) $prev->fetchColumn();
    $next = db()->prepare('SELECT id FROM messages WHERE created_at < ? ORDER BY created_at DESC LIMIT 1');
    $next->execute([$m['created_at']]);
    $nextId = (int) $next->fetchColumn();

    // Otros mensajes del mismo remitente (util para detectar spam o seguimiento).
    $sameSender = db()->prepare(
        'SELECT id, subject, created_at FROM messages WHERE email = ? AND id <> ? ORDER BY created_at DESC LIMIT 5'
    );
    $sameSender->execute([$m['email'], $viewId]);
    $others = $sameSender->fetchAll();

    $ua = ua_parse((string) ($m['user_agent'] ?? ''));

    admin_header('Mensaje', 'messages.php');
    show_flash();
    ?>
    <div class="subdash">
    <div class="toolbar">
      <h1 style="margin:0;">Mensaje #<?= (int) $m['id'] ?></h1>
      <div class="actions">
        <a class="btn ghost sm <?= $prevId ? '' : 'disabled' ?>"
           href="<?= $prevId ? 'messages.php?id=' . $prevId : '#' ?>" <?= $prevId ? '' : 'disabled' ?>>&uarr; Mas reciente</a>
        <a class="btn ghost sm <?= $nextId ? '' : 'disabled' ?>"
           href="<?= $nextId ? 'messages.php?id=' . $nextId : '#' ?>" <?= $nextId ? '' : 'disabled' ?>>&darr; Mas antiguo</a>
        <a class="btn ghost sm" href="messages.php">&larr; Volver al buzon</a>
      </div>
    </div>

    <div class="card">
      <table>
        <tr><th style="width:130px;">De</th><td><strong><?= e($m['name']) ?></strong></td></tr>
        <tr><th>Email</th><td><a href="mailto:<?= e($m['email']) ?>"><?= e($m['email']) ?></a></td></tr>
        <tr><th>Asunto</th><td><?= e($m['subject'] !== '' ? $m['subject'] : '(sin asunto)') ?></td></tr>
        <tr><th>Fecha</th><td class="muted"><?= e(fdate($m['created_at'], 'd/m/Y H:i:s')) ?> · <?= e(ago($m['created_at'])) ?></td></tr>
        <tr><th>IP</th><td class="faint mono"><?= e($m['ip_address']) ?></td></tr>
        <tr><th>Dispositivo</th><td class="faint"><?= e($ua['browser'] . ' · ' . $ua['os'] . ' · ' . $ua['device']) ?></td></tr>
        <tr><th>Estado</th><td>
          <span class="pill <?= (int) $m['is_starred'] ? 'warn' : 'off' ?>"><?= (int) $m['is_starred'] ? '★ Destacado' : 'Sin destacar' ?></span>
          <span class="pill <?= (int) $m['is_archived'] ? 'off' : 'on' ?>"><?= (int) $m['is_archived'] ? 'Archivado' : 'En bandeja' ?></span>
        </td></tr>
      </table>

      <h2>Contenido</h2>
      <div class="card inset" style="white-space:pre-wrap;"><?= e($m['message']) ?></div>

      <div class="actions" style="margin-top:1rem;">
        <a class="btn" href="mailto:<?= e($m['email']) ?>?subject=<?= rawurlencode('RE: ' . $m['subject']) ?>">Responder por email</a>

        <form method="post" style="display:inline;">
          <?= csrf_field() ?>
          <input type="hidden" name="action" value="<?= (int) $m['is_starred'] ? 'unstar' : 'star' ?>">
          <input type="hidden" name="id" value="<?= (int) $m['id'] ?>">
          <button class="btn ghost" type="submit"><?= (int) $m['is_starred'] ? 'Quitar destacado' : '★ Destacar' ?></button>
        </form>

        <form method="post" style="display:inline;">
          <?= csrf_field() ?>
          <input type="hidden" name="action" value="unread">
          <input type="hidden" name="id" value="<?= (int) $m['id'] ?>">
          <button class="btn ghost" type="submit">Marcar como no leido</button>
        </form>

        <form method="post" style="display:inline;">
          <?= csrf_field() ?>
          <input type="hidden" name="action" value="<?= (int) $m['is_archived'] ? 'unarchive' : 'archive' ?>">
          <input type="hidden" name="id" value="<?= (int) $m['id'] ?>">
          <button class="btn ghost" type="submit"><?= (int) $m['is_archived'] ? 'Desarchivar' : 'Archivar' ?></button>
        </form>

        <form method="post" data-confirm="¿Eliminar este mensaje? No se puede deshacer." style="display:inline;">
          <?= csrf_field() ?>
          <input type="hidden" name="action" value="delete">
          <input type="hidden" name="id" value="<?= (int) $m['id'] ?>">
          <button class="btn danger" type="submit">Eliminar</button>
        </form>
      </div>
    </div>

    <?php if ($others): ?>
      <h2>Otros mensajes de <?= e($m['email']) ?></h2>
      <div class="card" style="padding:0;">
        <table>
          <tbody>
            <?php foreach ($others as $o): ?>
              <tr>
                <td><a href="messages.php?id=<?= (int) $o['id'] ?>"><?= e($o['subject'] !== '' ? $o['subject'] : '(sin asunto)') ?></a></td>
                <td class="faint nowrap" style="text-align:right;"><?= e(fdate($o['created_at'])) ?></td>
              </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    <?php endif; ?>
    </div><!-- /.subdash -->
    <?php
    admin_footer();
    exit;
}

// ============================================================================
// VISTA LISTA
// ============================================================================
[$whereSql, $params] = build_where($filter, $search);

$totalRows = 0;
try {
    $cnt = db()->prepare("SELECT COUNT(*) FROM messages $whereSql");
    $cnt->execute($params);
    $totalRows = (int) $cnt->fetchColumn();
} catch (Throwable $e) {
    // tabla vacia o inexistente
}
$totalPages = max(1, (int) ceil($totalRows / PER_PAGE));
$page   = min($page, $totalPages);
$offset = ($page - 1) * PER_PAGE;

$rows = [];
try {
    // LIMIT/OFFSET se interpolan como enteros ya validados (no admiten
    // placeholders con prepares reales en MySQL).
    $st = db()->prepare(
        "SELECT id, name, email, subject, is_read, is_starred, is_archived, created_at
         FROM messages $whereSql ORDER BY created_at DESC
         LIMIT " . PER_PAGE . ' OFFSET ' . (int) $offset
    );
    $st->execute($params);
    $rows = $st->fetchAll();
} catch (Throwable $e) {
    $rows = [];
}

// Contadores de las pestanas.
$counts = ['inbox' => 0, 'unread' => 0, 'starred' => 0, 'archived' => 0, 'all' => 0];
try {
    $c = db()->query(
        'SELECT
            SUM(is_archived = 0) AS inbox,
            SUM(is_read = 0 AND is_archived = 0) AS unread,
            SUM(is_starred = 1) AS starred,
            SUM(is_archived = 1) AS archived,
            COUNT(*) AS total
         FROM messages'
    )->fetch();
    $counts = [
        'inbox'    => (int) $c['inbox'],
        'unread'   => (int) $c['unread'],
        'starred'  => (int) $c['starred'],
        'archived' => (int) $c['archived'],
        'all'      => (int) $c['total'],
    ];
} catch (Throwable $e) {
    // sin datos
}

/** URL de la lista conservando filtro/busqueda. */
function list_url(string $filter, string $search, int $page = 1): string
{
    $qs = ['f' => $filter];
    if ($search !== '') $qs['q'] = $search;
    if ($page > 1)      $qs['p'] = $page;
    return 'messages.php?' . http_build_query($qs);
}

$tabs = [
    'inbox'    => 'Bandeja',
    'unread'   => 'Sin leer',
    'starred'  => 'Destacados',
    'archived' => 'Archivados',
    'all'      => 'Todos',
];

admin_header('Mensajes', 'messages.php');
show_flash();
?>
<div class="subdash">
<div class="toolbar">
  <h1 style="margin:0;">Buzon de contacto</h1>
  <div class="actions">
    <?php if ($counts['unread'] > 0): ?>
      <form method="post" data-confirm="¿Marcar TODOS los mensajes como leidos?" style="display:inline;">
        <?= csrf_field() ?>
        <input type="hidden" name="action" value="mark_all_read">
        <button class="btn ghost sm" type="submit">Marcar todo como leido</button>
      </form>
    <?php endif; ?>
    <a class="btn ghost sm" href="<?= e(list_url($filter, $search)) ?>&amp;export=csv">Exportar CSV</a>
  </div>
</div>

<div class="tabs">
  <?php foreach ($tabs as $key => $label): ?>
    <a class="<?= $filter === $key ? 'active' : '' ?>" href="<?= e(list_url($key, $search)) ?>">
      <?= e($label) ?> <span class="faint">(<?= $counts[$key] ?>)</span>
    </a>
  <?php endforeach; ?>
</div>

<form method="get" class="card" style="display:flex; gap:.6rem; align-items:center; padding:.75rem 1rem;">
  <input type="hidden" name="f" value="<?= e($filter) ?>">
  <input type="search" name="q" value="<?= e($search) ?>" placeholder="Buscar por nombre, email, asunto o texto..." style="flex:1;">
  <button class="btn sm" type="submit">Buscar</button>
  <?php if ($search !== ''): ?>
    <a class="btn ghost sm" href="<?= e(list_url($filter, '')) ?>">Limpiar</a>
  <?php endif; ?>
</form>

<form method="post" id="bulk-form">
  <?= csrf_field() ?>
  <div class="card" style="padding:.6rem 1rem; display:flex; gap:.5rem; flex-wrap:wrap; align-items:center;">
    <label style="margin:0; font-weight:400; display:flex; align-items:center; gap:.4rem;">
      <input type="checkbox" id="check-all" style="width:auto;"> <span class="faint">Seleccionar todo</span>
    </label>
    <span class="faint" style="margin-right:.5rem;">Acciones:</span>
    <button class="btn ghost sm" type="submit" name="action" value="read">Leido</button>
    <button class="btn ghost sm" type="submit" name="action" value="unread">No leido</button>
    <button class="btn ghost sm" type="submit" name="action" value="star">★ Destacar</button>
    <button class="btn ghost sm" type="submit" name="action" value="archive">Archivar</button>
    <button class="btn ghost sm" type="submit" name="action" value="unarchive">Desarchivar</button>
    <button class="btn danger sm" type="submit" name="action" value="delete"
            data-confirm-btn="¿Eliminar los mensajes seleccionados? No se puede deshacer.">Borrar</button>
  </div>

  <div class="card" style="padding:0;">
    <div class="scroll-x">
      <table>
        <thead>
          <tr>
            <th style="width:34px;"></th>
            <th>De</th>
            <th>Asunto</th>
            <th>Fecha</th>
            <th style="text-align:right;">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <?php if (!$rows): ?>
            <tr><td colspan="5" class="empty">
              <?= $search !== '' ? 'Ningun mensaje coincide con la busqueda.' : 'No hay mensajes en esta vista.' ?>
            </td></tr>
          <?php endif; ?>
          <?php foreach ($rows as $m): ?>
            <?php $unreadRow = ((int) $m['is_read'] === 0); ?>
            <tr>
              <td><input type="checkbox" name="ids[]" value="<?= (int) $m['id'] ?>" class="row-check" style="width:auto;"></td>
              <td>
                <?php if ((int) $m['is_starred']): ?><span title="Destacado" style="color:var(--warn);">★</span><?php endif; ?>
                <?php if ($unreadRow): ?><span class="pill on" style="margin-right:.3rem;">Nuevo</span><?php endif; ?>
                <a href="messages.php?id=<?= (int) $m['id'] ?>" style="<?= $unreadRow ? 'font-weight:700;' : '' ?>">
                  <?= e($m['name']) ?>
                </a>
                <div class="faint"><?= e($m['email']) ?></div>
              </td>
              <td class="<?= $unreadRow ? '' : 'muted' ?>">
                <a href="messages.php?id=<?= (int) $m['id'] ?>" style="color:inherit; <?= $unreadRow ? 'font-weight:600;' : '' ?>">
                  <?= e($m['subject'] !== '' ? $m['subject'] : '(sin asunto)') ?>
                </a>
                <?php if ((int) $m['is_archived']): ?><span class="pill off" style="margin-left:.3rem;">Archivado</span><?php endif; ?>
              </td>
              <td class="faint nowrap"><?= e(fdate($m['created_at'])) ?><br><span style="font-size:.75rem;"><?= e(ago($m['created_at'])) ?></span></td>
              <td>
                <div class="actions" style="justify-content:flex-end;">
                  <a class="btn ghost sm" href="messages.php?id=<?= (int) $m['id'] ?>">Ver</a>
                </div>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>
</form>

<?php if ($totalPages > 1): ?>
  <div class="actions" style="justify-content:center; margin-top:1rem;">
    <?php if ($page > 1): ?>
      <a class="btn ghost sm" href="<?= e(list_url($filter, $search, $page - 1)) ?>">&larr; Anterior</a>
    <?php endif; ?>
    <span class="faint">Pagina <?= $page ?> de <?= $totalPages ?> · <?= number_format($totalRows) ?> mensajes</span>
    <?php if ($page < $totalPages): ?>
      <a class="btn ghost sm" href="<?= e(list_url($filter, $search, $page + 1)) ?>">Siguiente &rarr;</a>
    <?php endif; ?>
  </div>
<?php endif; ?>

</div><!-- /.subdash -->
<?php admin_footer(); ?>
