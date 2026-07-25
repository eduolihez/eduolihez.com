-- ===========================================================================
--  MIGRACION v2  ·  Portfolio Eduardo Olivares
--  Fecha: 2026-07-25
--
--  QUE HACE:
--    - Anade la tabla `activity_log` (registro de auditoria del panel).
--    - Anade columnas de analitica a `visits` (device, browser, os, lang).
--    - Anade `is_starred` / `is_archived` a `messages`.
--    - Anade indices que faltaban (rendimiento del panel).
--    - Inserta los ajustes nuevos con sus valores por defecto.
--
--  COMO APLICARLA (CDMON):
--    phpMyAdmin -> tu base de datos -> pestana "Importar" -> este archivo.
--
--  ES SEGURA DE EJECUTAR VARIAS VECES: usa un procedimiento que comprueba si
--  la columna/indice ya existe antes de crearlo, asi que no da error si ya
--  la habias aplicado.
-- ===========================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- Helper: anade una columna solo si no existe.
-- ---------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `add_column_if_missing`;
DELIMITER $$
CREATE PROCEDURE `add_column_if_missing`(
  IN tbl VARCHAR(64), IN col VARCHAR(64), IN definition TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND COLUMN_NAME = col
  ) THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', definition);
    PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
  END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------------
-- Helper: anade un indice solo si no existe.
-- ---------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `add_index_if_missing`;
DELIMITER $$
CREATE PROCEDURE `add_index_if_missing`(
  IN tbl VARCHAR(64), IN idx VARCHAR(64), IN cols TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND INDEX_NAME = idx
  ) THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD INDEX `', idx, '` (', cols, ')');
    PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
  END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------------
-- 1) Registro de auditoria del panel: quien hizo que y cuando.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `activity_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id`   INT UNSIGNED NULL,
  `username`   VARCHAR(60)  NULL,
  `action`     VARCHAR(40)  NOT NULL,   -- create | update | delete | login | ...
  `entity`     VARCHAR(40)  NULL,       -- project | certification | message | ...
  `entity_id`  INT UNSIGNED NULL,
  `details`    VARCHAR(255) NULL,
  `ip_address` VARCHAR(45)  NULL,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_time` (`created_at`),
  KEY `idx_entity` (`entity`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 2) Analitica mas rica: dispositivo, navegador, sistema operativo e idioma.
--    Se calculan en PHP al registrar la visita (server/lib/ua.php).
--    Las visitas antiguas se quedan a NULL y aparecen como "Desconocido".
-- ---------------------------------------------------------------------------
CALL add_column_if_missing('visits', 'device',  "VARCHAR(10) NULL AFTER `country`");
CALL add_column_if_missing('visits', 'browser', "VARCHAR(24) NULL AFTER `device`");
CALL add_column_if_missing('visits', 'os',      "VARCHAR(24) NULL AFTER `browser`");
CALL add_column_if_missing('visits', 'lang',    "CHAR(2) NULL AFTER `os`");
CALL add_column_if_missing('visits', 'is_bot',  "TINYINT(1) NOT NULL DEFAULT 0 AFTER `lang`");

CALL add_index_if_missing('visits', 'idx_hash_time',  '`ip_hash`, `visited_at`');
CALL add_index_if_missing('visits', 'idx_bot_time',   '`is_bot`, `visited_at`');
CALL add_index_if_missing('visits', 'idx_country',    '`country`');

-- ---------------------------------------------------------------------------
-- 3) Buzon: destacar y archivar mensajes.
-- ---------------------------------------------------------------------------
CALL add_column_if_missing('messages', 'is_starred',  'TINYINT(1) NOT NULL DEFAULT 0');
CALL add_column_if_missing('messages', 'is_archived', 'TINYINT(1) NOT NULL DEFAULT 0');
CALL add_index_if_missing('messages', 'idx_created', '`created_at`');

-- ---------------------------------------------------------------------------
-- 4) Ajustes nuevos (editables desde /admin/settings.php).
--    INSERT IGNORE: si ya existen, no se tocan tus valores.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `settings` (`key`, `value`) VALUES
  ('open_to_work',       '1'),   -- badge "Disponible" del hero
  ('contact_enabled',    '1'),   -- formulario de contacto activo
  ('analytics_enabled',  '1'),   -- registro de visitas activo
  ('announcement_on',    '0'),   -- banner superior activo
  ('announcement_es',    ''),    -- texto del banner en espanol
  ('announcement_en',    ''),    -- ... ingles
  ('announcement_ca',    ''),    -- ... catalan
  ('announcement_url',   '');    -- enlace opcional del banner

-- ---------------------------------------------------------------------------
-- Limpieza de los helpers.
-- ---------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `add_column_if_missing`;
DROP PROCEDURE IF EXISTS `add_index_if_missing`;
