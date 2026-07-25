<?php
/**
 * Conexion a la base de datos (PDO).
 * Devuelve una unica instancia PDO reutilizable (patron singleton simple).
 *
 * Uso:  $pdo = db();
 */

/** Carga la configuracion desde config.php (o config.example.php si falta). */
function config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }
    $path = __DIR__ . '/config.php';
    if (!file_exists($path)) {
        // Mensaje claro si aun no has creado tu config.php
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'error' => 'Falta config.php. Copia config.example.php a config.php y rellena tus credenciales.',
        ]);
        exit;
    }
    $config = require $path;
    return $config;
}

/** Devuelve la instancia PDO conectada a MySQL. */
function db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $cfg = config()['db'];
    $dsn = sprintf(
        'mysql:host=%s;dbname=%s;charset=%s',
        $cfg['host'],
        $cfg['name'],
        $cfg['charset']
    );

    try {
        $pdo = new PDO($dsn, $cfg['user'], $cfg['pass'], [
            // Lanza excepciones en vez de errores silenciosos.
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            // Devuelve arrays asociativos por defecto.
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            // Usa prepared statements reales (mas seguro).
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
        // Sincronizar zona horaria de MySQL con la de PHP
        $offset = date('P');
        $pdo->exec("SET time_zone = '$offset'");
    } catch (PDOException $e) {
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        $debug = config()['debug'] ?? false;
        echo json_encode([
            'error'  => 'No se pudo conectar a la base de datos.',
            'detail' => $debug ? $e->getMessage() : null,
        ]);
        exit;
    }

    return $pdo;
}
