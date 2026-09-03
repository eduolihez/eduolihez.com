-- ===========================================================================
--  ESQUEMA COMPLETO DE BASE DE DATOS  ·  Portfolio Eduardo Olivares
--  Motor: MySQL / MariaDB (CDMON)
--  Charset: utf8mb4 (acentos, emojis, simbolos como ™)
--
--  ESTE ARCHIVO ES EL UNICO QUE NECESITAS. Sustituye a los antiguos
--  migration-v2.sql, add-blog.sql y order-certs.sql, que ya no existen.
--
--  ES IDEMPOTENTE: puedes importarlo tantas veces como quieras.
--    - Crea lo que falta (tablas, columnas, indices).
--    - NO toca lo que ya existe: tus proyectos, certificaciones, mensajes,
--      visitas y usuarios se quedan como estan -- salvo las correcciones
--      puntuales descritas en la regla de mas abajo, que solo tocan un
--      campo concreto y solo si todavia tiene el valor antiguo conocido.
--    - Los datos de ejemplo solo se insertan si la tabla esta VACIA.
--
--  Sirve por igual para:
--    a) una instalacion NUEVA (crea todo desde cero, con datos de ejemplo);
--    b) actualizar una base de datos YA EN PRODUCCION (actua de migracion).
--
--  REGLA PARA CORREGIR DATOS YA SEMBRADOS: si anades un UPDATE que corrige un
--  valor que el seed ya inserto (ver ejemplos en las secciones "projects" y
--  "certifications" mas abajo), guarda el WHERE por el valor ANTERIOR del
--  campo, no solo por un identificador inmutable como el nombre/titulo. Un
--  WHERE solo-por-nombre reimportaria el valor viejo por encima de cualquier
--  edicion manual hecha despues desde /admin -- este archivo no lleva
--  tracking de "esto ya se aplico", asi que cada reimportacion vuelve a
--  ejecutar el UPDATE entero.
--
--  COMO IMPORTARLO EN CDMON:
--    1. Crea una base de datos MySQL desde el panel de CDMON.
--    2. phpMyAdmin -> selecciona esa base de datos -> pestana "Importar"
--       -> elige este archivo -> Continuar.
--    (No incluye "CREATE DATABASE": importalo DENTRO de la base ya creada.)
-- ===========================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';


-- ===========================================================================
--  0. HELPERS
--  Procedimientos auxiliares que permiten anadir columnas e indices solo si
--  faltan. Son lo que hace que este archivo se pueda reimportar sin errores
--  sobre una base de datos que ya tiene contenido. Se borran al final.
-- ===========================================================================

DROP PROCEDURE IF EXISTS `add_column_if_missing`;
DROP PROCEDURE IF EXISTS `add_index_if_missing`;
DROP PROCEDURE IF EXISTS `seed_if_empty`;
DROP PROCEDURE IF EXISTS `repair_legacy_posts`;

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

-- ---------------------------------------------------------------------------
-- REPARACION: tabla `posts` con la forma antigua.
--
-- Una version anterior de este esquema creaba `posts` con columnas
-- bilingues (title_es, body_es, status, published_at...) que NINGUNA parte
-- del codigo llega a usar: el panel y el API trabajan con
-- (title, slug, summary, content, lang, visible).
--
-- Como el parche que anadia la tabla buena usaba CREATE TABLE IF NOT EXISTS,
-- en una base de datos que ya tenia la tabla antigua no hacia nada, y el
-- blog fallaba con "Unknown column 'title'". Aqui se detecta y se corrige.
--
-- Es seguro eliminarla: esa forma nunca llego a ser escribible desde el panel
-- ni desde el API, asi que no puede contener ningun articulo. Se reconoce por
-- la columna `body_es`, que la tabla buena no tiene.
-- ---------------------------------------------------------------------------
CREATE PROCEDURE `repair_legacy_posts`()
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'posts' AND COLUMN_NAME = 'body_es'
  ) THEN
    DROP TABLE `posts`;
  END IF;
END$$

DELIMITER ;

CALL repair_legacy_posts();


-- ===========================================================================
--  1. PANEL DE ADMINISTRACION
-- ===========================================================================

-- Usuarios del panel.
-- La contrasena se establece con /admin/setup.php la primera vez (bcrypt).
CREATE TABLE IF NOT EXISTS `admin_users` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`      VARCHAR(60)  NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `last_login`    DATETIME     NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Intentos de login (control de fuerza bruta del panel).
-- Se purga sola: /api/visit.php borra los registros de mas de 90 dias.
CREATE TABLE IF NOT EXISTS `login_attempts` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ip_address`   VARCHAR(45)  NOT NULL,
  `username`     VARCHAR(60)  NULL,
  `success`      TINYINT(1)   NOT NULL DEFAULT 0,
  `attempted_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ip_time` (`ip_address`, `attempted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Registro de auditoria del panel: quien hizo que y cuando.
-- Se purga solo: se borran los registros de mas de 365 dias.
CREATE TABLE IF NOT EXISTS `activity_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id`   INT UNSIGNED NULL,
  `username`   VARCHAR(60)  NULL,
  `action`     VARCHAR(40)  NOT NULL,   -- create | update | delete | login | export
  `entity`     VARCHAR(40)  NULL,       -- project | certification | post | message
  `entity_id`  INT UNSIGNED NULL,
  `details`    VARCHAR(255) NULL,
  `ip_address` VARCHAR(45)  NULL,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_time` (`created_at`),
  KEY `idx_entity` (`entity`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ===========================================================================
--  2. CONTENIDO DEL PORTFOLIO
-- ===========================================================================

-- Proyectos. Bilingues: los campos _en caen a _es si estan vacios.
CREATE TABLE IF NOT EXISTS `projects` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title_es`       VARCHAR(150) NOT NULL,
  `title_en`       VARCHAR(150) NOT NULL DEFAULT '',
  `summary_es`     VARCHAR(400) NOT NULL,
  `summary_en`     VARCHAR(400) NOT NULL DEFAULT '',
  `description_es` TEXT         NULL,
  `description_en` TEXT         NULL,
  `image_url`      VARCHAR(255) NULL,
  `stack`          TEXT         NULL,                 -- JSON: ["PHP","MySQL"]
  `badges`         VARCHAR(255) NULL,                 -- JSON: ["open-source","in-development"]
  `repo_url`       VARCHAR(255) NULL,
  `demo_url`       VARCHAR(255) NULL,
  `store_url`      VARCHAR(255) NULL,
  `featured`       TINYINT(1)   NOT NULL DEFAULT 0,
  `sort_order`     INT          NOT NULL DEFAULT 0,
  `status`         ENUM('published','draft') NOT NULL DEFAULT 'published',
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  -- Cubre exactamente el ORDER BY de /api/projects.php.
  KEY `idx_status_order` (`status`, `featured`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Certificaciones. El nombre no se traduce (son nombres propios).
CREATE TABLE IF NOT EXISTS `certifications` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`           VARCHAR(200) NOT NULL,
  `issuer`         VARCHAR(120) NULL,
  `issue_date`     VARCHAR(20)  NULL,                 -- texto libre: "2026", "Mar 2026"
  `credential_url` VARCHAR(255) NULL,
  `logo_url`       VARCHAR(255) NULL,
  `category`       VARCHAR(60)  NULL,
  `visible`        TINYINT(1)   NOT NULL DEFAULT 1,
  `sort_order`     INT          NOT NULL DEFAULT 0,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_visible_order` (`visible`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Blog / notas tecnicas.
--
-- Un articulo = un idioma. La version en otro idioma es OTRA fila con su
-- propio slug; asi cada una tiene su URL y su SEO, en vez de mezclar dos
-- idiomas en la misma pagina.
--
-- ESTA es la forma que usan /api/posts.php, /api/post.php y el panel.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `posts` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title`        VARCHAR(200) NOT NULL,
  `slug`         VARCHAR(200) NOT NULL,
  `summary`      VARCHAR(500) NOT NULL,               -- meta description del articulo
  `content`      MEDIUMTEXT   NOT NULL,               -- HTML redactado desde el panel
  `cover_url`    VARCHAR(255) NULL,
  `tags`         VARCHAR(255) NULL,                   -- CSV: "python,soc,automatizacion"
  `lang`         CHAR(2)      NOT NULL DEFAULT 'es',  -- es | en | ca
  `visible`      TINYINT(1)   NOT NULL DEFAULT 1,     -- 0 = borrador
  -- Fecha que se muestra y que va al datePublished de Schema.org.
  -- Separada de created_at a proposito: un articulo puede pasar semanas en
  -- borrador, y entonces "cuando se creo la fila" y "cuando se publico" dejan
  -- de ser lo mismo. Tambien permite fechar hacia atras al importar.
  `published_at` DATETIME     NULL,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_slug` (`slug`),
  -- Cubre el WHERE + ORDER BY de /api/posts.php de una sola pasada.
  KEY `idx_visible_lang` (`visible`, `lang`, `published_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ===========================================================================
--  3. DATOS RECOGIDOS DEL SITIO
-- ===========================================================================

-- Mensajes del formulario de contacto (buzon persistente).
CREATE TABLE IF NOT EXISTS `messages` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(100) NOT NULL,
  `email`       VARCHAR(150) NOT NULL,
  `subject`     VARCHAR(150) NULL,
  `message`     TEXT         NOT NULL,
  `ip_address`  VARCHAR(45)  NULL,                    -- soporta IPv6
  `user_agent`  VARCHAR(255) NULL,
  `is_read`     TINYINT(1)   NOT NULL DEFAULT 0,
  `is_starred`  TINYINT(1)   NOT NULL DEFAULT 0,
  `is_archived` TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_read` (`is_read`),
  KEY `idx_created` (`created_at`),
  KEY `idx_ip_time` (`ip_address`, `created_at`)      -- para el rate-limit
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Visitas (analitica propia, sin terceros).
-- PRIVACIDAD: no se guarda la IP, solo su SHA-256 con sal + user-agent
-- (config.php). Las columnas de comportamiento (session_id, hit_id,
-- duration_s, scroll_pct) se anaden mas abajo, en la seccion 5, junto con
-- el resto de columnas que no vinieron en la version original de esta tabla.
-- Se purga sola: se borran las visitas de mas de 400 dias.
CREATE TABLE IF NOT EXISTS `visits` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `path`       VARCHAR(255) NOT NULL,
  `referrer`   VARCHAR(255) NOT NULL DEFAULT '',
  `ip_hash`    CHAR(64)     NULL,                     -- sha256(ip + sal)
  `user_agent` VARCHAR(255) NULL,
  `country`    CHAR(2)      NULL,
  `device`     VARCHAR(10)  NULL,                     -- desktop | mobile | tablet
  `browser`    VARCHAR(24)  NULL,                     -- Chrome, Firefox, Safari...
  `os`         VARCHAR(24)  NULL,                     -- Windows, macOS, Android...
  `lang`       CHAR(2)      NULL,                     -- idioma de la pagina vista
  `is_bot`     TINYINT(1)   NOT NULL DEFAULT 0,
  `visited_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_time` (`visited_at`),
  KEY `idx_path` (`path`),
  KEY `idx_hash_time` (`ip_hash`, `visited_at`),
  KEY `idx_bot_time` (`is_bot`, `visited_at`),
  KEY `idx_country` (`country`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ===========================================================================
--  4. AJUSTES DEL SITIO (clave/valor)
--  Se editan desde /admin/settings.php y los sirve /api/settings.php, asi que
--  cambian en la web SIN recompilar el frontend.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS `settings` (
  `key`        VARCHAR(60)  NOT NULL,
  `value`      TEXT         NULL,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ===========================================================================
--  5. ACTUALIZACION DE BASES DE DATOS ANTIGUAS
--  Los CREATE TABLE de arriba no tocan una tabla que ya existe, asi que las
--  columnas e indices anadidos despues de la primera version se aplican aqui.
--  En una instalacion nueva no hacen nada (ya vienen creados).
-- ===========================================================================

-- Analitica mas rica (dispositivo, navegador, SO, idioma, bots).
CALL add_column_if_missing('visits', 'device',  "VARCHAR(10) NULL AFTER `country`");
CALL add_column_if_missing('visits', 'browser', "VARCHAR(24) NULL AFTER `device`");
CALL add_column_if_missing('visits', 'os',      "VARCHAR(24) NULL AFTER `browser`");
CALL add_column_if_missing('visits', 'lang',    "CHAR(2) NULL AFTER `os`");
CALL add_column_if_missing('visits', 'is_bot',  "TINYINT(1) NOT NULL DEFAULT 0 AFTER `lang`");
CALL add_index_if_missing('visits', 'idx_hash_time', '`ip_hash`, `visited_at`');
CALL add_index_if_missing('visits', 'idx_bot_time',  '`is_bot`, `visited_at`');
CALL add_index_if_missing('visits', 'idx_country',   '`country`');

-- Analitica de comportamiento y atribucion. Nada de esto es persistente ni
-- identifica a nadie: session_id vive solo en sessionStorage (muere al
-- cerrar la pestana) y solo sirve para agrupar las paginas vistas en una
-- misma visita; hit_id es un token de un solo uso por pagina que existe
-- unicamente para que el navegador pueda decirle a esta fila "el visitante
-- se quedo X segundos y bajo hasta el Y%" sin tener que reenviar nada mas.
-- Ninguno de los dos se reutiliza entre visitas ni se cruza con otra tabla.
CALL add_column_if_missing('visits', 'session_id',   "CHAR(16) NULL AFTER `is_bot`");
CALL add_column_if_missing('visits', 'hit_id',       "CHAR(16) NULL AFTER `session_id`");
CALL add_column_if_missing('visits', 'duration_s',   "SMALLINT UNSIGNED NULL AFTER `hit_id`");
CALL add_column_if_missing('visits', 'scroll_pct',   "TINYINT UNSIGNED NULL AFTER `duration_s`");
CALL add_column_if_missing('visits', 'utm_source',   "VARCHAR(60) NULL AFTER `scroll_pct`");
CALL add_column_if_missing('visits', 'utm_medium',   "VARCHAR(60) NULL AFTER `utm_source`");
CALL add_column_if_missing('visits', 'utm_campaign', "VARCHAR(60) NULL AFTER `utm_medium`");
CALL add_column_if_missing('visits', 'viewport',     "VARCHAR(2) NULL AFTER `utm_campaign`");
CALL add_column_if_missing('visits', 'browser_lang', "CHAR(2) NULL AFTER `viewport`");
CALL add_index_if_missing('visits', 'idx_session', '`session_id`, `visited_at`');
CALL add_index_if_missing('visits', 'idx_hit',     '`hit_id`');

-- Buzon: destacar y archivar mensajes.
CALL add_column_if_missing('messages', 'is_starred',  'TINYINT(1) NOT NULL DEFAULT 0');
CALL add_column_if_missing('messages', 'is_archived', 'TINYINT(1) NOT NULL DEFAULT 0');
CALL add_index_if_missing('messages', 'idx_created', '`created_at`');

-- Proyectos: enlace a tienda de extensiones (Chrome Web Store / AMO).
CALL add_column_if_missing('projects', 'store_url', 'VARCHAR(255) NULL');

-- Proyectos: badges (etiquetas).
CALL add_column_if_missing('projects', 'badges', 'VARCHAR(255) NULL AFTER `stack`');

-- Proyectos: anadir Zeora si el sitio ya tenia proyectos.
--
-- INCIDENTE (2026-08-25): la primera version de este bloque solo comprobaba
-- "NOT EXISTS (title_es = Zeora)", sin mirar si la tabla estaba vacia. Cuando
-- se reimporto este archivo contra una `projects` que se habia quedado vacia,
-- ESTE insert se ejecuto primero (esta seccion va antes que la 6 en el
-- archivo) y dejo la tabla con 1 fila. El seed de la seccion 6 comprueba
-- `COUNT(*) = 0` para decidir si siembra los 6 proyectos de fabrica, y con
-- esa fila ya puesta la condicion era falsa: no sembro nada mas, y los otros
-- 5 proyectos (Dewi App, BinCat, NorthGate Browser, Password Sentinel,
-- PromptMaster) desaparecieron de produccion hasta que se restauraron a mano.
--
-- `EXISTS (SELECT 1 FROM projects)` evita que esto se repita: este bloque
-- SOLO actua sobre una tabla que YA tiene datos (una instalacion nueva, con
-- la tabla vacia, la deja intacta para que la siembre entera la seccion 6,
-- Zeora incluida).
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'Zéora', 'Zéora',
       'Webs profesionales listas en 72 horas para fontaneros, electricistas y reformistas, con SEO local y mantenimiento mensual.',
       'Professional websites ready in 72 hours for plumbers, electricians and renovators, with local SEO and monthly maintenance.',
       '["HTML","SEO local"]',
       '["private-code"]',
       NULL, '/projects/zeora/', NULL, 0, 6, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'Zéora');

-- Proyectos: restaura los 5 que se perdieron en el incidente de arriba
-- (Dewi App, BinCat, NorthGate Browser, Password Sentinel, PromptMaster).
-- Mismo patron: solo actua si la tabla ya tiene datos, y cada fila solo
-- entra si ese titulo todavia no existe -- reimportar esto no duplica nada.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'Dewi App', 'Dewi App',
       'Prototipo web ganador de la 8a Hackathon TecnoCampus para monitorizar el consumo de agua en tiempo real.',
       'Award-winning web prototype (8th TecnoCampus Hackathon) to monitor water consumption in real time.',
       '["Next.js","TypeScript","Tailwind CSS"]', '["open-source"]',
       'https://github.com/eduolihez/hackathon-Dewi', NULL, NULL, 1, 1, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'Dewi App');

INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'BinCat', 'BinCat',
       'Sistema de gestion segura de tokens en Python con cifrado Fernet y almacenamiento en SQLite.',
       'Secure token management system in Python using Fernet encryption and SQLite storage.',
       '["Python","Cryptography (Fernet)","SQLite"]', '["open-source"]',
       'https://github.com/eduolihez/BinCat', NULL, NULL, 1, 2, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'BinCat');

INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'NorthGate Browser', 'NorthGate Browser',
       'Navegador (fork de Mullvad/Firefox) con clasificador de phishing on-device en ONNX/Rust. En desarrollo temprano.',
       'Browser (Mullvad/Firefox fork) with an on-device phishing classifier in ONNX/Rust. Early stage.',
       '["Rust","ONNX","Firefox","Machine Learning"]', '["open-source","in-development"]',
       'https://github.com/eduolihez/northgate-browser', NULL, NULL, 1, 3, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'NorthGate Browser');

INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'Password Sentinel', 'Password Sentinel',
       'Extension de Chrome que comprueba la seguridad de tus contrasenas con Have I Been Pwned, sin enviar datos a ningun servidor.',
       'Chrome extension that checks password safety against Have I Been Pwned, without sending data to any server.',
       '["JavaScript","Chrome Extension","Have I Been Pwned API"]', '["open-source"]',
       NULL, '/projects/passwdcentinel/', NULL, 0, 4, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'Password Sentinel');

INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'PromptMaster Universal AI', 'PromptMaster Universal AI',
       'Extension de Chrome que optimiza tus prompts para ChatGPT, Claude y Gemini.',
       'Chrome extension that optimizes your prompts for ChatGPT, Claude and Gemini.',
       '["JavaScript","Chrome Extension","Prompt Engineering"]', '["private-code"]',
       NULL, '/projects/promptmaster/', 'https://addons.mozilla.org/es-ES/firefox/addon/promptmaster/', 0, 5, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'PromptMaster Universal AI');

-- Proyectos: Blue Team Hub (2026-09-04). Portal de herramientas de
-- ciberseguridad para analistas SOC, con vigilancia automatizada del
-- catalogo CISA KEV via GitHub Actions. demo_url es un dominio propio
-- (eduolihez.github.io), no una subpagina /projects/ de este sitio -- por
-- eso, a diferencia de Password Sentinel/PromptMaster/Zeora, lleva ambos:
-- repo_url (codigo) y demo_url (sitio en produccion).
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'Blue Team Hub', 'Blue Team Hub',
       'Portal de herramientas de ciberseguridad para analistas SOC: desarmador de IOCs, generador de reglas YARA, playbooks interactivos de respuesta a incidentes y vigilancia automatizada del catalogo CISA KEV.',
       'Cybersecurity toolkit for SOC analysts: IOC defanger, YARA rule generator, interactive incident-response playbooks, and automated CISA KEV catalog monitoring.',
       '["Astro","Tailwind CSS","TypeScript","GitHub Actions"]', '["open-source"]',
       'https://github.com/eduolihez/eduolihez.github.io', 'https://eduolihez.github.io/', NULL, 1, 8, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'Blue Team Hub');

-- PromptMaster es de codigo privado, no open-source (correccion 2026-08-25).
-- Cubre la fila que ya estuviera insertada con el badge antiguo (el INSERT de
-- arriba solo aplica el valor nuevo si la fila no existe todavia).
--
-- Guardado por el VALOR anterior conocido, no solo por title_es: title_es no
-- cambia nunca, asi que un WHERE solo-por-nombre pisaria en silencio
-- cualquier badge que se edite despues a mano desde /admin cada vez que se
-- reimporte este archivo (schema.sql se reimporta entero, sin tracking de
-- "esto ya se aplico"). Con el valor antiguo en el WHERE, esto se aplica una
-- sola vez: en cuanto el badge deja de ser open-source, deja de coincidir.
UPDATE `projects` SET `badges` = '["private-code"]'
WHERE `title_es` = 'PromptMaster Universal AI' AND `badges` = '["open-source"]';

-- Proyectos: anadir CREM Report Generator (2026-09-01). Mismo patron que los
-- bloques de arriba: solo actua sobre una tabla que YA tiene datos, y solo si
-- el titulo todavia no existe -- reimportar esto no duplica nada.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'CREM Report Generator', 'CREM Report Generator',
       'Motor en Python que automatiza informes mensuales de seguridad sobre Trend Micro Vision One, con enriquecimiento de CVEs (NVD, CISA KEV, EPSS) y dashboard de escritorio.',
       'Python engine that automates monthly security reports over Trend Micro Vision One, with CVE enrichment (NVD, CISA KEV, EPSS) and a desktop dashboard.',
       '["Python","Flask","PyQt6"]',
       '["open-source"]',
       'https://github.com/eduolihez/vision-one-crem-report-generator', NULL, NULL, 1, 7, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'CREM Report Generator');

-- ---------------------------------------------------------------------------
-- Certificaciones: correcciones y ampliacion con las insignias de Credly
-- (https://www.credly.com/users/eduolihez), revisadas 2026-08-25.
-- ---------------------------------------------------------------------------

-- La de Python la emite Certiport (via Credly), no OpenBootcamp, y el nombre
-- oficial de la insignia es "IT Specialist - Python".
UPDATE `certifications` SET `name` = 'IT Specialist - Python', `issuer` = 'Certiport'
WHERE `name` = 'Python' AND `issuer` = 'OpenBootcamp';

-- "Fundamentos profesionales en ciberseguridad" figuraba con el emisor
-- combinado "Microsoft / LinkedIn", que en la vista por emisor creaba una
-- tarjeta propia de un solo curso en vez de sumarse al grupo "LinkedIn".
UPDATE `certifications` SET `issuer` = 'LinkedIn'
WHERE `issuer` = 'Microsoft / LinkedIn';

-- Los dos cursos de Google/Santander pasan de categoria "AI / Cloud" a
-- "Otros" para no mezclarse con las certificaciones tecnicas de IA/Cloud
-- reales. La de la Federacio Catalana de Vela YA estaba en "Otros" antes de
-- este cambio -- no forma parte de esta migracion, no hace falta tocarla.
--
-- Guardado por el VALOR anterior conocido (`category` = 'AI / Cloud'), no
-- solo por nombre: igual que el UPDATE de PromptMaster de mas arriba, un
-- WHERE solo-por-nombre pisaria en silencio una recategorizacion manual
-- hecha despues desde /admin cada vez que se reimporte este archivo.
UPDATE `certifications` SET `category` = 'Otros'
WHERE `name` IN ('Iniciación al Desarrollo con IA', 'Domina la IA con Gemini')
  AND `category` = 'AI / Cloud';

-- Insignias de Fortinet en Credly que no estaban en la tabla. Solo actua si
-- `certifications` ya tiene datos (mismo motivo que en `projects` mas arriba:
-- en una instalacion nueva, con la tabla vacia, esto se dejaria para el seed
-- completo de la seccion 6 en vez de anticiparse y vaciar el COUNT(*) = 0).
INSERT INTO `certifications` (`name`, `issuer`, `issue_date`, `credential_url`, `category`, `visible`, `sort_order`)
SELECT v.name, 'Fortinet', v.issue_date, v.url, 'Network Security', 1, 32 + v.n
FROM (
  SELECT 1 AS n, 'Fortinet Certified Associate Cybersecurity' AS name, '2026' AS issue_date, 'https://www.credly.com/badges/d211824c-9076-4d47-a3e4-df212f541969' AS url
  UNION ALL SELECT 2, 'Fortinet FortiGate 7.6 Operator', '2026', 'https://www.credly.com/badges/cd693891-405c-4fe2-81c9-16b42816fa0e'
  UNION ALL SELECT 3, 'Fortinet NSE 3 Certified in Cybersecurity', '2026', 'https://www.credly.com/badges/9a8e25b3-ca1d-4010-ba2e-59378b3eb668'
  UNION ALL SELECT 4, 'Technical Introduction to Cybersecurity 3.0', '2026', 'https://www.credly.com/badges/24f091e5-8613-4e39-97b4-df961ee0d4a6'
  UNION ALL SELECT 5, 'Fortinet Certified Fundamentals Cybersecurity', '2026', 'https://www.credly.com/badges/67a908ff-25ff-4595-be0f-341082223ddb'
  UNION ALL SELECT 6, 'Fortinet NSE 1 Certified in Cybersecurity', '2026', 'https://www.credly.com/badges/378cb1cc-36ff-4873-8bf3-343155f79a14'
  UNION ALL SELECT 7, 'Fortinet NSE 2 Certified in Cybersecurity', '2026', 'https://www.credly.com/badges/ac473901-06f2-4919-92e4-485d3233a4e0'
  UNION ALL SELECT 8, 'Getting Started in Cybersecurity 3.0', '2026', 'https://www.credly.com/badges/1d0b424a-bcdd-48bd-b40f-a6af00fc0f05'
  UNION ALL SELECT 9, 'Introduction to the Threat Landscape 3.0', '2026', 'https://www.credly.com/badges/c9f14aef-cfe0-4f45-927f-8442f0e03b05'
) v
WHERE EXISTS (SELECT 1 FROM `certifications`)
  AND NOT EXISTS (SELECT 1 FROM `certifications` WHERE `certifications`.`name` = v.name);

-- Enlaces a Credly para las filas que aun no tenian ninguno. Cubre tanto una
-- instalacion nueva (el INSERT de arriba ya no aplica) como produccion (donde
-- las 9 de Fortinet ya se insertaron sin link antes de conocer estas URLs).
UPDATE `certifications` SET `credential_url` = 'https://www.credly.com/badges/3010ded8-d149-438c-b041-0da42fc58d09'
WHERE `name` = 'Microsoft Certified: Azure AI Fundamentals' AND `credential_url` IS NULL;

UPDATE `certifications` SET `credential_url` = CASE `name`
  WHEN 'Fortinet Certified Associate Cybersecurity'   THEN 'https://www.credly.com/badges/d211824c-9076-4d47-a3e4-df212f541969'
  WHEN 'Fortinet FortiGate 7.6 Operator'              THEN 'https://www.credly.com/badges/cd693891-405c-4fe2-81c9-16b42816fa0e'
  WHEN 'Fortinet NSE 3 Certified in Cybersecurity'    THEN 'https://www.credly.com/badges/9a8e25b3-ca1d-4010-ba2e-59378b3eb668'
  WHEN 'Technical Introduction to Cybersecurity 3.0'  THEN 'https://www.credly.com/badges/24f091e5-8613-4e39-97b4-df961ee0d4a6'
  WHEN 'Fortinet Certified Fundamentals Cybersecurity' THEN 'https://www.credly.com/badges/67a908ff-25ff-4595-be0f-341082223ddb'
  WHEN 'Fortinet NSE 1 Certified in Cybersecurity'    THEN 'https://www.credly.com/badges/378cb1cc-36ff-4873-8bf3-343155f79a14'
  WHEN 'Fortinet NSE 2 Certified in Cybersecurity'    THEN 'https://www.credly.com/badges/ac473901-06f2-4919-92e4-485d3233a4e0'
  WHEN 'Getting Started in Cybersecurity 3.0'         THEN 'https://www.credly.com/badges/1d0b424a-bcdd-48bd-b40f-a6af00fc0f05'
  WHEN 'Introduction to the Threat Landscape 3.0'     THEN 'https://www.credly.com/badges/c9f14aef-cfe0-4f45-927f-8442f0e03b05'
END
WHERE `name` IN (
  'Fortinet Certified Associate Cybersecurity', 'Fortinet FortiGate 7.6 Operator',
  'Fortinet NSE 3 Certified in Cybersecurity', 'Technical Introduction to Cybersecurity 3.0',
  'Fortinet Certified Fundamentals Cybersecurity', 'Fortinet NSE 1 Certified in Cybersecurity',
  'Fortinet NSE 2 Certified in Cybersecurity', 'Getting Started in Cybersecurity 3.0',
  'Introduction to the Threat Landscape 3.0'
) AND `credential_url` IS NULL;

-- "Fortinet NSE" (id 1) es la entrada resumen de toda la trayectoria
-- Fortinet, no una insignia individual de Credly -- no tiene pagina de
-- verificacion propia. Enlaza al perfil de Credly completo en vez de dejarla
-- sin link.
UPDATE `certifications` SET `credential_url` = 'https://www.credly.com/users/eduolihez'
WHERE `name` = 'Fortinet NSE' AND `credential_url` IS NULL;

-- Blog: etiquetas y fecha de publicacion propia.
CALL add_column_if_missing('posts', 'tags',         "VARCHAR(255) NULL AFTER `cover_url`");
CALL add_column_if_missing('posts', 'published_at', "DATETIME NULL AFTER `visible`");
CALL add_index_if_missing('posts', 'idx_visible_lang', '`visible`, `lang`, `published_at`');

-- Los articulos que ya existieran antes de tener published_at se fechan con su
-- created_at, que es lo que se venia mostrando como fecha de publicacion.
UPDATE `posts` SET `published_at` = `created_at` WHERE `published_at` IS NULL;


-- ===========================================================================
--  6. DATOS INICIALES
--  Solo se insertan si la tabla correspondiente esta VACIA, para que
--  reimportar este archivo nunca duplique tu contenido real.
-- ===========================================================================

DELIMITER $$

CREATE PROCEDURE `seed_if_empty`()
BEGIN
  -- --- Proyectos -----------------------------------------------------------
  IF (SELECT COUNT(*) FROM `projects`) = 0 THEN
    INSERT INTO `projects`
      (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
       `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
    VALUES
      ('Dewi App',
       'Dewi App',
       'Prototipo web ganador de la 8a Hackathon TecnoCampus para monitorizar el consumo de agua en tiempo real.',
       'Award-winning web prototype (8th TecnoCampus Hackathon) to monitor water consumption in real time.',
       '["Next.js","TypeScript","Tailwind CSS"]',
       '["open-source"]',
       'https://github.com/eduolihez/hackathon-Dewi', NULL, NULL, 1, 1, 'published'),

      ('BinCat',
       'BinCat',
       'Sistema de gestion segura de tokens en Python con cifrado Fernet y almacenamiento en SQLite.',
       'Secure token management system in Python using Fernet encryption and SQLite storage.',
       '["Python","Cryptography (Fernet)","SQLite"]',
       '["open-source"]',
       'https://github.com/eduolihez/BinCat', NULL, NULL, 1, 2, 'published'),

      ('NorthGate Browser',
       'NorthGate Browser',
       'Navegador (fork de Mullvad/Firefox) con clasificador de phishing on-device en ONNX/Rust. En desarrollo temprano.',
       'Browser (Mullvad/Firefox fork) with an on-device phishing classifier in ONNX/Rust. Early stage.',
       '["Rust","ONNX","Firefox","Machine Learning"]',
       '["open-source","in-development"]',
       'https://github.com/eduolihez/northgate-browser', NULL, NULL, 1, 3, 'published'),

      ('Password Sentinel',
       'Password Sentinel',
       'Extension de Chrome que comprueba la seguridad de tus contrasenas con Have I Been Pwned, sin enviar datos a ningun servidor.',
       'Chrome extension that checks password safety against Have I Been Pwned, without sending data to any server.',
       '["JavaScript","Chrome Extension","Have I Been Pwned API"]',
       '["open-source"]',
       NULL, '/projects/passwdcentinel/', NULL, 0, 4, 'published'),

      ('PromptMaster Universal AI',
       'PromptMaster Universal AI',
       'Extension de Chrome que optimiza tus prompts para ChatGPT, Claude y Gemini.',
       'Chrome extension that optimizes your prompts for ChatGPT, Claude and Gemini.',
       '["JavaScript","Chrome Extension","Prompt Engineering"]',
       '["private-code"]',
       NULL, '/projects/promptmaster/', 'https://addons.mozilla.org/es-ES/firefox/addon/promptmaster/', 0, 5, 'published'),

      ('Zéora',
       'Zéora',
       'Webs profesionales listas en 72 horas para fontaneros, electricistas y reformistas, con SEO local y mantenimiento mensual.',
       'Professional websites ready in 72 hours for plumbers, electricians and renovators, with local SEO and monthly maintenance.',
       '["HTML","SEO local"]',
       '["private-code"]',
       NULL, '/projects/zeora/', NULL, 0, 6, 'published'),

      ('Blue Team Hub',
       'Blue Team Hub',
       'Portal de herramientas de ciberseguridad para analistas SOC: desarmador de IOCs, generador de reglas YARA, playbooks interactivos de respuesta a incidentes y vigilancia automatizada del catalogo CISA KEV.',
       'Cybersecurity toolkit for SOC analysts: IOC defanger, YARA rule generator, interactive incident-response playbooks, and automated CISA KEV catalog monitoring.',
       '["Astro","Tailwind CSS","TypeScript","GitHub Actions"]',
       '["open-source"]',
       'https://github.com/eduolihez/eduolihez.github.io', 'https://eduolihez.github.io/', NULL, 1, 8, 'published');
  END IF;

  -- --- Certificaciones -----------------------------------------------------
  -- El sort_order ya viene con la prioridad definitiva: primero las de mas
  -- peso profesional (Fortinet, Microsoft, Trend Micro Advanced, TryHackMe),
  -- despues el resto. Se reordena cuando quieras desde /admin.
  IF (SELECT COUNT(*) FROM `certifications`) = 0 THEN
    INSERT INTO `certifications`
      (`name`, `issuer`, `issue_date`, `credential_url`, `logo_url`, `category`, `visible`, `sort_order`)
    VALUES
      ('Fortinet NSE', 'Fortinet', '2026', 'https://www.credly.com/users/eduolihez', NULL, 'Network Security', 1, 1),
      ('Microsoft Certified: Azure AI Fundamentals', 'Microsoft', '2026', 'https://www.credly.com/badges/3010ded8-d149-438c-b041-0da42fc58d09', NULL, 'AI / Cloud', 1, 2),
      ('Trend Micro Vision One Platform - Advanced', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%20Platform%20Advanced.pdf', NULL, 'XDR / SecOps', 1, 3),
      ('TryHackMe Pre-Security', 'TryHackMe', '2023', '/certificaciones/THM-R3JSJHVXSI.pdf', NULL, 'Cybersecurity', 1, 4),
      ('Introducción a la Ciberseguridad', 'Cisco Networking Academy', '2023', '/certificaciones/Cisco/Introduccion%20a%20la%20Ciberseguridad.pdf', NULL, 'Cybersecurity', 1, 5),
      ('Introduction to Modern AI', 'Cisco Networking Academy', '2024', '/certificaciones/Cisco/Introduction%20to%20Modern%20AI.pdf', NULL, 'AI / Cloud', 1, 6),
      ('Fundamentos profesionales en ciberseguridad', 'LinkedIn', '2023', '/certificaciones/LinkedIn/CertificadoDeFinalizacion_Fundamentos%20profesionales%20en%20ciberseguridad%20por%20Microsoft%20y%20LinkedIn.pdf', NULL, 'Cybersecurity', 1, 7),
      ('Microsoft Copilot para Seguridad', 'LinkedIn', '2024', '/certificaciones/LinkedIn/CertificadoDeFinalizacion_Microsoft%20Copilot%20para%20Seguridad.pdf', NULL, 'AI / Cloud', 1, 8),
      ('Iniciación al Desarrollo con IA', 'Google / Santander', '2024', '/certificaciones/Certificado_Iniciación_Al_Desarrollo_Con_IA.pdf', NULL, 'Otros', 1, 9),
      ('Domina la IA con Gemini', 'Google / Santander', '2024', '/certificaciones/Domina%20la%20IA%20con%20Gemini.pdf', NULL, 'Otros', 1, 10),
      ('First Certificate in English (B2)', 'Cambridge English', '2021', '/certificaciones/First%20Certificate.jpg', NULL, 'Idiomas', 1, 11),
      ('IC3 Digital Literacy GS6 Level 1', 'Certiport', '2023', '/certificaciones/IC3%20GS6%20Level%201.pdf', NULL, 'Sistemas', 1, 12),
      ('IT Specialist - Python', 'Certiport', '2023', '/certificaciones/Python.pdf', NULL, 'Desarrollo', 1, 13),
      ('Reglas de la IA: cómo usarla sin correr riesgos legales', 'LinkedIn', '2024', '/certificaciones/Reglas%20de%20la%20IA%20c%C3%B3mo%20usarla%20sin%20correr%20riesgos%20legales.pdf', NULL, 'AI / Cloud', 1, 14),
      ('Concienciación en Ciberseguridad: Terminología', 'LinkedIn', '2023', '/certificaciones/LinkedIn/CertificadoDeFinalizacion_Concienciacion%20en%20ciberseguridad%20Terminologia%20de%20ciberseguridad.pdf', NULL, 'Cybersecurity', 1, 15),
      ('Fundamentos de Ciberseguridad', 'LinkedIn', '2023', '/certificaciones/LinkedIn/CertificadoDeFinalizacion_Fundamentos%20de%20ciberseguridad%20(1).pdf', NULL, 'Cybersecurity', 1, 16),
      ('Panorámica de amenazas a la ciberseguridad', 'LinkedIn', '2023', '/certificaciones/LinkedIn/CertificadoDeFinalizacion_Panoramica%20de%20amenazas%20a%20la%20ciberseguridad%20(1).pdf', NULL, 'Cybersecurity', 1, 17),
      ('Trend Micro Vision One™ Security Operations (SecOps) Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20OneTM%20Security%20Operations%20(SecOps)%20Foundation.pdf', NULL, 'XDR / SecOps', 1, 18),
      ('Trend Micro Vision One™ AI Security Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20AI%20Security%20Foundation.pdf', NULL, 'AI Security', 1, 19),
      ('Trend Micro Vision One™ Cloud Security Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Cloud%20Security%20Foundation.pdf', NULL, 'Cloud Security', 1, 20),
      ('Trend Micro Vision One™ Cyber Risk Exposure Management (CREM) Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Cyber%20Risk%20Exposure%20Management%20(CREM)%20Foundation.pdf', NULL, 'Cybersecurity', 1, 21),
      ('Trend Micro Vision One™ Ecosystem Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Ecosystem%20Foundation.pdf', NULL, 'Sistemas', 1, 22),
      ('Trend Micro Vision One™ Email & Collaboration Security Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Email%20and%20Collaboration%20Security%20Foundation.pdf', NULL, 'Cybersecurity', 1, 23),
      ('Trend Micro Vision One™ Endpoint Security Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Endpoint%20Security%20Foundation.pdf', NULL, 'Cybersecurity', 1, 24),
      ('Trend Micro Vision One™ Identity Security Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Identity%20Security%20Foundation.pdf', NULL, 'Cybersecurity', 1, 25),
      ('Trend Micro Vision One™ Platform Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Platform%20Foundation.pdf', NULL, 'XDR / SecOps', 1, 26),
      ('Trend Micro Vision One™ Services Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Services%20Foundation.pdf', NULL, 'Sistemas', 1, 27),
      ('Trend Micro Vision One™ Threat Intelligence Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20Threat%20Intelligence%20Foundation.pdf', NULL, 'Threat Intel', 1, 28),
      ('Trend Micro Vision One™ for Service Providers (xSP) Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%E2%84%A2%20for%20Service%20Providers%20(xSP)%20Foundation.pdf', NULL, 'Sistemas', 1, 29),
      ('Trend Micro Flex Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%E2%84%A2%20Flex%20Foundation.pdf', NULL, 'AI Security', 1, 30),
      ('Trend Micro Research Foundation', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%E2%84%A2%20Research%20Foundation.pdf', NULL, 'Threat Intel', 1, 31),
      ('Certificado de Vela - Acceso', 'Federació Catalana de Vela', '2022', '/certificaciones/Certificat%20vela_prova%20acces.pdf', NULL, 'Otros', 1, 32),
      ('Fortinet Certified Associate Cybersecurity', 'Fortinet', '2026', 'https://www.credly.com/badges/d211824c-9076-4d47-a3e4-df212f541969', NULL, 'Network Security', 1, 33),
      ('Fortinet FortiGate 7.6 Operator', 'Fortinet', '2026', 'https://www.credly.com/badges/cd693891-405c-4fe2-81c9-16b42816fa0e', NULL, 'Network Security', 1, 34),
      ('Fortinet NSE 3 Certified in Cybersecurity', 'Fortinet', '2026', 'https://www.credly.com/badges/9a8e25b3-ca1d-4010-ba2e-59378b3eb668', NULL, 'Network Security', 1, 35),
      ('Technical Introduction to Cybersecurity 3.0', 'Fortinet', '2026', 'https://www.credly.com/badges/24f091e5-8613-4e39-97b4-df961ee0d4a6', NULL, 'Network Security', 1, 36),
      ('Fortinet Certified Fundamentals Cybersecurity', 'Fortinet', '2026', 'https://www.credly.com/badges/67a908ff-25ff-4595-be0f-341082223ddb', NULL, 'Network Security', 1, 37),
      ('Fortinet NSE 1 Certified in Cybersecurity', 'Fortinet', '2026', 'https://www.credly.com/badges/378cb1cc-36ff-4873-8bf3-343155f79a14', NULL, 'Network Security', 1, 38),
      ('Fortinet NSE 2 Certified in Cybersecurity', 'Fortinet', '2026', 'https://www.credly.com/badges/ac473901-06f2-4919-92e4-485d3233a4e0', NULL, 'Network Security', 1, 39),
      ('Getting Started in Cybersecurity 3.0', 'Fortinet', '2026', 'https://www.credly.com/badges/1d0b424a-bcdd-48bd-b40f-a6af00fc0f05', NULL, 'Network Security', 1, 40),
      ('Introduction to the Threat Landscape 3.0', 'Fortinet', '2026', 'https://www.credly.com/badges/c9f14aef-cfe0-4f45-927f-8442f0e03b05', NULL, 'Network Security', 1, 41);
  END IF;

  -- --- Articulos del blog ---------------------------------------------------
  -- Cuatro entradas sobre trabajo real: dos proyectos propios y dos rutinas
  -- del dia a dia en el SOC. El cuerpo va en HTML porque es lo que espera
  -- /blog/post/ y lo que produce el editor del panel.
  IF (SELECT COUNT(*) FROM `posts`) = 0 THEN
    INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`) VALUES

    -- 1 ----------------------------------------------------------------------
    ('Comprobar si una contraseña está filtrada sin enviársela a nadie',
     'comprobar-si-una-contrasena-esta-filtrada-sin-enviarsela-a-nadie',
     'Have I Been Pwned tiene más de 800 millones de contraseñas filtradas. Se puede consultar esa base sin revelar cuál estás buscando, y el truco que lo hace posible se llama k-anonimato. Así lo implementé en Password Sentinel.',
     '<p>Cuando construí <strong>Password Sentinel</strong>, una extensión de navegador que avisa si una contraseña aparece en filtraciones conocidas, el problema no era técnico sino de confianza. Para saber si tu contraseña está en una brecha hay que compararla contra un corpus de cientos de millones. Y ese corpus no cabe en una extensión.</p>
<p>La solución obvia es preguntarle a un servidor. La solución obvia es también terrible: implicaría que mi extensión envía tus contraseñas a un tercero. Nadie deberia instalar eso, y yo no queria escribirlo.</p>

<h2>El truco: preguntar sin decir qué preguntas</h2>
<p>Have I Been Pwned resuelve esto con una técnica llamada <strong>k-anonimato</strong>. La idea es que en vez de preguntar por tu contraseña, preguntas por un grupo lo bastante grande de candidatas como para que la tuya se pierda dentro.</p>
<p>El procedimiento tiene tres pasos:</p>
<ul>
  <li>Se calcula el <code>SHA-1</code> de la contraseña <strong>en local</strong>, dentro del navegador.</li>
  <li>Se envían al servidor únicamente los <strong>cinco primeros caracteres</strong> hexadecimales de ese hash. Nada más.</li>
  <li>El servidor devuelve todos los hashes de su base que empiezan por ese prefijo, y la comparación final se hace <strong>otra vez en local</strong>.</li>
</ul>
<pre><code>Contraseña:  correcthorsebatterystaple
SHA-1:       BE4A8DE9AFCEE30B29C0A0AB29F9E7A9CF4E1B2C
Se envía:    BE4A8
Se recibe:   ~800 sufijos que empiezan por BE4A8
Se compara:  en el navegador, contra la lista recibida</code></pre>

<h2>Por qué los números funcionan</h2>
<p>Cinco caracteres hexadecimales dan <code>16^5</code>, algo más de un millón de prefijos posibles. Repartidos sobre un corpus de unos 850 millones de hashes, a cada prefijo le tocan del orden de <strong>800 candidatos</strong>.</p>
<p>Eso significa que el servidor sabe que has preguntado por una de unas 800 contraseñas, sin ninguna forma de distinguir cuál. Y no puede afinar con peticiones sucesivas, porque cada consulta devuelve el grupo entero: no hay un segundo intento que estreche el cerco.</p>

<h2>Tres detalles que conviene no pasar por alto</h2>
<p><strong>SHA-1 aquí no es un fallo.</strong> Es lo primero que salta al leer el protocolo, y la respuesta es que SHA-1 no se está usando como función de seguridad: es el índice del corpus. Que SHA-1 tenga colisiones no ayuda a nadie a averiguar qué preguntaste, porque la parte sensible nunca sale del navegador. Otra cosa muy distinta sería usar SHA-1 para almacenar contraseñas, que sí es un error grave.</p>
<p><strong>TLS sigue haciendo falta.</strong> El k-anonimato protege frente al servidor. No protege frente a alguien que observe la red y vea el prefijo. Son dos capas distintas y las dos son necesarias.</p>
<p><strong>Cero apariciones no significa contraseña buena.</strong> Este es el malentendido más común. Que una contraseña no esté en el corpus solo quiere decir que aún no se ha filtrado. <code>Barcelona2026!</code> probablemente dé cero resultados, y sigue siendo una contraseña pésima: entra en cualquier ataque de diccionario con reglas. La comprobación de filtraciones descarta lo que ya se sabe roto; no certifica lo que queda.</p>

<h2>Lo que me llevé de escribirlo</h2>
<p>El k-anonimato me interesa menos por la criptografía que por el planteamiento. La pregunta de partida no fue <em>cómo cifro esto</em>, sino <strong>qué es lo mínimo que necesita saber la otra parte para responderme</strong>. Casi siempre es mucho menos de lo que se acaba enviando por costumbre.</p>
<p>Es el mismo razonamiento que aplico a la analítica de esta web: no guardo direcciones IP porque para contar visitantes no me hacen falta. Guardo un hash con sal y con eso basta. Recoger datos que no necesitas no es neutral: es asumir un riesgo a cambio de nada.</p>',
     'criptografia,have-i-been-pwned,k-anonimato,extensiones,javascript,privacidad',
     'es', 1, '2026-03-14 10:00:00', '2026-03-14 10:00:00'),

    -- 2 ----------------------------------------------------------------------
    ('Triaje de alertas en un SOC: en qué orden mirar lo que salta',
     'triaje-de-alertas-en-un-soc-en-que-orden-mirar',
     'La severidad que trae una alerta no es su prioridad. Cómo ordeno la cola cuando hay más alertas que horas, las tres preguntas con las que abro cada uno y por qué un falso positivo recurrente es un fallo de la regla y no del analista.',
     '<p>Lo primero que se aprende en un SOC es que la cola no se vacía. Siempre hay más alertas que horas, y el trabajo no consiste en mirarlas todas sino en <strong>acertar con el orden</strong>. Esto es cómo lo enfoco yo.</p>

<h2>La severidad no es la prioridad</h2>
<p>Toda alerta llega con una severidad puesta por el fabricante. Es un punto de partida útil y un mal criterio único, porque esa etiqueta se calcula en el vacío: describe lo grave que <em>seria</em> ese evento en abstracto, sin saber nada de tu organización.</p>
<p>La prioridad real sale de cruzar esa severidad con el contexto:</p>
<ul>
  <li><strong>Qué activo es.</strong> El mismo evento no pesa igual en un portátil de becario que en un controlador de dominio.</li>
  <li><strong>Qué usuario.</strong> Una cuenta con privilegios de administración cambia la conversación entera.</li>
  <li><strong>Cuándo.</strong> Actividad normal a las once de la mañana; la misma a las cuatro de la madrugada de un domingo merece una mirada.</li>
  <li><strong>Qué hay alrededor.</strong> Una alerta media aislada es ruido. Tres alertas medias sobre el mismo host en diez minutos son una cadena.</li>
</ul>
<p>Ese último punto es donde una plataforma XDR se separa de un SIEM clásico. Trabajando con <strong>Trend Micro Vision One</strong>, lo que más me ha cambiado el triaje no es detectar más cosas, sino que los eventos lleguen ya <strong>correlacionados</strong>. Ver la cadena completa (correo, ejecución, conexión de salida) evita el error de cerrar tres alertas por separado como poco relevantes cuando juntas cuentan otra historia.</p>

<h2>Las tres preguntas</h2>
<p>Al abrir una alerta voy siempre en el mismo orden, y en este orden concreto:</p>
<ol>
  <li><strong>¿Es real?</strong> Distinguir detección de incidente. La mayor parte del volumen muere aquí, y está bien que así sea.</li>
  <li><strong>¿Es relevante?</strong> Puede ser perfectamente real y no importar. Un escaneo bloqueado en el perímetro es real y no es un incidente.</li>
  <li><strong>¿Está contenido?</strong> Si ha pasado algo, lo urgente no es entenderlo del todo: es que deje de extenderse. Entender viene después.</li>
</ol>
<p>El orden importa porque el error caro es saltarse la tercera para seguir investigando la primera. La curiosidad técnica tira mucho, y contener es aburrido comparado con reconstruir. Contener primero.</p>

<h2>Enriquecer antes de escalar</h2>
<p>Una alerta escalada sin contexto le traslada el trabajo al siguiente nivel y no ahorra nada. Antes de mover algo hacia arriba intento llevar respondido:</p>
<ul>
  <li>Qué hace normalmente ese host o ese usuario, para tener con qué comparar.</li>
  <li>Si el indicador aparece en fuentes de inteligencia y desde cuándo.</li>
  <li>Si esto ya se vio antes y cómo se cerró entonces.</li>
  <li>Qué se ha hecho ya y qué está pendiente.</li>
</ul>
<p>Lo tercero se paga solo. La mitad de las alertas que llegan son variaciones de algo ya resuelto, y sin registro de la decisión anterior el análisis se repite entero cada vez.</p>

<h2>Un falso positivo recurrente es un error de la regla</h2>
<p>Esta es la parte que más se descuida, porque cerrar rápido siempre parece más productivo que arreglar. Si una alerta se cierra como falso positivo por sistema, el problema ya no es la alerta: <strong>es la regla</strong>. Cada repetición cuesta atención, y la atención es el recurso escaso de un SOC.</p>
<p>Peor todavía: una cola llena de ruido conocido educa al equipo para cerrar deprisa. Y el día que entre algo de verdad, llegará con el mismo aspecto que las mil anteriores.</p>
<p>Ajustar una regla no es bajar la guardia. Es decidir a conciencia qué merece interrumpir a una persona, en vez de dejar que lo decida un valor por defecto que puso alguien que no conoce tu red.</p>',
     'soc,blue-team,xdr,respuesta-a-incidentes,trend-micro-vision-one,triaje',
     'es', 1, '2026-04-22 09:30:00', '2026-04-22 09:30:00'),

    -- 3 ----------------------------------------------------------------------
    ('Clasificar phishing en el navegador sin mandar la URL a ningún servidor',
     'clasificar-phishing-en-el-navegador-sin-mandar-la-url',
     'Las listas de navegación segura funcionan, pero implican contarle a alguien por dónde navegas. En NorthGate Browser estoy probando lo contrario: llevar un modelo ONNX pequeño al propio navegador para que la URL no salga nunca del equipo.',
     '<p>Los navegadores llevan años protegiendo contra phishing con listas de reputación. Funciona bien y tiene un coste que casi nunca se menciona: para saber si un sitio es peligroso, alguien tiene que enterarse de que vas a visitarlo. Las implementaciones seria usan trucos para reducirlo, pero la forma del problema no cambia.</p>
<p><strong>NorthGate Browser</strong> es un proyecto en desarrollo temprano donde estoy explorando la otra dirección: en lugar de mandar la URL al modelo, mandar el modelo al navegador.</p>

<h2>Qué se puede saber solo con la URL</h2>
<p>Antes de descargar nada, la propia cadena ya dice bastante. Las señales que estoy usando salen todas de ahí:</p>
<ul>
  <li><strong>Longitud y profundidad</strong> del dominio y de la ruta.</li>
  <li><strong>Número de subdominios.</strong> <code>banco.seguro.login.ejemplo.tk</code> tiene una forma característica.</li>
  <li><strong>Entropía de los caracteres</strong>, que delata dominios generados por algoritmo.</li>
  <li><strong>Presencia de punycode</strong>, la vía clásica del ataque homográfico.</li>
  <li><strong>Marca conocida en el subdominio pero no en el dominio registrable.</strong> Esta es la señal más fuerte que he encontrado, y también la más fácil de explicar: <code>paypal.com.verificacion-cuenta.xyz</code> no es PayPal.</li>
  <li><strong>Proporción de dígitos y guiones</strong>, y el TLD.</li>
</ul>
<p>Nada de esto es concluyente por separado. Juntas, y con suficientes ejemplos, se separan razonablemente bien.</p>

<h2>Por qué ONNX</h2>
<p>Entrenar es cómodo en Python y ejecutar dentro de un navegador no lo es. <strong>ONNX</strong> resuelve exactamente ese hueco: se entrena con las herramientas de siempre, se exporta a un formato intermedio y se ejecuta desde el runtime nativo, sin arrastrar Python al producto final.</p>
<p>En un navegador eso importa por tres motivos muy concretos:</p>
<ul>
  <li><strong>El tamaño se paga en cada instalación.</strong> Un modelo de decenas de megas no es viable dentro de un binario que la gente descarga.</li>
  <li><strong>El presupuesto de latencia es minúsculo.</strong> Esto tiene que resolverse antes de que la página pinte. Hablamos de un puñado de milisegundos, no de cientos.</li>
  <li><strong>No puede depender de la red.</strong> Si necesitara conexión para decidir, habriamos vuelto al punto de partida.</li>
</ul>
<p>La integración va en <strong>Rust</strong>, que es el lenguaje del núcleo sobre el que trabajo, y encaja bien: sin recolector de basura, sin pausas impredecibles en una ruta que se ejecuta en cada navegación.</p>

<h2>El umbral es la decisión difícil</h2>
<p>La parte que más tiempo me está llevando no es el modelo, es dónde poner el corte. Y es porque los dos errores no cuestan lo mismo:</p>
<ul>
  <li>Un <strong>falso negativo</strong> deja pasar una página de phishing. Malo, pero es el estado actual sin ninguna protección.</li>
  <li>Un <strong>falso positivo</strong> marca el banco real del usuario como fraudulento. Eso es peor de lo que parece: entrena a la gente a ignorar el aviso. Y un aviso que se ignora no protege de nada, solo da sensación de que sí.</li>
</ul>
<p>Por eso el umbral está deliberadamente conservador y la señal se plantea como advertencia, no como bloqueo. Prefiero cubrir menos y que el aviso conserve su significado.</p>

<h2>Estado</h2>
<p>Está en desarrollo temprano y lo digo sin adornos: hay un pipeline de extracción de características, un modelo que se comporta de forma razonable en validación y una integración que todavía no consideraria lista. Lo interesante del proyecto, de momento, es la restricción de partida: <strong>si la URL no sale del equipo, hay una categoría entera de fugas que simplemente no puede ocurrir</strong>. Diseñar con esa limitación desde el principio obliga a decisiones bastante más honestas que añadir privacidad al final.</p>',
     'machine-learning,onnx,rust,phishing,privacidad,navegadores',
     'es', 1, '2026-05-30 18:00:00', '2026-05-30 18:00:00'),

    -- 4 ----------------------------------------------------------------------
    ('Automatizar el informe semanal del SOC con Python',
     'automatizar-el-informe-semanal-del-soc-con-python',
     'El informe semanal era tres horas de copiar y pegar que salían iguales cada lunes. Al automatizarlo con Python, los problemas de verdad no fueron el código: fueron la paginación, las zonas horarias y qué pasa cuando el script falla en silencio.',
     '<p>Hay una tarea que aparece en todos los SOC: el informe periódico. Cuántas alertas, de qué tipo, cuántas cerradas, qué tendencia. Se tarda horas, sale casi idéntico cada vez y nadie lo echa de menos cuando desaparece. Es el candidato perfecto para automatizar.</p>
<p>Lo monté en Python. El código fue lo fácil. Lo que costó fue todo lo demás.</p>

<h2>Separar las tres fases</h2>
<p>El primer intento fue un script que consultaba, calculaba y escribía el documento a la vez. Funcionó una semana y se volvió imposible de tocar. Rehecho en tres partes independientes:</p>
<ul>
  <li><strong>Extraer.</strong> Hablar con la API y guardar la respuesta cruda, sin interpretar nada.</li>
  <li><strong>Normalizar.</strong> Pasar esa respuesta a una estructura propia, estable, que no cambie aunque cambie la API.</li>
  <li><strong>Renderizar.</strong> Convertir esa estructura en el documento final.</li>
</ul>
<p>La ventaja aparece a la primera incidencia. Si el informe sale raro, se sabe en qué fase mirar sin releer el script entero. Y si el fabricante cambia un campo, solo se toca la fase de normalizar.</p>

<h2>La paginación, que siempre muerde</h2>
<p>El error clásico, y lo cometí: pedir los datos, recibir una lista con buena pinta y darla por completa. Casi ninguna API devuelve todo de una vez. Suele haber un tope por página y un cursor para seguir.</p>
<p>Lo peor de este fallo es que <strong>no rompe nada</strong>. No hay excepción ni traza. Simplemente el informe dice 200 alertas donde hubo 1.400, y el número parece perfectamente plausible. Estuvo mal dos semanas antes de que alguien lo notara.</p>
<p>Desde entonces, cualquier consulta que pueda devolver más de un elemento pasa por una función que agota el cursor, y el resultado se contrasta con el total que declara la propia API. Si no cuadran, el script se detiene.</p>

<h2>Zonas horarias</h2>
<p>La API responde en UTC. El informe se lee en hora peninsular. Entre una cosa y otra hay una o dos horas según la época del año, y eso desplaza el corte de la semana.</p>
<p>El síntoma es sutil: las alertas del domingo por la noche caen en la semana equivocada. Los totales del mes cuadran, los semanales no, y cuesta ver por qué.</p>
<p>La regla que sigo ahora es simple y no la he vuelto a romper: <strong>todo se maneja en UTC y con fechas conscientes de zona horaria hasta el último momento</strong>. La conversión a hora local ocurre solo al escribir el texto, nunca en un cálculo.</p>

<h2>Que falle en alto, no en silencio</h2>
<p>Un script programado que falla sin avisar es peor que no tenerlo, porque la ausencia de informe se interpreta como semana tranquila. Lo que aprendí a cubrir:</p>
<ul>
  <li><strong>Reintentos con espera creciente</strong> ante límites de peticiones, en vez de machacar la API.</li>
  <li><strong>Idempotencia.</strong> Ejecutarlo dos veces debe producir el mismo informe, no duplicar nada.</li>
  <li><strong>Un aviso explícito al fallar</strong>, con la fase que se rompió. Un traceback en un log que nadie lee no es un aviso.</li>
  <li><strong>Comprobaciones de coherencia:</strong> si el total de la semana es cero, casi seguro que el roto es el script y no la realidad.</li>
</ul>

<h2>Qué no automaticé</h2>
<p>El análisis. El script reúne los datos, calcula las cifras y deja el documento montado. La lectura de <em>por qué</em> han subido las detecciones de un tipo concreto, o si una caída es buena noticia o un sensor caído, la sigue haciendo una persona.</p>
<p>Automatizar la recogida devuelve las horas que se iban en copiar y pegar. Automatizar la conclusión produce informes que nadie se cree, y con razón.</p>',
     'python,automatizacion,soc,reporting,buenas-practicas',
     'es', 1, '2026-06-18 12:00:00', '2026-06-18 12:00:00');
  END IF;
END$$

DELIMITER ;

CALL seed_if_empty();

-- ---------------------------------------------------------------------------
-- Blog: enlazar "Automatizar el informe semanal del SOC con Python" al
-- repositorio publico del generador completo (2026-09-01).
--
-- Guardado por el VALOR anterior conocido del contenido (que NO contenga ya
-- el enlace), no solo por slug: mismo motivo que las correcciones de arriba
-- en `projects` y `certifications` -- evita que reimportar este archivo
-- vuelva a anadir el parrafo si alguien ya lo edito o lo quito a mano desde
-- /admin.
UPDATE `posts` SET `content` = CONCAT(`content`,
  '\r\n<p>Ese generador semanal crecio con el tiempo hasta convertirse en algo mas completo: un sistema que tambien enriquece cada CVE contra NVD, CISA KEV y EPSS antes de meterlo en el informe. Lo publique en abierto: <a href="https://github.com/eduolihez/vision-one-crem-report-generator">el codigo esta en GitHub</a>.</p>')
WHERE `slug` = 'automatizar-el-informe-semanal-del-soc-con-python'
  AND `content` NOT LIKE '%vision-one-crem-report-generator%';

-- ---------------------------------------------------------------------------
-- Blog: cuatro articulos nuevos (2026-09-01). Mismo patron que las
-- ampliaciones de `projects`: solo entran si su slug todavia no existe, asi
-- que reimportar este archivo nunca los duplica.
-- ---------------------------------------------------------------------------

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Priorizar CVEs sin fiarse solo del CVSS',
  'priorizar-cves-sin-fiarse-solo-del-cvss',
  'Un CVSS de 9.8 puede ser irrelevante y uno de 6.5 una emergencia. Como cruzo NVD, el catalogo KEV de CISA y la probabilidad de EPSS para decidir que vulnerabilidad se parchea primero, y como lo automatice para que no dependa de que yo me acuerde de mirarlo.',
  '<p>El error que mas veces he visto -- y que cometi yo tambien al principio -- es ordenar una lista de CVEs por CVSS y llamar a eso priorizacion. El CVSS mide gravedad tecnica en abstracto. No dice si alguien esta explotando ese fallo ahora mismo. Son preguntas distintas, y tratarlas como si fueran la misma hace que se gasten semanas en un CVE de 9.8 que nadie usa mientras uno de 6.5 se explota activamente.</p>\r\n<h2>Tres fuentes, tres preguntas distintas</h2>\r\n<p>Cada una de las siguientes responde algo que las otras dos no saben:</p>\r\n<ul>\r\n  <li><strong>NVD</strong> responde que es el fallo: CVSS, CWE, y la version que lo corrige.</li>\r\n  <li><strong>CISA KEV</strong> responde si se esta explotando de verdad, ahora mismo, confirmado.</li>\r\n  <li><strong>EPSS</strong> responde la probabilidad de que se explote en los proximos 30 dias, aunque todavia no este en KEV.</li>\r\n</ul>\r\n<p>Ninguna sustituye a las otras dos. NVD sin las otras da listas larguisimas sin orden real. KEV solo es binario: dentro o fuera. EPSS solo es un numero sin contexto de que corrige.</p>\r\n<h2>El criterio que aplico</h2>\r\n<p>Con las tres cruzadas, el orden queda asi, sin excepciones:</p>\r\n<ol>\r\n  <li>Si esta en <strong>KEV</strong>, va primero. Da igual el CVSS.</li>\r\n  <li>Si no esta en KEV pero el <strong>EPSS es alto</strong>, va despues. Es la senal de que empieza a explotarse.</li>\r\n  <li>CVSS alto con EPSS bajo y fuera de KEV puede esperar al ciclo normal de parcheo.</li>\r\n</ol>\r\n<p>La sorpresa la primera vez que aplico esto sobre un tenant real siempre es la misma: la lista final no se parece nada a la que sale de ordenar solo por CVSS.</p>\r\n<h2>Por que lo automatice</h2>\r\n<p>Cruzar tres fuentes a mano cada mes no escala, y es justo el tipo de tarea que se salta cuando hay prisa, que es precisamente cuando mas falta hace. Lo integre en el generador de informes que uso para los clientes: cada CVE que aparece se enriquece automaticamente contra las tres fuentes antes de entrar en el documento, con cache en disco para no volver a preguntar por un CVE que ya se consulto. <a href="https://github.com/eduolihez/vision-one-crem-report-generator">El codigo esta publicado</a> si a alguien le sirve de referencia.</p>\r\n<h2>Lo que ninguna de las tres sabe</h2>\r\n<p>Ni NVD, ni KEV, ni EPSS saben si el activo afectado es un portatil de pruebas o un controlador de dominio. Eso solo lo sabe quien conoce la red. La automatizacion ordena por senal tecnica; el contexto de negocio lo sigue poniendo una persona, y ahi es donde de verdad se decide que se parchea esta semana y que espera al mes que viene.</p>',
  'cve,vulnerabilidades,nvd,epss,gestion-de-riesgo', 'es', 1, '2026-07-14 10:00:00', '2026-07-14 10:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'priorizar-cves-sin-fiarse-solo-del-cvss');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Hardening de FortiGate: lo que reviso antes de dar un despliegue por bueno',
  'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno',
  'La configuracion de fabrica de un FortiGate no esta lista para produccion solo porque bloquea trafico por defecto. Esta es la lista que reviso siempre, y por que la inspeccion SSL es la que mas se pospone sin motivo.',
  '<p>La configuracion de fabrica de un FortiGate es un punto de partida razonable, no un estado final. He heredado mas de un firewall ya en produccion donde nadie habia tocado nada de esta lista desde el dia de la instalacion. No es exhaustiva: es lo que reviso siempre, en este orden, antes de dar un despliegue por bueno.</p>\r\n<h2>Administracion</h2>\r\n<ul>\r\n  <li>Solo <strong>HTTPS</strong> en la interfaz de gestion, nunca HTTP, y nunca expuesta a la WAN.</li>\r\n  <li>Acceso restringido por <em>trusted host</em>: IPs concretas, no cualquiera con la contrasena.</li>\r\n  <li>Cuentas nominales por administrador. Compartir el usuario admin por defecto hace imposible saber despues quien cambio que.</li>\r\n  <li>MFA en todas las cuentas de administracion, sin excepcion.</li>\r\n</ul>\r\n<h2>Politicas</h2>\r\n<p>Lo mas comun que encuentro en una auditoria no es un fallo tecnico sofisticado: es una politica <code>ALL a ALL</code> que quedo ahi "temporalmente" hace meses. Reviso siempre:</p>\r\n<ul>\r\n  <li>Que no exista ninguna regla asi de amplia sin fecha de caducidad.</li>\r\n  <li>Que todas las politicas tengan <strong>logging activado</strong>. Sin logs, el resto del stack (SIEM, XDR) no tiene nada que correlacionar.</li>\r\n  <li>Que los servicios que no se usan esten deshabilitados, no solo sin politica que los permita.</li>\r\n</ul>\r\n<h2>La inspeccion SSL, que casi siempre se pospone</h2>\r\n<p>Es el punto que mas se retrasa porque "puede romper algo", y sin el el firewall es efectivamente ciego a casi todo el trafico moderno, que va cifrado. Lo que hago para que no rompa nada al activarlo:</p>\r\n<ul>\r\n  <li>Empezar en modo de inspeccion de certificado si la inspeccion completa no es viable de inmediato -- ver al menos el SNI y el certificado ya aporta algo.</li>\r\n  <li>Desplegar el certificado de la CA del FortiGate por GPO en los equipos del dominio, para no generar avisos de certificado no confiable en cada sesion.</li>\r\n  <li>Excepciones explicitas y documentadas para lo que de verdad no se debe inspeccionar -- nunca una excepcion porque si.</li>\r\n</ul>\r\n<h2>La regla que mas aplico</h2>\r\n<p>Si una politica, una excepcion o una cuenta de administracion no tiene una razon documentada de por que existe, no deberia existir. La mayoria de las exposiciones que encuentro en auditorias no son fallos tecnicos complejos: son configuraciones "temporales" que nadie volvio a mirar.</p>',
  'fortinet,fortigate,hardening,firewall,blue-team', 'es', 1, '2026-08-02 09:00:00', '2026-08-02 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'De soporte tecnico a SOC: lo que cambio no fue el puesto',
  'de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto',
  'El salto de dar soporte a mas de 100 usuarios a triar alertas en un SOC no fue un cambio de titulo de un dia para otro. Fue un cambio en la pregunta que me hacia delante de cada tarea repetitiva.',
  '<p>Empece dando soporte tecnico a mas de cien usuarios: contrasenas bloqueadas, administracion de Active Directory, el dia a dia habitual de cualquiera que empieza en IT. No hay nada malo en ese trabajo -- de hecho es donde aprendi mas de lo que esperaba. Pero hay un momento en el que empiezas a ver patrones, y ese momento es el que nadie te explica de antemano.</p>\r\n<h2>El ticket numero cuarenta y tantos</h2>\r\n<p>La primera vez que reseteas una contrasena es un tramite. La vez cuarenta y tantos, empiezas a preguntarte por que el proceso sigue siendo manual. Ese fue mi patron: no fue una vocacion repentina, fue la irritacion acumulada de repetir lo mismo sin que nadie se planteara automatizarlo. Ahi empece a escribir los primeros scripts en Python, no en un curso, sino para resolver tareas concretas del dia a dia.</p>\r\n<h2>El paso intermedio que nadie menciona</h2>\r\n<p>De soporte no pase directo a SOC. Pase antes por administrar FortiGate y FortiAnalyzer, y por responder incidentes de nivel 1 y 2. Ese paso intermedio importa mas de lo que parece: entender la red desde dentro, tocando firewalls y viendo trafico real, es lo que despues hace que triar una alerta XDR tenga sentido en vez de ser una etiqueta de severidad sin contexto.</p>\r\n<h2>El cambio real no fue de titulo</h2>\r\n<p>Pasar a analista de SOC no fue un cambio de un dia para otro. Fue un cambio en la pregunta que me hacia frente a cada tarea repetitiva: de <em>como lo resuelvo</em> a <em>como hago que esto no vuelva a pasar</em>. Ese giro es el que, con el tiempo, lleva de gestionar tickets a gestionar riesgo.</p>\r\n<h2>Lo que me hubiera gustado saber antes</h2>\r\n<ul>\r\n  <li><strong>El soporte de nivel 1 no es un peaje, es formacion.</strong> Ver por que un usuario hace algo "mal" ensena a disenar sistemas que fallan menos.</li>\r\n  <li><strong>Nadie va a pedirte que automatices nada.</strong> El primer script que escribi para ahorrarme trabajo no me lo pidio nadie.</li>\r\n  <li><strong>El SOC no es un destino, es seguir haciendo la misma pregunta.</strong> Sigo automatizando cosas que antes hacia a mano, el mismo impulso que el primer script de reseteo de contrasenas.</li>\r\n</ul>\r\n<p>Si estas en soporte tecnico y sientes que todavia no estas listo para dar el salto: probablemente ya tienes la parte mas dificil, que es entender la infraestructura real, con usuarios reales rompiendola de formas que ningun curso ensena. Lo que falta no es mas teoria: es empezar a preguntarte, delante de cada tarea repetitiva, como evitar que vuelva a pasar.</p>',
  'carrera,soc,blue-team,automatizacion', 'es', 1, '2026-08-19 08:30:00', '2026-08-19 08:30:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Active Directory: los primeros diez cambios en cualquier dominio nuevo',
  'active-directory-los-primeros-diez-cambios-en-cualquier-dominio-nuevo',
  'Antes de tocar GPOs avanzadas, hay una lista corta que reviso siempre en un dominio de Active Directory nuevo. La mayoria llevan mal configuradas desde la instalacion y nadie las vuelve a mirar.',
  '<p>Cuando heredo un dominio de Active Directory que no monte yo, hay una lista rapida que reviso antes que nada, antes de meterme en GPOs complejas. Son los fallos mas comunes, los mas baratos de arreglar, y con mas impacto real si se explotan.</p>\r\n<h2>Cuentas y privilegios</h2>\r\n<ol>\r\n  <li><strong>Contrasenas de cuentas privilegiadas que no caducan.</strong> Sorprendentemente comun, incluso en administradores de dominio. Se revisa en un minuto con PowerShell.</li>\r\n  <li><strong>Demasiada gente en Domain Admins.</strong> El grupo deberia tener el minimo posible, y ninguna de esas cuentas deberia usarse para el dia a dia.</li>\r\n  <li><strong>Cuentas de servicio con privilegios de mas.</strong> Se crean "temporalmente" con permisos de administrador de dominio para instalar algo, y ahi se quedan.</li>\r\n</ol>\r\n<h2>Configuracion que se hereda mal</h2>\r\n<ol start="4">\r\n  <li><strong>Delegacion de Kerberos sin restricciones.</strong> Es una de las rutas de escalada de privilegios mas explotadas en AD real. Migrar a delegacion restringida siempre que se pueda.</li>\r\n  <li><strong>Politica de contrasenas por defecto.</strong> Sigue sin exigir una longitud minima competitiva. Subir a 14 caracteres o mas.</li>\r\n  <li><strong>LAPS sin desplegar.</strong> Si el administrador local comparte contrasena en todos los equipos, un solo equipo comprometido da acceso lateral a todos los demas. Es gratuito y lleva anos siendo casi un estandar.</li>\r\n  <li><strong>SMBv1 todavia activo</strong> "por si acaso". Anos despues de que dejara de ser defendible, sigue apareciendo.</li>\r\n</ol>\r\n<h2>Visibilidad y recuperacion</h2>\r\n<ol start="8">\r\n  <li><strong>Auditoria avanzada sin activar.</strong> Sin registro de cambios de grupo y autenticaciones fallidas, cualquier investigacion empieza a ciegas.</li>\r\n  <li><strong>Grupos anidados sin documentar.</strong> Varios niveles de anidamiento acaban dando accesos que nadie recuerda haber concedido.</li>\r\n  <li><strong>Sin plan de recuperacion del propio AD probado de verdad.</strong> Si el dominio cae, todo lo demas cae con el. Es la pieza que menos se puede permitir fallar en silencio.</li>\r\n</ol>\r\n<p>Ninguno de estos diez puntos necesita presupuesto ni herramientas de terceros: es configuracion nativa de Windows Server. Es exactamente el tipo de deuda que se acumula porque "funciona asi desde siempre", hasta que aparece en una auditoria o, peor, en un incidente real.</p>',
  'active-directory,hardening,windows-server,sysadmin', 'es', 1, '2026-08-28 09:00:00', '2026-08-28 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'active-directory-los-primeros-diez-cambios-en-cualquier-dominio-nuevo');

-- Ajustes del sitio. INSERT IGNORE: si ya existen, NO se tocan tus valores.
INSERT IGNORE INTO `settings` (`key`, `value`) VALUES
  ('open_to_work',      '1'),   -- badge "Disponible" del hero
  ('contact_enabled',   '1'),   -- formulario de contacto activo
  ('analytics_enabled', '1'),   -- registro de visitas activo
  ('announcement_on',   '0'),   -- banner superior activo
  ('announcement_es',   ''),    -- texto del banner en espanol
  ('announcement_en',   ''),    -- ... ingles
  ('announcement_ca',   ''),    -- ... catalan
  ('announcement_url',  '');    -- enlace opcional del banner


-- ===========================================================================
--  7. LIMPIEZA
--  Los helpers ya han hecho su trabajo: no deben quedarse en la base de datos.
-- ===========================================================================
DROP PROCEDURE IF EXISTS `add_column_if_missing`;
DROP PROCEDURE IF EXISTS `add_index_if_missing`;
DROP PROCEDURE IF EXISTS `seed_if_empty`;
DROP PROCEDURE IF EXISTS `repair_legacy_posts`;
