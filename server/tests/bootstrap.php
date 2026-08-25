<?php
/**
 * bootstrap.php - Arranque de PHPUnit para server/.
 * ---------------------------------------------------------------------------
 * Deliberadamente NO requiere server/lib/http.php ni server/config.php: esos
 * arrancan sesion y abren conexion real a MySQL con las credenciales de
 * produccion, que no existen (ni deben existir) en un entorno de test/CI.
 *
 * Esta suite solo cubre codigo SIN dependencias externas (parseo de texto,
 * utilidades puras). Si en el futuro se testea algo que si necesita DB, la
 * via correcta es una base de datos de test propia, inyectada aparte -- no
 * apuntar los tests a config.php de produccion.
 *
 * AVISO para quien anada un test nuevo: si tu archivo (directa o
 * indirectamente, ej. via partials/layout.php) hace require de auth.php,
 * http.php o db.php, PHPUnit no fallara ESE test con un mensaje limpio --
 * server/db.php hace `exit;` en cuanto config() no encuentra config.php
 * (que nunca existe aqui), matando el PROCESO entero de PHPUnit a mitad de
 * la suite, sin el formato de fallo habitual. Si tu test necesita algo de
 * eso, no lo metas en esta suite: monta una base de datos de test aparte.
 */
require_once __DIR__ . '/../lib/text.php';
require_once __DIR__ . '/../lib/validate.php';
