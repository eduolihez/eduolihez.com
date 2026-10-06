<?php
/**
 * seed.php - Deja la base de datos de TEST lista para la suite E2E.
 *
 * Uso (desde la raiz del repo o desde e2e/):
 *   DB_HOST=127.0.0.1 DB_NAME=eduolihez_test DB_USER=root DB_PASS= \
 *   E2E_USER=e2e E2E_PASSWORD='...' php e2e/seed/seed.php
 *
 * SEGURIDAD: solo actua si DB_NAME termina en "_test". Este script borra
 * filas (intentos de login, usuarios del lab, restos de ejecuciones
 * anteriores): contra la base de datos real seria un desastre, asi que se
 * niega en redondo en vez de fiarse de que nadie se equivoque de variable.
 *
 * Idempotente: se puede ejecutar antes de cada pasada. Todo lo que crea lleva
 * una marca reconocible (email @e2e.test, user_agent "e2e-seed", titulos
 * "E2E ...") para poder borrarlo en la siguiente ejecucion sin tocar el resto.
 * No depende de server/config.php: lee la conexion del entorno.
 */

declare(strict_types=1);

function env(string $name, ?string $default = null): string
{
    $v = getenv($name);
    if ($v === false) {
        if ($default === null) {
            fwrite(STDERR, "Falta la variable de entorno $name.\n");
            exit(2);
        }
        return $default;
    }
    return $v;
}

$host = env('DB_HOST', '127.0.0.1');
$port = env('DB_PORT', '3306');
$name = env('DB_NAME');
$user = env('DB_USER');
$pass = env('DB_PASS', '');
$adminUser = env('E2E_USER');
$adminPass = env('E2E_PASSWORD');

if (!preg_match('/_test$/', $name)) {
    fwrite(STDERR, "ABORTADO: DB_NAME=\"$name\" no termina en \"_test\". El seed solo toca bases de datos de test.\n");
    exit(1);
}
if (strlen($adminPass) < 12) {
    fwrite(STDERR, "ABORTADO: E2E_PASSWORD debe tener al menos 12 caracteres.\n");
    exit(1);
}

$pdo = new PDO(
    sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4', $host, $port, $name),
    $user,
    $pass,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
);
// Comprobacion doble: la base de datos a la que de verdad se ha conectado.
$current = (string) $pdo->query('SELECT DATABASE()')->fetchColumn();
if (!preg_match('/_test$/', $current)) {
    fwrite(STDERR, "ABORTADO: conectado a \"$current\", que no termina en \"_test\".\n");
    exit(1);
}

$log = static function (string $msg): void {
    echo "[seed] $msg\n";
};

// --- Usuario admin ---------------------------------------------------------
$pdo->prepare('DELETE FROM admin_users WHERE username = ?')->execute([$adminUser]);
$pdo->prepare('INSERT INTO admin_users (username, password_hash) VALUES (?, ?)')
    ->execute([$adminUser, password_hash($adminPass, PASSWORD_DEFAULT)]);
$log("admin \"$adminUser\" (re)creado");

// --- Estado limpio de login y del lab --------------------------------------
foreach (['login_attempts', 'lab_login_attempts', 'lab_users'] as $table) {
    $n = $pdo->exec("DELETE FROM `$table`");
    $log("$table vaciada ($n filas)");
}

// --- Restos de ejecuciones anteriores (por si un test fallo a medias) -------
$n = $pdo->exec("DELETE FROM projects WHERE title_es LIKE 'E2E %'");
$log("proyectos E2E antiguos borrados: $n");
$n = $pdo->exec("DELETE FROM posts WHERE title LIKE 'E2E %' OR slug LIKE 'e2e-%'");
$log("articulos E2E antiguos borrados: $n");

// --- Apps fijas (schema.sql ya las crea; esto solo cubre una BD a medias) ---
$ins = $pdo->prepare('INSERT IGNORE INTO apps (slug, display_name, has_content) VALUES (?, ?, ?)');
foreach ([['eduolihez', 'eduolihez.com', 1], ['nowait', 'NoWait', 0], ['phishlab', 'PhishLab', 0]] as $app) {
    $ins->execute($app);
}
$apps = $pdo->query('SELECT slug, id FROM apps')->fetchAll(PDO::FETCH_KEY_PAIR);
$log('apps: ' . implode(', ', array_keys($apps)));

// --- Mensajes: 2 sin leer + 1 leido ----------------------------------------
$n = $pdo->exec("DELETE FROM messages WHERE email LIKE '%@e2e.test'");
$msg = $pdo->prepare(
    'INSERT INTO messages (name, email, subject, message, ip_address, user_agent, is_read, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, NOW() - INTERVAL ? HOUR)'
);
$messages = [
    ['Ana E2E', 'ana@e2e.test', 'E2E sin leer 1', 'Primer mensaje de prueba.', 0, 1],
    ['Luis E2E', 'luis@e2e.test', 'E2E sin leer 2', 'Segundo mensaje de prueba.', 0, 2],
    ['Eva E2E', 'eva@e2e.test', 'E2E leido', 'Mensaje ya leido.', 1, 3],
];
foreach ($messages as [$from, $email, $subject, $body, $read, $hoursAgo]) {
    $msg->execute([$from, $email, $subject, $body, '127.0.0.1', 'e2e-seed', $read, $hoursAgo]);
}
$log("mensajes: $n antiguos borrados, 3 insertados (2 sin leer, 1 leido)");

// --- Visitas de los ultimos dias para eduolihez y phishlab -----------------
$n = $pdo->exec("DELETE FROM visits WHERE user_agent = 'e2e-seed'");
$visit = $pdo->prepare(
    "INSERT INTO visits (app_id, path, referrer, ip_hash, user_agent, country, device, browser, os, lang,
                         is_bot, session_id, duration_s, scroll_pct, viewport, browser_lang, visited_at)
     VALUES (?, ?, '', ?, 'e2e-seed', 'ES', ?, 'Chrome', 'Windows', 'es', 0, ?, ?, ?, 'lg', 'es',
             NOW() - INTERVAL ? DAY - INTERVAL ? MINUTE)"
);
$count = 0;
foreach (['eduolihez' => ['/', '/blog/', '/proyectos/'], 'phishlab' => ['/projects/phishlab/']] as $slug => $paths) {
    if (!isset($apps[$slug])) {
        continue;
    }
    for ($day = 0; $day < 6; $day++) {
        foreach ($paths as $i => $path) {
            $session = substr(hash('sha256', "$slug-$day-$i"), 0, 16);
            $visit->execute([
                (int) $apps[$slug], $path, hash('sha256', "ip-$slug-$i"),
                $i % 2 ? 'mobile' : 'desktop', $session, 30 + $i * 10, 50 + $i * 10, $day, 5 + $i,
            ]);
            $count++;
        }
    }
}
$log("visitas: $n antiguas borradas, $count insertadas (eduolihez y phishlab, ultimos 6 dias)");
$log('listo');
