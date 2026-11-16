<?php
/**
 * visitor.php - Utilidades puras para el visitor_id opt-in (tarea 11).
 * ---------------------------------------------------------------------------
 * visitor_id es el valor de la cookie propia `eo_vid` que el navegador crea
 * SOLO tras aceptar la analitica (src/scripts/consent.ts) y envia en el cuerpo
 * de /api/visit.php. El servidor nunca hace Set-Cookie. Sin dependencias (ni
 * db() ni sesion) para poder testearlo con PHPUnit sin base de datos.
 */

/** 16 hex en minusculas, o null si falta o no cuadra (se ignora en silencio). */
function clean_visitor_id(mixed $v): ?string
{
    return is_string($v) && preg_match('/^[a-f0-9]{16}z/', $v) ? $v : null;
}

/**
 * ¿El error es "columna desconocida"? (SQLSTATE 42S22 / MySQL 1054). Permite
 * desplegar el PHP antes que la migracion de schema.sql: si la columna
 * visitor_id aun no existe, visit.php reintenta el INSERT sin ella.
 */
function is_unknown_column(Throwable $e): bool
{
    if ($e instanceof PDOException) {
        $info = $e->errorInfo ?? null;
        if (is_array($info) && (($info[0] ?? '') === '42S22' || (int) ($info[1] ?? 0) === 1054)) {
            return true;
        }
        return (string) $e->getCode() === '42S22';
    }
    return false;
}
