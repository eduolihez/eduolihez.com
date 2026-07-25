-- ===========================================================================
--  MIGRACION: Tabla de Posts (Blog)
--  Portfolio Eduardo Olivares
--  Fecha: 2026-07-25
--
--  INSTRUCCIONES:
--    phpMyAdmin -> tu base de datos -> pestaña "Importar" -> este archivo.
-- ===========================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `posts` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title`       VARCHAR(200) NOT NULL,
  `slug`        VARCHAR(200) NOT NULL,
  `summary`     VARCHAR(500) NOT NULL,
  `content`     MEDIUMTEXT   NOT NULL,
  `cover_url`   VARCHAR(255) NULL,
  `lang`        CHAR(2)      NOT NULL DEFAULT 'es',
  `visible`     TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_slug` (`slug`),
  KEY `idx_visible_lang` (`visible`, `lang`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
