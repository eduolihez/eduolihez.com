<?php
/**
 * db_retry.php - Reintento corto al abrir la conexion a MySQL.
 * ---------------------------------------------------------------------------
 * POR QUE EXISTE: el hosting compartido (CDMON) limita las conexiones
 * simultaneas por usuario de MySQL. La portada lanza varias llamadas a la API
 * a la vez y, a partir de ~4 conexiones concurrentes, alguna fallaba al
 * conectar y la API respondia 500 "No se pudo conectar a la base de datos"
 * (reproducido en produccion: 0 fallos con 3 peticiones en paralelo, 2-3 de
 * cada 6 con 6). Las otras conexiones duran milisegundos, asi que esperar un
 * momento y reintentar basta casi siempre.
 *
 * Solo se reintentan errores TRANSITORIOS de capacidad o de red. Un error de
 * credenciales (1045) o de base de datos inexistente (1049) no se arregla
 * esperando: reintentarlo solo retrasaria el 500 y multiplicaria intentos de
 * login fallidos contra MySQL.
 *
 * Archivo puro (sin config.php, sin sesion, sin red) para poder testearlo en
 * server/tests sin base de datos real.
 */

/** Codigos de error de MySQL que merecen reintento. */
const DB_RETRYABLE_ERRORS = [
    1040, // Too many connections (limite global del servidor)
    1203, // User already has more than 'max_user_connections' active connections
    2002, // Can't connect to MySQL server (socket/host momentaneamente saturado)
    2006, // MySQL server has gone away
    2013, // Lost connection to MySQL server during query (handshake)
];

/** Extrae el codigo numerico de MySQL de una PDOException de conexion. */
function db_error_code(PDOException $e): int
{
    // En errores de conexion, getCode() trae el numero de MySQL (ej. 1203);
    // en errores de consulta trae el SQLSTATE y el numero va en errorInfo[1].
    if (is_array($e->errorInfo ?? null) && isset($e->errorInfo[1]) && is_numeric($e->errorInfo[1])) {
        return (int) $e->errorInfo[1];
    }
    // 0 = sin codigo: no sirve, se intenta sacar del mensaje.
    if (is_numeric($e->getCode()) && (int) $e->getCode() !== 0) {
        return (int) $e->getCode();
    }
    // Ultimo recurso: "SQLSTATE[HY000] [1203] User already has ..."
    if (preg_match('/\[(\d{4})\]/', $e->getMessage(), $m)) {
        return (int) $m[1];
    }
    return 0;
}

/**
 * Ejecuta $connect hasta $attempts veces mientras falle con un error
 * transitorio. Entre intentos espera 150 ms, 300 ms... (mas un poco de azar
 * para que varias peticiones simultaneas no reintenten a la vez).
 *
 * @param callable():PDO   $connect  Abre la conexion (lanza PDOException).
 * @param callable(int):void|null $sleep  Espera en microsegundos (inyectable en tests).
 */
function db_connect_with_retry(callable $connect, int $attempts = 3, ?callable $sleep = null)
{
    $sleep = $sleep ?? static function (int $micros): void {
        usleep($micros);
    };

    for ($try = 1; ; $try++) {
        try {
            return $connect();
        } catch (PDOException $e) {
            $retryable = in_array(db_error_code($e), DB_RETRYABLE_ERRORS, true);
            if (!$retryable || $try >= $attempts) {
                throw $e;
            }
            $sleep(150000 * $try + random_int(0, 100000));
        }
    }
}
