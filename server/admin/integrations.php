<?php
/**
 * integrations.php - Panel de integraciones externas gestionadas desde /admin.
 *
 * Hoy solo hay una: GitHub Stats (server/lib/github.php, server/api/github-
 * {stats,langs,streak}.php) -- las 3 tarjetas SVG animadas que usa el README
 * de perfil (github.com/eduolihez/eduolihez). No es un framework generico de
 * "integraciones" (se decidio explicitamente no construir eso todavia, ver
 * docs/designs/admin-dashboard.md): esta pagina es solo el panel de control
 * de ESTA integracion concreta. Si en el futuro hay una segunda, esta pagina
 * es donde anadir su propia seccion, con el mismo patron.
 *
 * Los ajustes viven en la tabla `settings` (claves `github_stats_*`), no en
 * config.php: asi se pueden cambiar sin FTP. config.php se sigue leyendo
 * como fallback (ver github_setting() en server/lib/github.php) para no
 * romper nada si esta pagina no se ha usado todavia.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/github.php';
require_once __DIR__ . '/../lib/svg_card.php';
require_login();

$errors = [];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();
    $action = (string) ($_POST['action'] ?? 'save');

    if ($action === 'refresh_cache') {
        // No hace falta borrar las filas: vaciar gh_profile_cache_at basta
        // para que github_profile_cached() lo trate como caducado en la
        // proxima peticion (ver esa funcion: exige $cachedAt !== '').
        setting_set(GITHUB_CACHE_AT, '');
        log_activity('update', 'integration', null, 'GitHub Stats: cache invalidada manualmente');
        set_flash('ok', 'Cache invalidada. La proxima visita a las tarjetas volvera a consultar GitHub.');
        redirect('integrations.php');
    }

    // --- action=save: guarda los ajustes del formulario ---------------------
    $username = mb_substr(trim((string) ($_POST['github_username'] ?? '')), 0, 60);
    $username = (string) preg_replace('/[^A-Za-z0-9_-]/', '', $username);
    if ($username === '') {
        $errors[] = 'El usuario de GitHub no puede estar vacio.';
    }

    $ttl = (int) ($_POST['github_ttl'] ?? 0);
    if ($ttl < 5 || $ttl > 10080) { // 5 min .. 7 dias
        $errors[] = 'La cache debe estar entre 5 y 10080 minutos (7 dias).';
    }

    // CSV de repos excluidos: normaliza (recorta espacios, quita vacios,
    // minusculas para que coincida con la comparacion case-insensitive de
    // github_fetch_profile()), pero guarda el CSV tal cual lo escribe el
    // usuario -- normalizar en exceso al guardar sorprende al releer el form.
    $excludeRaw = (string) ($_POST['github_exclude'] ?? '');
    $excludeList = array_filter(array_map('trim', explode(',', $excludeRaw)));
    $excludeCsv = mb_substr(implode(',', $excludeList), 0, 500);

    // CSS custom: sin limite de caracteres artificial mas alla de un tope
    // generoso (evita que alguien pegue algo descomunal por error), sin
    // validar sintaxis CSS -- ver svg_custom_css_block() sobre por que no
    // hace falta sanitizar mas: el autor es el propio dueno autenticado.
    $customCss = mb_substr((string) ($_POST['github_custom_css'] ?? ''), 0, 20000);

    // Token: campo tipo password que se deja en blanco a proposito al
    // recargar (nunca se re-imprime el valor guardado, ver el HTML abajo).
    // Solo se sobreescribe si el usuario escribe uno nuevo; en blanco significa
    // "no tocar", no "borrar" -- borrar el token por error rompe las 3
    // tarjetas del README en produccion, y un campo vacio enviado sin querer
    // (recarga del navegador, autocompletado raro) es un accidente facil.
    $newToken = trim((string) ($_POST['github_token'] ?? ''));

    if (!$errors) {
        $changed = [];
        $apply = static function (string $key, string $value) use (&$changed): void {
            if (setting_get($key, '') !== $value) {
                $changed[] = $key;
            }
            setting_set($key, $value);
        };
        $apply('github_stats_username', $username);
        $apply('github_stats_cache_ttl_minutes', (string) $ttl);
        $apply('github_stats_exclude_repos', $excludeCsv);
        $apply('github_stats_custom_css', $customCss);
        if ($newToken !== '') {
            $apply('github_stats_token', $newToken);
        }
        // Cualquier cambio invalida la cache: si cambio el usuario o los repos
        // excluidos, la tarjeta en cache ya no refleja los ajustes nuevos.
        if ($changed) {
            setting_set(GITHUB_CACHE_AT, '');
        }
        log_activity('update', 'integration', null,
            $changed ? 'GitHub Stats: ' . implode(', ', $changed) : 'GitHub Stats: guardado sin cambios');
        set_flash('ok', 'Ajustes de GitHub Stats guardados.' . ($changed ? ' Cache invalidada.' : ''));
        redirect('integrations.php');
    }
}

$hasToken   = github_configured();
$tokenFromSettings = trim(setting_get('github_stats_token', '')) !== '';
$username   = github_username();
$ttl        = (int) github_setting('cache_ttl_minutes', '360');
$excludeCsv = (function (): string {
    $fromSettings = trim(setting_get('github_stats_exclude_repos', ''));
    if ($fromSettings !== '') {
        return $fromSettings;
    }
    // Solo para mostrar el valor heredado de config.php la primera vez que
    // se abre esta pantalla (antes de guardar nada desde aqui todavia).
    $fromConfig = (array) (config()['github']['exclude_from_languages'] ?? []);
    return implode(',', $fromConfig);
})();
$customCssValue = setting_get('github_stats_custom_css', '');
$cachedAt = setting_get(GITHUB_CACHE_AT, '');

admin_header('Integraciones', 'integrations.php');
show_flash();
?>
<h1>Integraciones</h1>
<p class="hint" style="margin-bottom:1.25rem;">
  Servicios externos que este sitio consulta y cachea. Hoy solo hay uno: las
  tarjetas SVG animadas de GitHub que usa el
  <a href="https://github.com/eduolihez/eduolihez" target="_blank" rel="noopener">README de perfil</a>.
</p>

<?php if ($errors): ?>
  <div class="flash err"><?= e(implode(' ', $errors)) ?></div>
<?php endif; ?>

<div class="toolbar">
  <h2 style="margin:0;">GitHub Stats</h2>
  <span class="pill <?= $hasToken ? 'on' : 'warn' ?>"><?= $hasToken ? 'Activa' : 'Sin token' ?></span>
</div>

<div class="card">
  <table style="margin-bottom:1rem;">
    <tr>
      <th style="width:220px;">Token</th>
      <td>
        <?php if ($hasToken): ?>
          <span class="pill on">Configurado</span>
          <span class="faint" style="font-size:.85rem;">
            (<?= $tokenFromSettings ? 'desde este panel' : 'heredado de config.php — guarda aquí uno nuevo para pasar a gestionarlo desde el panel' ?>)
          </span>
        <?php else: ?>
          <span class="pill warn">Sin configurar</span> — las tarjetas del README muestran un aviso hasta que se rellene.
        <?php endif; ?>
      </td>
    </tr>
    <tr>
      <th>Última consulta a GitHub</th>
      <td><?= $cachedAt !== '' ? e(ago($cachedAt)) : '<span class="faint">nunca (o cache recién invalidada)</span>' ?></td>
    </tr>
    <tr>
      <th>Próxima consulta</th>
      <td class="faint">Cuando alguien vea las tarjetas y hayan pasado <?= (int) $ttl ?> minutos desde la última, o al pulsar "Refrescar ahora".</td>
    </tr>
  </table>

  <form method="post" style="display:inline;">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="refresh_cache">
    <button type="submit" class="btn ghost sm">Refrescar caché ahora</button>
  </form>
</div>

<h2>Vista previa en vivo</h2>
<div class="card">
  <div class="scroll-x" style="display:flex; gap:1rem; flex-wrap:wrap;">
    <img src="/api/github-stats.php" alt="GitHub Stats" height="165" style="border-radius:8px;">
    <img src="/api/github-langs.php" alt="Top Languages" height="165" style="border-radius:8px;">
    <img src="/api/github-streak.php" alt="GitHub Streak" height="165" style="border-radius:8px;">
  </div>
  <p class="hint" style="margin-top:.75rem; margin-bottom:0;">
    Estas imágenes se sirven con caché HTTP corta; si acabas de refrescar o guardar,
    puede que tu navegador siga mostrando la versión anterior — recarga forzando (Ctrl/Cmd+Shift+R) si hace falta.
  </p>
</div>

<h2>Ajustes</h2>
<form method="post">
  <?= csrf_field() ?>
  <input type="hidden" name="action" value="save">
  <div class="card">
    <label for="github_username">Usuario de GitHub</label>
    <input type="text" id="github_username" name="github_username" maxlength="60"
           value="<?= e($username) ?>" pattern="[A-Za-z0-9_-]+" required>
    <div class="hint">El perfil cuyas estadísticas se muestran.</div>

    <label for="github_token" style="margin-top:1rem;">Token de GitHub</label>
    <input type="password" id="github_token" name="github_token" maxlength="255"
           placeholder="<?= $hasToken ? '•••••••••••••••••••••• (déjalo en blanco para no cambiarlo)' : 'ghp_…' ?>"
           autocomplete="off">
    <div class="hint">
      Classic, sin scopes (Settings → Developer settings → Personal access tokens).
      Nunca se vuelve a mostrar una vez guardado; deja el campo en blanco para conservar el actual.
    </div>

    <label for="github_ttl" style="margin-top:1rem;">Minutos de caché</label>
    <input type="number" id="github_ttl" name="github_ttl" min="5" max="10080" value="<?= (int) $ttl ?>" required style="max-width:160px;">
    <div class="hint">Cuánto se reutilizan los datos antes de volver a consultar GitHub. 360 = 6 horas.</div>

    <label for="github_exclude" style="margin-top:1rem;">Repos excluidos del cálculo de lenguajes</label>
    <input type="text" id="github_exclude" name="github_exclude" maxlength="500"
           value="<?= e($excludeCsv) ?>" placeholder="northgate-browser, otro-repo">
    <div class="hint">
      Separados por comas. Útil para forks manuales con código ajeno vendorizado que
      distorsionarían el % de lenguajes (ver el caso de <code>northgate-browser</code> en el commit
      que introdujo esto).
    </div>

    <label for="github_custom_css" style="margin-top:1rem;">CSS personalizado para las tarjetas</label>
    <textarea id="github_custom_css" name="github_custom_css" rows="8" maxlength="20000"
              placeholder=".card-title { fill: #ff00ff; }"
              style="width:100%; font-family:monospace; resize:vertical; font-size:.85rem;"><?= e($customCssValue) ?></textarea>
    <div class="hint">
      Se añade DESPUÉS del CSS por defecto de la tarjeta, así que puede sobreescribir cualquier
      regla (mismas clases: <code>.card-title</code>, <code>.stat-label</code>, <code>.stat-value</code>).
      Sin validar sintaxis — un error aquí no rompe la tarjeta, como mucho no aplica el cambio.
    </div>
  </div>

  <div style="margin:1.5rem 0;">
    <button type="submit" class="btn">Guardar ajustes</button>
    <a class="btn ghost" href="index.php">Cancelar</a>
  </div>
</form>

<?php admin_footer(); ?>
