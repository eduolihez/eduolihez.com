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

-- Cuentas de acceso a lab.eduolihez.com (PhishLab completo, marca real,
-- detras de este gate en PHP -- ver server/lab/auth.php y
-- public/lab-app/index.php). Gestionadas desde /admin -> lab-users.php.
-- lockout_enabled: interruptor por usuario para el bloqueo por fuerza bruta
-- (ver lab_login_is_locked() en server/lab/auth.php) -- por si algun dia hay
-- una cuenta de confianza (ej. una intranet) para la que no tiene sentido.
CREATE TABLE IF NOT EXISTS `lab_users` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`         VARCHAR(60)  NOT NULL,
  `password_hash`    VARCHAR(255) NOT NULL,
  `active`           TINYINT(1)   NOT NULL DEFAULT 1,
  `lockout_enabled`  TINYINT(1)   NOT NULL DEFAULT 1,
  `last_login`       DATETIME     NULL,
  `created_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_lab_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Intentos de login de lab.eduolihez.com (control de fuerza bruta), separado
-- de login_attempts (ese es del panel /admin) para no mezclar dos superficies
-- de acceso distintas en el mismo contador.
CREATE TABLE IF NOT EXISTS `lab_login_attempts` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ip_address`   VARCHAR(45)  NOT NULL,
  `username`     VARCHAR(60)  NULL,
  `success`      TINYINT(1)   NOT NULL DEFAULT 0,
  `attempted_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ip_time` (`ip_address`, `attempted_at`),
  KEY `idx_user_time` (`username`, `attempted_at`)
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

-- Registro de "apps" para admin.eduolihez.com (docs/designs/admin-dashboard.md):
-- un sub-dashboard por proyecto (eduolihez.com, y los que vengan despues,
-- p.ej. BloomGram), cada uno con su propia clave de ingesta.
--
-- NO se llama `projects`: esa tabla ya existe mas abajo (seccion 2) y es
-- otra cosa -- las tarjetas de portfolio (Blue Team Hub, PromptMaster...).
-- Confundir los dos nombres fue el primer hallazgo de la revision de
-- arquitectura de este diseno.
--
-- `api_key_hash` guarda SHA-256 de la clave, nunca la clave en claro (mismo
-- tratamiento que `visits.ip_hash`): la clave real solo se ensena una vez,
-- al crearla o rotarla, desde el panel. `key_rotated_at` es el mecanismo de
-- revocacion -- rotar invalida la clave anterior al instante, no hace falta
-- una lista de claves revocadas a esta escala.
CREATE TABLE IF NOT EXISTS `apps` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `slug`             VARCHAR(60)  NOT NULL,
  `display_name`     VARCHAR(100) NOT NULL,
  `api_key_hash`     CHAR(64)     NULL,      -- SHA-256 hex; NULL hasta generar la clave
  `allowed_origins`  TEXT         NULL,      -- JSON: ["https://...", "chrome-extension://..."]
  `key_rotated_at`   DATETIME     NULL,
  `created_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_slug` (`slug`)
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
  -- idx_status_order es legado (`sort_order` ya no ordena la vista publica,
  -- ver /api/projects.php); se deja por si `sort_order` vuelve a usarse.
  -- idx_status_updated cubre el ORDER BY actual: featured, luego updated_at.
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
  -- Categoria UNICA para el filtro del listado (2026-09-06): las tags de
  -- arriba son libres y por articulo salian ~5, asi que con 13 articulos el
  -- filtro llegaba a mostrar mas de 40 botones -- inutilizable. `category`
  -- es un valor fijo de una lista corta (ver POST_CATEGORIES en
  -- server/lib/post.php), pensado solo para filtrar/navegar; `tags` sigue
  -- existiendo tal cual para SEO (keywords de Schema.org) y como metadato
  -- fino visible en la propia tarjeta/articulo.
  `category`     VARCHAR(40)  NULL,
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

-- Telemetria generica de las apps registradas en `apps` (arriba, seccion 1):
-- instalaciones, errores, clics... lo que cada app quiera reportar. A
-- diferencia de `visits` (forma fija, pagina vista de ESTE sitio), aqui el
-- `payload` es JSON de forma libre porque una app futura puede reportar
-- tipos de evento que hoy no existen.
--
-- `UNIQUE KEY (app_id, event_id)` deduplica reintentos: si el cliente (una
-- extension, un programa, no del todo bajo control en el momento de la
-- peticion) repite el mismo POST por un fallo de red, la segunda llegada no
-- duplica la fila.
-- `event_id` lo genera el cliente (p.ej. un UUID por evento), no el servidor.
--
-- Se purga sola igual que `visits` (400 dias) por consistencia -- decision
-- revisada en plan-eng-review 2026-09-04, mantenida a proposito: sin datos
-- reales de cuanto hace falta retener eventos de una app que aun no existe,
-- fijar otro numero seria adivinar.
CREATE TABLE IF NOT EXISTS `app_events` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_id`     INT UNSIGNED NOT NULL,
  `event_id`   VARCHAR(64)  NOT NULL,
  `type`       VARCHAR(60)  NOT NULL,
  `payload`    TEXT         NULL,           -- JSON, forma libre por app
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_dedup` (`app_id`, `event_id`),
  KEY `idx_app_type_time` (`app_id`, `type`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rate-limit por IP de server/api/events.php, ANTES de identificar la app
-- (una clave invalida nunca llega al contador por app_id de arriba, asi que
-- sin esto el limite por clave no frena intentos de fuerza bruta). Misma
-- IP hasheada que `visits.ip_hash` -- nunca la IP en claro. Vida muy corta
-- a proposito: la unica consulta que hace este endpoint sobre esta tabla es
-- "cuantas peticiones en el ultimo minuto", asi que un dia de margen ya es
-- generoso; se purga sola con el mismo patron probabilistico que `visits`
-- (ver server/api/events.php).
CREATE TABLE IF NOT EXISTS `app_events_ip_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ip_hash`    CHAR(64)  NOT NULL,
  `created_at` DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_hash_time` (`ip_hash`, `created_at`)
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

-- admin.eduolihez.com (docs/designs/admin-dashboard.md): cada visita queda
-- ligada a la app que la genero. El backfill de abajo asigna las visitas ya
-- existentes (todas de antes de que existiera el concepto de "apps") a
-- eduolihez.com -- son suyas, no deben quedar en NULL.
CALL add_column_if_missing('visits', 'app_id', 'INT UNSIGNED NULL AFTER `id`');
CALL add_index_if_missing('visits', 'idx_app_time', '`app_id`, `visited_at`');

-- Rediseno del selector de proyectos de /admin (2026-09-08): que apps tienen
-- secciones de contenido (Proyectos/Certificaciones/Blog) propias frente a
-- las que son solo un sitio estatico sin CMS (nowait). 0 por defecto porque
-- una app nueva registrada desde el panel normalmente NO trae contenido
-- propio -- eduolihez.com es la excepcion, no la regla, y se marca explicita
-- mas abajo.
CALL add_column_if_missing('apps', 'has_content', "TINYINT(1) NOT NULL DEFAULT 0 AFTER `display_name`");

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

-- Proyectos: la portada publica ahora ordena por featured + ultima
-- actualizacion (ver /api/projects.php), no por sort_order.
CALL add_index_if_missing('projects', 'idx_status_updated', '`status`, `featured`, `updated_at`');

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
SELECT 'Password Centinel', 'Password Centinel',
       'Gestor de contrasenas 100% local para Chrome: cifrado AES-256-GCM, TOTP/2FA y comprobacion de filtraciones con Have I Been Pwned, sin enviar datos a ningun servidor propio.',
       'Fully local password manager for Chrome: AES-256-GCM encryption, built-in TOTP/2FA and breach checking via Have I Been Pwned, without sending data to any first-party server.',
       '["JavaScript","Chrome Extension","Have I Been Pwned API"]', '["private-code"]',
       NULL, '/projects/password-centinel/', 'https://chromewebstore.google.com/detail/fiephcocbhccfidlfnklglonoplmggcl', 0, 4, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'Password Centinel');

-- Correccion (2026-09-17): "Password Sentinel" -> "Password Centinel" (el
-- nombre real del producto; "Sentinel" quedo mal desde el alta original),
-- badge de open-source a private-code (el repo de GitHub es privado), y
-- demo_url/store_url al slug y ficha de tienda reales. La extension ya
-- estaba publicada en Chrome Web Store bajo el nombre antiguo; el nombre
-- mostrado en la tienda se actualiza aparte, al subir la v1.0.0. Guardado
-- por los valores anteriores exactos para no pisar una edicion manual hecha
-- despues desde /admin.
UPDATE `projects` SET
  `title_es` = 'Password Centinel',
  `title_en` = 'Password Centinel',
  `badges` = '["private-code"]',
  `demo_url` = '/projects/password-centinel/',
  `store_url` = 'https://chromewebstore.google.com/detail/fiephcocbhccfidlfnklglonoplmggcl'
WHERE `title_es` = 'Password Sentinel' AND `badges` = '["open-source"]';

INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'PromptMaster Universal AI', 'PromptMaster Universal AI',
       'Extension de Chrome que optimiza tus prompts para ChatGPT, Claude y Gemini.',
       'Chrome extension that optimizes your prompts for ChatGPT, Claude and Gemini.',
       '["JavaScript","Chrome Extension","Prompt Engineering"]', '["private-code"]',
       NULL, '/projects/prompt-master/', 'https://addons.mozilla.org/es-ES/firefox/addon/promptmaster/', 0, 5, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'PromptMaster Universal AI');

-- Correccion (2026-09-17): demo_url de PromptMaster al slug nuevo
-- (prompt-master, con guion, igual que /apps/prompt-master/) en vez del
-- slug viejo (promptmaster, sin guion) que ya no sirve ninguna pagina.
UPDATE `projects` SET `demo_url` = '/projects/prompt-master/'
WHERE `title_es` = 'PromptMaster Universal AI' AND `demo_url` = '/projects/promptmaster/';

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

-- Proyectos: kev-digest y phishing-triage (2026-09-04). El primero alimenta
-- KEV Watch en Blue Team Hub (repo_url apunta al pipeline, no a un sitio
-- propio: no tiene demo_url). El segundo se acaba de hacer publico esta
-- misma sesion; ver el post del blog para el resultado completo con tablas.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'kev-digest', 'kev-digest',
       'Vigilancia automatizada del catalogo CISA KEV: comprueba cada tres horas que vulnerabilidades tienen explotacion activa confirmada, marca las de uso conocido en ransomware y deja un registro versionado en Markdown. Python sin dependencias, sobre GitHub Actions.',
       'Automated CISA KEV catalog monitoring: checks every three hours which vulnerabilities have confirmed active exploitation, flags known ransomware use, and keeps a versioned Markdown log. Dependency-free Python on GitHub Actions.',
       '["Python","GitHub Actions"]', '["open-source"]',
       'https://github.com/eduolihez/kev-digest', NULL, NULL, 1, 9, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'kev-digest');

INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'phishing-triage', 'phishing-triage',
       'Mide sobre 7.822 correos reales si el desacuerdo entre 4 clasificadores sirve para priorizar que correo revisa antes un analista. El resultado no fue el esperado: pierde contra una senal mas simple, la incertidumbre media del propio ensemble.',
       'Measures over 7,822 real emails whether disagreement between 4 classifiers helps prioritize which email an analyst reviews first. The result was not the expected one: it loses against a simpler signal, the ensemble''s own mean uncertainty.',
       '["Python","scikit-learn"]', '["open-source"]',
       'https://github.com/eduolihez/phishing-triage', NULL, NULL, 1, 10, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'phishing-triage');

-- Proyectos: anadir PhishLab (2026-09-14, docs/EDUOLIHEZ.md en el repo de
-- PhishLab). Repo privado -- el codigo compone material de phishing con
-- marca real, no tiene sentido publicarlo -- por eso repo_url va a NULL y el
-- badge es private-code, mismo patron que Zeora. demo_url SI es publica:
-- una copia estatica de la demo (marcas ficticias, sin exportacion) vive en
-- public/projects/phishlab/, igual que nowait o passwdcentinel -- el sitio
-- esta publicado aunque el codigo no. Esta app tambien tiene fila en `apps`
-- (ver el INSERT de mas arriba en este archivo) para reportar analitica al
-- panel multi-proyecto.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `description_es`, `description_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'PhishLab — Biblioteca de plantillas de phishing', 'PhishLab — Phishing Template Library',
       'Generador de material para simulaciones de phishing autorizadas: plantillas por bloques, calibradas por senal, con exportacion lista para GoPhish. Demo publica con marcas ficticias.',
       'Template generator for authorized phishing simulations: block-based templates calibrated by detection signal, with ready-to-import GoPhish export. Public demo uses fictional brands only.',
       '<p>Herramienta interna que uso para preparar ejercicios de concienciacion en seguridad: cada plantilla se compone por bloques anotados y se calibra por seis senales de deteccion independientes (urgencia, erratas, saludo generico, dominio del remitente, enlace que no coincide, incoherencia de marca), asi que el informe final puede decir que senal concreta se le paso a cada persona, no solo si pico o no.</p><p>Wizard guiado de 4 pasos (correo, landing, marca, exportar), biblioteca filtrable por senal, compania o categoria, e importacion de material real (.eml o HTML pegado) saneado automaticamente antes de guardarlo.</p><p>La version completa (marcas reales, exportacion a GoPhish) se queda en local a proposito. Lo que ves aqui es la demo publica: marcas inventadas, sin exportacion, pensada para ensenar la arquitectura sin publicar un kit de phishing funcional.</p>',
       '<p>Internal tool I use to prepare security-awareness exercises: every template is composed from annotated blocks and calibrated across six independent detection signals (urgency, typos, generic greeting, sender domain, mismatched link, brand inconsistency), so the final report can say exactly which signal a given person missed, not just whether they clicked.</p><p>Guided 4-step wizard (email, landing, branding, export), a library filterable by signal, company or category, and import of real captured material (.eml or pasted HTML), sanitized automatically before saving.</p><p>The full tool (real brands, GoPhish export) stays local on purpose. What you see here is the public demo: fictional brands, no export, built to show the architecture without publishing a working phishing kit.</p>',
       '["JavaScript","ES Modules","Node.js","GoPhish"]', '["private-code"]',
       NULL, '/projects/phishlab/', NULL, 1, 12, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'PhishLab — Biblioteca de plantillas de phishing');

-- Correccion (2026-09-15, docs/EDUOLIHEZ.md): la version completa de
-- PhishLab ya NO se queda solo en local -- vive en lab.eduolihez.com detras
-- de HTTP Basic Auth (ver CLOUDFLARE.md, seccion 5), disponible bajo peticion
-- en vez de "se queda en local a proposito". Guardado por el valor ANTERIOR
-- exacto, para no pisar una edicion manual hecha despues desde /admin.
UPDATE `projects` SET
  `description_es` = '<p>Herramienta interna que uso para preparar ejercicios de concienciacion en seguridad: cada plantilla se compone por bloques anotados y se calibra por seis senales de deteccion independientes (urgencia, erratas, saludo generico, dominio del remitente, enlace que no coincide, incoherencia de marca), asi que el informe final puede decir que senal concreta se le paso a cada persona, no solo si pico o no.</p><p>Wizard guiado de 4 pasos (correo, landing, marca, exportar), biblioteca filtrable por senal, compania o categoria, e importacion de material real (.eml o HTML pegado) saneado automaticamente antes de guardarlo.</p><p>Lo que ves aqui es la demo publica: marcas inventadas, sin exportacion. La version completa (marcas reales, exportacion a GoPhish) esta disponible bajo peticion -- escribeme si quieres probarla de verdad.</p>',
  `description_en` = '<p>Internal tool I use to prepare security-awareness exercises: every template is composed from annotated blocks and calibrated across six independent detection signals (urgency, typos, generic greeting, sender domain, mismatched link, brand inconsistency), so the final report can say exactly which signal a given person missed, not just whether they clicked.</p><p>Guided 4-step wizard (email, landing, branding, export), a library filterable by signal, company or category, and import of real captured material (.eml or pasted HTML), sanitized automatically before saving.</p><p>What you see here is the public demo: fictional brands, no export. The full tool (real brands, GoPhish export) is available on request -- reach out if you would like to try it for real.</p>'
WHERE `title_es` = 'PhishLab — Biblioteca de plantillas de phishing'
  AND `description_es` = '<p>Herramienta interna que uso para preparar ejercicios de concienciacion en seguridad: cada plantilla se compone por bloques anotados y se calibra por seis senales de deteccion independientes (urgencia, erratas, saludo generico, dominio del remitente, enlace que no coincide, incoherencia de marca), asi que el informe final puede decir que senal concreta se le paso a cada persona, no solo si pico o no.</p><p>Wizard guiado de 4 pasos (correo, landing, marca, exportar), biblioteca filtrable por senal, compania o categoria, e importacion de material real (.eml o HTML pegado) saneado automaticamente antes de guardarlo.</p><p>La version completa (marcas reales, exportacion a GoPhish) se queda en local a proposito. Lo que ves aqui es la demo publica: marcas inventadas, sin exportacion, pensada para ensenar la arquitectura sin publicar un kit de phishing funcional.</p>';

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

-- Proyectos: anadir NoWait (2026-09-06). Extension de navegador (fork de
-- FastForward, Unlicense) que evade acortadores de enlaces; el content
-- script solo se inyecta en los dominios con bypass real, no en <all_urls>.
-- Tiene landing de bienvenida propia en /projects/nowait/ (demo_url), igual
-- que Blue Team Hub lleva repo_url y demo_url a la vez.
--
-- Actualizado 2026-09-17: el repo de GitHub paso a privado (repo_url NULL,
-- badge private-code en vez de open-source) y la extension se publica esta
-- misma semana, asi que status pasa de 'draft' a 'published'.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'NoWait', 'NoWait',
       'Extension de navegador que evade automaticamente las pantallas de espera de los acortadores de enlaces y bloquea registradores de IP. Mas de 90 bypasses especificos por sitio, inyectados solo donde realmente hacen falta.',
       'Browser extension that automatically bypasses link-shortener wait screens and blocks IP loggers. 90+ site-specific bypasses, injected only where they''re actually needed.',
       '["JavaScript","Chrome Extension","Manifest V3"]', '["private-code"]',
       NULL, '/projects/nowait/', NULL, 0, 11, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'NoWait');

-- Correccion (2026-09-17): cubre la fila de NoWait que ya estuviera
-- insertada con los valores antiguos (el INSERT de arriba solo aplica el
-- valor nuevo si la fila no existe todavia). Guardado por los valores
-- anteriores exactos para no pisar una edicion manual hecha despues desde
-- /admin.
UPDATE `projects` SET
  `badges` = '["private-code"]',
  `repo_url` = NULL,
  `status` = 'published'
WHERE `title_es` = 'NoWait' AND `badges` = '["open-source"]' AND `status` = 'draft';

-- Proyectos: anadir Chess Copilot (2026-09-22). Extension MV3 que analiza
-- partidas de chess.com con Stockfish 16 en WASM enteramente en el cliente.
-- Repo privado -- badge private-code, sin repo_url -- y sin landing propia
-- todavia, asi que tampoco lleva demo_url.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'Chess Copilot', 'Chess Copilot',
       'Extension de Chrome que analiza partidas de chess.com con Stockfish 16 en WebAssembly y muestra las mejores jugadas en el panel lateral nativo. Cien por cien local, sin backend ni telemetria; pensada solo para practica y analisis, no para partidas puntuadas.',
       'Chrome extension that analyzes chess.com games with Stockfish 16 in WebAssembly and shows the best moves in the native side panel. Fully local, no backend or telemetry; built for practice and analysis, not rated games.',
       '["JavaScript","Stockfish","WebAssembly","Chrome Extension"]', '["private-code"]',
       NULL, NULL, NULL, 0, 13, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'Chess Copilot');

-- Proyectos: anadir BadaVeu (2026-09-22). Plataforma GovTech PWA de
-- participacion ciudadana. Repo privado -- badge private-code -- y sin
-- landing publica todavia.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'BadaVeu', 'BadaVeu',
       'Plataforma GovTech PWA de participacion ciudadana para la gestion de incidencias urbanas en Badalona.',
       'GovTech PWA for citizen participation and urban incident management in Badalona.',
       '["TypeScript","PWA"]', '["private-code"]',
       NULL, NULL, NULL, 0, 14, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'BadaVeu');

-- Zeora ya no esta activo (2026-09-22): se retira de la vista publica sin
-- borrar la fila, por si se retoma. Guardado por el status anterior para no
-- pisar una reactivacion manual hecha despues desde /admin.
UPDATE `projects` SET `status` = 'draft'
WHERE `title_es` = 'Zéora' AND `status` = 'published';

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

-- Insignias reales de Credly (2026-09-22), no el logo generico del emisor:
-- para el visualizador en formato galeria, cada credencial verificada en
-- Credly muestra su propia imagen (revisado contra
-- credly.com/users/eduolihez/badges). Las certificaciones sin badge de
-- Credly (Trend Micro, LinkedIn...) no llevan imagen inventada -- se quedan
-- con el sello de color + inicial, como hasta ahora.
-- Guardado por `logo_url IS NULL`: si alguien sube un logo distinto a mano
-- desde /admin, reimportar esto no lo pisa.
UPDATE `certifications` SET `logo_url` = CASE `name`
  WHEN 'IT Specialist - Python' THEN 'https://images.credly.com/images/3c4602d8-832e-4a24-b42d-00359ce746f7/ITS-Badges_Python_1200px.png'
  WHEN 'IC3 Digital Literacy GS6 Level 1' THEN 'https://images.credly.com/images/29a6f7a3-2cf6-426c-969d-e432b44532e0/IC3_Digital_Literacy_Levels_1.png'
  WHEN 'Microsoft Certified: Azure AI Fundamentals' THEN 'https://images.credly.com/images/4136ced8-75d5-4afb-8677-40b6236e2672/azure-ai-fundamentals-600x600.png'
  WHEN 'Fortinet Certified Associate Cybersecurity' THEN 'https://images.credly.com/images/20082fc1-94af-4773-9df0-28856b566748/image.png'
  WHEN 'Fortinet FortiGate 7.6 Operator' THEN 'https://images.credly.com/images/453a3ef3-b400-4840-91b1-2f1f5157e015/blob'
  WHEN 'Fortinet NSE 3 Certified in Cybersecurity' THEN 'https://images.credly.com/images/7ca06297-1543-4ed2-b9fc-7f0af8635700/blob'
  WHEN 'Technical Introduction to Cybersecurity 3.0' THEN 'https://images.credly.com/images/eb17d3c5-12f5-4be9-87b5-a6ccff62a22b/blob'
  WHEN 'Fortinet Certified Fundamentals Cybersecurity' THEN 'https://images.credly.com/images/22a0ece5-ff05-4594-8320-25e55e9ae203/image.png'
  WHEN 'Fortinet NSE 1 Certified in Cybersecurity' THEN 'https://images.credly.com/images/0dc7965b-8507-4312-9c12-1add6c50fa49/blob'
  WHEN 'Fortinet NSE 2 Certified in Cybersecurity' THEN 'https://images.credly.com/images/a30952f3-f354-4233-b02a-690ffe95d190/blob'
  WHEN 'Getting Started in Cybersecurity 3.0' THEN 'https://images.credly.com/images/a27867b1-d64f-4890-b577-89f162015407/blob'
  WHEN 'Introduction to the Threat Landscape 3.0' THEN 'https://images.credly.com/images/a06a4e98-21bf-49ab-ad70-c61641f26fc8/blob'
END
WHERE `name` IN (
  'IT Specialist - Python', 'IC3 Digital Literacy GS6 Level 1',
  'Microsoft Certified: Azure AI Fundamentals', 'Fortinet Certified Associate Cybersecurity',
  'Fortinet FortiGate 7.6 Operator', 'Fortinet NSE 3 Certified in Cybersecurity',
  'Technical Introduction to Cybersecurity 3.0', 'Fortinet Certified Fundamentals Cybersecurity',
  'Fortinet NSE 1 Certified in Cybersecurity', 'Fortinet NSE 2 Certified in Cybersecurity',
  'Getting Started in Cybersecurity 3.0', 'Introduction to the Threat Landscape 3.0'
) AND `logo_url` IS NULL;

-- Correccion (2026-09-22): "Introduccion a la Ciberseguridad" (PDF propio de
-- Cisco Networking Academy, 2023) y la insignia de Credly "Introduction to
-- Cybersecurity" (Cisco, emitida 1 mar 2025) son el mismo curso -- se
-- actualiza al nombre/fecha de Credly, mas verificable, y se anade la
-- insignia real. El PDF original se mantiene como `credential_url`: no hay
-- URL de insignia individual de Credly capturada para este par todavia.
-- Mismo caso para "Introduction to Modern AI": el nombre ya coincidia, solo
-- cambian emisor/fecha/imagen. Guardado por el `issuer` anterior exacto.
UPDATE `certifications` SET
  `name` = 'Introduction to Cybersecurity',
  `issuer` = 'Cisco',
  `issue_date` = '2025',
  `logo_url` = 'https://images.credly.com/images/af8c6b4e-fc31-47c4-8dcb-eb7a2065dc5b/I2CS__1_.png'
WHERE `name` = 'Introducción a la Ciberseguridad' AND `issuer` = 'Cisco Networking Academy';

UPDATE `certifications` SET
  `issuer` = 'Cisco',
  `issue_date` = '2025',
  `logo_url` = 'https://images.credly.com/images/e2d12302-10f9-40d4-8ff1-066a7008b61d/blob'
WHERE `name` = 'Introduction to Modern AI' AND `issuer` = 'Cisco Networking Academy';

-- Blog: etiquetas y fecha de publicacion propia.
CALL add_column_if_missing('posts', 'tags',         "VARCHAR(255) NULL AFTER `cover_url`");
CALL add_column_if_missing('posts', 'published_at', "DATETIME NULL AFTER `visible`");
CALL add_index_if_missing('posts', 'idx_visible_lang', '`visible`, `lang`, `published_at`');

-- Blog: categoria unica para el filtro (ver comentario en la definicion de
-- `posts` mas arriba). `tags` no se toca -- sigue siendo libre y para SEO.
CALL add_column_if_missing('posts', 'category', "VARCHAR(40) NULL AFTER `tags`");

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

  -- --- Apps (admin.eduolihez.com) -------------------------------------------
  -- Solo la app "eduolihez" en la siembra inicial: BloomGram y las que
  -- vengan despues se registran desde el panel cuando existan de verdad, no
  -- se inventan aqui. Sin api_key_hash todavia -- la clave real se genera y
  -- se ensena una vez desde /admin (docs/designs/admin-dashboard.md), nunca
  -- se guarda en claro ni se versiona en este archivo.
  IF (SELECT COUNT(*) FROM `apps`) = 0 THEN
    INSERT INTO `apps` (`slug`, `display_name`)
    VALUES ('eduolihez', 'eduolihez.com');
  END IF;
END$$

DELIMITER ;

CALL seed_if_empty();

-- Backfill: las visitas ya existentes son todas de eduolihez.com (el
-- concepto de "apps" no existia cuando se registraron). Guardado por
-- `app_id IS NULL`, no por rango de fechas ni otro criterio -- asi es
-- naturalmente idempotente: una vez rellenado, reimportar este archivo no
-- vuelve a tocar esas filas ni pisa una asignacion manual futura.
UPDATE `visits`
SET `app_id` = (SELECT `id` FROM `apps` WHERE `slug` = 'eduolihez')
WHERE `app_id` IS NULL;

-- eduolihez.com es la unica app con secciones de contenido propias
-- (Proyectos/Certificaciones/Blog): marca su fila explicitamente. Guardado
-- por `has_content = 0` (el DEFAULT recien anadido), no solo por slug -- si
-- alguien lo desmarca a mano desde el panel mas adelante, reimportar esto no
-- lo vuelve a marcar por encima.
UPDATE `apps` SET `has_content` = 1 WHERE `slug` = 'eduolihez' AND `has_content` = 0;

-- Registro de "nowait" (docs/designs/admin-dashboard.md, extension 2026-09-08):
-- sitio estatico en public/projects/nowait/ (HTML/CSS/JS a mano, sin BD ni
-- CMS), servido en /projects/nowait/... -- no tenia fila en `apps` hasta
-- ahora, asi que su trafico no se podia ver por separado en el selector de
-- proyectos. `has_content` se queda en el DEFAULT (0): no tiene
-- Proyectos/Certificaciones/Blog que gestionar, solo analitica de visitas.
-- Sin api_key_hash: no reporta eventos a server/api/events.php, solo
-- visitas normales via server/api/visit.php (ver ese archivo: resolve_app_id()).
INSERT INTO `apps` (`slug`, `display_name`)
SELECT 'nowait', 'NoWait'
WHERE NOT EXISTS (SELECT 1 FROM `apps` WHERE `slug` = 'nowait');

-- Registro de "phishlab" (2026-09-14, docs/EDUOLIHEZ.md en el repo de
-- PhishLab): a diferencia de nowait, esta SI lleva api_key_hash desde el
-- principio -- la clave se genero fuera del panel (Claude Code, en la misma
-- sesion que preparo esta migracion) y aqui solo se guarda su SHA-256, nunca
-- la clave en claro, mismo tratamiento que ya describe
-- docs/designs/admin-dashboard.md para toda `apps.api_key_hash`. La clave
-- real se le entrego a Eduardo una sola vez fuera de este archivo y ya esta
-- copiada en `assets/telemetry.config.json` (gitignored) del repo de
-- PhishLab, listo para que la demo empiece a mandar eventos con solo
-- desplegar. allowed_origins solo permite el propio dominio: la demo vive en
-- public/projects/phishlab/, mismo origen que el resto del sitio.
-- has_content se queda en el DEFAULT (0): sin Proyectos/Certificaciones/Blog
-- propios, solo analitica de visitas y eventos.
INSERT INTO `apps` (`slug`, `display_name`, `api_key_hash`, `allowed_origins`)
SELECT 'phishlab', 'PhishLab',
       'afa925ac36e50099ff7e3d32dd3e88a21e22a317c54d07b01bfeb9d36cb84a28',
       '["https://eduolihez.com"]'
WHERE NOT EXISTS (SELECT 1 FROM `apps` WHERE `slug` = 'phishlab');

-- Correccion (2026-09-15, docs/EDUOLIHEZ.md): la extension de captura de
-- PhishLab tambien reporta eventos a este mismo endpoint, desde su propio
-- service worker -- que manda `Origin: chrome-extension://<id>` en cada
-- fetch cross-origin, no el origen del sitio. El id es estable porque el
-- manifest de la extension fija su clave publica (campo "key"), asi que no
-- cambia entre instalaciones. Guardado por el valor ANTERIOR exacto, segun
-- la regla de mas arriba, para no pisar un allowed_origins editado a mano
-- desde /admin despues del seed inicial.
UPDATE `apps` SET `allowed_origins` = '["https://eduolihez.com","chrome-extension://mjdcdfamonohblhifhmdkceepgaelkld"]'
WHERE `slug` = 'phishlab' AND `allowed_origins` = '["https://eduolihez.com"]';

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
  '<p>El error que mas veces he visto, y que cometi yo tambien al principio, es ordenar una lista de CVEs por CVSS y llamar a eso priorizacion. El CVSS mide gravedad tecnica en abstracto. No dice si alguien esta explotando ese fallo ahora mismo. Son preguntas distintas, y tratarlas como si fueran la misma hace que se gasten semanas en un CVE de 9.8 que nadie usa mientras uno de 6.5 se explota activamente.</p>\r\n<h2>Tres fuentes, tres preguntas distintas</h2>\r\n<p>Cada una de las siguientes responde algo que las otras dos no saben:</p>\r\n<ul>\r\n  <li><strong>NVD</strong> responde que es el fallo: CVSS, CWE, y la version que lo corrige.</li>\r\n  <li><strong>CISA KEV</strong> responde si se esta explotando de verdad, ahora mismo, confirmado.</li>\r\n  <li><strong>EPSS</strong> responde la probabilidad de que se explote en los proximos 30 dias, aunque todavia no este en KEV.</li>\r\n</ul>\r\n<p>Ninguna sustituye a las otras dos. NVD sin las otras da listas larguisimas sin orden real. KEV solo es binario: dentro o fuera. EPSS solo es un numero sin contexto de que corrige.</p>\r\n<h2>El criterio que aplico</h2>\r\n<p>Con las tres cruzadas, el orden queda asi, sin excepciones:</p>\r\n<ol>\r\n  <li>Si esta en <strong>KEV</strong>, va primero. Da igual el CVSS.</li>\r\n  <li>Si no esta en KEV pero el <strong>EPSS es alto</strong>, va despues. Es la senal de que empieza a explotarse.</li>\r\n  <li>CVSS alto con EPSS bajo y fuera de KEV puede esperar al ciclo normal de parcheo.</li>\r\n</ol>\r\n<p>La sorpresa la primera vez que aplico esto sobre un tenant real siempre es la misma: la lista final no se parece nada a la que sale de ordenar solo por CVSS.</p>\r\n<h2>Por que lo automatice</h2>\r\n<p>Cruzar tres fuentes a mano cada mes no escala, y es justo el tipo de tarea que se salta cuando hay prisa, que es precisamente cuando mas falta hace. Lo integre en el generador de informes que uso para los clientes: cada CVE que aparece se enriquece automaticamente contra las tres fuentes antes de entrar en el documento, con cache en disco para no volver a preguntar por un CVE que ya se consulto. <a href="https://github.com/eduolihez/vision-one-crem-report-generator">El codigo esta publicado</a> si a alguien le sirve de referencia.</p>\r\n<h2>Lo que ninguna de las tres sabe</h2>\r\n<p>Ni NVD, ni KEV, ni EPSS saben si el activo afectado es un portatil de pruebas o un controlador de dominio. Eso solo lo sabe quien conoce la red. La automatizacion ordena por senal tecnica; el contexto de negocio lo sigue poniendo una persona, y ahi es donde de verdad se decide que se parchea esta semana y que espera al mes que viene.</p>',
  'cve,vulnerabilidades,nvd,epss,gestion-de-riesgo', 'es', 1, '2026-07-14 10:00:00', '2026-07-14 10:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'priorizar-cves-sin-fiarse-solo-del-cvss');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Hardening de FortiGate: lo que reviso antes de dar un despliegue por bueno',
  'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno',
  'La configuracion de fabrica de un FortiGate no esta lista para produccion solo porque bloquea trafico por defecto. Esta es la lista que reviso siempre, y por que la inspeccion SSL es la que mas se pospone sin motivo.',
  '<p>La configuracion de fabrica de un FortiGate es un punto de partida razonable, no un estado final. He heredado mas de un firewall ya en produccion donde nadie habia tocado nada de esta lista desde el dia de la instalacion. No es exhaustiva: es lo que reviso siempre, en este orden, antes de dar un despliegue por bueno.</p>\r\n<h2>Administracion</h2>\r\n<ul>\r\n  <li>Solo <strong>HTTPS</strong> en la interfaz de gestion, nunca HTTP, y nunca expuesta a la WAN.</li>\r\n  <li>Acceso restringido por <em>trusted host</em>: IPs concretas, no cualquiera con la contrasena.</li>\r\n  <li>Cuentas nominales por administrador. Compartir el usuario admin por defecto hace imposible saber despues quien cambio que.</li>\r\n  <li>MFA en todas las cuentas de administracion, sin excepcion.</li>\r\n</ul>\r\n<h2>Politicas</h2>\r\n<p>Lo mas comun que encuentro en una auditoria no es un fallo tecnico sofisticado: es una politica <code>ALL a ALL</code> que quedo ahi "temporalmente" hace meses. Reviso siempre:</p>\r\n<ul>\r\n  <li>Que no exista ninguna regla asi de amplia sin fecha de caducidad.</li>\r\n  <li>Que todas las politicas tengan <strong>logging activado</strong>. Sin logs, el resto del stack (SIEM, XDR) no tiene nada que correlacionar.</li>\r\n  <li>Que los servicios que no se usan esten deshabilitados, no solo sin politica que los permita.</li>\r\n</ul>\r\n<h2>La inspeccion SSL, que casi siempre se pospone</h2>\r\n<p>Es el punto que mas se retrasa porque "puede romper algo", y sin el el firewall es efectivamente ciego a casi todo el trafico moderno, que va cifrado. Lo que hago para que no rompa nada al activarlo:</p>\r\n<ul>\r\n  <li>Empezar en modo de inspeccion de certificado si la inspeccion completa no es viable de inmediato: ver al menos el SNI y el certificado ya aporta algo.</li>\r\n  <li>Desplegar el certificado de la CA del FortiGate por GPO en los equipos del dominio, para no generar avisos de certificado no confiable en cada sesion.</li>\r\n  <li>Excepciones explicitas y documentadas para lo que de verdad no se debe inspeccionar, nunca una excepcion porque si.</li>\r\n</ul>\r\n<h2>La regla que mas aplico</h2>\r\n<p>Si una politica, una excepcion o una cuenta de administracion no tiene una razon documentada de por que existe, no deberia existir. La mayoria de las exposiciones que encuentro en auditorias no son fallos tecnicos complejos: son configuraciones "temporales" que nadie volvio a mirar.</p>',
  'fortinet,fortigate,hardening,firewall,blue-team', 'es', 1, '2026-08-02 09:00:00', '2026-08-02 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'De soporte tecnico a SOC: lo que cambio no fue el puesto',
  'de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto',
  'El salto de dar soporte a mas de 100 usuarios a triar alertas en un SOC no fue un cambio de titulo de un dia para otro. Fue un cambio en la pregunta que me hacia delante de cada tarea repetitiva.',
  '<p>Empece dando soporte tecnico a mas de cien usuarios: contrasenas bloqueadas, administracion de Active Directory, el dia a dia habitual de cualquiera que empieza en IT. No hay nada malo en ese trabajo: de hecho es donde aprendi mas de lo que esperaba. Pero hay un momento en el que empiezas a ver patrones, y ese momento es el que nadie te explica de antemano.</p>\r\n<h2>El ticket numero cuarenta y tantos</h2>\r\n<p>La primera vez que reseteas una contrasena es un tramite. La vez cuarenta y tantos, empiezas a preguntarte por que el proceso sigue siendo manual. Ese fue mi patron: no fue una vocacion repentina, fue la irritacion acumulada de repetir lo mismo sin que nadie se planteara automatizarlo. Ahi empece a escribir los primeros scripts en Python, no en un curso, sino para resolver tareas concretas del dia a dia.</p>\r\n<h2>El paso intermedio que nadie menciona</h2>\r\n<p>De soporte no pase directo a SOC. Pase antes por administrar FortiGate y FortiAnalyzer, y por responder incidentes de nivel 1 y 2. Ese paso intermedio importa mas de lo que parece: entender la red desde dentro, tocando firewalls y viendo trafico real, es lo que despues hace que triar una alerta XDR tenga sentido en vez de ser una etiqueta de severidad sin contexto.</p>\r\n<h2>El cambio real no fue de titulo</h2>\r\n<p>Pasar a analista de SOC no fue un cambio de un dia para otro. Fue un cambio en la pregunta que me hacia frente a cada tarea repetitiva: de <em>como lo resuelvo</em> a <em>como hago que esto no vuelva a pasar</em>. Ese giro es el que, con el tiempo, lleva de gestionar tickets a gestionar riesgo.</p>\r\n<h2>Lo que me hubiera gustado saber antes</h2>\r\n<ul>\r\n  <li><strong>El soporte de nivel 1 no es un peaje, es formacion.</strong> Ver por que un usuario hace algo "mal" ensena a disenar sistemas que fallan menos.</li>\r\n  <li><strong>Nadie va a pedirte que automatices nada.</strong> El primer script que escribi para ahorrarme trabajo no me lo pidio nadie.</li>\r\n  <li><strong>El SOC no es un destino, es seguir haciendo la misma pregunta.</strong> Sigo automatizando cosas que antes hacia a mano, el mismo impulso que el primer script de reseteo de contrasenas.</li>\r\n</ul>\r\n<p>Si estas en soporte tecnico y sientes que todavia no estas listo para dar el salto: probablemente ya tienes la parte mas dificil, que es entender la infraestructura real, con usuarios reales rompiendola de formas que ningun curso ensena. Lo que falta no es mas teoria: es empezar a preguntarte, delante de cada tarea repetitiva, como evitar que vuelva a pasar.</p>',
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

-- Posts 2026-09-04: uno por cada proyecto de GitHub sin cobertura todavia en
-- el blog (kev-digest, Blue Team Hub, BinCat, Dewi App, phishing-triage).
-- Mismo patron idempotente que los bloques de arriba. Enlazados entre si y a
-- sus paginas de proyecto siguiendo la estructura de clusters: kev-digest
-- refuerza el cluster de Inteligencia de Vulnerabilidades (junto al post de
-- CVSS/EPSS), Blue Team Hub el de Automatizacion SOC, BinCat el de
-- Credenciales (junto al post de HIBP), phishing-triage el de ML Aplicado
-- (junto al post de deteccion de phishing en el navegador). Dewi App queda
-- fuera de los clusters de seguridad a proposito: no tiene relacion tematica
-- real y forzarla diluiria la autoridad tematica del resto.
INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Vigilar el catalogo KEV de CISA sin tener un servidor encendido',
  'vigilar-el-catalogo-kev-de-cisa-sin-servidor',
  'kev-digest comprueba el catalogo CISA KEV cada tres horas, detecta que ha cambiado y publica el resultado, todo sobre GitHub Actions y sin una sola dependencia externa. Como esta montado y por que el guardian anti-encogimiento es la parte que de verdad importa.',
  '<p>El catalogo KEV (Known Exploited Vulnerabilities) de CISA es de las pocas fuentes que responden a la pregunta que de verdad ordena una cola de parcheo: de todo lo publicado, que se esta explotando ahora mismo. <a href="/blog/post/priorizar-cves-sin-fiarse-solo-del-cvss/">Ya escribi sobre por que cruzarlo con NVD y EPSS cambia por completo el orden de prioridad</a>. Lo que me faltaba era dejar de mirarlo a mano.</p>\r\n<h2>El diseno: sin dependencias, sin servidor</h2>\r\n<p>kev-digest es un script de Python que usa solo libreria estandar (<code>urllib</code>, <code>json</code>, <code>hashlib</code>, <code>pathlib</code>) y corre cada tres horas en un cron de GitHub Actions. No hay base de datos: el estado completo vive en un archivo <code>seen_cves.json</code> versionado en el propio repositorio. Cada cambio real (entrada nueva, campo modificado, plazo que entra en la ventana de siete dias, o el caso que mas me interesa: una CVE que llevaba meses en el catalogo y de repente pasa a tener uso confirmado en ransomware) se anade al archivo del dia en <code>digest/</code> y genera un commit. Si no hay novedades, no se escribe nada: con ocho pasadas al dia, escribir siempre llenaria el historial de commits vacios.</p>\r\n<h2>El guardian anti-encogimiento</h2>\r\n<p>La parte que de verdad me preocupaba no era detectar cambios, era no destruir el historial por un fallo de red. Si el catalogo llega vacio o con un diez por ciento menos de entradas que la ultima vez, el script aborta sin guardar nada. Una descarga a medias marcaria cientos de CVEs como retiradas y grabaria esa foto como buena, borrando la linea base de un plumazo. Cuando el encogimiento es real (CISA si retira entradas de vez en cuando), se lanza a mano con <code>--force</code>. Es la misma logica que aplicaria a cualquier pipeline que escribe estado persistente: mejor no escribir nada que escribir algo corrupto con confianza.</p>\r\n<h2>Enriquecimiento sin volverse caro</h2>\r\n<p>Que algo este en KEV dice que se explota, no si es un 9.8 o un 5.4. Las entradas nuevas se enriquecen con EPSS (probabilidad de explotacion en 30 dias, consulta en bloque) y NVD (CVSS y severidad, con cache en disco porque tiene rate-limit). Solo las entradas nuevas: pedir el CVSS de las mas de mil seiscientas que ya estan en seguimiento en cada pasada no aportaria nada y agotaria la cuota.</p>\r\n<h2>Donde acaba el dato</h2>\r\n<p><code>data/latest.json</code> es la salida publica, con contrato de campos estable porque algo mas lo consume: la seccion <a href="https://eduolihez.github.io/#kev-watch">KEV Watch de Blue Team Hub</a> descarga ese JSON ya procesado cada tres horas y lo pinta. El calculo del diff vive en un solo sitio a proposito: dos implementaciones del mismo diff en dos lenguajes acabarian discrepando, y esa discrepancia seria dificil de detectar hasta que alguien confiara en el numero equivocado.</p>\r\n<p>Ahora mismo el catalogo tiene mas de 1.694 CVEs en seguimiento, 352 con uso confirmado en campanas de ransomware. Todo eso corre sin que yo tenga que acordarme de mirarlo, y sin un solo servidor que mantener.</p>',
  'cisa-kev,vulnerabilidades,github-actions,automatizacion,python,blue-team', 'es', 1, '2026-09-01 09:00:00', '2026-09-01 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'vigilar-el-catalogo-kev-de-cisa-sin-servidor');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Blue Team Hub: por que quite el cristal esmerilado de mi propia herramienta',
  'blue-team-hub-por-que-quite-el-cristal-esmerilado',
  'Siete herramientas de SOC gratuitas y del lado del cliente, mas vigilancia en vivo del catalogo KEV integrada en la propia portada. Y la razon, nada esteticista, por la que acabe rediseñando el sitio entero en blanco y negro.',
  '<p>Blue Team Hub es un portal estatico con siete utilidades que uso yo mismo en el dia a dia: desarmador de IOCs, analizador de cabeceras de correo (SPF/DKIM/DMARC y linea de tiempo de saltos), generador de reglas YARA con linter en tiempo real, playbooks interactivos de respuesta a incidentes con consultas SIEM generadas al vuelo, decodificador de payloads (Base64/URL/Hex y deofuscacion de PowerShell), un hub de OSINT, y vigilancia del catalogo CISA KEV. Todo corre en el navegador: nada de lo que pegues en ninguna herramienta sale de tu maquina.</p>\r\n<h2>KEV Watch ya no vive detras de un enlace</h2>\r\n<p>La vigilancia de CISA KEV la genera <a href="/blog/post/vigilar-el-catalogo-kev-de-cisa-sin-servidor/">kev-digest</a>, un proyecto aparte que comprueba el catalogo cada tres horas. Al principio KEV Watch era una pagina de herramienta mas, con su propio enlace en el menu. La movi a la propia portada, como una seccion en linea con la misma tipografia y retricula que el resto: no tenia sentido que la unica herramienta con datos que cambian solos estuviera un clic mas lejos que las demas.</p>\r\n<h2>El rediseno que no esperaba hacer</h2>\r\n<p>El sitio nacio con una estetica glassmorphism de cristal esmerilado, gradientes y desenfoques, muy en la linea de lo que cualquier generador de UI produce por defecto ahora mismo. Funcionaba, pero no decia nada especifico sobre lo que es la herramienta. Probe dos direcciones antes de quedarme con la definitiva: una consola tipo terminal con tipografia monoespaciada hasta en los titulares, y una edicion tipo informe editorial con serif y tinta calida. Las descarte las dos: la primera se sentia a cliche de hacker, la segunda pesaba mas de la cuenta para algo que se usa deprisa.</p>\r\n<p>Lo que quedo es minimalismo casi suizo: blanco, negro, retricula estricta, y un unico rojo reservado sin excepcion para lo urgente: un CVE critico, una entrada marcada como ransomware. Nada de sombras, nada de desenfoques. La idea central, que solo termine de confirmar despues auditando el SEO y el posicionamiento en IA de mi propio portafolio, es que el peso decorativo no es gratis: cuesta renderizar, y comunica "SaaS de consumo pulido" en vez de "herramienta construida por alguien que la usa de verdad". Para una caja de herramientas de SOC, la precision tipografica vende mas credibilidad que el cristal.</p>\r\n<h2>Como se despliega</h2>\r\n<p>Cada push a la rama principal compila con Astro y publica en GitHub Pages via Actions, sin intervencion manual. El mismo pipeline etiqueta versiones y empaqueta lo necesario para desplegar. Es exactamente el tipo de automatizacion que aplico tambien en <a href="/blog/post/automatizar-el-informe-semanal-del-soc-con-python/">otros proyectos</a>: si un paso se repite, no deberia depender de que me acuerde de hacerlo.</p>',
  'blue-team,soc,herramientas,astro,github-actions,cisa-kev', 'es', 1, '2026-09-02 09:00:00', '2026-09-02 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'blue-team-hub-por-que-quite-el-cristal-esmerilado');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Revocar un token sin tener que derribar la sesion entera',
  'revocar-un-token-sin-derribar-la-sesion-entera',
  'BinCat es un SDK de Python para emitir, validar y revocar tokens Fernet y JWT con registro de auditoria, con un panel encima para hacerlo sin escribir codigo. La pregunta que lo motivo: por que revocar un acceso obligaba tantas veces a cerrar la sesion completa.',
  '<p>Una peticion que he visto repetirse: revocar el acceso de un token concreto sin forzar a todo el mundo a volver a autenticarse. Muchas implementaciones caseras de tokens no dejan margen para eso: o el JWT es valido hasta que caduca por su cuenta, o hay que invalidar la sesion entera. BinCat nacio de resolver justo eso: emitir, validar y revocar tokens de forma individual, con registro de cada operacion.</p>\r\n<h2>Dos tipos de token, cada uno para su caso</h2>\r\n<p>Fernet, de la libreria <code>cryptography</code>, para cifrado simetrico cuando el mismo sistema emite y valida. JWT firmados criptograficamente con claims con estado, para cuando el token viaja entre servicios distintos. Los intervalos de expiracion se configuran desde la API o desde el panel, y cualquier token individual se puede revocar al instante sin tocar los demas, que es la diferencia frente a depender solo de la expiracion natural.</p>\r\n<h2>Que trae el paquete</h2>\r\n<ul>\r\n  <li>Un SDK de Python que se integra directamente en una aplicacion existente.</li>\r\n  <li>Un panel de una sola pagina, tema oscuro, con recuento de tokens totales, activos, revocados y expirados, y una consola de logs que traza la actividad segun ocurre.</li>\r\n  <li>Una API REST con seis endpoints: generar, validar, revocar, purgar y consultar el log de las ultimas cincuenta operaciones.</li>\r\n  <li>Registro en SQLite de cada emision, validacion y revocacion, para poder responder despues quien tenia acceso y cuando dejo de tenerlo.</li>\r\n</ul>\r\n<h2>La clave de cifrado no se toca a mano</h2>\r\n<p>Si BinCat no encuentra una clave en <code>.env</code> al arrancar, genera una criptograficamente segura por su cuenta. Es la misma logica que aplico en <a href="/blog/post/comprobar-si-una-contrasena-esta-filtrada-sin-enviarsela-a-nadie/">Password Sentinel</a>: cuanto menos dependa la seguridad de que alguien recuerde configurar algo bien, menos formas hay de que se quede mal configurado. Si una clave se filtra, el procedimiento es simple: borrar <code>.env</code>, dejar que se genere una nueva, y reemitir los tokens que estaban cifrados con la anterior. No hay rotacion magica que salve ese paso: hay que reemitir.</p>\r\n<p>Los tests corren contra una base de datos SQLite aislada, asi que nunca tocan la de desarrollo ni arrastran estado entre ejecuciones.</p>',
  'python,criptografia,jwt,seguridad,tokens,sdk', 'es', 1, '2026-09-03 09:00:00', '2026-09-03 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'revocar-un-token-sin-derribar-la-sesion-entera');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Lo que da tiempo a aprender construyendo un sensor de agua en 24 horas',
  'lo-que-da-tiempo-a-aprender-en-24-horas-de-hackathon',
  'Dewi App fue nuestro prototipo ganador en la 8a Hackathon TecnoCampus: un sensor fisico de caudal conectado a una web de consumo de agua, montado entre cuatro personas en menos de un dia. No es el tipo de proyecto que suelo publicar aqui, y por eso mismo vale la pena contar que se aprende en ese formato.',
  '<p>Esto se sale del terreno habitual de este blog (nada de SOC, nada de blue team) pero merece un hueco porque la restriccion mas dura que he tenido nunca en un proyecto no fue tecnica, fue el reloj: veinticuatro horas, de la idea al prototipo funcionando sobre un escenario.</p>\r\n<h2>Que construimos</h2>\r\n<p>Dewi App nacio en la 8a Hackathon TecnoCampus con un objetivo simple: ayudar a monitorizar y reducir el consumo de agua domestico. La parte fisica fue un sensor de caudal por Arduino, programado y calibrado esa misma noche. La parte web, una aplicacion en Next.js y TypeScript que recibia esos datos y los convertia en algo legible: consumo, tendencias, recomendaciones para gastar menos.</p>\r\n<h2>Lo que cambia cuando el limite es el tiempo, no el alcance</h2>\r\n<p>En un proyecto sin fecha limite se puede discutir arquitectura durante horas. En una hackathon esa discusion es un lujo que no existe: se elige la opcion que se sabe montar rapido y se avanza. Eso obliga a una disciplina que luego traslado a proyectos con mas tiempo: decidir rapido, medir si funciona, y no protegerse detras de "hacerlo bien" cuando lo que hace falta es tener algo que funcione ya.</p>\r\n<h2>Un prototipo, no un producto</h2>\r\n<p>El propio repositorio lo deja claro: es un prototipo, no algo listo para produccion. Faltan autenticacion real, persistencia de datos en serio, integracion en tiempo real con el sensor mas alla de la demo. Eso esta bien: no era el objetivo de la noche. El objetivo era demostrar que la idea se sostiene, y ganamos la hackathon con esa demostracion.</p>\r\n<p>El equipo fue Marc Lumbreras, Nil Sentis, Jan Naranjo y yo. El prototipo <a href="https://dewi-hackathon.vercel.app">sigue desplegado</a>, tal cual salio esa noche.</p>',
  'hackathon,nextjs,arduino,prototipo,trabajo-en-equipo', 'es', 1, '2026-09-03 18:00:00', '2026-09-03 18:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'lo-que-da-tiempo-a-aprender-en-24-horas-de-hackathon');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'El desacuerdo entre clasificadores pierde contra algo mucho mas simple',
  'el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple',
  'Media sobre 7.822 correos reales si el desacuerdo entre cuatro clasificadores sirve para decidir que revisa antes un analista. Esperaba que si. Los datos dicen que pierde claramente contra una senal mas simple: la incertidumbre media del propio ensemble.',
  '<p>Un analista no puede revisar todo el correo que marca un clasificador. La pregunta que queria responder con datos, no con intuicion: puede el desacuerdo entre varios clasificadores decirle a ese analista cual revisar primero. La motivacion venia de dos sitios muy distintos: <a href="https://huggingface.co/BSC-LT/catalan-verification-model-pkt-a">los modelos de verificacion del BSC para catalan</a>, que entrenan dos copias del mismo reconocedor de voz con mitades disjuntas del corpus para que sus errores no esten correlacionados, y <a href="https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2026.1829902/full">un estudio de 2026 sobre transcripcion medica</a> que usa el desacuerdo entre ocho transcriptores como senal sin referencia para decidir que revisa un humano, recuperando el 93,7% de los errores revisando el 28,6% del texto. La estructura del problema en un SOC es identica: sin verdad de referencia, con revision humana cara y escasa. Parecia trasladable.</p>\r\n<h2>El resultado, en una linea</h2>\r\n<p>Sobre 7.822 correos reales (Nazario phishing corpus + SpamAssassin publico), el desacuerdo funciona para priorizar la revision (AUC 0,905 frente a 0,515 del azar), pero pierde claramente contra una senal mucho mas simple: la incertidumbre media del propio ensemble, con AUC 0,959. Para capturar el 95% de los errores hace falta revisar el 14,10% del correo mirando solo la incertidumbre media. Con el desacuerdo por desviacion, hacen falta el 22,62%. No hace falta ensemble para el resultado bueno: basta con mirar donde el modelo no esta seguro.</p>\r\n<table>\r\n<tr><th>Senal de prioridad</th><th>AUC de triaje</th><th>Correo a revisar para el 95% de errores</th></tr>\r\n<tr><td>Oraculo (techo teorico)</td><td>0,991</td><td>1,75%</td></tr>\r\n<tr><td><strong>Incertidumbre media</strong></td><td><strong>0,959</strong></td><td><strong>14,10%</strong></td></tr>\r\n<tr><td>Desacuerdo: desviacion</td><td>0,905</td><td>22,62%</td></tr>\r\n<tr><td>Desacuerdo: fuerza de mayoria</td><td>0,907</td><td>41,20%</td></tr>\r\n<tr><td>Azar (suelo)</td><td>0,515</td><td>97,66%</td></tr>\r\n</table>\r\n<h2>Por que fallo la hipotesis</h2>\r\n<p>El ensemble da cuatro vistas del mismo correo (remitente, URLs, estructura del HTML y texto), pero no son igual de fuertes. La vista de texto (TF-IDF mas regresion logistica) sola llega a 98,17% de exactitud y AUC 0,998, practicamente igualando al ensemble completo. Cuando un miembro es muy superior al resto, el desacuerdo deja de medir duda genuina y pasa a medir que los debiles se equivocan, algo que no informa sobre si el ensemble acierta. Ahi esta la diferencia con el montaje del BSC: sus dos modelos tienen tasas de error casi identicas por diseno. Esa parece ser la condicion que hace util al desacuerdo, y es una condicion que aqui no se cumple.</p>\r\n<h2>El control que casi invalida el experimento</h2>\r\n<p>Los corpus publicos de phishing arrastran un problema que casi nunca se declara: el correo legitimo y el phishing vienen de epocas distintas: el 87% del phishing es de 2004-2007, el legitimo es de 2002. Clasificar usando solo el ano da 99,74% de exactitud: el atajo existe y es casi perfecto. Restringiendo la evaluacion a la franja donde ambas clases se solapan (2004 o antes), el rendimiento no cae (98,31%, AUC 1,000), lo que indica que el modelo no esta usando ese atajo, aunque con la cautela de que esa franja solo tiene 31 casos de phishing: evidencia indicativa, no concluyente.</p>\r\n<h2>Limites, dichos sin adornos</h2>\r\n<ul>\r\n  <li>No dice que el desacuerdo sea inutil. Dice que pierde contra un baseline mas simple en este montaje concreto, con vistas de fuerza desigual.</li>\r\n  <li>Solo 43 errores en la particion de prueba: las curvas de triaje son ruidosas.</li>\r\n  <li>El corpus es de 2004-2007: sin HTTPS generalizado, sin acortadores, sin typosquatting moderno. Las conclusiones de metodo deberian aguantar; las cifras absolutas no son extrapolables a un SOC de hoy.</li>\r\n  <li>Una unica particion 70/30 con semilla fija, sin validacion cruzada.</li>\r\n</ul>\r\n<p>Es el mismo problema, visto desde el otro lado, que trabajo en <a href="/blog/post/clasificar-phishing-en-el-navegador-sin-mandar-la-url/">el clasificador de phishing en el navegador</a>: alli la pregunta era clasificar bien sin mandar nada a un servidor; aqui, una vez clasificado, que le hace perder menos tiempo al analista que tiene que revisarlo. El siguiente experimento que tengo en la lista: repetir esto con cuatro modelos de la misma familia entrenados sobre particiones disjuntas del corpus, replicando el metodo del BSC en vez de solo su intuicion, para comprobar si el desacuerdo remonta al equiparar fuerzas entre vistas. <a href="https://github.com/eduolihez/phishing-triage">El codigo, los experimentos y el README completo con todos los numeros estan publicados</a>.</p>',
  'machine-learning,phishing,triaje,soc,scikit-learn,investigacion', 'es', 1, '2026-09-04 09:00:00', '2026-09-04 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple');

-- Reescritura 2026-09-04: estos 8 posts ya estaban subidos a la BD en
-- produccion cuando se les quito el patron "-- aside --" (marca tipica de
-- texto generado por IA). Los bloques INSERT de arriba son un no-op en un
-- reimport porque el slug ya existe (WHERE NOT EXISTS), asi que el contenido
-- corregido no llegaria nunca a produccion sin este UPDATE explicito. Un
-- UPDATE con el mismo valor es idempotente por naturaleza: no hace falta
-- guardarlo con NOT EXISTS ni comprobar el contenido anterior.
UPDATE `posts` SET `content` = '<p>El error que mas veces he visto, y que cometi yo tambien al principio, es ordenar una lista de CVEs por CVSS y llamar a eso priorizacion. El CVSS mide gravedad tecnica en abstracto. No dice si alguien esta explotando ese fallo ahora mismo. Son preguntas distintas, y tratarlas como si fueran la misma hace que se gasten semanas en un CVE de 9.8 que nadie usa mientras uno de 6.5 se explota activamente.</p>\r\n<h2>Tres fuentes, tres preguntas distintas</h2>\r\n<p>Cada una de las siguientes responde algo que las otras dos no saben:</p>\r\n<ul>\r\n  <li><strong>NVD</strong> responde que es el fallo: CVSS, CWE, y la version que lo corrige.</li>\r\n  <li><strong>CISA KEV</strong> responde si se esta explotando de verdad, ahora mismo, confirmado.</li>\r\n  <li><strong>EPSS</strong> responde la probabilidad de que se explote en los proximos 30 dias, aunque todavia no este en KEV.</li>\r\n</ul>\r\n<p>Ninguna sustituye a las otras dos. NVD sin las otras da listas larguisimas sin orden real. KEV solo es binario: dentro o fuera. EPSS solo es un numero sin contexto de que corrige.</p>\r\n<h2>El criterio que aplico</h2>\r\n<p>Con las tres cruzadas, el orden queda asi, sin excepciones:</p>\r\n<ol>\r\n  <li>Si esta en <strong>KEV</strong>, va primero. Da igual el CVSS.</li>\r\n  <li>Si no esta en KEV pero el <strong>EPSS es alto</strong>, va despues. Es la senal de que empieza a explotarse.</li>\r\n  <li>CVSS alto con EPSS bajo y fuera de KEV puede esperar al ciclo normal de parcheo.</li>\r\n</ol>\r\n<p>La sorpresa la primera vez que aplico esto sobre un tenant real siempre es la misma: la lista final no se parece nada a la que sale de ordenar solo por CVSS.</p>\r\n<h2>Por que lo automatice</h2>\r\n<p>Cruzar tres fuentes a mano cada mes no escala, y es justo el tipo de tarea que se salta cuando hay prisa, que es precisamente cuando mas falta hace. Lo integre en el generador de informes que uso para los clientes: cada CVE que aparece se enriquece automaticamente contra las tres fuentes antes de entrar en el documento, con cache en disco para no volver a preguntar por un CVE que ya se consulto. <a href="https://github.com/eduolihez/vision-one-crem-report-generator">El codigo esta publicado</a> si a alguien le sirve de referencia.</p>\r\n<h2>Lo que ninguna de las tres sabe</h2>\r\n<p>Ni NVD, ni KEV, ni EPSS saben si el activo afectado es un portatil de pruebas o un controlador de dominio. Eso solo lo sabe quien conoce la red. La automatizacion ordena por senal tecnica; el contexto de negocio lo sigue poniendo una persona, y ahi es donde de verdad se decide que se parchea esta semana y que espera al mes que viene.</p>'
WHERE `slug` = 'priorizar-cves-sin-fiarse-solo-del-cvss';

UPDATE `posts` SET `content` = '<p>La configuracion de fabrica de un FortiGate es un punto de partida razonable, no un estado final. He heredado mas de un firewall ya en produccion donde nadie habia tocado nada de esta lista desde el dia de la instalacion. No es exhaustiva: es lo que reviso siempre, en este orden, antes de dar un despliegue por bueno.</p>\r\n<h2>Administracion</h2>\r\n<ul>\r\n  <li>Solo <strong>HTTPS</strong> en la interfaz de gestion, nunca HTTP, y nunca expuesta a la WAN.</li>\r\n  <li>Acceso restringido por <em>trusted host</em>: IPs concretas, no cualquiera con la contrasena.</li>\r\n  <li>Cuentas nominales por administrador. Compartir el usuario admin por defecto hace imposible saber despues quien cambio que.</li>\r\n  <li>MFA en todas las cuentas de administracion, sin excepcion.</li>\r\n</ul>\r\n<h2>Politicas</h2>\r\n<p>Lo mas comun que encuentro en una auditoria no es un fallo tecnico sofisticado: es una politica <code>ALL a ALL</code> que quedo ahi "temporalmente" hace meses. Reviso siempre:</p>\r\n<ul>\r\n  <li>Que no exista ninguna regla asi de amplia sin fecha de caducidad.</li>\r\n  <li>Que todas las politicas tengan <strong>logging activado</strong>. Sin logs, el resto del stack (SIEM, XDR) no tiene nada que correlacionar.</li>\r\n  <li>Que los servicios que no se usan esten deshabilitados, no solo sin politica que los permita.</li>\r\n</ul>\r\n<h2>La inspeccion SSL, que casi siempre se pospone</h2>\r\n<p>Es el punto que mas se retrasa porque "puede romper algo", y sin el el firewall es efectivamente ciego a casi todo el trafico moderno, que va cifrado. Lo que hago para que no rompa nada al activarlo:</p>\r\n<ul>\r\n  <li>Empezar en modo de inspeccion de certificado si la inspeccion completa no es viable de inmediato: ver al menos el SNI y el certificado ya aporta algo.</li>\r\n  <li>Desplegar el certificado de la CA del FortiGate por GPO en los equipos del dominio, para no generar avisos de certificado no confiable en cada sesion.</li>\r\n  <li>Excepciones explicitas y documentadas para lo que de verdad no se debe inspeccionar, nunca una excepcion porque si.</li>\r\n</ul>\r\n<h2>La regla que mas aplico</h2>\r\n<p>Si una politica, una excepcion o una cuenta de administracion no tiene una razon documentada de por que existe, no deberia existir. La mayoria de las exposiciones que encuentro en auditorias no son fallos tecnicos complejos: son configuraciones "temporales" que nadie volvio a mirar.</p>'
WHERE `slug` = 'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno';

UPDATE `posts` SET `content` = '<p>Empece dando soporte tecnico a mas de cien usuarios: contrasenas bloqueadas, administracion de Active Directory, el dia a dia habitual de cualquiera que empieza en IT. No hay nada malo en ese trabajo: de hecho es donde aprendi mas de lo que esperaba. Pero hay un momento en el que empiezas a ver patrones, y ese momento es el que nadie te explica de antemano.</p>\r\n<h2>El ticket numero cuarenta y tantos</h2>\r\n<p>La primera vez que reseteas una contrasena es un tramite. La vez cuarenta y tantos, empiezas a preguntarte por que el proceso sigue siendo manual. Ese fue mi patron: no fue una vocacion repentina, fue la irritacion acumulada de repetir lo mismo sin que nadie se planteara automatizarlo. Ahi empece a escribir los primeros scripts en Python, no en un curso, sino para resolver tareas concretas del dia a dia.</p>\r\n<h2>El paso intermedio que nadie menciona</h2>\r\n<p>De soporte no pase directo a SOC. Pase antes por administrar FortiGate y FortiAnalyzer, y por responder incidentes de nivel 1 y 2. Ese paso intermedio importa mas de lo que parece: entender la red desde dentro, tocando firewalls y viendo trafico real, es lo que despues hace que triar una alerta XDR tenga sentido en vez de ser una etiqueta de severidad sin contexto.</p>\r\n<h2>El cambio real no fue de titulo</h2>\r\n<p>Pasar a analista de SOC no fue un cambio de un dia para otro. Fue un cambio en la pregunta que me hacia frente a cada tarea repetitiva: de <em>como lo resuelvo</em> a <em>como hago que esto no vuelva a pasar</em>. Ese giro es el que, con el tiempo, lleva de gestionar tickets a gestionar riesgo.</p>\r\n<h2>Lo que me hubiera gustado saber antes</h2>\r\n<ul>\r\n  <li><strong>El soporte de nivel 1 no es un peaje, es formacion.</strong> Ver por que un usuario hace algo "mal" ensena a disenar sistemas que fallan menos.</li>\r\n  <li><strong>Nadie va a pedirte que automatices nada.</strong> El primer script que escribi para ahorrarme trabajo no me lo pidio nadie.</li>\r\n  <li><strong>El SOC no es un destino, es seguir haciendo la misma pregunta.</strong> Sigo automatizando cosas que antes hacia a mano, el mismo impulso que el primer script de reseteo de contrasenas.</li>\r\n</ul>\r\n<p>Si estas en soporte tecnico y sientes que todavia no estas listo para dar el salto: probablemente ya tienes la parte mas dificil, que es entender la infraestructura real, con usuarios reales rompiendola de formas que ningun curso ensena. Lo que falta no es mas teoria: es empezar a preguntarte, delante de cada tarea repetitiva, como evitar que vuelva a pasar.</p>'
WHERE `slug` = 'de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto';

UPDATE `posts` SET `content` = '<p>El catalogo KEV (Known Exploited Vulnerabilities) de CISA es de las pocas fuentes que responden a la pregunta que de verdad ordena una cola de parcheo: de todo lo publicado, que se esta explotando ahora mismo. <a href="/blog/post/priorizar-cves-sin-fiarse-solo-del-cvss/">Ya escribi sobre por que cruzarlo con NVD y EPSS cambia por completo el orden de prioridad</a>. Lo que me faltaba era dejar de mirarlo a mano.</p>\r\n<h2>El diseno: sin dependencias, sin servidor</h2>\r\n<p>kev-digest es un script de Python que usa solo libreria estandar (<code>urllib</code>, <code>json</code>, <code>hashlib</code>, <code>pathlib</code>) y corre cada tres horas en un cron de GitHub Actions. No hay base de datos: el estado completo vive en un archivo <code>seen_cves.json</code> versionado en el propio repositorio. Cada cambio real (entrada nueva, campo modificado, plazo que entra en la ventana de siete dias, o el caso que mas me interesa: una CVE que llevaba meses en el catalogo y de repente pasa a tener uso confirmado en ransomware) se anade al archivo del dia en <code>digest/</code> y genera un commit. Si no hay novedades, no se escribe nada: con ocho pasadas al dia, escribir siempre llenaria el historial de commits vacios.</p>\r\n<h2>El guardian anti-encogimiento</h2>\r\n<p>La parte que de verdad me preocupaba no era detectar cambios, era no destruir el historial por un fallo de red. Si el catalogo llega vacio o con un diez por ciento menos de entradas que la ultima vez, el script aborta sin guardar nada. Una descarga a medias marcaria cientos de CVEs como retiradas y grabaria esa foto como buena, borrando la linea base de un plumazo. Cuando el encogimiento es real (CISA si retira entradas de vez en cuando), se lanza a mano con <code>--force</code>. Es la misma logica que aplicaria a cualquier pipeline que escribe estado persistente: mejor no escribir nada que escribir algo corrupto con confianza.</p>\r\n<h2>Enriquecimiento sin volverse caro</h2>\r\n<p>Que algo este en KEV dice que se explota, no si es un 9.8 o un 5.4. Las entradas nuevas se enriquecen con EPSS (probabilidad de explotacion en 30 dias, consulta en bloque) y NVD (CVSS y severidad, con cache en disco porque tiene rate-limit). Solo las entradas nuevas: pedir el CVSS de las mas de mil seiscientas que ya estan en seguimiento en cada pasada no aportaria nada y agotaria la cuota.</p>\r\n<h2>Donde acaba el dato</h2>\r\n<p><code>data/latest.json</code> es la salida publica, con contrato de campos estable porque algo mas lo consume: la seccion <a href="https://eduolihez.github.io/#kev-watch">KEV Watch de Blue Team Hub</a> descarga ese JSON ya procesado cada tres horas y lo pinta. El calculo del diff vive en un solo sitio a proposito: dos implementaciones del mismo diff en dos lenguajes acabarian discrepando, y esa discrepancia seria dificil de detectar hasta que alguien confiara en el numero equivocado.</p>\r\n<p>Ahora mismo el catalogo tiene mas de 1.694 CVEs en seguimiento, 352 con uso confirmado en campanas de ransomware. Todo eso corre sin que yo tenga que acordarme de mirarlo, y sin un solo servidor que mantener.</p>'
WHERE `slug` = 'vigilar-el-catalogo-kev-de-cisa-sin-servidor';

UPDATE `posts` SET `content` = '<p>Blue Team Hub es un portal estatico con siete utilidades que uso yo mismo en el dia a dia: desarmador de IOCs, analizador de cabeceras de correo (SPF/DKIM/DMARC y linea de tiempo de saltos), generador de reglas YARA con linter en tiempo real, playbooks interactivos de respuesta a incidentes con consultas SIEM generadas al vuelo, decodificador de payloads (Base64/URL/Hex y deofuscacion de PowerShell), un hub de OSINT, y vigilancia del catalogo CISA KEV. Todo corre en el navegador: nada de lo que pegues en ninguna herramienta sale de tu maquina.</p>\r\n<h2>KEV Watch ya no vive detras de un enlace</h2>\r\n<p>La vigilancia de CISA KEV la genera <a href="/blog/post/vigilar-el-catalogo-kev-de-cisa-sin-servidor/">kev-digest</a>, un proyecto aparte que comprueba el catalogo cada tres horas. Al principio KEV Watch era una pagina de herramienta mas, con su propio enlace en el menu. La movi a la propia portada, como una seccion en linea con la misma tipografia y retricula que el resto: no tenia sentido que la unica herramienta con datos que cambian solos estuviera un clic mas lejos que las demas.</p>\r\n<h2>El rediseno que no esperaba hacer</h2>\r\n<p>El sitio nacio con una estetica glassmorphism de cristal esmerilado, gradientes y desenfoques, muy en la linea de lo que cualquier generador de UI produce por defecto ahora mismo. Funcionaba, pero no decia nada especifico sobre lo que es la herramienta. Probe dos direcciones antes de quedarme con la definitiva: una consola tipo terminal con tipografia monoespaciada hasta en los titulares, y una edicion tipo informe editorial con serif y tinta calida. Las descarte las dos: la primera se sentia a cliche de hacker, la segunda pesaba mas de la cuenta para algo que se usa deprisa.</p>\r\n<p>Lo que quedo es minimalismo casi suizo: blanco, negro, retricula estricta, y un unico rojo reservado sin excepcion para lo urgente: un CVE critico, una entrada marcada como ransomware. Nada de sombras, nada de desenfoques. La idea central, que solo termine de confirmar despues auditando el SEO y el posicionamiento en IA de mi propio portafolio, es que el peso decorativo no es gratis: cuesta renderizar, y comunica "SaaS de consumo pulido" en vez de "herramienta construida por alguien que la usa de verdad". Para una caja de herramientas de SOC, la precision tipografica vende mas credibilidad que el cristal.</p>\r\n<h2>Como se despliega</h2>\r\n<p>Cada push a la rama principal compila con Astro y publica en GitHub Pages via Actions, sin intervencion manual. El mismo pipeline etiqueta versiones y empaqueta lo necesario para desplegar. Es exactamente el tipo de automatizacion que aplico tambien en <a href="/blog/post/automatizar-el-informe-semanal-del-soc-con-python/">otros proyectos</a>: si un paso se repite, no deberia depender de que me acuerde de hacerlo.</p>'
WHERE `slug` = 'blue-team-hub-por-que-quite-el-cristal-esmerilado';

UPDATE `posts` SET `content` = '<p>Una peticion que he visto repetirse: revocar el acceso de un token concreto sin forzar a todo el mundo a volver a autenticarse. Muchas implementaciones caseras de tokens no dejan margen para eso: o el JWT es valido hasta que caduca por su cuenta, o hay que invalidar la sesion entera. BinCat nacio de resolver justo eso: emitir, validar y revocar tokens de forma individual, con registro de cada operacion.</p>\r\n<h2>Dos tipos de token, cada uno para su caso</h2>\r\n<p>Fernet, de la libreria <code>cryptography</code>, para cifrado simetrico cuando el mismo sistema emite y valida. JWT firmados criptograficamente con claims con estado, para cuando el token viaja entre servicios distintos. Los intervalos de expiracion se configuran desde la API o desde el panel, y cualquier token individual se puede revocar al instante sin tocar los demas, que es la diferencia frente a depender solo de la expiracion natural.</p>\r\n<h2>Que trae el paquete</h2>\r\n<ul>\r\n  <li>Un SDK de Python que se integra directamente en una aplicacion existente.</li>\r\n  <li>Un panel de una sola pagina, tema oscuro, con recuento de tokens totales, activos, revocados y expirados, y una consola de logs que traza la actividad segun ocurre.</li>\r\n  <li>Una API REST con seis endpoints: generar, validar, revocar, purgar y consultar el log de las ultimas cincuenta operaciones.</li>\r\n  <li>Registro en SQLite de cada emision, validacion y revocacion, para poder responder despues quien tenia acceso y cuando dejo de tenerlo.</li>\r\n</ul>\r\n<h2>La clave de cifrado no se toca a mano</h2>\r\n<p>Si BinCat no encuentra una clave en <code>.env</code> al arrancar, genera una criptograficamente segura por su cuenta. Es la misma logica que aplico en <a href="/blog/post/comprobar-si-una-contrasena-esta-filtrada-sin-enviarsela-a-nadie/">Password Sentinel</a>: cuanto menos dependa la seguridad de que alguien recuerde configurar algo bien, menos formas hay de que se quede mal configurado. Si una clave se filtra, el procedimiento es simple: borrar <code>.env</code>, dejar que se genere una nueva, y reemitir los tokens que estaban cifrados con la anterior. No hay rotacion magica que salve ese paso: hay que reemitir.</p>\r\n<p>Los tests corren contra una base de datos SQLite aislada, asi que nunca tocan la de desarrollo ni arrastran estado entre ejecuciones.</p>'
WHERE `slug` = 'revocar-un-token-sin-derribar-la-sesion-entera';

UPDATE `posts` SET `content` = '<p>Esto se sale del terreno habitual de este blog (nada de SOC, nada de blue team) pero merece un hueco porque la restriccion mas dura que he tenido nunca en un proyecto no fue tecnica, fue el reloj: veinticuatro horas, de la idea al prototipo funcionando sobre un escenario.</p>\r\n<h2>Que construimos</h2>\r\n<p>Dewi App nacio en la 8a Hackathon TecnoCampus con un objetivo simple: ayudar a monitorizar y reducir el consumo de agua domestico. La parte fisica fue un sensor de caudal por Arduino, programado y calibrado esa misma noche. La parte web, una aplicacion en Next.js y TypeScript que recibia esos datos y los convertia en algo legible: consumo, tendencias, recomendaciones para gastar menos.</p>\r\n<h2>Lo que cambia cuando el limite es el tiempo, no el alcance</h2>\r\n<p>En un proyecto sin fecha limite se puede discutir arquitectura durante horas. En una hackathon esa discusion es un lujo que no existe: se elige la opcion que se sabe montar rapido y se avanza. Eso obliga a una disciplina que luego traslado a proyectos con mas tiempo: decidir rapido, medir si funciona, y no protegerse detras de "hacerlo bien" cuando lo que hace falta es tener algo que funcione ya.</p>\r\n<h2>Un prototipo, no un producto</h2>\r\n<p>El propio repositorio lo deja claro: es un prototipo, no algo listo para produccion. Faltan autenticacion real, persistencia de datos en serio, integracion en tiempo real con el sensor mas alla de la demo. Eso esta bien: no era el objetivo de la noche. El objetivo era demostrar que la idea se sostiene, y ganamos la hackathon con esa demostracion.</p>\r\n<p>El equipo fue Marc Lumbreras, Nil Sentis, Jan Naranjo y yo. El prototipo <a href="https://dewi-hackathon.vercel.app">sigue desplegado</a>, tal cual salio esa noche.</p>'
WHERE `slug` = 'lo-que-da-tiempo-a-aprender-en-24-horas-de-hackathon';

UPDATE `posts` SET `content` = '<p>Un analista no puede revisar todo el correo que marca un clasificador. La pregunta que queria responder con datos, no con intuicion: puede el desacuerdo entre varios clasificadores decirle a ese analista cual revisar primero. La motivacion venia de dos sitios muy distintos: <a href="https://huggingface.co/BSC-LT/catalan-verification-model-pkt-a">los modelos de verificacion del BSC para catalan</a>, que entrenan dos copias del mismo reconocedor de voz con mitades disjuntas del corpus para que sus errores no esten correlacionados, y <a href="https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2026.1829902/full">un estudio de 2026 sobre transcripcion medica</a> que usa el desacuerdo entre ocho transcriptores como senal sin referencia para decidir que revisa un humano, recuperando el 93,7% de los errores revisando el 28,6% del texto. La estructura del problema en un SOC es identica: sin verdad de referencia, con revision humana cara y escasa. Parecia trasladable.</p>\r\n<h2>El resultado, en una linea</h2>\r\n<p>Sobre 7.822 correos reales (Nazario phishing corpus + SpamAssassin publico), el desacuerdo funciona para priorizar la revision (AUC 0,905 frente a 0,515 del azar), pero pierde claramente contra una senal mucho mas simple: la incertidumbre media del propio ensemble, con AUC 0,959. Para capturar el 95% de los errores hace falta revisar el 14,10% del correo mirando solo la incertidumbre media. Con el desacuerdo por desviacion, hacen falta el 22,62%. No hace falta ensemble para el resultado bueno: basta con mirar donde el modelo no esta seguro.</p>\r\n<table>\r\n<tr><th>Senal de prioridad</th><th>AUC de triaje</th><th>Correo a revisar para el 95% de errores</th></tr>\r\n<tr><td>Oraculo (techo teorico)</td><td>0,991</td><td>1,75%</td></tr>\r\n<tr><td><strong>Incertidumbre media</strong></td><td><strong>0,959</strong></td><td><strong>14,10%</strong></td></tr>\r\n<tr><td>Desacuerdo: desviacion</td><td>0,905</td><td>22,62%</td></tr>\r\n<tr><td>Desacuerdo: fuerza de mayoria</td><td>0,907</td><td>41,20%</td></tr>\r\n<tr><td>Azar (suelo)</td><td>0,515</td><td>97,66%</td></tr>\r\n</table>\r\n<h2>Por que fallo la hipotesis</h2>\r\n<p>El ensemble da cuatro vistas del mismo correo (remitente, URLs, estructura del HTML y texto), pero no son igual de fuertes. La vista de texto (TF-IDF mas regresion logistica) sola llega a 98,17% de exactitud y AUC 0,998, practicamente igualando al ensemble completo. Cuando un miembro es muy superior al resto, el desacuerdo deja de medir duda genuina y pasa a medir que los debiles se equivocan, algo que no informa sobre si el ensemble acierta. Ahi esta la diferencia con el montaje del BSC: sus dos modelos tienen tasas de error casi identicas por diseno. Esa parece ser la condicion que hace util al desacuerdo, y es una condicion que aqui no se cumple.</p>\r\n<h2>El control que casi invalida el experimento</h2>\r\n<p>Los corpus publicos de phishing arrastran un problema que casi nunca se declara: el correo legitimo y el phishing vienen de epocas distintas: el 87% del phishing es de 2004-2007, el legitimo es de 2002. Clasificar usando solo el ano da 99,74% de exactitud: el atajo existe y es casi perfecto. Restringiendo la evaluacion a la franja donde ambas clases se solapan (2004 o antes), el rendimiento no cae (98,31%, AUC 1,000), lo que indica que el modelo no esta usando ese atajo, aunque con la cautela de que esa franja solo tiene 31 casos de phishing: evidencia indicativa, no concluyente.</p>\r\n<h2>Limites, dichos sin adornos</h2>\r\n<ul>\r\n  <li>No dice que el desacuerdo sea inutil. Dice que pierde contra un baseline mas simple en este montaje concreto, con vistas de fuerza desigual.</li>\r\n  <li>Solo 43 errores en la particion de prueba: las curvas de triaje son ruidosas.</li>\r\n  <li>El corpus es de 2004-2007: sin HTTPS generalizado, sin acortadores, sin typosquatting moderno. Las conclusiones de metodo deberian aguantar; las cifras absolutas no son extrapolables a un SOC de hoy.</li>\r\n  <li>Una unica particion 70/30 con semilla fija, sin validacion cruzada.</li>\r\n</ul>\r\n<p>Es el mismo problema, visto desde el otro lado, que trabajo en <a href="/blog/post/clasificar-phishing-en-el-navegador-sin-mandar-la-url/">el clasificador de phishing en el navegador</a>: alli la pregunta era clasificar bien sin mandar nada a un servidor; aqui, una vez clasificado, que le hace perder menos tiempo al analista que tiene que revisarlo. El siguiente experimento que tengo en la lista: repetir esto con cuatro modelos de la misma familia entrenados sobre particiones disjuntas del corpus, replicando el metodo del BSC en vez de solo su intuicion, para comprobar si el desacuerdo remonta al equiparar fuerzas entre vistas. <a href="https://github.com/eduolihez/phishing-triage">El codigo, los experimentos y el README completo con todos los numeros estan publicados</a>.</p>'
WHERE `slug` = 'el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple';

-- Enlazado interno bidireccional: los 3 posts antiguos que ahora tienen un
-- post relacionado nuevo (cluster) apuntaban solo hacia afuera o a nada.
-- Se añade un parrafo de lectura relacionada al final de cada uno, protegido
-- por NOT LIKE para que reimportar esto no lo duplique.
UPDATE `posts`
SET `content` = CONCAT(`content`, '\r\n<p><strong>Relacionado:</strong> <a href="/blog/post/vigilar-el-catalogo-kev-de-cisa-sin-servidor/">automaticé la vigilancia del propio catálogo KEV</a> para no depender de acordarme de consultarlo.</p>')
WHERE `slug` = 'priorizar-cves-sin-fiarse-solo-del-cvss'
  AND `content` NOT LIKE '%vigilar-el-catalogo-kev-de-cisa-sin-servidor%';

UPDATE `posts`
SET `content` = CONCAT(`content`, '\r\n<p><strong>Relacionado:</strong> el mismo principio de minimizar lo que se confía en manos ajenas aparece en <a href="/blog/post/revocar-un-token-sin-derribar-la-sesion-entera/">BinCat</a>, para revocar un token sin derribar toda la sesión.</p>')
WHERE `slug` = 'comprobar-si-una-contrasena-esta-filtrada-sin-enviarsela-a-nadie'
  AND `content` NOT LIKE '%revocar-un-token-sin-derribar-la-sesion-entera%';

UPDATE `posts`
SET `content` = CONCAT(`content`, '\r\n<p><strong>Relacionado:</strong> <a href="/blog/post/el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple/">medí después si el desacuerdo entre varios clasificadores ayuda a priorizar qué correo revisar</a> — la respuesta no fue la esperada.</p>')
WHERE `slug` = 'clasificar-phishing-en-el-navegador-sin-mandar-la-url'
  AND `content` NOT LIKE '%el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple%';

-- ---------------------------------------------------------------------------
-- Blog: categoria de cada articulo existente (2026-09-06).
--
-- Las categorias son las mismas que POST_CATEGORIES en
-- server/lib/post.php -- si se anade una aqui, hay que anadirla alli tambien
-- (y viceversa) o el filtro del listado la mostraria con la clave en bruto
-- en vez de la etiqueta legible.
--
-- Un UPDATE por slug, no una unica sentencia con CASE: son solo 13 filas y
-- asi cada linea se lee y se corrige sola sin tener que tocar las demas.
-- ---------------------------------------------------------------------------
UPDATE `posts` SET `category` = 'herramientas'     WHERE `slug` = 'comprobar-si-una-contrasena-esta-filtrada-sin-enviarsela-a-nadie';
UPDATE `posts` SET `category` = 'blue-team-soc'    WHERE `slug` = 'triaje-de-alertas-en-un-soc-en-que-orden-mirar';
UPDATE `posts` SET `category` = 'ia-aplicada'      WHERE `slug` = 'clasificar-phishing-en-el-navegador-sin-mandar-la-url';
UPDATE `posts` SET `category` = 'automatizacion'   WHERE `slug` = 'automatizar-el-informe-semanal-del-soc-con-python';
UPDATE `posts` SET `category` = 'blue-team-soc'    WHERE `slug` = 'priorizar-cves-sin-fiarse-solo-del-cvss';
UPDATE `posts` SET `category` = 'blue-team-soc'    WHERE `slug` = 'hardening-fortigate-antes-de-dar-un-despliegue-por-bueno';
UPDATE `posts` SET `category` = 'carrera-personal' WHERE `slug` = 'de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto';
UPDATE `posts` SET `category` = 'blue-team-soc'    WHERE `slug` = 'active-directory-los-primeros-diez-cambios-en-cualquier-dominio-nuevo';
UPDATE `posts` SET `category` = 'automatizacion'   WHERE `slug` = 'vigilar-el-catalogo-kev-de-cisa-sin-servidor';
UPDATE `posts` SET `category` = 'herramientas'     WHERE `slug` = 'blue-team-hub-por-que-quite-el-cristal-esmerilado';
UPDATE `posts` SET `category` = 'herramientas'     WHERE `slug` = 'revocar-un-token-sin-derribar-la-sesion-entera';
UPDATE `posts` SET `category` = 'carrera-personal' WHERE `slug` = 'lo-que-da-tiempo-a-aprender-en-24-horas-de-hackathon';
UPDATE `posts` SET `category` = 'ia-aplicada'      WHERE `slug` = 'el-desacuerdo-entre-clasificadores-pierde-contra-algo-mas-simple';

-- ---------------------------------------------------------------------------
-- Blog: diez articulos nuevos (2026-10-12). Cubren el foco del perfil que el
-- blog no tocaba todavia (Cloud Security, IAM y seguridad del correo) mas
-- SOC y normativa. Mismo patron idempotente que los bloques de arriba: solo
-- entran si su slug no existe, asi que reimportar no los duplica.
--
-- Pensados tambien para GEO (respuestas de asistentes de IA): cada uno abre
-- con una respuesta directa en el primer parrafo, usa H2 con la pregunta que
-- se busca y cierra con preguntas frecuentes en H3, que es el formato que
-- mejor se cita literalmente.
--
-- Las categorias `cloud-iam` y `normativa` son nuevas: tienen que existir en
-- POST_CATEGORIES (server/lib/post.php) o el listado las muestra sin etiqueta.
-- ---------------------------------------------------------------------------

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'MFA resistente a phishing: por qué el SMS ya no basta',
  'mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta',
  'El MFA por SMS o push se salta con phishing en tiempo real y fatiga de MFA. Qué métodos resisten de verdad el phishing y cómo migrar sin bloquear a nadie.',
  '<p>Un segundo factor por SMS es mejor que no tener ninguno, pero ya no frena a un atacante con un mínimo de preparación. El MFA resistente a phishing es el que no se puede reenviar a una web falsa: la credencial está ligada criptográficamente al dominio legítimo, así que aunque el usuario pique, lo que entrega no sirve en otro sitio. Hoy eso significa llaves FIDO2, passkeys y Windows Hello for Business, o certificados con smart card.</p>
<h2>Cómo se salta un MFA "normal"</h2>
<p>Hay tres técnicas habituales, y ninguna necesita romper criptografía:</p>
<ul>
  <li>Phishing en tiempo real (AiTM): un proxy inverso se coloca entre la víctima y el login real. El usuario escribe usuario, contraseña y código, el proxy los reenvía al servicio de verdad y se queda con la cookie de sesión. Kits como Evilginx o EvilProxy lo dejan al alcance de cualquiera.</li>
  <li>Fatiga de MFA: el atacante ya tiene la contraseña y lanza notificaciones push una tras otra hasta que alguien pulsa "Aprobar" para que paren. En el incidente de Uber de 2022 el atacante combinó eso con un mensaje por WhatsApp haciéndose pasar por el soporte interno.</li>
  <li>SIM swapping: con el número de teléfono portado a otra SIM, los códigos por SMS llegan directamente al atacante.</li>
</ul>
<p>Los tres funcionan porque el factor (un código de seis dígitos, un botón de aprobar) no sabe en qué web se está usando.</p>
<h2>Qué métodos son resistentes a phishing</h2>
<p>CISA publicó en 2022 una guía específica sobre esto, <a href="https://www.cisa.gov/sites/default/files/publications/fact-sheet-implementing-phishing-resistant-mfa-508c.pdf">Implementing Phishing-Resistant MFA</a>, y su clasificación sigue siendo una buena referencia:</p>
<table>
  <thead><tr><th>Método</th><th>¿Resistente a phishing?</th></tr></thead>
  <tbody>
    <tr><td>Código por SMS o llamada</td><td>No</td></tr>
    <tr><td>Código TOTP (app autenticadora)</td><td>No</td></tr>
    <tr><td>Push sin number matching</td><td>No</td></tr>
    <tr><td>Push con number matching</td><td>Mejor, pero no</td></tr>
    <tr><td>Llave FIDO2 / passkey</td><td>Sí</td></tr>
    <tr><td>Windows Hello for Business</td><td>Sí</td></tr>
    <tr><td>Certificado (PKI / smart card)</td><td>Sí</td></tr>
  </tbody>
</table>
<p>El number matching (el usuario teclea en el móvil el número que ve en pantalla) acaba casi del todo con la fatiga de MFA, y Microsoft lo activó para todos los inquilinos de Authenticator en 2023. Pero un proxy AiTM puede mostrar ese número igual que muestra la página de login, así que no protege contra el phishing en tiempo real.</p>
<h2>Por qué FIDO2 y las passkeys sí aguantan</h2>
<p>Una passkey es un par de claves. La privada nunca sale del dispositivo, y al registrarla queda asociada al dominio exacto del servicio. Cuando el navegador recibe una petición de autenticación de <code>login.micr0soft-secure.com</code>, la passkey de <code>login.microsoftonline.com</code> simplemente no responde. No hay código que copiar ni botón que pulsar por cansancio: el usuario no tiene forma de entregar algo que valga en el dominio falso.</p>
<h2>Cómo migrar sin bloquear a nadie</h2>
<p>El error típico es querer activarlo para todo el mundo el mismo día. El orden que funciona:</p>
<ol>
  <li><strong>Cuentas privilegiadas primero.</strong> Administradores globales, de Exchange, de seguridad. Son pocas, el riesgo es máximo y la gente que las usa entiende por qué se cambia.</li>
  <li><strong>Cuentas de emergencia (break-glass) con llave FIDO2 física</strong>, guardada fuera del flujo diario.</li>
  <li><strong>Usuarios con más exposición</strong>: finanzas, recursos humanos, dirección. Son los objetivos habituales de <a href="/blog/post/business-email-compromise-senales-en-microsoft-365/">fraude BEC</a>.</li>
  <li><strong>El resto, por fases</strong>, dejando un método de respaldo temporal y quitándolo cuando el registro de passkeys pase de un umbral que tengas medido.</li>
</ol>
<p>En Microsoft Entra ID esto se controla con las <em>authentication strengths</em> dentro de <a href="/blog/post/acceso-condicional-microsoft-365-politicas-base/">acceso condicional</a>: puedes exigir "MFA resistente a phishing" solo para ciertos roles o aplicaciones sin tocar al resto.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Una app autenticadora con código es segura?</h3>
<p>Es más segura que el SMS porque no depende del número de teléfono, pero el código se puede introducir en una web falsa igual que una contraseña. No es resistente a phishing.</p>
<h3>¿Las passkeys sincronizadas en la nube cuentan?</h3>
<p>Sí resisten el phishing, porque siguen ligadas al dominio. La diferencia con una llave física es dónde vive la clave privada: en una passkey sincronizada depende de la seguridad de la cuenta de Apple, Google o del gestor de contraseñas. Para cuentas de administración prefiero llave física.</p>
<h3>¿El MFA resistente a phishing evita el robo de cookies de sesión?</h3>
<p>Evita el AiTM, que es la forma más común de robarlas. Si un infostealer ya está en el equipo y se lleva la cookie después del login, el MFA no interviene; para eso hacen falta controles de dispositivo y protección de tokens.</p>',
  'mfa,passkeys,fido2,iam,phishing,entra-id', 'cloud-iam', 'es', 1, '2026-09-14 09:00:00', '2026-09-14 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'SPF, DKIM y DMARC: cómo pasar de p=none a p=reject',
  'spf-dkim-dmarc-de-p-none-a-p-reject',
  'Qué hacen SPF, DKIM y DMARC, por qué tantos dominios se quedan en p=none y cómo llegar a p=reject por fases sin perder correo legítimo.',
  '<p>SPF dice qué servidores pueden enviar correo en nombre de tu dominio, DKIM firma cada mensaje para demostrar que no se ha modificado, y DMARC le dice al receptor qué hacer cuando un correo falla esas comprobaciones y a quién mandar el informe. Por separado ninguno impide que alguien suplante tu dominio en el campo <code>From</code> que ve el usuario. DMARC con <code>p=reject</code> sí.</p>
<p>Y aun así, muchísimos dominios llevan años con DMARC publicado en <code>p=none</code>. Es el equivalente a tener una alarma que solo apunta en una libreta quién ha entrado.</p>
<h2>Qué comprueba cada registro</h2>
<h3>SPF</h3>
<p>Un registro TXT en el dominio con la lista de IPs y servicios autorizados:</p>
<pre><code>v=spf1 include:spf.protection.outlook.com include:_spf.google.com -all</code></pre>
<p>Dos detalles que rompen más SPF de los que deberían: el límite de <strong>10 consultas DNS</strong> (cada <code>include</code> cuenta, y los anidados también) y que SPF valida el remitente del sobre (<code>Return-Path</code>), no el <code>From</code> visible.</p>
<h3>DKIM</h3>
<p>El servidor emisor firma cabeceras y cuerpo con una clave privada, y publica la pública en DNS bajo un selector (<code>selector1._domainkey.tudominio.com</code>). Sobrevive a reenvíos mejor que SPF, que es justo por lo que DMARC acepta cualquiera de los dos.</p>
<h3>DMARC</h3>
<p>DMARC exige <em>alineación</em>: que el dominio que pasa SPF o DKIM coincida con el del <code>From</code>. Ahí está la protección real contra la suplantación.</p>
<pre><code>v=DMARC1; p=none; rua=mailto:dmarc@tudominio.com; fo=1</code></pre>
<h2>Por qué ya no es opcional</h2>
<p>Desde febrero de 2024, Google y Yahoo exigen SPF, DKIM y DMARC a quien envíe más de 5.000 correos al día a sus usuarios, y Microsoft anunció requisitos equivalentes para Outlook.com en 2025. Para un dominio corporativo pequeño el volumen no llega a esos umbrales, pero la dirección es clara: el correo sin autenticar cada vez llega peor.</p>
<h2>El proceso por fases hasta p=reject</h2>
<ol>
  <li><strong>Inventario.</strong> Publica <code>p=none</code> con <code>rua</code> y deja que lleguen informes agregados al menos dos o tres semanas. Te van a aparecer remitentes que nadie recordaba: el CRM, la herramienta de facturas, el formulario de la web, el escáner de la oficina.</li>
  <li><strong>Arreglar cada remitente legítimo.</strong> Para cada uno, configurar DKIM con tu dominio (mejor que añadirlo a SPF, que tiene el límite de 10 consultas).</li>
  <li><strong><code>p=quarantine</code> con <code>pct</code> bajo.</strong> Empieza con <code>pct=10</code> o <code>25</code>, revisa informes, sube.</li>
  <li><strong><code>p=reject</code></strong> cuando los informes lleven un tiempo limpios. Aquí también conviene <code>sp=reject</code> para los subdominios, que es por donde entra la suplantación cuando el dominio principal ya está protegido.</li>
</ol>
<p>Los informes agregados son XML y leerlos a mano es una tortura. Para revisar un mensaje concreto, el <a href="/blog/post/blue-team-hub-por-que-quite-el-cristal-esmerilado/">analizador de cabeceras de Blue Team Hub</a> muestra el resultado de SPF, DKIM y DMARC y los saltos del correo sin enviar nada a ningún servidor.</p>
<h2>Lo que DMARC no hace</h2>
<p>DMARC protege tu dominio exacto. No impide que alguien registre <code>tudominio-pagos.com</code> o use un nombre visible engañoso con una cuenta de Gmail. Contra eso hacen falta filtros del lado receptor y formación. Tampoco sirve si el atacante entra en un buzón real de tu organización, que es el escenario del <a href="/blog/post/business-email-compromise-senales-en-microsoft-365/">BEC con cuenta comprometida</a>.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Puedo poner p=reject directamente?</h3>
<p>Puedes, pero si hay un servicio legítimo que envía en tu nombre y no está alineado, sus correos se rechazarán sin aviso. Las semanas en <code>p=none</code> sirven precisamente para descubrirlos.</p>
<h3>¿Qué diferencia hay entre ~all y -all en SPF?</h3>
<p><code>~all</code> (softfail) marca como sospechoso lo que no está en la lista; <code>-all</code> (fail) lo marca como no autorizado. Con DMARC en <code>reject</code>, la política que manda es la de DMARC, así que la diferencia importa menos de lo que parece.</p>
<h3>¿Hace falta DMARC en un dominio que no envía correo?</h3>
<p>Sí, y es el caso más fácil: <code>v=spf1 -all</code> y <code>v=DMARC1; p=reject</code>. Los dominios aparcados sin protección son los favoritos para campañas de suplantación.</p>',
  'spf,dkim,dmarc,email-security,dns,phishing', 'blue-team-soc', 'es', 1, '2026-09-17 09:00:00', '2026-09-17 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'spf-dkim-dmarc-de-p-none-a-p-reject');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Mínimo privilegio en Microsoft Entra ID, en la práctica',
  'minimo-privilegio-en-microsoft-entra-id',
  'Demasiados administradores globales y roles permanentes. Cómo aplicar el mínimo privilegio en Microsoft Entra ID con roles específicos, PIM y cuentas break-glass.',
  '<p>El principio de mínimo privilegio dice que cada cuenta tiene solo los permisos que necesita, durante el tiempo que los necesita. En Microsoft Entra ID (el antiguo Azure AD) eso se traduce en tres cosas concretas: usar roles específicos en vez de Administrador global, que los roles privilegiados sean temporales con PIM y tener cuentas de emergencia que funcionen cuando todo lo demás falla.</p>
<p>Es lo mismo que <a href="/blog/post/active-directory-los-primeros-diez-cambios-en-cualquier-dominio-nuevo/">revisaba en Active Directory con Domain Admins</a>, pero en la nube el radio de impacto es mayor: un administrador global controla el correo, los ficheros de SharePoint y OneDrive, las identidades y, con un clic, las suscripciones de Azure.</p>
<h2>Cuántos administradores globales son demasiados</h2>
<p>Microsoft recomienda <a href="https://learn.microsoft.com/es-es/entra/identity/role-based-access-control/best-practices">menos de cinco administradores globales</a> por inquilino. Lo habitual es lo contrario: el técnico que montó el inquilino, el proveedor que hizo la migración, el director que lo pidió "por si acaso" y alguna cuenta de servicio que nadie sabe para qué es.</p>
<p>Para sacarlos rápido, desde PowerShell con Microsoft Graph:</p>
<pre><code>Connect-MgGraph -Scopes RoleManagement.Read.Directory
$rol = Get-MgDirectoryRole -Filter "displayName eq ''Global Administrator''"
Get-MgDirectoryRoleMember -DirectoryRoleId $rol.Id</code></pre>
<h2>Roles específicos en lugar de Administrador global</h2>
<p>Casi nadie necesita Administrador global para su trabajo diario. Las tareas habituales tienen su rol:</p>
<table>
  <thead><tr><th>Tarea</th><th>Rol suficiente</th></tr></thead>
  <tbody>
    <tr><td>Resetear contraseñas</td><td>Helpdesk Administrator</td></tr>
    <tr><td>Crear usuarios y grupos</td><td>User Administrator</td></tr>
    <tr><td>Gestionar buzones</td><td>Exchange Administrator</td></tr>
    <tr><td>Revisar alertas</td><td>Security Reader / Operator</td></tr>
    <tr><td>Licencias</td><td>License Administrator</td></tr>
    <tr><td>Políticas de acceso condicional</td><td>Conditional Access Administrator</td></tr>
  </tbody>
</table>
<p>Un detalle que se pasa por alto: los permisos que tiene un usuario para <em>consentir aplicaciones</em>. Si cualquiera puede dar permisos de lectura de correo a una app OAuth, el mínimo privilegio en roles se queda corto. Conviene restringir el consentimiento a editores verificados o a un flujo de aprobación.</p>
<h2>PIM: privilegio solo cuando hace falta</h2>
<p>Privileged Identity Management convierte los roles en <em>elegibles</em> en vez de <em>activos</em>. La persona no es administradora hasta que lo pide, justifica el motivo, pasa MFA y, si se configura, alguien lo aprueba. Al cabo de unas horas el rol caduca solo.</p>
<p>Para el SOC, la ventaja es que una cuenta comprometida sin rol activo no puede hacer casi nada, y cada activación queda registrada con su justificación. Una activación de Administrador global a las tres de la mañana es una alerta muy fácil de escribir.</p>
<p>PIM requiere licencia Entra ID P2 (o Entra ID Governance). Si no la hay, al menos separa la cuenta de administración de la cuenta diaria con la que se lee el correo y se navega.</p>
<h2>Cuentas de emergencia (break-glass)</h2>
<p>Dos cuentas cloud-only, sin buzón, con Administrador global permanente, excluidas de las políticas de acceso condicional que podrían dejarte fuera, y protegidas con llave FIDO2 física. Microsoft recomienda dos, con credenciales separadas.</p>
<p>Lo que casi nadie hace: <strong>probarlas</strong> cada pocos meses y tener una alerta que salte cada vez que una de ellas inicia sesión. Si se usan y nadie se entera, son la puerta trasera perfecta.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué es el principio de mínimo privilegio?</h3>
<p>Conceder a cada usuario, aplicación o servicio solo los permisos imprescindibles para su función y durante el tiempo justo. Reduce lo que puede hacer un atacante con una cuenta robada.</p>
<h3>¿PIM sustituye al MFA?</h3>
<p>No, lo complementa. PIM puede exigir MFA en cada activación, y lo ideal es que sea <a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">MFA resistente a phishing</a>.</p>
<h3>¿Cada cuánto revisar los roles asignados?</h3>
<p>Como mínimo trimestralmente, y siempre que alguien cambie de puesto o se vaya. Es el mismo problema que el <a href="/blog/post/joiner-mover-leaver-cuentas-huerfanas/">ciclo joiner-mover-leaver</a>, aplicado a privilegios.</p>',
  'entra-id,iam,minimo-privilegio,pim,azure,microsoft-365', 'cloud-iam', 'es', 1, '2026-09-21 09:00:00', '2026-09-21 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'minimo-privilegio-en-microsoft-entra-id');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'XDR, SIEM y EDR: en qué se diferencian en un SOC real',
  'xdr-vs-siem-vs-edr-diferencias-en-un-soc',
  'EDR vigila el endpoint, SIEM centraliza logs de cualquier fuente y XDR correlaciona varias capas de serie. Qué aporta cada uno al trabajo diario de un SOC.',
  '<p>Un EDR vigila lo que pasa dentro de cada equipo y puede aislarlo. Un SIEM recoge logs de cualquier fuente, los guarda y permite correlacionarlos y buscar en ellos. Un XDR junta la telemetría de varias capas (endpoint, correo, identidad, red, cloud) normalmente de un mismo fabricante, y la correlaciona por ti en un único incidente. No son sustitutos exactos: se solapan, y la mayoría de SOCs acaban usando dos de los tres.</p>
<p>Trabajo a diario con Trend Micro Vision One, que es un XDR, así que lo que sigue sale de esa perspectiva.</p>
<h2>EDR: el detalle del endpoint</h2>
<p>El EDR registra procesos, conexiones de red, cambios en el registro y ficheros, y detecta comportamiento sospechoso en el propio equipo. Su fuerza es la profundidad: puedes ver el árbol de procesos completo de un <code>winword.exe</code> que lanzó <code>powershell.exe</code> con un comando codificado, y aislar el equipo de la red con un botón.</p>
<p>Su límite es que solo ve endpoints. Un inicio de sesión desde una IP rara en Microsoft 365 o una regla de reenvío creada en un buzón no pasan por ahí.</p>
<h2>SIEM: todo en un sitio, a tu manera</h2>
<p>Un SIEM (Splunk, Microsoft Sentinel, QRadar, Elastic, Wazuh) ingesta logs de lo que quieras: firewalls, controladores de dominio, proxies, aplicaciones propias, cloud. Lo que aporta:</p>
<ul>
  <li>Retención larga y búsqueda sobre todo ese histórico.</li>
  <li>Reglas de correlación propias, escritas para tu entorno.</li>
  <li>Cumplimiento normativo: muchas auditorías piden logs centralizados durante un tiempo concreto.</li>
</ul>
<p>A cambio, da trabajo: normalizar fuentes, escribir y afinar reglas, pagar por volumen ingestado. Un SIEM recién instalado y sin afinar genera ruido, no detección.</p>
<h2>XDR: correlación ya hecha</h2>
<p>El XDR parte de que el fabricante controla los sensores de varias capas y por tanto puede correlacionarlos de serie. En la práctica, en vez de tres alertas sueltas (correo sospechoso entregado, macro ejecutada, conexión a un dominio nuevo) recibes un único incidente con la secuencia completa y el usuario afectado.</p>
<p>Para el <a href="/blog/post/triaje-de-alertas-en-un-soc-en-que-orden-mirar/">triaje de alertas</a> eso cambia mucho el tiempo por incidente. La contrapartida es que la visibilidad es mejor dentro del ecosistema del fabricante y más pobre fuera de él.</p>
<h2>Tabla comparativa</h2>
<table>
  <thead><tr><th></th><th>EDR</th><th>SIEM</th><th>XDR</th></tr></thead>
  <tbody>
    <tr><td>Fuentes</td><td>Endpoints</td><td>Cualquiera</td><td>Varias capas, mismo fabricante</td></tr>
    <tr><td>Correlación</td><td>En el equipo</td><td>Reglas propias</td><td>De serie</td></tr>
    <tr><td>Respuesta</td><td>Aislar, matar proceso</td><td>Vía SOAR</td><td>Integrada</td></tr>
    <tr><td>Retención</td><td>Corta</td><td>Larga</td><td>Media</td></tr>
    <tr><td>Esfuerzo de ajuste</td><td>Bajo</td><td>Alto</td><td>Medio</td></tr>
  </tbody>
</table>
<h2>Cuál necesita una empresa mediana</h2>
<p>Si hay que elegir uno, para una organización sin equipo para mantener reglas de correlación, un XDR (o un EDR con servicio gestionado) da más detección por hora de trabajo. El SIEM llega cuando hace falta retención por normativa, cuando hay fuentes que el XDR no cubre (OT, aplicaciones propias) o cuando el equipo quiere escribir su propia detección. Lo habitual es acabar con XDR y SIEM a la vez, con el XDR enviando sus incidentes al SIEM.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿El XDR sustituye al SIEM?</h3>
<p>En algunas organizaciones pequeñas, sí. En cuanto hay requisitos de retención de logs o fuentes de terceros, no: se complementan.</p>
<h3>¿Qué es un SOAR?</h3>
<p>Una plataforma de orquestación y respuesta automatizada que ejecuta playbooks sobre alertas: enriquecer un IOC, abrir un ticket, bloquear un usuario. Muchos SIEM y XDR ya incluyen parte de esa función.</p>
<h3>¿Y MDR?</h3>
<p>Managed Detection and Response no es un producto sino un servicio: un equipo externo vigila y responde usando EDR o XDR. Es la opción cuando no hay SOC propio 24x7.</p>',
  'xdr,siem,edr,soc,vision-one,deteccion', 'blue-team-soc', 'es', 1, '2026-09-24 09:00:00', '2026-09-24 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'xdr-vs-siem-vs-edr-diferencias-en-un-soc');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Errores de configuración en cloud que más se repiten',
  'errores-de-configuracion-cloud-mas-comunes',
  'Casi todas las brechas en cloud vienen de la configuración del cliente: buckets públicos, claves eternas, puertos abiertos y logs apagados. Qué revisar primero.',
  '<p>La mayoría de brechas en cloud no explotan un fallo de AWS, Azure o Google Cloud. Explotan algo que el cliente configuró mal. Es lo que dice el <strong>modelo de responsabilidad compartida</strong>: el proveedor responde de la seguridad <em>de</em> la nube (centros de datos, hipervisor, red física) y tú de la seguridad <em>en</em> la nube (identidades, datos, configuración de cada servicio). Gartner llegó a predecir que hasta 2025 el 99 % de los fallos de seguridad en cloud serían responsabilidad del cliente.</p>
<p>Esta es la lista corta que miraría primero en una cuenta cloud desconocida, ordenada por el daño que hace cada fallo.</p>
<h2>1. Almacenamiento expuesto a internet</h2>
<p>Buckets de S3, contenedores de Azure Blob o buckets de GCS con acceso público. Es el clásico de las filtraciones de datos. AWS activa <em>Block Public Access</em> por defecto en los buckets nuevos desde abril de 2023, pero los antiguos siguen como estaban y cualquiera con permisos puede desactivarlo.</p>
<p>Qué mirar: Block Public Access a nivel de <strong>cuenta</strong>, no solo de bucket, y una alerta si alguien lo cambia.</p>
<h2>2. Claves de acceso de larga duración</h2>
<p>Access keys de IAM creadas hace años, asignadas a un usuario que ya no existe en la empresa, con permisos de administrador y pegadas en algún script. Es la credencial ideal para un atacante: no caduca y no tiene MFA.</p>
<p>Qué mirar: claves con más de 90 días, claves sin uso reciente, y si se pueden sustituir por roles con credenciales temporales. Cuando una de esas claves acaba en un repositorio, el problema es el que cuento en <a href="/blog/post/secretos-en-repositorios-como-se-filtran-y-como-evitarlo/">cómo se filtran los secretos en Git</a>.</p>
<h2>3. Roles con permisos de más</h2>
<p>Políticas con <code>"Action": "*"</code> o <code>"Resource": "*"</code> porque "así funcionaba". La brecha de Capital One de 2019 combinó un SSRF en una aplicación web con el servicio de metadatos de la instancia (IMDSv1) y un rol con acceso a demasiados buckets. Sin ese rol sobredimensionado, el SSRF se habría quedado en poca cosa.</p>
<p>Qué mirar: exigir IMDSv2 en las instancias, y usar las herramientas del propio proveedor (IAM Access Analyzer en AWS, por ejemplo) para ver qué permisos no se usan nunca.</p>
<h2>4. Puertos de administración abiertos a 0.0.0.0/0</h2>
<p>SSH (22) y RDP (3389) abiertos a todo internet en un security group o un NSG. Los escáneres los encuentran en minutos. La alternativa es un bastión, acceso a través del propio proveedor (Session Manager, Azure Bastion, IAP) o al menos restringir por IP de origen.</p>
<h2>5. Logs apagados o sin retención</h2>
<p>CloudTrail desactivado en alguna región, Azure Activity Log sin exportar, logs de acceso de almacenamiento sin habilitar. No impide el ataque, pero cuando llega el incidente no hay forma de saber qué pasó. Sin logs, la investigación se queda en suposiciones.</p>
<h2>6. Identidad débil en la consola</h2>
<p>La cuenta raíz de AWS sin MFA, o con access keys propias. Usuarios de consola sin MFA. Es la versión cloud del mismo problema de siempre, y se arregla con <a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">MFA resistente a phishing</a> y <a href="/blog/post/minimo-privilegio-en-microsoft-entra-id/">mínimo privilegio</a>.</p>
<h2>Revisarlo una vez no sirve: CSPM</h2>
<p>Todo lo anterior se puede revisar a mano, pero la configuración cambia cada día. Las herramientas de CSPM (Cloud Security Posture Management) comprueban la configuración de forma continua contra marcos como los CIS Benchmarks y avisan cuando algo se desvía. Los proveedores tienen la suya (AWS Security Hub, Microsoft Defender for Cloud) y plataformas como Trend Micro Vision One también lo cubren. Para empezar sin coste, <a href="https://github.com/prowler-cloud/prowler">Prowler</a> es de código abierto y muy completo.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué es el modelo de responsabilidad compartida?</h3>
<p>El reparto de quién protege qué en la nube. El proveedor protege la infraestructura; el cliente, todo lo que configura encima. Cuanto más gestionado es el servicio (SaaS frente a IaaS), más parte asume el proveedor, pero las identidades y los datos siempre son tuyos.</p>
<h3>¿Qué es CSPM?</h3>
<p>Una categoría de herramientas que evalúan de forma continua la configuración de tus cuentas cloud contra buenas prácticas y normativas, y detectan desviaciones como un bucket que se ha vuelto público.</p>
<h3>¿Por dónde empiezo si solo tengo una tarde?</h3>
<p>MFA en la cuenta raíz y en todos los administradores, Block Public Access a nivel de cuenta y CloudTrail (o el equivalente) activo en todas las regiones.</p>',
  'cloud-security,aws,azure,cspm,misconfiguration,iam', 'cloud-iam', 'es', 1, '2026-09-28 09:00:00', '2026-09-28 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'errores-de-configuracion-cloud-mas-comunes');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Secretos en repositorios: cómo se filtran y cómo evitarlo',
  'secretos-en-repositorios-como-se-filtran-y-como-evitarlo',
  'Una clave de API subida a GitHub se explota en minutos y borrarla del commit no basta. Cómo se filtran, cómo frenarlos antes del push y qué hacer después.',
  '<p>Un secreto (clave de API, token, contraseña de base de datos) subido a un repositorio público hay que darlo por comprometido desde el primer segundo. Hay bots que leen el flujo de commits públicos de GitHub en tiempo real buscando patrones de claves. Y borrar la línea en el commit siguiente no arregla nada: la clave sigue en el historial. Lo único que funciona es revocarla y rotarla.</p>
<p>GitGuardian, en su informe <em>State of Secrets Sprawl</em> de 2025, contó más de 23 millones de secretos nuevos expuestos en commits públicos de GitHub durante 2024. Y no es solo cosa de proyectos personales: muchos salen de repositorios de empresas.</p>
<h2>Por dónde se escapan</h2>
<ul>
  <li>El <code>.env</code> que no estaba en <code>.gitignore</code>, o que se añadió al <code>.gitignore</code> después de haberlo commiteado una vez.</li>
  <li>La clave "temporal" en el código para probar algo rápido, que se queda.</li>
  <li>Ficheros de configuración de ejemplo con valores reales en vez de marcadores.</li>
  <li>Logs y salidas de CI que imprimen variables de entorno.</li>
  <li>Un repositorio privado que se hace público años después, con todo su historial.</li>
</ul>
<h2>Detectarlos antes del push</h2>
<p>El mejor momento para encontrar un secreto es antes de que salga de tu máquina. Un hook de pre-commit con <a href="https://github.com/gitleaks/gitleaks">gitleaks</a> revisa cada commit y lo bloquea si encuentra algo:</p>
<pre><code># .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks</code></pre>
<p>En el propio GitHub, <em>push protection</em> del secret scanning rechaza el push si detecta un patrón de un proveedor conocido, y está activo por defecto en los repositorios públicos desde 2024. En este mismo portfolio hay un test de PHPUnit (<code>NoSecretsTest</code>) que recorre los ficheros versionados y falla si encuentra una clave de API. Un hook local se puede saltar con <code>--no-verify</code>; un test que corre en CI, no.</p>
<h2>Revisar el historial que ya existe</h2>
<p>Para repositorios con años de historia, gitleaks y <a href="https://github.com/trufflesecurity/trufflehog">TruffleHog</a> escanean todos los commits. TruffleHog además puede verificar si una clave encontrada sigue siendo válida, lo que ayuda a priorizar.</p>
<pre><code>gitleaks detect --source . --log-opts="--all"</code></pre>
<h2>Si ya se ha filtrado</h2>
<ol>
  <li><strong>Revocar y rotar primero.</strong> Antes que limpiar el historial. Cada minuto cuenta.</li>
  <li><strong>Revisar los logs del servicio</strong> afectado para ver si alguien la ha usado desde que se subió. En una clave de AWS, CloudTrail filtrando por ese access key ID.</li>
  <li><strong>Limpiar el historial</strong> con <code>git filter-repo</code> si el repositorio es tuyo, sabiendo que cualquier fork o clon anterior conserva la clave. Por eso el paso 1 va primero.</li>
  <li><strong>Buscar la causa</strong> para que no se repita: ¿faltaba el <code>.gitignore</code>? ¿no había hook?</li>
</ol>
<h2>La solución de fondo: que no haya secretos que filtrar</h2>
<p>Cuantos menos secretos estáticos existan, menos hay que proteger. Un gestor de secretos (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault) en lugar de ficheros, y en CI/CD federación OIDC en vez de claves: GitHub Actions puede pedir credenciales temporales a AWS o Azure sin guardar ninguna clave en el repositorio. Y la opción más segura sigue siendo no necesitar credenciales: <a href="/blog/post/vigilar-el-catalogo-kev-de-cisa-sin-servidor/">kev-digest</a> solo lee un catálogo público, así que corre en Actions sin ningún secreto de terceros que proteger.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Basta con hacer el repositorio privado?</h3>
<p>No. Cualquiera con acceso al repositorio, o cualquier integración con permisos de lectura, ve el secreto. Y si alguien lo clonó mientras era público, ya lo tiene.</p>
<h3>¿Borrar el commit elimina la clave?</h3>
<p>No de forma fiable. El commit puede seguir accesible por su hash, en forks, en cachés y en clones. Hay que revocar la clave siempre.</p>
<h3>¿Qué herramienta uso para empezar?</h3>
<p>gitleaks como hook de pre-commit y en CI, más push protection en GitHub. Las dos son gratuitas.</p>',
  'secretos,git,github,devsecops,gitleaks,credenciales', 'vulnerabilidades', 'es', 1, '2026-10-01 09:00:00', '2026-10-01 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'secretos-en-repositorios-como-se-filtran-y-como-evitarlo');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Business Email Compromise: las señales en Microsoft 365',
  'business-email-compromise-senales-en-microsoft-365',
  'Un BEC casi nunca trae malware: trae un login raro, una regla de bandeja oculta y un cambio de cuenta bancaria. Qué buscar en los logs de Microsoft 365.',
  '<p>El Business Email Compromise (BEC) es un fraude en el que el atacante se hace pasar por alguien de confianza, o directamente usa su buzón comprometido, para conseguir un pago o datos. No suele llevar adjuntos maliciosos ni enlaces a malware, así que los filtros clásicos lo dejan pasar. Según el informe IC3 del FBI, en 2024 el BEC causó pérdidas declaradas de casi 2.800 millones de dólares solo en Estados Unidos, muy por encima del ransomware.</p>
<p>Cuando el BEC sale de una cuenta real comprometida, deja rastro en los logs de Microsoft 365. Estas son las señales que conviene buscar.</p>
<h2>1. El inicio de sesión</h2>
<p>Casi siempre empieza con credenciales robadas por phishing, y cada vez más con un proxy AiTM que también roba la cookie de sesión y salta el MFA tradicional. En los logs de inicio de sesión de Entra ID:</p>
<ul>
  <li>IP de un proveedor de hosting o VPN comercial, no de un ISP residencial ni de la oficina.</li>
  <li>País o ciudad que no encaja con el usuario, o "viaje imposible" respecto al inicio de sesión anterior.</li>
  <li>Un user agent distinto al habitual del usuario, a veces de librerías como <code>python-requests</code> o <code>axios</code>.</li>
  <li>Un inicio de sesión correcto justo después de que el usuario hiciera clic en un enlace de un correo.</li>
</ul>
<h2>2. Las reglas de bandeja de entrada</h2>
<p>Es la señal más fiable y la que menos falsos positivos da, porque lo primero que hace el atacante es esconderse: una regla que mueve a "RSS" o "Archivo" y marca como leído cualquier correo que contenga "factura", "pago", "transferencia" o el nombre del proveedor que quiere suplantar. Así la víctima no ve las respuestas.</p>
<p>En el registro de auditoría unificado, las operaciones <code>New-InboxRule</code>, <code>Set-InboxRule</code> y <code>UpdateInboxRules</code>. Desconfía de reglas con nombres de un solo carácter (".", "..", "a") o que mueven a carpetas que nadie usa.</p>
<h2>3. Reenvíos externos</h2>
<p>Un <code>Set-Mailbox</code> con <code>ForwardingSmtpAddress</code> a una dirección externa, o una regla que reenvía copia de todo. Lo ideal es bloquear el reenvío automático externo en la política antispam saliente y crear excepciones solo cuando haya un motivo.</p>
<h2>4. Aplicaciones OAuth con permisos de correo</h2>
<p>Una variante más persistente: el atacante consigue que el usuario consienta una aplicación con permisos como <code>Mail.Read</code> o <code>Mail.Send</code>. Aunque se cambie la contraseña, la app sigue teniendo acceso. Revisa los consentimientos recientes en Entra ID y restringe quién puede darlos, como cuento en el artículo de <a href="/blog/post/minimo-privilegio-en-microsoft-entra-id/">mínimo privilegio en Entra ID</a>.</p>
<h2>5. El propio fraude</h2>
<p>El correo final: "hemos cambiado de banco, a partir de ahora los pagos a esta cuenta", con un hilo real de conversación detrás y a veces desde un dominio casi idéntico al del proveedor. Aquí la defensa ya no es técnica: cualquier cambio de datos bancarios se verifica por un canal distinto (una llamada al número que ya tenías, no al del correo).</p>
<h2>Respuesta en el orden correcto</h2>
<ol>
  <li>Revocar sesiones del usuario (<code>Revoke-MgUserSignInSession</code>), no solo cambiar la contraseña: la cookie robada sigue valiendo.</li>
  <li>Restablecer contraseña y revisar los métodos de MFA registrados, por si el atacante añadió el suyo.</li>
  <li>Eliminar reglas de bandeja y reenvíos maliciosos.</li>
  <li>Revisar y revocar consentimientos OAuth sospechosos.</li>
  <li>Buscar en el registro de auditoría qué correos se leyeron y enviaron durante el acceso, y avisar a los destinatarios.</li>
</ol>
<p>Para que no se repita, lo que más reduce el riesgo es el <a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">MFA resistente a phishing</a> en los usuarios de finanzas y dirección, junto a <a href="/blog/post/spf-dkim-dmarc-de-p-none-a-p-reject/">DMARC en p=reject</a> para que nadie pueda suplantar tu dominio desde fuera.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué es el BEC?</h3>
<p>Business Email Compromise: fraude por correo en el que el atacante suplanta a un directivo, un empleado o un proveedor, o usa su cuenta comprometida, para conseguir transferencias, cambios de cuenta bancaria o información sensible.</p>
<h3>¿Cambiar la contraseña basta para echar al atacante?</h3>
<p>No. Hay que revocar las sesiones activas, revisar los métodos de MFA, las reglas de bandeja y las aplicaciones con consentimiento. Si no, el atacante conserva el acceso.</p>
<h3>¿Cómo distingo un BEC de un phishing normal?</h3>
<p>El phishing busca credenciales o instalar malware de forma masiva. El BEC es dirigido, suele ir sin enlaces ni adjuntos y busca dinero directamente, apoyándose en una relación de confianza real.</p>',
  'bec,microsoft-365,email-security,respuesta-a-incidentes,fraude,soc', 'blue-team-soc', 'es', 1, '2026-10-05 09:00:00', '2026-10-05 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'business-email-compromise-senales-en-microsoft-365');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Acceso condicional en Microsoft 365: las políticas base',
  'acceso-condicional-microsoft-365-politicas-base',
  'Seis políticas de acceso condicional de Entra ID que cubren casi todo el riesgo de identidad en Microsoft 365, y cómo activarlas sin dejar a nadie fuera.',
  '<p>El acceso condicional de Microsoft Entra ID es un motor de reglas del tipo "si se cumple esto, exige aquello": si el usuario es administrador, exige MFA resistente a phishing; si la autenticación usa un protocolo heredado, bloquéala; si el riesgo de inicio de sesión es alto, pide MFA. Requiere licencia Entra ID P1, incluida en Microsoft 365 Business Premium y E3. Sin ella, la alternativa son los <em>security defaults</em>, que activan un MFA básico para todos pero sin ningún ajuste.</p>
<p>Con seis políticas se cubre la mayor parte de los ataques de identidad habituales. No lo cubren todo, pero son el punto de partida razonable en cualquier inquilino.</p>
<h2>Antes de crear ninguna</h2>
<ul>
  <li><strong>Excluye las cuentas de emergencia</strong> de todas las políticas. Si una política mal configurada te deja fuera, son la forma de volver a entrar. Lo explico en <a href="/blog/post/minimo-privilegio-en-microsoft-entra-id/">mínimo privilegio en Entra ID</a>.</li>
  <li><strong>Crea cada política en modo "solo informe"</strong> (report-only). Durante una o dos semanas registra qué habría bloqueado sin bloquear nada. Revisas el impacto y luego la activas.</li>
</ul>
<h2>Las seis políticas base</h2>
<h3>1. Bloquear la autenticación heredada</h3>
<p>Protocolos como POP, IMAP, SMTP AUTH o ActiveSync con autenticación básica no admiten MFA, así que son la vía favorita del password spraying. Microsoft desactivó la autenticación básica en Exchange Online en 2022, pero bloquearla en acceso condicional cierra los huecos que queden.</p>
<h3>2. MFA resistente a phishing para administradores</h3>
<p>Para todos los roles privilegiados, con la <em>authentication strength</em> "Phishing-resistant MFA". Por qué no vale cualquier MFA lo cuento en <a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">MFA resistente a phishing</a>.</p>
<h3>3. MFA para todos los usuarios</h3>
<p>En todas las aplicaciones en la nube. Las excepciones, las mínimas, documentadas y revisadas.</p>
<h3>4. MFA para el registro de métodos de seguridad</h3>
<p>Si un atacante entra con la contraseña de un usuario que aún no tenía MFA, lo primero que intentará es registrar su propio teléfono. Esta política exige estar en una ubicación de confianza o con un MFA ya existente para registrar métodos nuevos.</p>
<h3>5. Bloquear países donde no operas</h3>
<p>No para por sí sola a un atacante (una VPN lo salta), pero elimina mucho ruido de intentos automatizados. Conviene combinarla con un grupo de excepción para viajes, con fecha de caducidad.</p>
<h3>6. Políticas basadas en riesgo</h3>
<p>Con Entra ID P2, Identity Protection calcula el riesgo del inicio de sesión (IP anónima, credenciales filtradas, viaje imposible) y del usuario. Exige MFA con riesgo de inicio de sesión medio o alto, y cambio de contraseña seguro con riesgo de usuario alto.</p>
<h2>El siguiente paso: el dispositivo</h2>
<p>Con las seis anteriores en marcha, la mejora más grande es exigir dispositivo gestionado (compliant en Intune o unido a Entra) para acceder a datos sensibles. Así, aunque alguien robe una sesión, no puede usarla desde un equipo que no controlas. Es el paso que más protege contra el robo de tokens que acompaña a casi todo <a href="/blog/post/business-email-compromise-senales-en-microsoft-365/">BEC</a> actual.</p>
<h2>Cómo detectar si alguien las salta</h2>
<p>En los logs de inicio de sesión, cada evento indica qué políticas se aplicaron y con qué resultado. Busca inicios de sesión correctos con resultado "notApplied" en usuarios que deberían estar cubiertos: suele ser una exclusión olvidada. Y alerta de cualquier cambio en las propias políticas; modificar una política de acceso condicional es una de las primeras cosas que hace un atacante con privilegios.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué es el acceso condicional?</h3>
<p>La función de Microsoft Entra ID que decide si permite, bloquea o exige requisitos adicionales (MFA, dispositivo gestionado) en cada inicio de sesión según el usuario, la aplicación, la ubicación, el dispositivo y el riesgo.</p>
<h3>¿Security defaults o acceso condicional?</h3>
<p>Security defaults si no tienes licencia P1: es gratis y mucho mejor que nada. Acceso condicional en cuanto tengas P1, porque permite excepciones controladas y métodos de MFA fuertes. No se pueden usar las dos a la vez.</p>
<h3>¿Cuánto tiempo dejar una política en modo solo informe?</h3>
<p>Lo suficiente para que pasen por ella los patrones normales de uso: al menos una semana completa, mejor dos si hay usuarios que viajan o trabajan por turnos.</p>',
  'acceso-condicional,entra-id,microsoft-365,iam,mfa,zero-trust', 'cloud-iam', 'es', 1, '2026-10-07 09:00:00', '2026-10-07 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'acceso-condicional-microsoft-365-politicas-base');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Cuentas huérfanas: el fallo del ciclo joiner-mover-leaver',
  'joiner-mover-leaver-cuentas-huerfanas',
  'Cuentas activas de gente que se fue y permisos que se acumulan al cambiar de puesto. Qué es el ciclo joiner-mover-leaver, dónde falla y cómo revisarlo.',
  '<p>El ciclo joiner-mover-leaver (JML) es el proceso de gestión de identidades que cubre tres momentos: cuando alguien entra en la organización (joiner), cuando cambia de puesto (mover) y cuando se va (leaver). Las cuentas huérfanas, activas pero sin una persona detrás que las necesite, aparecen casi siempre por un fallo en el tercero. Y la acumulación de permisos, por un fallo en el segundo.</p>
<p>Desde <a href="/blog/post/de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto/">soporte técnico</a> se ve muy claro que el alta es la parte que siempre funciona: la persona nueva llega, necesita entrar y alguien se queja si no puede. La baja no la reclama nadie.</p>
<h2>Joiner: el alta</h2>
<p>El riesgo en el alta es dar demasiado desde el primer día, normalmente copiando los permisos de "alguien que hace lo mismo". Ese alguien lleva cinco años acumulando accesos. Lo correcto es asignar por rol: grupos que representan un puesto, con sus permisos definidos, en vez de permisos individuales copiados.</p>
<p>La contraseña inicial también importa: generada, de un solo uso y con registro de MFA obligatorio en el primer inicio de sesión. Una contraseña inicial estándar del tipo "Empresa2026!" es una de las primeras cosas que prueba un atacante con password spraying.</p>
<h2>Mover: el cambio de puesto</h2>
<p>Es la fase que menos se gestiona y la que produce la <em>acumulación de privilegios</em>: alguien pasa de finanzas a comercial y se lleva los accesos nuevos sin perder los antiguos. Tras tres cambios de puesto, esa cuenta tiene acceso a medio negocio, y es justo la que interesa comprometer.</p>
<p>La regla sana: un cambio de puesto es una baja de los permisos del puesto anterior más un alta en el nuevo, con un periodo de transición fijado si hace falta, no una suma.</p>
<h2>Leaver: la baja</h2>
<p>Una cuenta de alguien que se ha ido es peligrosa por dos motivos: nadie va a notar si alguien la usa, y su contraseña puede estar en alguna filtración antigua. Lo que debería pasar el último día, o antes si la salida no es amistosa:</p>
<ol>
  <li>Deshabilitar la cuenta y <strong>revocar las sesiones activas</strong>. Deshabilitar sin revocar deja vivos los tokens ya emitidos durante un tiempo.</li>
  <li>Quitar los métodos de MFA y los dispositivos registrados.</li>
  <li>Convertir el buzón en compartido o delegarlo si hace falta, en vez de mantener la cuenta activa "para ver el correo".</li>
  <li>Revisar lo que no pasa por el directorio: cuentas locales en aplicaciones SaaS sin SSO, claves de API que creó, accesos a proveedores, <a href="/blog/post/secretos-en-repositorios-como-se-filtran-y-como-evitarlo/">secretos que conocía</a>.</li>
  <li>Eliminar la cuenta tras el periodo de retención definido.</li>
</ol>
<p>El punto 4 es el que falla más. El SSO ayuda mucho aquí: si todas las aplicaciones autentican contra Entra ID o el directorio corporativo, deshabilitar una cuenta corta el acceso en todas.</p>
<h2>Cómo encontrar las cuentas huérfanas que ya existen</h2>
<p>En Active Directory, cuentas habilitadas sin inicio de sesión en 90 días:</p>
<pre><code>Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly |
  Where-Object { $_.Enabled } |
  Select-Object Name, SamAccountName, LastLogonDate</code></pre>
<p>Y el cruce más útil: exportar la lista de usuarios activos del directorio y compararla con la de empleados actuales de recursos humanos. Lo que esté en la primera y no en la segunda necesita una explicación. Si la explicación es "es una cuenta de servicio", que tenga un responsable con nombre y apellidos.</p>
<h2>Revisiones de acceso periódicas</h2>
<p>Las revisiones de acceso (access reviews) piden a cada responsable que confirme, cada cierto tiempo, que su equipo sigue necesitando los accesos que tiene. Entra ID Governance las automatiza y puede retirar el acceso si nadie responde. Sin esa herramienta, una hoja de cálculo trimestral con los grupos sensibles ya es una mejora enorme. Para los roles de administración, lo mismo aplica con más frecuencia, como cuento en <a href="/blog/post/minimo-privilegio-en-microsoft-entra-id/">mínimo privilegio en Entra ID</a>.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué es una cuenta huérfana?</h3>
<p>Una cuenta activa que ya no corresponde a ninguna persona o servicio que la necesite, normalmente porque su usuario dejó la organización o el servicio se retiró sin dar de baja la identidad.</p>
<h3>¿Qué significa joiner-mover-leaver?</h3>
<p>Es el ciclo de vida de una identidad en una organización: alta al incorporarse, ajuste de permisos al cambiar de puesto y baja al marcharse. Es la base de cualquier proceso de IAM.</p>
<h3>¿Deshabilitar o eliminar la cuenta al irse alguien?</h3>
<p>Deshabilitar el primer día y eliminar después de un periodo de retención definido, para poder recuperar datos o investigar si hace falta.</p>',
  'iam,joiner-mover-leaver,active-directory,entra-id,gobierno-de-identidades', 'cloud-iam', 'es', 1, '2026-10-09 09:00:00', '2026-10-09 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'joiner-mover-leaver-cuentas-huerfanas');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'NIS2 en España: qué se sabe en octubre de 2026',
  'nis2-en-espana-estado-octubre-2026',
  'NIS2 debía estar transpuesta en octubre de 2024 y España sigue sin ley en el BOE. Qué está en vigor hoy, qué exigirá a las empresas y qué hacer ya.',
  '<p>La directiva europea NIS2 (Directiva (UE) 2022/2555) amplía las obligaciones de ciberseguridad a muchos más sectores y empresas que la NIS original, y endurece las sanciones. Los Estados miembros tenían que transponerla antes del 17 de octubre de 2024. A fecha de este artículo, octubre de 2026, España no ha publicado en el BOE la ley que la transpone, la futura Ley de Coordinación y Gobernanza de la Ciberseguridad.</p>
<h2>Dónde está la ley española</h2>
<ul>
  <li><strong>14 de enero de 2025:</strong> el Consejo de Ministros aprueba el anteproyecto y lo tramita por la vía de urgencia.</li>
  <li><strong>Mayo de 2025:</strong> la Comisión Europea envía a España un dictamen motivado por no haber notificado la transposición.</li>
  <li><strong>Julio de 2026:</strong> la Comisión lleva a España ante el Tribunal de Justicia de la UE por el mismo motivo.</li>
</ul>
<p>Mientras tanto siguen en vigor el Real Decreto-ley 12/2018 y su reglamento, el Real Decreto 43/2021, que transponen la NIS anterior y solo obligan a operadores de servicios esenciales y proveedores de servicios digitales. Si trabajas con la Administración, también aplica el Esquema Nacional de Seguridad (ENS).</p>
<p>Conviene comprobar el estado en el <a href="https://www.boe.es/">BOE</a> antes de tomar decisiones: este artículo describe la situación en una fecha concreta.</p>
<h2>A quién afectará NIS2</h2>
<p>La directiva distingue entre <strong>entidades esenciales</strong> e <strong>importantes</strong>, según el sector y el tamaño. Como regla general entran las medianas y grandes empresas (a partir de 50 empleados o 10 millones de euros de facturación) de sectores como energía, transporte, banca, sanidad, agua, infraestructura digital, gestión de servicios TIC, administración pública, servicios postales, gestión de residuos, química, alimentación, fabricación de ciertos productos y proveedores digitales. Algunas entidades entran sea cual sea su tamaño, como los proveedores de DNS o de servicios de confianza.</p>
<p>Lo que más se pasa por alto: aunque tu empresa no entre, si eres proveedor de una que sí, te van a llegar requisitos por contrato. NIS2 obliga a las entidades a gestionar la seguridad de su cadena de suministro.</p>
<h2>Qué exige</h2>
<p>El artículo 21 de la directiva enumera las medidas mínimas de gestión de riesgos. Las que más trabajo dan en la práctica:</p>
<ul>
  <li>Análisis de riesgos y políticas de seguridad de los sistemas de información.</li>
  <li>Gestión de incidentes, continuidad de negocio y copias de seguridad.</li>
  <li>Seguridad de la cadena de suministro.</li>
  <li>Gestión de vulnerabilidades, incluida su divulgación.</li>
  <li>Autenticación multifactor, control de accesos y gestión de activos.</li>
  <li>Cifrado, formación y ciberhigiene básica.</li>
</ul>
<p>Y la parte con plazos: ante un incidente significativo, una <strong>alerta temprana en 24 horas</strong>, una notificación en <strong>72 horas</strong> y un informe final en <strong>un mes</strong>. La directiva hace además responsables a los órganos de dirección: tienen que aprobar las medidas y formarse.</p>
<h2>Sanciones</h2>
<p>Para entidades esenciales, hasta 10 millones de euros o el 2 % de la facturación mundial anual, lo que sea mayor. Para entidades importantes, hasta 7 millones o el 1,4 %. La cuantía concreta en España dependerá de la ley final.</p>
<h2>Qué conviene hacer sin esperar a la ley</h2>
<p>Casi todo lo que pide el artículo 21 es buena práctica que conviene tener igualmente, y la ley no va a cambiar la directiva en lo esencial:</p>
<ol>
  <li>Confirmar si tu organización, o tus clientes, entran en el ámbito por sector y tamaño.</li>
  <li>Tener un procedimiento de gestión de incidentes que permita cumplir el plazo de 24 horas: quién decide qué es significativo y quién notifica.</li>
  <li>Inventario de activos y de proveedores críticos.</li>
  <li>MFA y <a href="/blog/post/minimo-privilegio-en-microsoft-entra-id/">mínimo privilegio</a> en las cuentas con acceso a sistemas importantes. Es el punto que con menos esfuerzo más riesgo quita.</li>
  <li>Un proceso de <a href="/blog/post/priorizar-cves-sin-fiarse-solo-del-cvss/">gestión de vulnerabilidades</a> que priorice por explotación real y no solo por CVSS.</li>
</ol>
<h2>Preguntas frecuentes</h2>
<h3>¿NIS2 ya es obligatoria en España?</h3>
<p>La directiva está en vigor a nivel europeo, pero obliga a los Estados, no directamente a las empresas. En España las obligaciones concretas llegarán con la ley de transposición, que en octubre de 2026 aún no está publicada en el BOE. Hoy se aplica el Real Decreto-ley 12/2018.</p>
<h3>¿Mi pyme está afectada por NIS2?</h3>
<p>Las pequeñas empresas (menos de 50 empleados y menos de 10 millones de facturación) quedan fuera en general, salvo excepciones por actividad. Pero pueden recibir requisitos si son proveedoras de una entidad obligada.</p>
<h3>¿Qué diferencia hay entre NIS2 y el ENS?</h3>
<p>El ENS es la norma española de seguridad para el sector público y sus proveedores. NIS2 es una directiva europea para sectores críticos públicos y privados. Se solapan en muchas medidas, y estar certificado en ENS adelanta buena parte del trabajo.</p>',
  'nis2,normativa,cumplimiento,espana,gestion-de-riesgo,incidentes', 'normativa', 'es', 1, '2026-10-12 09:00:00', '2026-10-12 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'nis2-en-espana-estado-octubre-2026');

-- Ajustes del sitio. INSERT IGNORE: si ya existen, NO se tocan tus valores.
INSERT IGNORE INTO `settings` (`key`, `value`) VALUES
  ('open_to_work',      '1'),   -- badge "Disponible" del hero
  ('contact_enabled',   '1'),   -- formulario de contacto activo
  ('analytics_enabled', '1'),   -- registro de visitas activo
  ('announcement_on',   '0'),   -- banner superior activo
  ('announcement_es',   ''),    -- texto del banner en espanol
  ('announcement_en',   ''),    -- ... ingles
  -- Integracion GitHub Stats (server/admin/integrations.php,
  -- server/lib/github.php): antes vivian solo en config.php (no editable
  -- desde el panel sin FTP); token vacio por defecto a proposito, config.php
  -- se sigue leyendo como fallback si esto esta vacio (ver github_setting()
  -- en server/lib/github.php) para no romper nada durante la migracion.
  ('github_stats_token',              ''),
  ('github_stats_username',           'eduolihez'),
  ('github_stats_cache_ttl_minutes',  '360'),
  ('github_stats_exclude_repos',      'northgate-browser'),
  ('github_stats_custom_css',         ''),
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
