<?php
/**
 * settings.php - Ajustes del sitio editables SIN recompilar la web.
 *
 * Todo lo de aqui se guarda en la tabla `settings` y lo lee el frontend
 * estatico desde /api/settings.php al cargar la pagina. Por eso los cambios
 * se ven al instante (basta con recargar), sin pasar por `npm run build`.
 */
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/partials/layout.php';
require_once __DIR__ . '/../lib/validate.php';
require_login();

// Ajustes gestionados desde esta pantalla: clave => tipo.
// 'bool' se guarda como '1'/'0'; 'text' tal cual (con limite de longitud).
const MANAGED = [
    'open_to_work'      => 'bool',
    'contact_enabled'   => 'bool',
    'analytics_enabled' => 'bool',
    'announcement_on'   => 'bool',
    'announcement_es'   => 'text',
    'announcement_en'   => 'text',
    'announcement_ca'   => 'text',
    'announcement_url'  => 'text',
];

$errors = [];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    csrf_check();

    // Validamos el enlace del banner antes de guardar nada: solo rutas
    // internas o https. Asi el frontend nunca recibe un javascript:...
    $url = trim((string) ($_POST['announcement_url'] ?? ''));
    if ($err = validate_public_url($url, 'El enlace del aviso')) {
        $errors[] = $err;
    }

    if (!$errors) {
        $changed = [];
        foreach (MANAGED as $key => $type) {
            if ($type === 'bool') {
                $value = isset($_POST[$key]) ? '1' : '0';
            } else {
                if (strpos($key, 'announcement_') === 0 && $key !== 'announcement_url') {
                    // Permitir saltos de línea y hasta 1000 caracteres para el banner en markdown
                    $value = mb_substr(trim((string) ($_POST[$key] ?? '')), 0, 1000);
                    // Quitamos otros caracteres de control pero dejamos \n y \r (\x0A, \x0D)
                    $value = (string) preg_replace('/[\x00-\x09\x0B\x0C\x0E-\x1F\x7F]+/u', '', $value);
                } else {
                    $value = mb_substr(trim((string) ($_POST[$key] ?? '')), 0, 300);
                    // Sin saltos de linea ni caracteres de control en textos cortos.
                    $value = (string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $value);
                }
            }
            if (setting_get($key, '') !== $value) {
                $changed[] = $key;
            }
            setting_set($key, $value);
        }
        log_activity('update', 'settings', null,
            $changed ? 'Cambiados: ' . implode(', ', $changed) : 'Guardado sin cambios');
        set_flash('ok', 'Ajustes guardados. Recarga la web para verlos aplicados.');
        redirect('settings.php');
    }
}

$v = static fn(string $k, string $d = ''): string => setting_get($k, $d);
$b = static fn(string $k, bool $d = true): bool => setting_on($k, $d);

admin_header('Ajustes', 'settings.php');
show_flash();
?>
<h1>Ajustes del sitio</h1>
<?php if ($errors): ?>
  <div class="flash err"><?= e(implode(' ', $errors)) ?></div>
<?php endif; ?>

<p class="hint" style="margin-bottom:1.25rem;">
  Estos ajustes se aplican <strong>al instante</strong>: la web los consulta al cargar.
  No hace falta recompilar ni volver a subir nada por FTP.
</p>

<form method="post">
  <?= csrf_field() ?>

  <h2>Disponibilidad</h2>
  <div class="card">
    <label class="checkline">
      <input type="checkbox" name="open_to_work" value="1" <?= $b('open_to_work', true) ? 'checked' : '' ?>>
      <span>
        <strong>Disponible para trabajar</strong>
        <span class="hint">Muestra el badge verde "Disponible" y el marco luminoso alrededor
          de tu foto. Desactivalo cuando no busques ofertas.</span>
      </span>
    </label>
  </div>

  <h2>Formulario de contacto</h2>
  <div class="card">
    <label class="checkline">
      <input type="checkbox" name="contact_enabled" value="1" <?= $b('contact_enabled', true) ? 'checked' : '' ?>>
      <span>
        <strong>Formulario de contacto activo</strong>
        <span class="hint">Si lo desactivas, el formulario deja de aceptar envios y muestra un
          aviso con tus enlaces directos (email y LinkedIn). Util si recibes spam.</span>
      </span>
    </label>
  </div>

  <h2>Analitica</h2>
  <div class="card">
    <label class="checkline">
      <input type="checkbox" name="analytics_enabled" value="1" <?= $b('analytics_enabled', true) ? 'checked' : '' ?>>
      <span>
        <strong>Registrar visitas</strong>
        <span class="hint">Guarda las visitas para la seccion Analitica (IP hasheada, sin
          cookies ni terceros). Si lo apagas, deja de registrarse nada nuevo; lo ya
          guardado se conserva.</span>
      </span>
    </label>
  </div>

  <h2>Aviso destacado (banner superior)</h2>
  <div class="card">
    <label class="checkline">
      <input type="checkbox" name="announcement_on" value="1" <?= $b('announcement_on', false) ? 'checked' : '' ?>>
      <span>
        <strong>Mostrar el aviso en la web</strong>
        <span class="hint">Aparece una franja fina arriba del todo, encima del menu.
          Solo se muestra si ademas escribes un texto abajo.</span>
      </span>
    </label>

    <div class="row3" style="margin-bottom:1rem;">
      <div>
        <label for="announcement_es">Texto en español (Markdown)</label>
        <textarea id="announcement_es" name="announcement_es" maxlength="1000" rows="3"
                  placeholder="**Nuevo** artículo sobre [detección de phishing](/#proyectos)"
                  style="width:100%; font-family:monospace; resize:vertical; font-size:0.85rem;"><?= e($v('announcement_es')) ?></textarea>
      </div>
      <div>
        <label for="announcement_en">Texto en inglés (Markdown)</label>
        <textarea id="announcement_en" name="announcement_en" maxlength="1000" rows="3"
                  placeholder="**New** article about [phishing detection](/#proyectos)"
                  style="width:100%; font-family:monospace; resize:vertical; font-size:0.85rem;"><?= e($v('announcement_en')) ?></textarea>
      </div>
      <div>
        <label for="announcement_ca">Texto en catalán (Markdown)</label>
        <textarea id="announcement_ca" name="announcement_ca" maxlength="1000" rows="3"
                  placeholder="**Nou** article sobre [detecció de phishing](/#proyectos)"
                  style="width:100%; font-family:monospace; resize:vertical; font-size:0.85rem;"><?= e($v('announcement_ca')) ?></textarea>
      </div>
    </div>
    <div class="hint" style="margin-bottom:1rem;">Si dejas el inglés o el catalán vacíos, se usará el texto en español. Puedes usar negritas (<code>**texto**</code>), cursivas (<code>*texto*</code>), código (<code>`texto`</code>) y enlaces (<code>[texto](URL)</code>).</div>

    <label for="announcement_url">Enlace del aviso <span class="faint">(opcional)</span></label>
    <input type="text" id="announcement_url" name="announcement_url" maxlength="300"
           value="<?= e($v('announcement_url')) ?>" placeholder="https://www.linkedin.com/posts/... o /#proyectos">
    <div class="hint">Debe empezar por <code>https://</code> o por <code>/</code>. Si lo dejas vacio,
      el aviso se muestra como texto sin enlace.</div>
  </div>

  <div style="margin:1.5rem 0;">
    <button type="submit" class="btn">Guardar ajustes</button>
    <a class="btn ghost" href="index.php">Cancelar</a>
  </div>
</form>

<h2>Que NO se edita aqui</h2>
<div class="card">
  <table>
    <tr>
      <th style="width:220px;">Experiencia laboral</th>
      <td class="muted">Es estatica: <code>src/data/experience.ts</code> + <code>npm run build</code>.</td>
    </tr>
    <tr>
      <th>Habilidades</th>
      <td class="muted"><code>src/data/skills.ts</code> + <code>npm run build</code>.</td>
    </tr>
    <tr>
      <th>Textos de la interfaz</th>
      <td class="muted"><code>src/i18n/ui.ts</code> (ES / EN / CA) + <code>npm run build</code>.</td>
    </tr>
    <tr>
      <th>Preguntas frecuentes (FAQ)</th>
      <td class="muted"><code>src/data/faq.ts</code> — tambien alimentan el SEO y a las IAs.</td>
    </tr>
    <tr>
      <th>Credenciales y seguridad</th>
      <td class="muted"><code>server/config.php</code> por FTP. Estado en <a href="security.php">Seguridad</a>.</td>
    </tr>
  </table>
</div>

<?php admin_footer(); ?>
