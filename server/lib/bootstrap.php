<?php
/**
 * bootstrap.php - Arranque comun a TODO el backend (API publica y panel).
 * ---------------------------------------------------------------------------
 * Lo incluyen lib/http.php (API) y admin/auth.php (panel), asi que basta con
 * tocar este archivo para cambiar el comportamiento global.
 *
 * Que hace:
 *   - Apaga la salida de errores en produccion (evita filtrar rutas y SQL).
 *   - Fija la zona horaria (para que las fechas del panel cuadren).
 *   - Cabeceras de seguridad basicas para respuestas PHP.
 *   - Helpers de ajustes (settings) y de registro de auditoria (activity_log).
 */

require_once __DIR__ . '/../db.php';

// ---------------------------------------------------------------------------
// Runtime seguro
// ---------------------------------------------------------------------------
(function (): void {
    $cfg   = config();
    $debug = !empty($cfg['debug']);

    // En produccion NUNCA mostramos errores al visitante: solo al log del hosting.
    // Un warning de PHP puede revelar rutas absolutas, credenciales o SQL.
    ini_set('display_errors', $debug ? '1' : '0');
    ini_set('display_startup_errors', $debug ? '1' : '0');
    ini_set('log_errors', '1');
    error_reporting($debug ? E_ALL : (E_ALL & ~E_DEPRECATED & ~E_NOTICE));

    // Zona horaria: si no se fija, PHP avisa y las fechas salen en UTC.
    $tz = $cfg['timezone'] ?? 'Europe/Madrid';
    if (is_string($tz) && $tz !== '') {
        @date_default_timezone_set($tz);
    }

    // Endurecimiento de sesiones (aplica a las paginas del panel).
    // use_strict_mode evita que un atacante fije un ID de sesion propio.
    if (session_status() === PHP_SESSION_NONE) {
        ini_set('session.use_strict_mode', '1');
        ini_set('session.use_only_cookies', '1');
        ini_set('session.cookie_httponly', '1');
    }
})();

/**
 * Cabeceras de seguridad para cualquier respuesta generada por PHP.
 * (El .htaccess ya las pone para los archivos estaticos; esto cubre el caso
 * de que mod_headers no este disponible o la respuesta venga de PHP.)
 */
function send_security_headers(bool $noindex = true): void
{
    if (headers_sent()) {
        return;
    }
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('Referrer-Policy: strict-origin-when-cross-origin');
    if ($noindex) {
        // El API y el panel nunca deben aparecer en Google.
        header('X-Robots-Tag: noindex, nofollow, noarchive');
    }
}

/**
 * Comprueba si la base de datos esta al dia con lo que espera el codigo.
 *
 * El panel usa tablas y columnas que solo existen despues de importar
 * `database/schema.sql`. Sin esta comprobacion, entrar al buzon o al blog con
 * una base de datos antigua daria una pagina en blanco (error fatal de SQL)
 * sin ninguna pista de que hacer.
 *
 * IMPORTANTE: de `posts` se comprueban las COLUMNAS, no solo que la tabla
 * exista. Una version antigua del esquema creaba una tabla `posts` con otra
 * forma (title_es, body_es...) que el codigo no sabe leer; comprobar solo el
 * nombre daba por buena esa tabla y el blog fallaba igualmente.
 *
 * @return string[] Lista de lo que falta. Array vacio = todo correcto.
 */
function migration_pending(): array
{
    static $missing = null;
    if ($missing !== null) {
        return $missing;
    }
    $missing = [];

    try {
        $pdo = db();

        // Tablas que deben existir.
        foreach (['activity_log', 'posts'] as $table) {
            if (!$pdo->query("SHOW TABLES LIKE " . $pdo->quote($table))->fetchColumn()) {
                $missing[] = "tabla $table";
            }
        }

        $need = [
            'messages' => ['is_starred', 'is_archived'],
            'visits'   => ['device', 'browser', 'os', 'lang', 'is_bot'],
            'posts'    => ['title', 'slug', 'summary', 'content', 'lang', 'visible', 'tags', 'published_at'],
            'projects' => ['badges'],
        ];
        foreach ($need as $table => $columns) {
            if (in_array("tabla $table", $missing, true)) {
                continue; // la tabla entera falta: no hace falta listar sus columnas
            }
            $have = $pdo->query("SHOW COLUMNS FROM `$table`")->fetchAll(PDO::FETCH_COLUMN);
            foreach ($columns as $col) {
                if (!in_array($col, $have, true)) {
                    $missing[] = "columna $table.$col";
                }
            }
        }
    } catch (Throwable $e) {
        // Si ni siquiera podemos consultar el esquema, no bloqueamos el panel:
        // ya habra un error mas explicito en otro sitio.
        $missing = [];
    }

    return $missing;
}

// ---------------------------------------------------------------------------
// Ajustes del sitio (tabla `settings`)
// ---------------------------------------------------------------------------

/** Devuelve TODOS los ajustes como array clave => valor (cacheado por peticion). */
function settings_all(bool $fresh = false): array
{
    static $cache = null;
    if ($cache !== null && !$fresh) {
        return $cache;
    }
    $cache = [];
    try {
        foreach (db()->query('SELECT `key`, `value` FROM settings')->fetchAll() as $row) {
            $cache[$row['key']] = (string) $row['value'];
        }
    } catch (Throwable $e) {
        // Si la tabla no existe todavia, devolvemos vacio y se usan los defectos.
    }
    return $cache;
}

/** Lee un ajuste con valor por defecto. */
function setting_get(string $key, string $default = ''): string
{
    $all = settings_all();
    return array_key_exists($key, $all) && $all[$key] !== '' ? $all[$key] : $default;
}

/** True si un ajuste booleano ('1'/'0') esta activado. */
function setting_on(string $key, bool $default = true): bool
{
    $all = settings_all();
    if (!array_key_exists($key, $all)) {
        return $default;
    }
    return $all[$key] === '1';
}

/** Guarda (crea o actualiza) un ajuste. */
function setting_set(string $key, string $value): void
{
    db()->prepare(
        'INSERT INTO settings (`key`, `value`, updated_at) VALUES (?, ?, NOW())
         ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), updated_at = NOW()'
    )->execute([$key, $value]);
    settings_all(true); // refresca la cache de esta peticion
}

/**
 * Renumera la columna `sort_order` de una tabla a 1, 2, 3... respetando el
 * orden actual. Se llama antes de mover un elemento arriba/abajo: si varios
 * comparten el mismo numero (todos a 0, por ejemplo), intercambiarlos no
 * cambiaria nada.
 *
 * $table esta en lista blanca porque se interpola en el SQL (los nombres de
 * tabla no admiten placeholders).
 */
function normalize_sort_order(string $table): void
{
    if (!in_array($table, ['projects', 'certifications'], true)) {
        return;
    }
    try {
        $ids = db()->query("SELECT id FROM `$table` ORDER BY sort_order ASC, id ASC")
            ->fetchAll(PDO::FETCH_COLUMN);
        $upd = db()->prepare("UPDATE `$table` SET sort_order = ? WHERE id = ?");
        foreach ($ids as $i => $id) {
            $upd->execute([$i + 1, (int) $id]);
        }
    } catch (Throwable $e) {
        // si falla, el orden simplemente se queda como estaba
    }
}

// ---------------------------------------------------------------------------
// Registro de auditoria (tabla `activity_log`)
// ---------------------------------------------------------------------------

/**
 * Anota una accion del panel. Nunca lanza excepciones: si el log falla,
 * la operacion principal debe seguir adelante.
 */
function log_activity(
    string $action,
    ?string $entity = null,
    ?int $entityId = null,
    string $details = ''
): void {
    try {
        db()->prepare(
            'INSERT INTO activity_log (admin_id, username, action, entity, entity_id, details, ip_address, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, NOW())'
        )->execute([
            isset($_SESSION['admin_id']) ? (int) $_SESSION['admin_id'] : null,
            $_SESSION['admin_username'] ?? null,
            mb_substr($action, 0, 40),
            $entity !== null ? mb_substr($entity, 0, 40) : null,
            $entityId,
            mb_substr($details, 0, 255),
            function_exists('client_ip') ? client_ip() : ($_SERVER['REMOTE_ADDR'] ?? null),
        ]);
    } catch (Throwable $e) {
        // silencioso a proposito
    }
}
