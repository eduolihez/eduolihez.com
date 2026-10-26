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

-- Proyectos: anadir llm-chatbot-pentest (2026-10-26). Herramienta open source
-- de red teaming autonomo de chatbots LLM (OWASP Top 10 para aplicaciones LLM,
-- juez LLM independiente, informe reproducible; solo uso autorizado). Mismo
-- patron idempotente que los bloques de arriba: solo actua sobre una tabla
-- que ya tiene datos y no duplica si el titulo ya existe.
INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `badges`,
   `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
SELECT 'llm-chatbot-pentest', 'llm-chatbot-pentest',
       'Red teaming autonomo de chatbots LLM: identifica el objetivo, genera payloads alineados con el OWASP Top 10 para aplicaciones LLM y los puntua con un modelo juez independiente. No se ejecuta sin autorizacion explicita y un alcance definido. CLI y panel web.',
       'Autonomous red teaming of LLM chatbots: fingerprints the target, generates payloads mapped to the OWASP Top 10 for LLM Applications and scores them with an independent judge model. Will not run without explicit authorization and a defined scope. CLI and web dashboard.',
       '["Python","OWASP LLM Top 10","PyRIT","Red Teaming"]', '["open-source"]',
       'https://github.com/eduolihez/llm-chatbot-pentest', NULL, NULL, 1, 14, 'published'
WHERE EXISTS (SELECT 1 FROM `projects`)
  AND NOT EXISTS (SELECT 1 FROM `projects` WHERE `title_es` = 'llm-chatbot-pentest');

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


-- ---------------------------------------------------------------------------
-- Blog: SEO local y catalan (2026-10-26).
--
--  1. Seis articulos nuevos en espanol, pensados para busquedas reales
--     ("que hace un analista SOC", "ciberseguridad pymes Barcelona", "he hecho
--     clic en un phishing", "ransomware 24 horas", "certificaciones SOC",
--     "auditar permisos Microsoft 365").
--  2. La version catalana de TODOS los articulos (los 23 existentes + los 6
--     nuevos = 29). Mismas fechas de publicacion que el original y slugs
--     propios en catalan. El mapa ES <-> CA que usa el hreflang de los
--     articulos vive en src/lib/postTranslations.ts: si anades o cambias un
--     slug aqui, actualiza ese fichero tambien (hay un test que lo vigila).
--
-- Mismo patron idempotente que los bloques de arriba: solo entran si su slug
-- no existe, asi que reimportar este archivo nunca los duplica.
-- ---------------------------------------------------------------------------

-- Articulos nuevos (es)

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Qué hace un analista SOC: un día de trabajo real y cómo empezar',
  'que-hace-un-analista-soc-un-dia-de-trabajo-real',
  'Qué hace un analista SOC en su día a día: revisar alertas, investigar, contener y documentar. Niveles N1 a N3, herramientas, habilidades y cómo entrar sin experiencia.',
  '<p>Un analista SOC (Security Operations Center) vigila los sistemas de una organización para detectar, investigar y contener incidentes de seguridad. En la práctica, su día consiste en revisar alertas, decidir cuáles son reales, investigar las que lo son y escalar o contener lo que haga falta. No es un puesto de "hackear": es un puesto de analizar, comparar y decidir con rapidez y con poca información.</p>
<h2>Cómo es un día normal</h2>
<ol>
  <li><strong>Traspaso.</strong> Se empieza leyendo qué dejó abierto el turno anterior: incidentes en curso, alertas pendientes de respuesta, cambios en la infraestructura.</li>
  <li><strong>Cola de alertas.</strong> Se abre la consola (en mi caso Trend Micro Vision One) y se ordena lo que ha saltado. El orden importa más que la velocidad: lo explico en <a href="/blog/post/triaje-de-alertas-en-un-soc-en-que-orden-mirar/">triaje de alertas en un SOC</a>.</li>
  <li><strong>Investigación.</strong> Para cada alerta real: qué activo y qué usuario, qué pasó antes y después, si el indicador aparece en fuentes de inteligencia, si esto ya se vio antes.</li>
  <li><strong>Contención y escalado.</strong> Aislar un equipo, deshabilitar una cuenta, bloquear un dominio, o pasar el caso al nivel siguiente con todo el contexto ya reunido.</li>
  <li><strong>Documentación.</strong> Cada decisión queda escrita en el ticket. Es la parte menos vistosa y la que más ahorra al día siguiente.</li>
  <li><strong>Mejora.</strong> Afinar reglas que generan ruido, revisar falsos positivos recurrentes y <a href="/blog/post/automatizar-el-informe-semanal-del-soc-con-python/">automatizar informes</a> que se repiten.</li>
</ol>
<h2>Los niveles de un SOC</h2>
<table>
  <thead><tr><th>Nivel</th><th>Qué hace</th></tr></thead>
  <tbody>
    <tr><td>N1</td><td>Triaje: revisa alertas, descarta falsos positivos, escala lo relevante.</td></tr>
    <tr><td>N2</td><td>Investigación y respuesta: analiza incidentes, contiene, coordina con otros equipos.</td></tr>
    <tr><td>N3</td><td>Caza de amenazas, análisis forense y de malware, ingeniería de detección.</td></tr>
  </tbody>
</table>
<p>Los nombres y los límites cambian de una empresa a otra, y en un SOC pequeño una misma persona hace de las tres cosas.</p>
<h2>Con qué herramientas se trabaja</h2>
<ul>
  <li><strong>EDR / XDR</strong> para ver el endpoint, el correo y la identidad. Qué aporta cada uno está en <a href="/blog/post/xdr-vs-siem-vs-edr-diferencias-en-un-soc/">XDR, SIEM y EDR</a>.</li>
  <li><strong>SIEM</strong> para centralizar logs y buscar en ellos.</li>
  <li><strong>Gestor de tickets</strong> para registrar cada caso.</li>
  <li><strong>Fuentes de inteligencia</strong> (VirusTotal, AbuseIPDB, el catálogo KEV de CISA) para saber si un indicador es conocido.</li>
  <li><strong>Consola de correo y de identidad</strong> (Microsoft 365, Entra ID) para investigar <a href="/blog/post/business-email-compromise-senales-en-microsoft-365/">fraudes de correo</a> y cuentas comprometidas.</li>
</ul>
<h2>Qué hay que saber para empezar</h2>
<ul>
  <li>Redes básicas: TCP/IP, DNS, HTTP, qué es normal en un tráfico.</li>
  <li>Windows y Active Directory: cómo se autentica un usuario y qué rastro deja.</li>
  <li>Leer logs sin asustarse, y saber qué preguntar a una línea rara.</li>
  <li>Algo de scripting (Python o PowerShell) para no repetir a mano lo que se puede automatizar.</li>
  <li>Escribir claro: un buen resumen de incidente vale tanto como una buena detección.</li>
</ul>
<p>Mucha gente llega desde soporte técnico o administración de sistemas, y es una buena ruta: entender la infraestructura real pesa más que cualquier curso. Lo cuento en <a href="/blog/post/de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto/">de soporte técnico a SOC</a>, y qué certificaciones ayudan en <a href="/blog/post/certificaciones-para-empezar-como-analista-soc/">certificaciones para empezar como analista SOC</a>.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué hace un analista SOC?</h3>
<p>Monitoriza alertas de seguridad, decide cuáles son incidentes reales, los investiga y los contiene o escala. Además documenta cada caso y ayuda a afinar las reglas de detección para reducir el ruido.</p>
<h3>¿Cuál es la diferencia entre un analista SOC y un pentester?</h3>
<p>El analista SOC defiende: detecta y responde a ataques reales sobre los sistemas de la organización. El pentester ataca de forma autorizada para encontrar debilidades antes que los atacantes. Son perfiles complementarios.</p>
<h3>¿Se puede entrar en un SOC sin experiencia previa?</h3>
<p>Sí, en puestos de nivel 1, sobre todo con base en sistemas o redes, alguna certificación y práctica en laboratorios. Los SOC suelen valorar más la curiosidad y la capacidad de explicar un razonamiento que el título.</p>
<h3>¿Hay que trabajar de noche?</h3>
<p>Depende del SOC. Los que dan servicio 24x7 trabajan por turnos; otros cubren solo horario de oficina y dejan la noche a un servicio externo (MDR).</p>',
  'soc,analista-soc,blue-team,carrera,xdr', 'blue-team-soc', 'es', 1, '2026-10-14 09:00:00', '2026-10-14 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'que-hace-un-analista-soc-un-dia-de-trabajo-real');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Ciberseguridad para pymes en Barcelona y Badalona: 10 medidas para aplicar este mes',
  'ciberseguridad-para-pymes-en-barcelona-diez-medidas',
  'Diez medidas de ciberseguridad para una pyme con herramientas que ya pagas: MFA, copias de seguridad, bajas de cuentas, DMARC y un procedimiento contra el fraude.',
  '<p>Una pyme no necesita un presupuesto de gran empresa para protegerse de lo que de verdad le pasa: correos de phishing, cuentas robadas, ransomware y fraudes de cambio de cuenta bancaria. Estas diez medidas cubren la mayor parte del riesgo habitual de una pequeña empresa en Barcelona, Badalona o cualquier otro sitio, casi todas se hacen con herramientas que ya pagas (Microsoft 365 o Google Workspace) y se pueden aplicar en un mes.</p>
<h2>Las diez medidas, por orden</h2>
<ol>
  <li><strong>MFA en todas las cuentas de correo y de administración.</strong> Es la medida que más riesgo quita por menos esfuerzo. Mejor si es <a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">resistente a phishing</a> al menos para administradores y finanzas.</li>
  <li><strong>Copias de seguridad que no estén a mano del atacante.</strong> Una copia en el mismo servidor o en una unidad de red siempre conectada se cifra con el resto. La regla 3-2-1: tres copias, dos soportes, una fuera. Y probar a restaurar de verdad, al menos una vez.</li>
  <li><strong>Actualizar sistemas y aplicaciones.</strong> Activa las actualizaciones automáticas y presta atención especial a todo lo que esté expuesto a internet (VPN, firewall, servidor de correo). Para decidir qué urge, <a href="/blog/post/priorizar-cves-sin-fiarse-solo-del-cvss/">no mires solo el CVSS</a>.</li>
  <li><strong>Un usuario para cada persona, y sin permisos de administrador en el día a día.</strong> Quien lee correo no debería ser administrador del dominio. Detalle en <a href="/blog/post/minimo-privilegio-en-microsoft-entra-id/">mínimo privilegio</a>.</li>
  <li><strong>Dar de baja las cuentas de quien se va, el mismo día.</strong> Es el fallo más repetido: <a href="/blog/post/joiner-mover-leaver-cuentas-huerfanas/">cuentas huérfanas</a> que nadie revisa.</li>
  <li><strong>Proteger el dominio de correo con SPF, DKIM y DMARC.</strong> Evita que alguien envíe correos en nombre de tu empresa. Cómo llegar a <a href="/blog/post/spf-dkim-dmarc-de-p-none-a-p-reject/">p=reject</a> sin perder correo legítimo.</li>
  <li><strong>Un procedimiento para cambios de cuenta bancaria.</strong> Cualquier cambio de IBAN se confirma por teléfono, al número que ya tenías. Es la defensa contra el <a href="/blog/post/business-email-compromise-senales-en-microsoft-365/">fraude BEC</a>.</li>
  <li><strong>Antivirus con EDR en todos los equipos</strong> y el firewall con la configuración revisada, no la de fábrica.</li>
  <li><strong>Formación breve y repetida.</strong> Quince minutos al trimestre con ejemplos reales de phishing sirven más que una charla anual. Y una norma clara: dudar y preguntar no es molestar.</li>
  <li><strong>Saber a quién llamar si pasa algo.</strong> Un contacto técnico, una persona con autoridad para tomar decisiones y el teléfono de ayuda de INCIBE (017). Mejor tenerlo escrito antes de necesitarlo.</li>
</ol>
<h2>Si solo tienes una tarde</h2>
<p>MFA en el correo, una copia de seguridad desconectada y la baja de las cuentas que ya no se usan. Con esas tres, el riesgo cae mucho.</p>
<h2>Normativa: qué te afecta</h2>
<p>Si tratas datos personales, el RGPD te obliga a notificar a la AEPD una brecha en un plazo máximo de 72 horas desde que la conoces, salvo que sea improbable que suponga riesgo para las personas. Si eres proveedor de una empresa grande o de un sector regulado, es probable que te lleguen requisitos por contrato; mira <a href="/blog/post/nis2-en-espana-estado-octubre-2026/">cómo está NIS2 en España</a>.</p>
<h2>Recursos públicos</h2>
<p>INCIBE ofrece información y una línea de ayuda gratuita (017) para empresas y ciudadanos, y en Cataluña la Agència de Ciberseguretat de Catalunya publica avisos y guías. Son un buen punto de partida antes de contratar nada.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Por dónde empieza la ciberseguridad de una pyme?</h3>
<p>Por el correo y las cuentas: MFA, bajas de usuarios y copias de seguridad fuera del alcance del atacante. Es donde se producen la mayoría de incidentes reales.</p>
<h3>¿Una pyme es objetivo de ataques?</h3>
<p>Sí. Los ataques masivos (phishing, ransomware) no eligen por tamaño, sino por lo fácil que sea entrar. Las pymes suelen tener menos defensas y por eso salen rentables.</p>
<h3>¿Necesito un SOC propio?</h3>
<p>Normalmente no. Una pyme puede contratar un servicio gestionado (MDR) que vigile alertas 24x7. Lo que sí necesita es tener las bases cubiertas y saber quién responde cuando salta una alerta.</p>',
  'pymes,barcelona,badalona,ciberseguridad,mfa,backup', 'blue-team-soc', 'es', 1, '2026-10-16 09:00:00', '2026-10-16 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'ciberseguridad-para-pymes-en-barcelona-diez-medidas');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'He hecho clic en un phishing: qué hacer ahora mismo',
  'he-hecho-clic-en-un-phishing-que-hacer-ahora',
  'Qué hacer en los primeros minutos tras hacer clic en un phishing, según lo que pasó: solo clic, contraseña introducida, fichero abierto o datos bancarios. Y qué evitar.',
  '<p>Si has hecho clic en un enlace de phishing, lo que hagas en los primeros minutos importa más que lo que ocurra después. Lo esencial: no hace falta entrar en pánico, pero sí actuar ya. Desconecta el equipo de la red si has descargado o abierto algo, cambia la contraseña de la cuenta afectada desde otro dispositivo, avisa a quien gestione la seguridad en tu empresa y no borres el correo, porque sirve como evidencia.</p>
<h2>Qué hacer según lo que ocurrió</h2>
<h3>Hice clic, pero no escribí nada</h3>
<p>Cierra la pestaña. Si el navegador descargó un fichero, no lo abras y bórralo. Pasa un análisis con el antivirus. En muchos casos no ha pasado nada, pero avisa igualmente: otras personas pueden haber recibido el mismo correo.</p>
<h3>Escribí mi contraseña en la página falsa</h3>
<ol>
  <li>Cambia la contraseña ya, <strong>desde otro dispositivo</strong> si dudas del equipo.</li>
  <li>Cierra todas las sesiones abiertas de esa cuenta (en Microsoft 365: "Cerrar sesión en todas partes", o que el administrador revoque las sesiones). Cambiar la contraseña sin cerrar sesiones puede dejar al atacante dentro si ya tiene una sesión activa.</li>
  <li>Si usas esa contraseña en otros servicios, cámbiala también allí.</li>
  <li>Revisa los métodos de MFA registrados: el atacante puede haber añadido el suyo.</li>
  <li>Revisa reglas de bandeja de entrada y reenvíos: son lo primero que crean para esconderse. Qué buscar, en <a href="/blog/post/business-email-compromise-senales-en-microsoft-365/">señales de BEC en Microsoft 365</a>.</li>
</ol>
<h3>Descargué y abrí un fichero o instalé algo</h3>
<ol>
  <li><strong>Desconecta el equipo de la red</strong> (cable y Wi-Fi). No lo apagues si puedes evitarlo: apagarlo borra información útil para la investigación.</li>
  <li>Avisa al responsable de seguridad o a tu proveedor informático, y no sigas usando ese equipo.</li>
  <li>Cambia las contraseñas desde otro dispositivo, empezando por correo y banca.</li>
</ol>
<h3>Introduje datos de una tarjeta o bancarios</h3>
<p>Llama a tu banco ya, bloquea la tarjeta y pide que revisen los movimientos. Si hay un cargo no reconocido, denuncia ante la Policía o los Mossos d''Esquadra.</p>
<h2>Qué NO hacer</h2>
<ul>
  <li>No borres el correo ni lo reenvíes a compañeros: se reenvía como adjunto al equipo de seguridad.</li>
  <li>No te quedes callado por vergüenza. Un aviso rápido evita que otros caigan, y cualquier SOC prefiere veinte avisos falsos a un incidente tardío.</li>
  <li>No respondas al atacante.</li>
</ul>
<h2>Qué mira el equipo de seguridad después</h2>
<p>Revisa si el enlace se abrió desde más usuarios, si hubo un inicio de sesión sospechoso tras el clic, si se crearon reglas de bandeja o consentimientos OAuth, y si el equipo ejecutó algo raro. Con un EDR o XDR se ve la cadena completa; es lo que explico en <a href="/blog/post/xdr-vs-siem-vs-edr-diferencias-en-un-soc/">XDR, SIEM y EDR</a>.</p>
<p>Para que el próximo clic sea menos peligroso: <a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">MFA resistente a phishing</a>, que no cae aunque el usuario introduzca todo en la web falsa.</p>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué pasa si hago clic en un enlace de phishing?</h3>
<p>Depende de lo que haga la página: puede pedirte credenciales, descargar un fichero malicioso o solo registrar que el correo es real. Hacer clic sin más rara vez compromete el equipo, pero conviene avisar.</p>
<h3>¿Me pueden robar la cuenta aunque tenga MFA?</h3>
<p>Sí, con phishing en tiempo real que roba también la sesión. Por eso conviene cerrar sesiones y revisar los métodos de MFA, y usar métodos resistentes a phishing.</p>
<h3>¿A quién aviso?</h3>
<p>En una empresa, al equipo de seguridad o de informática. Si eres particular y hay fraude económico, a tu banco y a la policía. INCIBE tiene una línea gratuita de ayuda: 017.</p>',
  'phishing,respuesta-a-incidentes,guia-rapida,mfa,microsoft-365', 'blue-team-soc', 'es', 1, '2026-10-19 09:00:00', '2026-10-19 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'he-hecho-clic-en-un-phishing-que-hacer-ahora');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Ransomware: qué hacer en las primeras 24 horas',
  'ransomware-que-hacer-en-las-primeras-24-horas',
  'Orden de actuación ante un ransomware: aislar, cortar el acceso, proteger las copias, preservar evidencias, notificar a la AEPD en 72 horas y recuperar desde copias limpias.',
  '<p>Ante un ransomware, las primeras 24 horas deciden cuánto daño se produce. El orden de actuación: aislar los equipos afectados para frenar la propagación, activar el plan de respuesta y avisar a las personas que toman decisiones, preservar evidencias, evaluar el alcance, y solo después pensar en recuperar. Y casi nunca pagar: no garantiza recuperar los datos y las autoridades lo desaconsejan.</p>
<h2>Primera hora: contener</h2>
<ol>
  <li><strong>Aísla, no apagues.</strong> Desconecta de la red (cable, Wi-Fi, VPN) los equipos con síntomas: ficheros con extensiones raras, notas de rescate, equipos lentos. Apagarlos puede destruir información en memoria útil para la investigación; si el aislamiento no es posible, entonces sí, apagar es mejor que dejar que siga cifrando.</li>
  <li><strong>Corta el acceso del atacante.</strong> Deshabilita las cuentas comprometidas (empezando por las privilegiadas), revoca sesiones y bloquea accesos remotos (RDP, VPN) sospechosos. Si el atacante tiene credenciales de administrador de dominio, asume que toda la red está comprometida.</li>
  <li><strong>Protege las copias de seguridad.</strong> Desconecta las copias del resto de la red antes de que el ransomware las cifre o las borre. Los atacantes las buscan expresamente.</li>
  <li><strong>Reúne al equipo de crisis.</strong> Técnicos, dirección, quien lleve comunicación y asesoría legal. Una persona decide, otra documenta cada acción con hora.</li>
</ol>
<h2>Primeras horas: entender</h2>
<ul>
  <li><strong>Preserva evidencias.</strong> Notas de rescate, listas de ficheros afectados, logs del firewall y del controlador de dominio, muestras del ejecutable. No reinstales equipos todavía.</li>
  <li><strong>Averigua el vector de entrada</strong> antes de restaurar: un acceso remoto expuesto, una cuenta robada por phishing, una vulnerabilidad sin parchear. Si no se cierra, el atacante vuelve.</li>
  <li><strong>Evalúa qué datos se han exfiltrado.</strong> Hoy lo habitual es la doble extorsión: cifran y además roban datos para amenazar con publicarlos.</li>
</ul>
<h2>Avisos y obligaciones</h2>
<ul>
  <li>Si hay datos personales afectados, el RGPD obliga a notificar la brecha a la AEPD en un máximo de 72 horas desde que la conoces, salvo que sea improbable que suponga un riesgo para las personas.</li>
  <li>Si tu empresa entra en el ámbito de NIS2 o de la normativa sectorial, hay plazos de notificación específicos (consulta <a href="/blog/post/nis2-en-espana-estado-octubre-2026/">dónde está NIS2 en España</a>).</li>
  <li>Denuncia a la Policía Nacional, la Guardia Civil o los Mossos d''Esquadra, e informa a INCIBE-CERT. También avisa a tu aseguradora si tienes ciberseguro: algunas pólizas exigen avisar en plazo.</li>
</ul>
<h2>Recuperación</h2>
<ol>
  <li>Restaura desde copias <strong>limpias</strong>, comprobando que la copia es anterior a la intrusión.</li>
  <li>Reconstruye los sistemas críticos desde imagen limpia en lugar de limpiar a mano el que estaba comprometido.</li>
  <li>Cambia todas las credenciales, especialmente las de cuentas de servicio y administración, y revisa <a href="/blog/post/joiner-mover-leaver-cuentas-huerfanas/">cuentas huérfanas</a> y accesos que no deberían existir.</li>
  <li>Reconecta por fases, con monitorización reforzada.</li>
</ol>
<h2>¿Pagar el rescate?</h2>
<p>Las autoridades lo desaconsejan: no hay garantía de recibir una clave que funcione, financia a los atacantes y te marca como pagador. Es una decisión de la dirección con asesoramiento legal y, si se contempla, con una empresa especializada. Tener copias fuera de línea es lo que evita llegar a plantearse la pregunta.</p>
<h2>Lo que evita llegar aquí</h2>
<ul>
  <li><a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">MFA</a> en todos los accesos remotos y cuentas de administración.</li>
  <li>Copias de seguridad desconectadas y probadas.</li>
  <li><a href="/blog/post/errores-de-configuracion-cloud-mas-comunes/">Sin puertos de administración expuestos a internet</a> y con parches al día.</li>
  <li>Un EDR o <a href="/blog/post/xdr-vs-siem-vs-edr-diferencias-en-un-soc/">XDR</a> vigilado, con alguien que responda a la alerta.</li>
</ul>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué es el ransomware?</h3>
<p>Un malware que cifra los ficheros de una organización y exige un pago a cambio de la clave para recuperarlos. Cada vez más, también roba los datos antes de cifrar para presionar con su publicación.</p>
<h3>¿Se pueden recuperar los ficheros sin pagar?</h3>
<p>A veces. Con copias limpias, sí. En algunos casos existen descifradores gratuitos para ciertas familias; el proyecto No More Ransom reúne los disponibles.</p>
<h3>¿Hay que apagar el ordenador infectado?</h3>
<p>Lo preferible es aislarlo de la red sin apagarlo, para conservar evidencias. Si no puedes aislarlo y sigue cifrando, apágalo.</p>',
  'ransomware,respuesta-a-incidentes,backup,rgpd,incidentes', 'blue-team-soc', 'es', 1, '2026-10-21 09:00:00', '2026-10-21 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'ransomware-que-hacer-en-las-primeras-24-horas');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Certificaciones para empezar como analista SOC: cuáles valen la pena',
  'certificaciones-para-empezar-como-analista-soc',
  'Security+, SC-200, CySA+ y BTL1: qué aporta cada certificación para un primer puesto en un SOC, cuáles dejar para después y qué pesa más que cualquier título.',
  '<p>Para empezar como analista SOC no hay una certificación obligatoria, pero algunas ayudan a pasar el primer filtro y a ordenar lo que hay que aprender. Las más habituales en ofertas de nivel 1 son CompTIA Security+, Microsoft SC-200, CompTIA CySA+ y Blue Team Level 1 (BTL1). Pesan mucho menos que demostrar que sabes investigar una alerta, así que lo ideal es combinar una certificación con práctica real en laboratorios.</p>
<h2>Las certificaciones más útiles para empezar</h2>
<table>
  <thead><tr><th>Certificación</th><th>Para quién</th><th>Qué aporta</th></tr></thead>
  <tbody>
    <tr><td>CompTIA Security+</td><td>Punto de partida general</td><td>Base amplia: amenazas, controles, riesgo, criptografía. Muy reconocida en ofertas.</td></tr>
    <tr><td>Microsoft SC-200 (Security Operations Analyst)</td><td>Entornos Microsoft</td><td>Defender XDR, Sentinel y KQL: muy práctica si el SOC usa Microsoft.</td></tr>
    <tr><td>CompTIA CySA+</td><td>Ya con base de seguridad</td><td>Análisis de amenazas, logs y respuesta a incidentes, orientada a SOC.</td></tr>
    <tr><td>Blue Team Level 1 (BTL1)</td><td>Quien quiere práctica</td><td>Examen práctico de 24 horas sobre phishing, DFIR, inteligencia y SIEM.</td></tr>
    <tr><td>Certificaciones de fabricante (Trend Micro, Fortinet, Splunk...)</td><td>Según la herramienta del SOC</td><td>Demuestran manejo de la plataforma concreta que usarás.</td></tr>
  </tbody>
</table>
<p>Las certificaciones de fabricante pesan según el puesto: si el SOC trabaja con esa herramienta, son de las que más se notan.</p>
<h2>Las que dejaría para más adelante</h2>
<p>Las certificaciones de alto nivel (GIAC como GCIH o GCFA, o similares) son caras y se valoran más cuando ya hay experiencia. Merecen la pena cuando tu empresa las financia o cuando ya sabes en qué especialidad quieres crecer: respuesta a incidentes, forense o inteligencia.</p>
<h2>Lo que pesa más que cualquier título</h2>
<ul>
  <li><strong>Práctica en laboratorios.</strong> Plataformas como TryHackMe, LetsDefend o Blue Team Labs Online permiten simular alertas reales de un SOC. Un perfil con casos resueltos vale más que una lista de cursos.</li>
  <li><strong>Algo propio que enseñar.</strong> Un script que automatice una tarea, un análisis publicado, una herramienta pequeña. Por ejemplo, <a href="/blog/post/automatizar-el-informe-semanal-del-soc-con-python/">automatizar un informe</a> o <a href="/blog/post/vigilar-el-catalogo-kev-de-cisa-sin-servidor/">vigilar el catálogo KEV</a> demuestran criterio, no solo teoría.</li>
  <li><strong>Base de sistemas y redes.</strong> Muchos buenos analistas vienen de soporte o administración: <a href="/blog/post/de-soporte-tecnico-a-soc-lo-que-cambio-no-fue-el-puesto/">ese camino funciona</a>.</li>
  <li><strong>Saber explicar.</strong> En una entrevista, contar cómo investigarías una alerta paso a paso pesa más que recitar siglas. Si no sabes cómo funciona un día de trabajo, empieza por <a href="/blog/post/que-hace-un-analista-soc-un-dia-de-trabajo-real/">qué hace un analista SOC</a>.</li>
</ul>
<h2>Una ruta razonable</h2>
<ol>
  <li>Base de redes, Windows y Linux, y Active Directory.</li>
  <li>Security+ si necesitas el sello; si ya tienes base, ve directo a SC-200 o BTL1.</li>
  <li>Prácticas en laboratorios mientras estudias, y documenta lo que haces.</li>
  <li>Certificación de la herramienta concreta del SOC al que aspiras.</li>
  <li>Una especialidad (IAM, cloud, respuesta a incidentes) cuando ya tengas experiencia.</li>
</ol>
<h2>Preguntas frecuentes</h2>
<h3>¿Qué certificación pide más un SOC de nivel 1?</h3>
<p>Security+ es la que más aparece como requisito general; SC-200 y las de fabricante pesan cuando el SOC usa esas herramientas.</p>
<h3>¿Hace falta carrera universitaria?</h3>
<p>No siempre. Muchos SOC valoran experiencia, certificaciones y práctica por encima del título, aunque algunos puestos lo piden.</p>
<h3>¿Cuánto cuestan?</h3>
<p>Varían mucho y cambian cada año: conviene consultar el precio actual en la web del organismo. Algunas empresas financian la formación, y los exámenes de fabricante a veces son gratuitos o están incluidos en programas de partners.</p>',
  'certificaciones,soc,carrera,security-plus,sc-200', 'carrera-personal', 'es', 1, '2026-10-23 09:00:00', '2026-10-23 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'certificaciones-para-empezar-como-analista-soc');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Auditar los permisos de Microsoft 365 en una tarde',
  'auditar-permisos-de-microsoft-365-en-una-tarde',
  'Auditoría básica de permisos de Microsoft 365 en unas horas: administradores, MFA, cuentas sin uso, consentimientos OAuth y reenvíos, con PowerShell de solo lectura.',
  '<p>Se puede hacer una auditoría básica de permisos de Microsoft 365 en una tarde si se limita a lo que más riesgo concentra: administradores, invitados externos, cuentas sin MFA o sin uso, aplicaciones con consentimiento y reenvíos de correo. No sustituye a una auditoría completa, pero encuentra los fallos que usan los atacantes y que casi siempre se acumulan sin que nadie los mire.</p>
<p>Necesitas un rol de lectura (Global Reader o Security Reader) y el módulo de PowerShell de Microsoft Graph. Todo lo que sigue es de solo lectura.</p>
<h2>1. Administradores (30 minutos)</h2>
<p>Lista quién tiene roles privilegiados y por qué. Más de cinco administradores globales ya es una señal de alerta, y cada uno debería poder justificarse. El detalle de qué roles usar en su lugar está en <a href="/blog/post/minimo-privilegio-en-microsoft-entra-id/">mínimo privilegio en Entra ID</a>.</p>
<pre><code>Connect-MgGraph -Scopes "RoleManagement.Read.Directory","User.Read.All"
Get-MgDirectoryRole -All | ForEach-Object {
  $rol = $_.DisplayName
  Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id |
    ForEach-Object { [pscustomobject]@{ Rol = $rol; Usuario = $_.AdditionalProperties.userPrincipalName } }
}</code></pre>
<h2>2. MFA (30 minutos)</h2>
<p>El informe de registro de métodos de autenticación muestra quién no tiene MFA y quién usa métodos débiles.</p>
<pre><code>Connect-MgGraph -Scopes "AuditLog.Read.All"
Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Where-Object { -not $_.IsMfaRegistered } |
  Select-Object UserPrincipalName, IsAdmin</code></pre>
<p>Primero los administradores sin MFA, después finanzas y dirección. Para qué métodos exigir, mira <a href="/blog/post/mfa-resistente-a-phishing-por-que-el-sms-ya-no-basta/">MFA resistente a phishing</a>.</p>
<h2>3. Cuentas sin uso e invitados (30 minutos)</h2>
<pre><code>Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All"
Get-MgUser -All -Property DisplayName,UserPrincipalName,UserType,SignInActivity,AccountEnabled |
  Where-Object { $_.AccountEnabled -and $_.SignInActivity.LastSignInDateTime -lt (Get-Date).AddDays(-90) } |
  Select-Object UserPrincipalName, UserType, @{n=''UltimoAcceso'';e={$_.SignInActivity.LastSignInDateTime}}</code></pre>
<p>Cuenta habilitada sin acceso en 90 días: pregunta a su responsable. Los invitados externos (<code>UserType = Guest</code>) merecen revisión aparte: ¿siguen colaborando? ¿a qué equipos tienen acceso? Este mismo problema, en versión de ciclo de vida, es el de <a href="/blog/post/joiner-mover-leaver-cuentas-huerfanas/">las cuentas huérfanas</a>. Ten en cuenta que <code>SignInActivity</code> requiere licencia Entra ID P1.</p>
<h2>4. Aplicaciones con consentimiento (30 minutos)</h2>
<p>Las aplicaciones OAuth con permisos como <code>Mail.Read</code> o <code>Files.Read.All</code> siguen teniendo acceso aunque cambies la contraseña.</p>
<pre><code>Connect-MgGraph -Scopes "Directory.Read.All"
Get-MgOauth2PermissionGrant -All |
  Select-Object ClientId, ConsentType, Scope</code></pre>
<p>Busca aplicaciones desconocidas con permisos amplios y consentimiento de usuario. Revoca lo que nadie reconozca y restringe quién puede dar consentimiento.</p>
<h2>5. Reenvíos de correo (20 minutos)</h2>
<pre><code>Connect-ExchangeOnline
Get-Mailbox -ResultSize Unlimited |
  Where-Object { $_.ForwardingSmtpAddress -or $_.ForwardingAddress } |
  Select-Object UserPrincipalName, ForwardingSmtpAddress, ForwardingAddress</code></pre>
<p>Un reenvío a una dirección externa que nadie recuerda crear es una de las señales de <a href="/blog/post/business-email-compromise-senales-en-microsoft-365/">BEC</a>. Revisa también las reglas de bandeja que reenvían o mueven correo.</p>
<h2>6. Políticas de acceso (20 minutos)</h2>
<p>Comprueba que existen las políticas base y que ninguna cuenta está excluida sin motivo. Lista y orden en <a href="/blog/post/acceso-condicional-microsoft-365-politicas-base/">acceso condicional: las políticas base</a>. Mira también la puntuación de seguridad (Secure Score) en el portal de Defender, que sirve como lista de tareas priorizada.</p>
<h2>Qué hacer con lo que encuentres</h2>
<ol>
  <li>Anota cada hallazgo con responsable y fecha, en una hoja.</li>
  <li>Arregla primero lo que sea de riesgo alto y esfuerzo bajo: MFA a administradores, bajas de cuentas, reenvíos desconocidos.</li>
  <li>Repite cada trimestre. La utilidad de una auditoría está en la comparación entre fechas.</li>
</ol>
<h2>Preguntas frecuentes</h2>
<h3>¿Cada cuánto conviene revisar los permisos?</h3>
<p>Como mínimo cada trimestre, y siempre tras cambios grandes (fusiones, salidas de personal clave, migraciones).</p>
<h3>¿Necesito licencias especiales?</h3>
<p>Para lo básico no. La actividad de inicio de sesión requiere Entra ID P1, y las revisiones de acceso automáticas, Entra ID Governance.</p>
<h3>¿Es seguro ejecutar estos comandos?</h3>
<p>Son de solo lectura y no modifican nada, pero pruébalos primero con una cuenta de lectura y revisa el alcance de los permisos que concedes a Graph.</p>',
  'microsoft-365,entra-id,auditoria,powershell,iam', 'cloud-iam', 'es', 1, '2026-10-25 09:00:00', '2026-10-25 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'auditar-permisos-de-microsoft-365-en-una-tarde');

-- Version catalana de todos los articulos (ca)

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'NIS2 a Espanya: què se sap a l''octubre de 2026',
  'nis2-a-espanya-estat-octubre-2026',
  'NIS2 s''havia de transposar l''octubre de 2024 i Espanya continua sense llei al BOE. Què és en vigor avui, què exigirà a les empreses i què fer ja.',
  '<p>La directiva europea NIS2 (Directiva (UE) 2022/2555) amplia les obligacions de ciberseguretat a molts més sectors i empreses que la NIS original, i endureix les sancions. Els estats membres l''havien de transposar abans del 17 d''octubre de 2024. En la data d''aquest article, octubre de 2026, Espanya no ha publicat al BOE la llei que la transposa, la futura Ley de Coordinación y Gobernanza de la Ciberseguridad.</p>
<h2>On és la llei espanyola</h2>
<ul>
  <li><strong>14 de gener de 2025:</strong> el Consell de Ministres aprova l''avantprojecte i el tramita per la via d''urgència.</li>
  <li><strong>Maig de 2025:</strong> la Comissió Europea envia a Espanya un dictamen motivat per no haver notificat la transposició.</li>
  <li><strong>Juliol de 2026:</strong> la Comissió porta Espanya davant el Tribunal de Justícia de la UE pel mateix motiu.</li>
</ul>
<p>Mentrestant continuen en vigor el Real Decreto-ley 12/2018 i el seu reglament, el Real Decreto 43/2021, que transposen la NIS anterior i només obliguen operadors de serveis essencials i proveïdors de serveis digitals. Si treballes amb l''Administració, també s''aplica l''Esquema Nacional de Seguridad (ENS).</p>
<p>Convé comprovar l''estat al <a href="https://www.boe.es/">BOE</a> abans de prendre decisions: aquest article descriu la situació en una data concreta.</p>
<h2>A qui afectarà NIS2</h2>
<p>La directiva distingeix entre <strong>entitats essencials</strong> i <strong>importants</strong>, segons el sector i la mida. Com a regla general hi entren les mitjanes i grans empreses (a partir de 50 empleats o 10 milions d''euros de facturació) de sectors com energia, transport, banca, sanitat, aigua, infraestructura digital, gestió de serveis TIC, administració pública, serveis postals, gestió de residus, química, alimentació, fabricació de certs productes i proveïdors digitals. Algunes entitats hi entren sigui quina sigui la seva mida, com els proveïdors de DNS o de serveis de confiança.</p>
<p>El que més es passa per alt: encara que la teva empresa no hi entri, si ets proveïdor d''una que sí, et arribaran requisits per contracte. NIS2 obliga les entitats a gestionar la seguretat de la seva cadena de subministrament.</p>
<h2>Què exigeix</h2>
<p>L''article 21 de la directiva enumera les mesures mínimes de gestió de riscos. Les que donen més feina a la pràctica:</p>
<ul>
  <li>Anàlisi de riscos i polítiques de seguretat dels sistemes d''informació.</li>
  <li>Gestió d''incidents, continuïtat de negoci i còpies de seguretat.</li>
  <li>Seguretat de la cadena de subministrament.</li>
  <li>Gestió de vulnerabilitats, inclosa la seva divulgació.</li>
  <li>Autenticació multifactor, control d''accessos i gestió d''actius.</li>
  <li>Xifratge, formació i ciberhigiene bàsica.</li>
</ul>
<p>I la part amb terminis: davant d''un incident significatiu, una <strong>alerta primerenca en 24 hores</strong>, una notificació en <strong>72 hores</strong> i un informe final en <strong>un mes</strong>. La directiva fa a més responsables els òrgans de direcció: han d''aprovar les mesures i formar-se.</p>
<h2>Sancions</h2>
<p>Per a entitats essencials, fins a 10 milions d''euros o el 2 % de la facturació mundial anual, el que sigui més gran. Per a entitats importants, fins a 7 milions o l''1,4 %. La quantia concreta a Espanya dependrà de la llei final.</p>
<h2>Què convé fer sense esperar la llei</h2>
<p>Quasi tot el que demana l''article 21 és bona pràctica que convé tenir igualment, i la llei no canviarà la directiva en l''essencial:</p>
<ol>
  <li>Confirmar si la teva organització, o els teus clients, entren en l''àmbit per sector i mida.</li>
  <li>Tenir un procediment de gestió d''incidents que permeti complir el termini de 24 hores: qui decideix què és significatiu i qui notifica.</li>
  <li>Inventari d''actius i de proveïdors crítics.</li>
  <li>MFA i <a href="/ca/blog/post/minim-privilegi-a-microsoft-entra-id/">mínim privilegi</a> en els comptes amb accés a sistemes importants. És el punt que amb menys esforç treu més risc.</li>
  <li>Un procés de <a href="/ca/blog/post/prioritzar-cve-sense-refiar-se-nomes-del-cvss/">gestió de vulnerabilitats</a> que prioritzi per explotació real i no només per CVSS.</li>
</ol>
<h2>Preguntes freqüents</h2>
<h3>NIS2 ja és obligatòria a Espanya?</h3>
<p>La directiva és en vigor a nivell europeu, però obliga els estats, no directament les empreses. A Espanya les obligacions concretes arribaran amb la llei de transposició, que l''octubre de 2026 encara no és publicada al BOE. Avui s''aplica el Real Decreto-ley 12/2018.</p>
<h3>La meva pime està afectada per NIS2?</h3>
<p>Les petites empreses (menys de 50 empleats i menys de 10 milions de facturació) en general en queden fora, tret d''excepcions per activitat. Però poden rebre requisits si són proveïdores d''una entitat obligada.</p>
<h3>Quina diferència hi ha entre NIS2 i l''ENS?</h3>
<p>L''ENS és la norma espanyola de seguretat per al sector públic i els seus proveïdors. NIS2 és una directiva europea per a sectors crítics públics i privats. Es solapen en moltes mesures, i estar certificat en ENS avança bona part de la feina.</p>',
  'nis2,normativa,cumplimiento,espana,gestion-de-riesgo,incidentes', 'normativa', 'ca', 1, '2026-10-12 09:00:00', '2026-10-12 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'nis2-a-espanya-estat-octubre-2026');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Comptes òrfenes: la fallada del cicle joiner-mover-leaver',
  'joiner-mover-leaver-comptes-orfes',
  'Comptes actives de gent que ja ha marxat i permisos que s''acumulen en canviar de lloc. Què és el cicle joiner-mover-leaver, on falla i com revisar-lo.',
  '<p>El cicle joiner-mover-leaver (JML) és el procés de gestió d''identitats que cobreix tres moments: quan algú entra a l''organització (joiner), quan canvia de lloc (mover) i quan se''n va (leaver). Les comptes òrfenes, actives però sense cap persona al darrere que les necessiti, apareixen quasi sempre per una fallada en el tercer. I l''acumulació de permisos, per una fallada en el segon.</p>
<p>Des del <a href="/ca/blog/post/de-suport-tecnic-a-soc-el-que-va-canviar-no-va-ser-el-lloc/">suport tècnic</a> es veu molt clar que l''alta és la part que sempre funciona: la persona nova arriba, necessita entrar i algú es queixa si no pot. La baixa no la reclama ningú.</p>
<h2>Joiner: l''alta</h2>
<p>El risc en l''alta és donar massa des del primer dia, normalment copiant els permisos d''«algú que fa el mateix». Aquest algú porta cinc anys acumulant accessos. El correcte és assignar per rol: grups que representen un lloc de treball, amb els seus permisos definits, en lloc de permisos individuals copiats.</p>
<p>La contrasenya inicial també importa: generada, d''un sol ús i amb registre d''MFA obligatori en el primer inici de sessió. Una contrasenya inicial estàndard del tipus «Empresa2026!» és una de les primeres coses que prova un atacant amb password spraying.</p>
<h2>Mover: el canvi de lloc</h2>
<p>És la fase que menys es gestiona i la que produeix l''<em>acumulació de privilegis</em>: algú passa de finances a comercial i s''emporta els accessos nous sense perdre els antics. Després de tres canvis de lloc, aquesta compte té accés a mig negoci, i és justament la que interessa comprometre.</p>
<p>La regla sana: un canvi de lloc és una baixa dels permisos del lloc anterior més una alta al nou, amb un període de transició fixat si cal, no una suma.</p>
<h2>Leaver: la baixa</h2>
<p>Una compte d''algú que ha marxat és perillosa per dos motius: ningú notarà si algú la fa servir, i la seva contrasenya pot estar en alguna filtració antiga. El que hauria de passar l''últim dia, o abans si la sortida no és amistosa:</p>
<ol>
  <li>Deshabilitar la compte i <strong>revocar les sessions actives</strong>. Deshabilitar sense revocar deixa vius durant un temps els tokens ja emesos.</li>
  <li>Treure els mètodes d''MFA i els dispositius registrats.</li>
  <li>Convertir la bústia en compartida o delegar-la si cal, en lloc de mantenir la compte activa «per veure el correu».</li>
  <li>Revisar el que no passa pel directori: comptes locals en aplicacions SaaS sense SSO, claus d''API que va crear, accessos a proveïdors, <a href="/ca/blog/post/secrets-en-repositoris-com-es-filtren-i-com-evitar-ho/">secrets que coneixia</a>.</li>
  <li>Eliminar la compte passat el període de retenció definit.</li>
</ol>
<p>El punt 4 és el que falla més. L''SSO ajuda molt aquí: si totes les aplicacions autentiquen contra Entra ID o el directori corporatiu, deshabilitar una compte talla l''accés a totes.</p>
<h2>Com trobar les comptes òrfenes que ja existeixen</h2>
<p>A Active Directory, comptes habilitades sense inici de sessió en 90 dies:</p>
<pre><code>Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly |
  Where-Object { $_.Enabled } |
  Select-Object Name, SamAccountName, LastLogonDate</code></pre>
<p>I el creuament més útil: exportar la llista d''usuaris actius del directori i comparar-la amb la d''empleats actuals de recursos humans. El que sigui a la primera i no a la segona necessita una explicació. Si l''explicació és «és una compte de servei», que tingui un responsable amb nom i cognoms.</p>
<h2>Revisions d''accés periòdiques</h2>
<p>Les revisions d''accés (access reviews) demanen a cada responsable que confirmi, cada cert temps, que el seu equip continua necessitant els accessos que té. Entra ID Governance les automatitza i pot retirar l''accés si ningú respon. Sense aquesta eina, un full de càlcul trimestral amb els grups sensibles ja és una millora enorme. Per als rols d''administració, el mateix s''aplica amb més freqüència, com explico a <a href="/ca/blog/post/minim-privilegi-a-microsoft-entra-id/">mínim privilegi a Entra ID</a>.</p>
<h2>Preguntes freqüents</h2>
<h3>Què és una compte òrfena?</h3>
<p>Una compte activa que ja no correspon a cap persona o servei que la necessiti, normalment perquè el seu usuari va deixar l''organització o el servei es va retirar sense donar de baixa la identitat.</p>
<h3>Què significa joiner-mover-leaver?</h3>
<p>És el cicle de vida d''una identitat en una organització: alta en incorporar-se, ajust de permisos en canviar de lloc i baixa en marxar. És la base de qualsevol procés d''IAM.</p>
<h3>Deshabilitar o eliminar la compte quan algú se''n va?</h3>
<p>Deshabilitar el primer dia i eliminar després d''un període de retenció definit, per poder recuperar dades o investigar si cal.</p>',
  'iam,joiner-mover-leaver,active-directory,entra-id,gobierno-de-identidades', 'cloud-iam', 'ca', 1, '2026-10-09 09:00:00', '2026-10-09 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'joiner-mover-leaver-comptes-orfes');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Accés condicional a Microsoft 365: les polítiques base',
  'acces-condicional-microsoft-365-politiques-base',
  'Sis polítiques d''accés condicional d''Entra ID que cobreixen quasi tot el risc d''identitat a Microsoft 365, i com activar-les sense deixar ningú fora.',
  '<p>L''accés condicional de Microsoft Entra ID és un motor de regles del tipus «si es compleix això, exigeix allò»: si l''usuari és administrador, exigeix MFA resistent al phishing; si l''autenticació fa servir un protocol heretat, bloqueja-la; si el risc de l''inici de sessió és alt, demana MFA. Requereix llicència Entra ID P1, inclosa a Microsoft 365 Business Premium i E3. Sense ella, l''alternativa són els <em>security defaults</em>, que activen un MFA bàsic per a tothom però sense cap ajust.</p>
<p>Amb sis polítiques es cobreix la major part dels atacs d''identitat habituals. No ho cobreixen tot, però són el punt de partida raonable en qualsevol inquilí.</p>
<h2>Abans de crear-ne cap</h2>
<ul>
  <li><strong>Exclou els comptes d''emergència</strong> de totes les polítiques. Si una política mal configurada et deixa fora, són la manera de tornar a entrar. Ho explico a <a href="/ca/blog/post/minim-privilegi-a-microsoft-entra-id/">mínim privilegi a Entra ID</a>.</li>
  <li><strong>Crea cada política en mode «només informe»</strong> (report-only). Durant una o dues setmanes registra què hauria bloquejat sense bloquejar res. Revises l''impacte i després l''actives.</li>
</ul>
<h2>Les sis polítiques base</h2>
<h3>1. Bloquejar l''autenticació heretada</h3>
<p>Protocols com POP, IMAP, SMTP AUTH o ActiveSync amb autenticació bàsica no admeten MFA, així que són la via preferida del password spraying. Microsoft va desactivar l''autenticació bàsica a Exchange Online el 2022, però bloquejar-la a l''accés condicional tanca els buits que quedin.</p>
<h3>2. MFA resistent al phishing per a administradors</h3>
<p>Per a tots els rols privilegiats, amb l''<em>authentication strength</em> «Phishing-resistant MFA». Per què no val qualsevol MFA ho explico a <a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">MFA resistent al phishing</a>.</p>
<h3>3. MFA per a tots els usuaris</h3>
<p>En totes les aplicacions al núvol. Les excepcions, les mínimes, documentades i revisades.</p>
<h3>4. MFA per al registre de mètodes de seguretat</h3>
<p>Si un atacant entra amb la contrasenya d''un usuari que encara no tenia MFA, el primer que provarà és registrar el seu propi telèfon. Aquesta política exigeix estar en una ubicació de confiança o tenir ja un MFA per registrar mètodes nous.</p>
<h3>5. Bloquejar països on no operes</h3>
<p>No atura per si sola un atacant (una VPN se la salta), però elimina molt soroll d''intents automatitzats. Convé combinar-la amb un grup d''excepció per a viatges, amb data de caducitat.</p>
<h3>6. Polítiques basades en risc</h3>
<p>Amb Entra ID P2, Identity Protection calcula el risc de l''inici de sessió (IP anònima, credencials filtrades, viatge impossible) i de l''usuari. Exigeix MFA amb risc d''inici de sessió mitjà o alt, i canvi de contrasenya segur amb risc d''usuari alt.</p>
<h2>El pas següent: el dispositiu</h2>
<p>Amb les sis anteriors en marxa, la millora més gran és exigir dispositiu gestionat (compliant a Intune o unit a Entra) per accedir a dades sensibles. Així, encara que algú robi una sessió, no la pot fer servir des d''un equip que no controles. És el pas que més protegeix contra el robatori de tokens que acompanya quasi tot <a href="/ca/blog/post/business-email-compromise-senyals-a-microsoft-365/">BEC</a> actual.</p>
<h2>Com detectar si algú se les salta</h2>
<p>Als logs d''inici de sessió, cada esdeveniment indica quines polítiques s''han aplicat i amb quin resultat. Busca inicis de sessió correctes amb resultat «notApplied» en usuaris que haurien d''estar coberts: sol ser una exclusió oblidada. I alerta de qualsevol canvi a les polítiques mateixes; modificar una política d''accés condicional és una de les primeres coses que fa un atacant amb privilegis.</p>
<h2>Preguntes freqüents</h2>
<h3>Què és l''accés condicional?</h3>
<p>La funció de Microsoft Entra ID que decideix si permet, bloqueja o exigeix requisits addicionals (MFA, dispositiu gestionat) a cada inici de sessió segons l''usuari, l''aplicació, la ubicació, el dispositiu i el risc.</p>
<h3>Security defaults o accés condicional?</h3>
<p>Security defaults si no tens llicència P1: és gratis i molt millor que res. Accés condicional tan bon punt tinguis P1, perquè permet excepcions controlades i mètodes d''MFA forts. No es poden fer servir les dues alhora.</p>
<h3>Quant de temps deixar una política en mode només informe?</h3>
<p>El suficient perquè hi passin els patrons normals d''ús: com a mínim una setmana completa, millor dues si hi ha usuaris que viatgen o treballen per torns.</p>',
  'acceso-condicional,entra-id,microsoft-365,iam,mfa,zero-trust', 'cloud-iam', 'ca', 1, '2026-10-07 09:00:00', '2026-10-07 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'acces-condicional-microsoft-365-politiques-base');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Business Email Compromise: els senyals a Microsoft 365',
  'business-email-compromise-senyals-a-microsoft-365',
  'Un BEC quasi mai porta malware: porta un login estrany, una regla de safata oculta i un canvi de compte bancari. Què buscar als logs de Microsoft 365.',
  '<p>El Business Email Compromise (BEC) és un frau en què l''atacant es fa passar per algú de confiança, o directament fa servir la seva bústia compromesa, per aconseguir un pagament o dades. No sol dur adjunts maliciosos ni enllaços a malware, així que els filtres clàssics el deixen passar. Segons l''informe IC3 de l''FBI, el 2024 el BEC va causar pèrdues declarades de gairebé 2.800 milions de dòlars només als Estats Units, molt per sobre del ransomware.</p>
<p>Quan el BEC surt d''un compte real compromès, deixa rastre als logs de Microsoft 365. Aquests són els senyals que convé buscar.</p>
<h2>1. L''inici de sessió</h2>
<p>Quasi sempre comença amb credencials robades per phishing, i cada cop més amb un proxy AiTM que també roba la cookie de sessió i salta l''MFA tradicional. Als logs d''inici de sessió d''Entra ID:</p>
<ul>
  <li>IP d''un proveïdor d''hostatge o VPN comercial, no d''un ISP residencial ni de l''oficina.</li>
  <li>País o ciutat que no encaixa amb l''usuari, o «viatge impossible» respecte a l''inici de sessió anterior.</li>
  <li>Un user agent diferent de l''habitual de l''usuari, de vegades de llibreries com <code>python-requests</code> o <code>axios</code>.</li>
  <li>Un inici de sessió correcte just després que l''usuari fes clic en un enllaç d''un correu.</li>
</ul>
<h2>2. Les regles de la safata d''entrada</h2>
<p>És el senyal més fiable i el que menys falsos positius dona, perquè el primer que fa l''atacant és amagar-se: una regla que mou a «RSS» o «Arxiu» i marca com a llegit qualsevol correu que contingui «factura», «pagament», «transferència» o el nom del proveïdor que vol suplantar. Així la víctima no veu les respostes.</p>
<p>Al registre d''auditoria unificat, les operacions <code>New-InboxRule</code>, <code>Set-InboxRule</code> i <code>UpdateInboxRules</code>. Desconfia de regles amb noms d''un sol caràcter («.», «..», «a») o que mouen a carpetes que ningú fa servir.</p>
<h2>3. Reenviaments externs</h2>
<p>Un <code>Set-Mailbox</code> amb <code>ForwardingSmtpAddress</code> cap a una adreça externa, o una regla que reenvia còpia de tot. L''ideal és bloquejar el reenviament automàtic extern a la política antispam de sortida i crear excepcions només quan hi hagi un motiu.</p>
<h2>4. Aplicacions OAuth amb permisos de correu</h2>
<p>Una variant més persistent: l''atacant aconsegueix que l''usuari consenti una aplicació amb permisos com <code>Mail.Read</code> o <code>Mail.Send</code>. Encara que es canviï la contrasenya, l''app continua tenint accés. Revisa els consentiments recents a Entra ID i restringeix qui pot donar-los, com explico a l''article de <a href="/ca/blog/post/minim-privilegi-a-microsoft-entra-id/">mínim privilegi a Entra ID</a>.</p>
<h2>5. El frau en si</h2>
<p>El correu final: «hem canviat de banc, a partir d''ara els pagaments a aquest compte», amb un fil real de conversa al darrere i de vegades des d''un domini quasi idèntic al del proveïdor. Aquí la defensa ja no és tècnica: qualsevol canvi de dades bancàries es verifica per un canal diferent (una trucada al número que ja tenies, no al del correu).</p>
<h2>Resposta en l''ordre correcte</h2>
<ol>
  <li>Revocar les sessions de l''usuari (<code>Revoke-MgUserSignInSession</code>), no només canviar la contrasenya: la cookie robada continua valent.</li>
  <li>Restablir la contrasenya i revisar els mètodes d''MFA registrats, per si l''atacant hi ha afegit el seu.</li>
  <li>Eliminar regles de safata i reenviaments maliciosos.</li>
  <li>Revisar i revocar consentiments OAuth sospitosos.</li>
  <li>Buscar al registre d''auditoria quins correus es van llegir i enviar durant l''accés, i avisar els destinataris.</li>
</ol>
<p>Perquè no es repeteixi, el que més redueix el risc és l''<a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">MFA resistent al phishing</a> en els usuaris de finances i direcció, juntament amb <a href="/ca/blog/post/spf-dkim-i-dmarc-de-p-none-a-p-reject/">DMARC en p=reject</a> perquè ningú pugui suplantar el teu domini des de fora.</p>
<h2>Preguntes freqüents</h2>
<h3>Què és el BEC?</h3>
<p>Business Email Compromise: frau per correu en què l''atacant suplanta un directiu, un empleat o un proveïdor, o fa servir el seu compte compromès, per aconseguir transferències, canvis de compte bancari o informació sensible.</p>
<h3>Canviar la contrasenya n''hi ha prou per fer fora l''atacant?</h3>
<p>No. Cal revocar les sessions actives, revisar els mètodes d''MFA, les regles de safata i les aplicacions amb consentiment. Si no, l''atacant conserva l''accés.</p>
<h3>Com distingeixo un BEC d''un phishing normal?</h3>
<p>El phishing busca credencials o instal·lar malware de manera massiva. El BEC és dirigit, sol anar sense enllaços ni adjunts i busca diners directament, recolzant-se en una relació de confiança real.</p>',
  'bec,microsoft-365,email-security,respuesta-a-incidentes,fraude,soc', 'blue-team-soc', 'ca', 1, '2026-10-05 09:00:00', '2026-10-05 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'business-email-compromise-senyals-a-microsoft-365');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Secrets en repositoris: com es filtren i com evitar-ho',
  'secrets-en-repositoris-com-es-filtren-i-com-evitar-ho',
  'Una clau d''API pujada a GitHub s''explota en minuts i esborrar-la del commit no n''hi ha prou. Com es filtren, com aturar-los abans del push i què fer després.',
  '<p>Un secret (clau d''API, token, contrasenya de base de dades) pujat a un repositori públic cal donar-lo per compromès des del primer segon. Hi ha bots que llegeixen el flux de commits públics de GitHub en temps real buscant patrons de claus. I esborrar la línia al commit següent no arregla res: la clau continua a l''historial. L''única cosa que funciona és revocar-la i rotar-la.</p>
<p>GitGuardian, al seu informe <em>State of Secrets Sprawl</em> de 2025, va comptar més de 23 milions de secrets nous exposats en commits públics de GitHub durant el 2024. I no és només cosa de projectes personals: molts surten de repositoris d''empreses.</p>
<h2>Per on s''escapen</h2>
<ul>
  <li>El <code>.env</code> que no era al <code>.gitignore</code>, o que s''hi va afegir després d''haver-lo comès una vegada.</li>
  <li>La clau «temporal» al codi per provar alguna cosa ràpid, que s''hi queda.</li>
  <li>Fitxers de configuració d''exemple amb valors reals en lloc de marcadors.</li>
  <li>Logs i sortides de CI que imprimeixen variables d''entorn.</li>
  <li>Un repositori privat que es fa públic anys després, amb tot el seu historial.</li>
</ul>
<h2>Detectar-los abans del push</h2>
<p>El millor moment per trobar un secret és abans que surti de la teva màquina. Un hook de pre-commit amb <a href="https://github.com/gitleaks/gitleaks">gitleaks</a> revisa cada commit i el bloqueja si hi troba alguna cosa:</p>
<pre><code># .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks</code></pre>
<p>Al mateix GitHub, la <em>push protection</em> del secret scanning rebutja el push si detecta un patró d''un proveïdor conegut, i està activa per defecte als repositoris públics des del 2024. En aquest mateix portfolio hi ha un test de PHPUnit (<code>NoSecretsTest</code>) que recorre els fitxers versionats i falla si hi troba una clau d''API. Un hook local es pot saltar amb <code>--no-verify</code>; un test que corre a CI, no.</p>
<h2>Revisar l''historial que ja existeix</h2>
<p>Per a repositoris amb anys d''historial, gitleaks i <a href="https://github.com/trufflesecurity/trufflehog">TruffleHog</a> escanegen tots els commits. TruffleHog a més pot verificar si una clau trobada continua sent vàlida, cosa que ajuda a prioritzar.</p>
<pre><code>gitleaks detect --source . --log-opts="--all"</code></pre>
<h2>Si ja s''ha filtrat</h2>
<ol>
  <li><strong>Revocar i rotar primer.</strong> Abans que netejar l''historial. Cada minut compta.</li>
  <li><strong>Revisar els logs del servei</strong> afectat per veure si algú l''ha fet servir des que es va pujar. En una clau d''AWS, CloudTrail filtrant per aquell access key ID.</li>
  <li><strong>Netejar l''historial</strong> amb <code>git filter-repo</code> si el repositori és teu, sabent que qualsevol fork o clon anterior conserva la clau. Per això el pas 1 va primer.</li>
  <li><strong>Buscar la causa</strong> perquè no es repeteixi: faltava el <code>.gitignore</code>? No hi havia hook?</li>
</ol>
<h2>La solució de fons: que no hi hagi secrets per filtrar</h2>
<p>Com menys secrets estàtics existeixin, menys n''hi ha per protegir. Un gestor de secrets (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault) en lloc de fitxers, i a CI/CD federació OIDC en lloc de claus: GitHub Actions pot demanar credencials temporals a AWS o Azure sense guardar cap clau al repositori. I l''opció més segura continua sent no necessitar credencials: <a href="/ca/blog/post/vigilar-el-cataleg-kev-de-cisa-sense-servidor/">kev-digest</a> només llegeix un catàleg públic, així que corre a Actions sense cap secret de tercers per protegir.</p>
<h2>Preguntes freqüents</h2>
<h3>N''hi ha prou amb fer el repositori privat?</h3>
<p>No. Qualsevol persona amb accés al repositori, o qualsevol integració amb permisos de lectura, veu el secret. I si algú el va clonar mentre era públic, ja el té.</p>
<h3>Esborrar el commit elimina la clau?</h3>
<p>No de manera fiable. El commit pot continuar accessible pel seu hash, en forks, en caches i en clons. Cal revocar la clau sempre.</p>
<h3>Quina eina faig servir per començar?</h3>
<p>gitleaks com a hook de pre-commit i a CI, més push protection a GitHub. Les dues són gratuïtes.</p>',
  'secretos,git,github,devsecops,gitleaks,credenciales', 'vulnerabilidades', 'ca', 1, '2026-10-01 09:00:00', '2026-10-01 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'secrets-en-repositoris-com-es-filtren-i-com-evitar-ho');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Errors de configuració al cloud que més es repeteixen',
  'errors-de-configuracio-al-cloud-mes-repetits',
  'Quasi totes les bretxes al cloud vénen de la configuració del client: buckets públics, claus eternes, ports oberts i logs apagats. Què revisar primer.',
  '<p>La majoria de bretxes al cloud no exploten una fallada d''AWS, Azure o Google Cloud. Exploten alguna cosa que el client va configurar malament. És el que diu el <strong>model de responsabilitat compartida</strong>: el proveïdor respon de la seguretat <em>del</em> núvol (centres de dades, hipervisor, xarxa física) i tu de la seguretat <em>al</em> núvol (identitats, dades, configuració de cada servei). Gartner va arribar a predir que fins al 2025 el 99 % de les fallades de seguretat al cloud serien responsabilitat del client.</p>
<p>Aquesta és la llista curta que miraria primer en un compte cloud desconegut, ordenada pel mal que fa cada fallada.</p>
<h2>1. Emmagatzematge exposat a internet</h2>
<p>Buckets de S3, contenidors d''Azure Blob o buckets de GCS amb accés públic. És el clàssic de les filtracions de dades. AWS activa <em>Block Public Access</em> per defecte als buckets nous des de l''abril de 2023, però els antics continuen com estaven i qualsevol persona amb permisos el pot desactivar.</p>
<p>Què mirar: Block Public Access a nivell de <strong>compte</strong>, no només de bucket, i una alerta si algú el canvia.</p>
<h2>2. Claus d''accés de llarga durada</h2>
<p>Access keys d''IAM creades fa anys, assignades a un usuari que ja no és a l''empresa, amb permisos d''administrador i enganxades en algun script. És la credencial ideal per a un atacant: no caduca i no té MFA.</p>
<p>Què mirar: claus de més de 90 dies, claus sense ús recent, i si es poden substituir per rols amb credencials temporals. Quan una d''aquestes claus acaba en un repositori, el problema és el que explico a <a href="/ca/blog/post/secrets-en-repositoris-com-es-filtren-i-com-evitar-ho/">com es filtren els secrets a Git</a>.</p>
<h2>3. Rols amb permisos de més</h2>
<p>Polítiques amb <code>"Action": "*"</code> o <code>"Resource": "*"</code> perquè «així funcionava». La bretxa de Capital One del 2019 va combinar un SSRF en una aplicació web amb el servei de metadades de la instància (IMDSv1) i un rol amb accés a massa buckets. Sense aquest rol sobredimensionat, l''SSRF s''hauria quedat en poca cosa.</p>
<p>Què mirar: exigir IMDSv2 a les instàncies, i fer servir les eines del mateix proveïdor (IAM Access Analyzer a AWS, per exemple) per veure quins permisos no s''utilitzen mai.</p>
<h2>4. Ports d''administració oberts a 0.0.0.0/0</h2>
<p>SSH (22) i RDP (3389) oberts a tot internet en un security group o un NSG. Els escàners els troben en minuts. L''alternativa és un bastió, accés a través del mateix proveïdor (Session Manager, Azure Bastion, IAP) o almenys restringir per IP d''origen.</p>
<h2>5. Logs apagats o sense retenció</h2>
<p>CloudTrail desactivat en alguna regió, Azure Activity Log sense exportar, logs d''accés d''emmagatzematge sense habilitar. No impedeix l''atac, però quan arriba l''incident no hi ha manera de saber què ha passat. Sense logs, la investigació es queda en suposicions.</p>
<h2>6. Identitat feble a la consola</h2>
<p>El compte arrel d''AWS sense MFA, o amb access keys pròpies. Usuaris de consola sense MFA. És la versió cloud del mateix problema de sempre, i s''arregla amb <a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">MFA resistent al phishing</a> i <a href="/ca/blog/post/minim-privilegi-a-microsoft-entra-id/">mínim privilegi</a>.</p>
<h2>Revisar-ho una vegada no serveix: CSPM</h2>
<p>Tot l''anterior es pot revisar a mà, però la configuració canvia cada dia. Les eines de CSPM (Cloud Security Posture Management) comproven la configuració de manera contínua contra marcs com els CIS Benchmarks i avisen quan alguna cosa es desvia. Els proveïdors tenen la seva (AWS Security Hub, Microsoft Defender for Cloud) i plataformes com Trend Micro Vision One també ho cobreixen. Per començar sense cost, <a href="https://github.com/prowler-cloud/prowler">Prowler</a> és de codi obert i molt complet.</p>
<h2>Preguntes freqüents</h2>
<h3>Què és el model de responsabilitat compartida?</h3>
<p>El repartiment de qui protegeix què al núvol. El proveïdor protegeix la infraestructura; el client, tot el que configura al damunt. Com més gestionat és el servei (SaaS davant d''IaaS), més part assumeix el proveïdor, però les identitats i les dades sempre són teves.</p>
<h3>Què és CSPM?</h3>
<p>Una categoria d''eines que avaluen de manera contínua la configuració dels teus comptes cloud contra bones pràctiques i normatives, i detecten desviacions com un bucket que s''ha tornat públic.</p>
<h3>Per on començo si només tinc una tarda?</h3>
<p>MFA al compte arrel i a tots els administradors, Block Public Access a nivell de compte i CloudTrail (o l''equivalent) actiu a totes les regions.</p>',
  'cloud-security,aws,azure,cspm,misconfiguration,iam', 'cloud-iam', 'ca', 1, '2026-09-28 09:00:00', '2026-09-28 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'errors-de-configuracio-al-cloud-mes-repetits');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'XDR, SIEM i EDR: en què es diferencien en un SOC real',
  'xdr-siem-i-edr-diferencies-en-un-soc',
  'L''EDR vigila l''endpoint, el SIEM centralitza logs de qualsevol font i l''XDR correlaciona diverses capes de sèrie. Què aporta cadascun a la feina diària d''un SOC.',
  '<p>Un EDR vigila el que passa dins de cada equip i el pot aïllar. Un SIEM recull logs de qualsevol font, els guarda i permet correlacionar-los i cercar-hi. Un XDR ajunta la telemetria de diverses capes (endpoint, correu, identitat, xarxa, cloud) normalment d''un mateix fabricant, i la correlaciona per tu en un únic incident. No són substituts exactes: es solapen, i la majoria de SOC acaben fent servir dos dels tres.</p>
<p>Treballo a diari amb Trend Micro Vision One, que és un XDR, així que el que segueix surt d''aquesta perspectiva.</p>
<h2>EDR: el detall de l''endpoint</h2>
<p>L''EDR registra processos, connexions de xarxa, canvis al registre i fitxers, i detecta comportament sospitós al mateix equip. La seva força és la profunditat: pots veure l''arbre de processos complet d''un <code>winword.exe</code> que va llançar <code>powershell.exe</code> amb una ordre codificada, i aïllar l''equip de la xarxa amb un botó.</p>
<p>El seu límit és que només veu endpoints. Un inici de sessió des d''una IP estranya a Microsoft 365 o una regla de reenviament creada en una bústia no hi passen.</p>
<h2>SIEM: tot en un lloc, a la teva manera</h2>
<p>Un SIEM (Splunk, Microsoft Sentinel, QRadar, Elastic, Wazuh) ingesta logs del que vulguis: tallafocs, controladors de domini, proxies, aplicacions pròpies, cloud. El que aporta:</p>
<ul>
  <li>Retenció llarga i cerca sobre tot aquest historial.</li>
  <li>Regles de correlació pròpies, escrites per al teu entorn.</li>
  <li>Compliment normatiu: moltes auditories demanen logs centralitzats durant un temps concret.</li>
</ul>
<p>A canvi, dona feina: normalitzar fonts, escriure i afinar regles, pagar per volum ingestat. Un SIEM acabat d''instal·lar i sense afinar genera soroll, no detecció.</p>
<h2>XDR: correlació ja feta</h2>
<p>L''XDR parteix de què el fabricant controla els sensors de diverses capes i per tant els pot correlacionar de sèrie. A la pràctica, en lloc de tres alertes soltes (correu sospitós lliurat, macro executada, connexió a un domini nou) reps un únic incident amb la seqüència completa i l''usuari afectat.</p>
<p>Per al <a href="/ca/blog/post/triatge-alertes-en-un-soc-en-quin-ordre-mirar/">triatge d''alertes</a> això canvia molt el temps per incident. La contrapartida és que la visibilitat és millor dins de l''ecosistema del fabricant i més pobra fora.</p>
<h2>Taula comparativa</h2>
<table>
  <thead><tr><th></th><th>EDR</th><th>SIEM</th><th>XDR</th></tr></thead>
  <tbody>
    <tr><td>Fonts</td><td>Endpoints</td><td>Qualsevol</td><td>Diverses capes, mateix fabricant</td></tr>
    <tr><td>Correlació</td><td>A l''equip</td><td>Regles pròpies</td><td>De sèrie</td></tr>
    <tr><td>Resposta</td><td>Aïllar, matar procés</td><td>Via SOAR</td><td>Integrada</td></tr>
    <tr><td>Retenció</td><td>Curta</td><td>Llarga</td><td>Mitjana</td></tr>
    <tr><td>Esforç d''ajust</td><td>Baix</td><td>Alt</td><td>Mitjà</td></tr>
  </tbody>
</table>
<h2>Quin necessita una empresa mitjana</h2>
<p>Si cal triar-ne un, per a una organització sense equip per mantenir regles de correlació, un XDR (o un EDR amb servei gestionat) dona més detecció per hora de feina. El SIEM arriba quan cal retenció per normativa, quan hi ha fonts que l''XDR no cobreix (OT, aplicacions pròpies) o quan l''equip vol escriure la seva pròpia detecció. El normal és acabar amb XDR i SIEM alhora, amb l''XDR enviant els seus incidents al SIEM.</p>
<h2>Preguntes freqüents</h2>
<h3>L''XDR substitueix el SIEM?</h3>
<p>En algunes organitzacions petites, sí. Tan bon punt hi ha requisits de retenció de logs o fonts de tercers, no: es complementen.</p>
<h3>Què és un SOAR?</h3>
<p>Una plataforma d''orquestració i resposta automatitzada que executa playbooks sobre alertes: enriquir un IOC, obrir un tiquet, bloquejar un usuari. Molts SIEM i XDR ja inclouen part d''aquesta funció.</p>
<h3>I l''MDR?</h3>
<p>Managed Detection and Response no és un producte sinó un servei: un equip extern vigila i respon fent servir EDR o XDR. És l''opció quan no hi ha SOC propi 24x7.</p>',
  'xdr,siem,edr,soc,vision-one,deteccion', 'blue-team-soc', 'ca', 1, '2026-09-24 09:00:00', '2026-09-24 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'xdr-siem-i-edr-diferencies-en-un-soc');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Mínim privilegi a Microsoft Entra ID, a la pràctica',
  'minim-privilegi-a-microsoft-entra-id',
  'Massa administradors globals i rols permanents. Com aplicar el mínim privilegi a Microsoft Entra ID amb rols específics, PIM i comptes break-glass.',
  '<p>El principi de mínim privilegi diu que cada compte té només els permisos que necessita, durant el temps que els necessita. A Microsoft Entra ID (l''antic Azure AD) això es tradueix en tres coses concretes: fer servir rols específics en lloc d''Administrador global, que els rols privilegiats siguin temporals amb PIM i tenir comptes d''emergència que funcionin quan tota la resta falla.</p>
<p>És el mateix que <a href="/ca/blog/post/active-directory-els-deu-primers-canvis-en-qualsevol-domini-nou/">revisava a Active Directory amb Domain Admins</a>, però al núvol el radi d''impacte és més gran: un administrador global controla el correu, els fitxers de SharePoint i OneDrive, les identitats i, amb un clic, les subscripcions d''Azure.</p>
<h2>Quants administradors globals són massa</h2>
<p>Microsoft recomana <a href="https://learn.microsoft.com/es-es/entra/identity/role-based-access-control/best-practices">menys de cinc administradors globals</a> per inquilí. El normal és el contrari: el tècnic que va muntar l''inquilí, el proveïdor que va fer la migració, el director que ho va demanar «per si de cas» i algun compte de servei que ningú sap per a què és.</p>
<p>Per treure''ls ràpid, des de PowerShell amb Microsoft Graph:</p>
<pre><code>Connect-MgGraph -Scopes RoleManagement.Read.Directory
$rol = Get-MgDirectoryRole -Filter "displayName eq ''Global Administrator''"
Get-MgDirectoryRoleMember -DirectoryRoleId $rol.Id</code></pre>
<h2>Rols específics en lloc d''Administrador global</h2>
<p>Gairebé ningú necessita Administrador global per a la seva feina diària. Les tasques habituals tenen el seu rol:</p>
<table>
  <thead><tr><th>Tasca</th><th>Rol suficient</th></tr></thead>
  <tbody>
    <tr><td>Restablir contrasenyes</td><td>Helpdesk Administrator</td></tr>
    <tr><td>Crear usuaris i grups</td><td>User Administrator</td></tr>
    <tr><td>Gestionar bústies</td><td>Exchange Administrator</td></tr>
    <tr><td>Revisar alertes</td><td>Security Reader / Operator</td></tr>
    <tr><td>Llicències</td><td>License Administrator</td></tr>
    <tr><td>Polítiques d''accés condicional</td><td>Conditional Access Administrator</td></tr>
  </tbody>
</table>
<p>Un detall que es passa per alt: els permisos que té un usuari per <em>consentir aplicacions</em>. Si qualsevol pot donar permisos de lectura de correu a una app OAuth, el mínim privilegi en rols es queda curt. Convé restringir el consentiment a editors verificats o a un flux d''aprovació.</p>
<h2>PIM: privilegi només quan cal</h2>
<p>Privileged Identity Management converteix els rols en <em>elegibles</em> en lloc d''<em>actius</em>. La persona no és administradora fins que ho demana, justifica el motiu, passa MFA i, si es configura, algú ho aprova. Al cap d''unes hores el rol caduca sol.</p>
<p>Per al SOC, l''avantatge és que un compte compromès sense rol actiu no pot fer quasi res, i cada activació queda registrada amb la seva justificació. Una activació d''Administrador global a les tres de la matinada és una alerta molt fàcil d''escriure.</p>
<p>PIM requereix llicència Entra ID P2 (o Entra ID Governance). Si no n''hi ha, almenys separa el compte d''administració del compte diari amb què es llegeix el correu i es navega.</p>
<h2>Comptes d''emergència (break-glass)</h2>
<p>Dos comptes cloud-only, sense bústia, amb Administrador global permanent, exclosos de les polítiques d''accés condicional que et podrien deixar fora, i protegits amb clau FIDO2 física. Microsoft en recomana dos, amb credencials separades.</p>
<p>El que quasi ningú fa: <strong>provar-los</strong> cada pocs mesos i tenir una alerta que salti cada cop que un d''ells inicia sessió. Si es fan servir i ningú se n''assabenta, són la porta del darrere perfecta.</p>
<h2>Preguntes freqüents</h2>
<h3>Què és el principi de mínim privilegi?</h3>
<p>Concedir a cada usuari, aplicació o servei només els permisos imprescindibles per a la seva funció i durant el temps just. Redueix el que pot fer un atacant amb un compte robat.</p>
<h3>PIM substitueix l''MFA?</h3>
<p>No, el complementa. PIM pot exigir MFA a cada activació, i l''ideal és que sigui <a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">MFA resistent al phishing</a>.</p>
<h3>Cada quant revisar els rols assignats?</h3>
<p>Com a mínim trimestralment, i sempre que algú canviï de lloc o se''n vagi. És el mateix problema que el <a href="/ca/blog/post/joiner-mover-leaver-comptes-orfes/">cicle joiner-mover-leaver</a>, aplicat a privilegis.</p>',
  'entra-id,iam,minimo-privilegio,pim,azure,microsoft-365', 'cloud-iam', 'ca', 1, '2026-09-21 09:00:00', '2026-09-21 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'minim-privilegi-a-microsoft-entra-id');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'SPF, DKIM i DMARC: com passar de p=none a p=reject',
  'spf-dkim-i-dmarc-de-p-none-a-p-reject',
  'Què fan SPF, DKIM i DMARC, per què tants dominis es queden en p=none i com arribar a p=reject per fases sense perdre correu legítim.',
  '<p>SPF diu quins servidors poden enviar correu en nom del teu domini, DKIM signa cada missatge per demostrar que no s''ha modificat, i DMARC li diu al receptor què fer quan un correu falla aquestes comprovacions i a qui enviar l''informe. Per separat cap d''ells impedeix que algú suplanti el teu domini al camp <code>From</code> que veu l''usuari. DMARC amb <code>p=reject</code> sí.</p>
<p>I tot i així, moltíssims dominis porten anys amb DMARC publicat en <code>p=none</code>. És l''equivalent de tenir una alarma que només apunta en una llibreta qui ha entrat.</p>
<h2>Què comprova cada registre</h2>
<h3>SPF</h3>
<p>Un registre TXT al domini amb la llista d''IP i serveis autoritzats:</p>
<pre><code>v=spf1 include:spf.protection.outlook.com include:_spf.google.com -all</code></pre>
<p>Dos detalls que trenquen més SPF dels que haurien: el límit de <strong>10 consultes DNS</strong> (cada <code>include</code> compta, i els aniuats també) i que SPF valida el remitent del sobre (<code>Return-Path</code>), no el <code>From</code> visible.</p>
<h3>DKIM</h3>
<p>El servidor emissor signa capçaleres i cos amb una clau privada, i publica la pública a DNS sota un selector (<code>selector1._domainkey.tudominio.com</code>). Sobreviu als reenviaments millor que SPF, que és just el motiu pel qual DMARC accepta qualsevol dels dos.</p>
<h3>DMARC</h3>
<p>DMARC exigeix <em>alineació</em>: que el domini que passa SPF o DKIM coincideixi amb el del <code>From</code>. Aquí hi ha la protecció real contra la suplantació.</p>
<pre><code>v=DMARC1; p=none; rua=mailto:dmarc@tudominio.com; fo=1</code></pre>
<h2>Per què ja no és opcional</h2>
<p>Des del febrer de 2024, Google i Yahoo exigeixen SPF, DKIM i DMARC a qui enviï més de 5.000 correus al dia als seus usuaris, i Microsoft va anunciar requisits equivalents per a Outlook.com el 2025. Per a un domini corporatiu petit el volum no arriba a aquests llindars, però la direcció és clara: el correu sense autenticar arriba cada cop pitjor.</p>
<h2>El procés per fases fins a p=reject</h2>
<ol>
  <li><strong>Inventari.</strong> Publica <code>p=none</code> amb <code>rua</code> i deixa que arribin informes agregats almenys dues o tres setmanes. Et sortiran remitents que ningú recordava: el CRM, l''eina de factures, el formulari del web, l''escàner de l''oficina.</li>
  <li><strong>Arreglar cada remitent legítim.</strong> Per a cadascun, configurar DKIM amb el teu domini (millor que afegir-lo a SPF, que té el límit de 10 consultes).</li>
  <li><strong><code>p=quarantine</code> amb <code>pct</code> baix.</strong> Comença amb <code>pct=10</code> o <code>25</code>, revisa informes, puja.</li>
  <li><strong><code>p=reject</code></strong> quan els informes portin un temps nets. Aquí també convé <code>sp=reject</code> per als subdominis, que és per on entra la suplantació quan el domini principal ja està protegit.</li>
</ol>
<p>Els informes agregats són XML i llegir-los a mà és una tortura. Per revisar un missatge concret, l''<a href="/ca/blog/post/blue-team-hub-per-que-vaig-treure-el-vidre-esmerilat/">analitzador de capçaleres de Blue Team Hub</a> mostra el resultat de SPF, DKIM i DMARC i els salts del correu sense enviar res a cap servidor.</p>
<h2>El que DMARC no fa</h2>
<p>DMARC protegeix el teu domini exacte. No impedeix que algú registri <code>tudominio-pagos.com</code> o faci servir un nom visible enganyós amb un compte de Gmail. Contra això calen filtres del costat receptor i formació. Tampoc serveix si l''atacant entra en una bústia real de la teva organització, que és l''escenari del <a href="/ca/blog/post/business-email-compromise-senyals-a-microsoft-365/">BEC amb compte compromès</a>.</p>
<h2>Preguntes freqüents</h2>
<h3>Puc posar p=reject directament?</h3>
<p>Pots, però si hi ha un servei legítim que envia en nom teu i no està alineat, els seus correus es rebutjaran sense avís. Les setmanes en <code>p=none</code> serveixen precisament per descobrir-los.</p>
<h3>Quina diferència hi ha entre ~all i -all a SPF?</h3>
<p><code>~all</code> (softfail) marca com a sospitós el que no és a la llista; <code>-all</code> (fail) ho marca com a no autoritzat. Amb DMARC en <code>reject</code>, la política que mana és la de DMARC, així que la diferència importa menys del que sembla.</p>
<h3>Cal DMARC en un domini que no envia correu?</h3>
<p>Sí, i és el cas més fàcil: <code>v=spf1 -all</code> i <code>v=DMARC1; p=reject</code>. Els dominis aparcats sense protecció són els preferits per a campanyes de suplantació.</p>',
  'spf,dkim,dmarc,email-security,dns,phishing', 'blue-team-soc', 'ca', 1, '2026-09-17 09:00:00', '2026-09-17 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'spf-dkim-i-dmarc-de-p-none-a-p-reject');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'MFA resistent al phishing: per què l''SMS ja no basta',
  'mfa-resistent-al-phishing-per-que-sms-ja-no-basta',
  'L''MFA per SMS o push es salta amb phishing en temps real i fatiga d''MFA. Quins mètodes resisteixen de debò el phishing i com migrar sense bloquejar ningú.',
  '<p>Un segon factor per SMS és millor que no tenir-ne cap, però ja no frena un atacant amb una mica de preparació. L''MFA resistent al phishing és el que no es pot reenviar a una web falsa: la credencial està lligada criptogràficament al domini legítim, així que encara que l''usuari piqui, el que entrega no serveix a cap altre lloc. Avui això vol dir claus FIDO2, passkeys i Windows Hello for Business, o certificats amb smart card.</p>
<h2>Com es salta un MFA «normal»</h2>
<p>Hi ha tres tècniques habituals, i cap no necessita trencar criptografia:</p>
<ul>
  <li>Phishing en temps real (AiTM): un proxy invers es col·loca entre la víctima i el login real. L''usuari escriu usuari, contrasenya i codi, el proxy els reenvia al servei de veritat i es queda amb la cookie de sessió. Kits com Evilginx o EvilProxy ho deixen a l''abast de qualsevol.</li>
  <li>Fatiga d''MFA: l''atacant ja té la contrasenya i llança notificacions push una darrere l''altra fins que algú prem «Aprovar» perquè parin. A l''incident d''Uber del 2022 l''atacant va combinar això amb un missatge per WhatsApp fent-se passar pel suport intern.</li>
  <li>SIM swapping: amb el número de telèfon portat a una altra SIM, els codis per SMS arriben directament a l''atacant.</li>
</ul>
<p>Els tres funcionen perquè el factor (un codi de sis dígits, un botó d''aprovar) no sap en quina web s''està fent servir.</p>
<h2>Quins mètodes són resistents al phishing</h2>
<p>CISA va publicar el 2022 una guia específica sobre això, <a href="https://www.cisa.gov/sites/default/files/publications/fact-sheet-implementing-phishing-resistant-mfa-508c.pdf">Implementing Phishing-Resistant MFA</a>, i la seva classificació continua sent una bona referència:</p>
<table>
  <thead><tr><th>Mètode</th><th>Resistent al phishing?</th></tr></thead>
  <tbody>
    <tr><td>Codi per SMS o trucada</td><td>No</td></tr>
    <tr><td>Codi TOTP (app autenticadora)</td><td>No</td></tr>
    <tr><td>Push sense number matching</td><td>No</td></tr>
    <tr><td>Push amb number matching</td><td>Millor, però no</td></tr>
    <tr><td>Clau FIDO2 / passkey</td><td>Sí</td></tr>
    <tr><td>Windows Hello for Business</td><td>Sí</td></tr>
    <tr><td>Certificat (PKI / smart card)</td><td>Sí</td></tr>
  </tbody>
</table>
<p>El number matching (l''usuari tecleja al mòbil el número que veu a la pantalla) acaba quasi del tot amb la fatiga d''MFA, i Microsoft el va activar per a tots els inquilins d''Authenticator el 2023. Però un proxy AiTM pot mostrar aquest número igual que mostra la pàgina de login, així que no protegeix contra el phishing en temps real.</p>
<h2>Per què FIDO2 i les passkeys sí aguanten</h2>
<p>Una passkey és un parell de claus. La privada no surt mai del dispositiu, i en registrar-la queda associada al domini exacte del servei. Quan el navegador rep una petició d''autenticació de <code>login.micr0soft-secure.com</code>, la passkey de <code>login.microsoftonline.com</code> senzillament no respon. No hi ha cap codi per copiar ni cap botó per prémer per cansament: l''usuari no té manera d''entregar res que valgui al domini fals.</p>
<h2>Com migrar sense bloquejar ningú</h2>
<p>L''error típic és voler activar-ho per a tothom el mateix dia. L''ordre que funciona:</p>
<ol>
  <li><strong>Comptes privilegiats primer.</strong> Administradors globals, d''Exchange, de seguretat. Són pocs, el risc és màxim i la gent que els fa servir entén per què es canvia.</li>
  <li><strong>Comptes d''emergència (break-glass) amb clau FIDO2 física</strong>, guardada fora del flux diari.</li>
  <li><strong>Usuaris amb més exposició</strong>: finances, recursos humans, direcció. Són els objectius habituals de <a href="/ca/blog/post/business-email-compromise-senyals-a-microsoft-365/">frau BEC</a>.</li>
  <li><strong>La resta, per fases</strong>, deixant un mètode de reserva temporal i traient-lo quan el registre de passkeys passi d''un llindar que tinguis mesurat.</li>
</ol>
<p>A Microsoft Entra ID això es controla amb les <em>authentication strengths</em> dins d''<a href="/ca/blog/post/acces-condicional-microsoft-365-politiques-base/">accés condicional</a>: pots exigir «MFA resistent al phishing» només per a certs rols o aplicacions sense tocar la resta.</p>
<h2>Preguntes freqüents</h2>
<h3>Una app autenticadora amb codi és segura?</h3>
<p>És més segura que l''SMS perquè no depèn del número de telèfon, però el codi es pot introduir en una web falsa igual que una contrasenya. No és resistent al phishing.</p>
<h3>Les passkeys sincronitzades al núvol compten?</h3>
<p>Sí que resisteixen el phishing, perquè continuen lligades al domini. La diferència amb una clau física és on viu la clau privada: en una passkey sincronitzada depèn de la seguretat del compte d''Apple, Google o del gestor de contrasenyes. Per a comptes d''administració prefereixo clau física.</p>
<h3>L''MFA resistent al phishing evita el robatori de cookies de sessió?</h3>
<p>Evita l''AiTM, que és la forma més comuna de robar-les. Si un infostealer ja és a l''equip i s''emporta la cookie després del login, l''MFA no hi intervé; per a això calen controls de dispositiu i protecció de tokens.</p>',
  'mfa,passkeys,fido2,iam,phishing,entra-id', 'cloud-iam', 'ca', 1, '2026-09-14 09:00:00', '2026-09-14 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'mfa-resistent-al-phishing-per-que-sms-ja-no-basta');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'El desacord entre classificadors perd contra alguna cosa molt més simple',
  'el-desacord-entre-classificadors-perd-contra-alguna-cosa-mes-simple',
  'Mesura sobre 7.822 correus reals si el desacord entre quatre classificadors serveix per decidir què revisa abans un analista. Esperava que sí. Les dades diuen que no.',
  '<p>Un analista no pot revisar tot el correu que marca un classificador. La pregunta que volia respondre amb dades, no amb intuïció: pot el desacord entre diversos classificadors dir-li a aquest analista quin ha de revisar primer? La motivació venia de dos llocs molt diferents: <a href="https://huggingface.co/BSC-LT/catalan-verification-model-pkt-a">els models de verificació del BSC per al català</a>, que entrenen dues còpies del mateix reconeixedor de veu amb meitats disjuntes del corpus perquè els seus errors no estiguin correlacionats, i <a href="https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2026.1829902/full">un estudi del 2026 sobre transcripció mèdica</a> que fa servir el desacord entre vuit transcriptors com a senyal sense referència per decidir què revisa un humà, recuperant el 93,7 % dels errors revisant el 28,6 % del text. L''estructura del problema en un SOC és idèntica: sense veritat de referència, amb revisió humana cara i escassa. Semblava traslladable.</p>
<h2>El resultat, en una línia</h2>
<p>Sobre 7.822 correus reals (Nazario phishing corpus + SpamAssassin públic), el desacord funciona per prioritzar la revisió (AUC 0,905 davant de 0,515 de l''atzar), però perd clarament contra un senyal molt més simple: la incertesa mitjana del mateix ensemble, amb AUC 0,959. Per capturar el 95 % dels errors cal revisar el 14,10 % del correu mirant només la incertesa mitjana. Amb el desacord per desviació, en calen el 22,62 %. No cal ensemble per al bon resultat: n''hi ha prou amb mirar on el model no està segur.</p>
<table>
<tr><th>Senyal de prioritat</th><th>AUC de triatge</th><th>Correu a revisar per al 95 % d''errors</th></tr>
<tr><td>Oracle (sostre teòric)</td><td>0,991</td><td>1,75 %</td></tr>
<tr><td><strong>Incertesa mitjana</strong></td><td><strong>0,959</strong></td><td><strong>14,10 %</strong></td></tr>
<tr><td>Desacord: desviació</td><td>0,905</td><td>22,62 %</td></tr>
<tr><td>Desacord: força de majoria</td><td>0,907</td><td>41,20 %</td></tr>
<tr><td>Atzar (terra)</td><td>0,515</td><td>97,66 %</td></tr>
</table>
<h2>Per què va fallar la hipòtesi</h2>
<p>L''ensemble dona quatre vistes del mateix correu (remitent, URL, estructura de l''HTML i text), però no són igual de fortes. La vista de text (TF-IDF més regressió logística) sola arriba a un 98,17 % d''exactitud i AUC 0,998, pràcticament igualant l''ensemble complet. Quan un membre és molt superior a la resta, el desacord deixa de mesurar dubte genuí i passa a mesurar que els febles s''equivoquen, cosa que no informa sobre si l''ensemble encerta. Aquí hi ha la diferència amb el muntatge del BSC: els seus dos models tenen taxes d''error quasi idèntiques per disseny. Aquesta sembla ser la condició que fa útil el desacord, i és una condició que aquí no es compleix.</p>
<h2>El control que gairebé invalida l''experiment</h2>
<p>Els corpus públics de phishing arrosseguen un problema que gairebé mai es declara: el correu legítim i el phishing vénen d''èpoques diferents: el 87 % del phishing és del 2004-2007, el legítim és del 2002. Classificar fent servir només l''any dona un 99,74 % d''exactitud: la drecera existeix i és quasi perfecta. Restringint l''avaluació a la franja on les dues classes se solapen (2004 o abans), el rendiment no cau (98,31 %, AUC 1,000), cosa que indica que el model no està fent servir aquesta drecera, encara que amb la cautela que aquesta franja només té 31 casos de phishing: evidència indicativa, no concloent.</p>
<h2>Límits, dits sense adorns</h2>
<ul>
  <li>No diu que el desacord sigui inútil. Diu que perd contra un baseline més simple en aquest muntatge concret, amb vistes de força desigual.</li>
  <li>Només 43 errors a la partició de prova: les corbes de triatge són sorolloses.</li>
  <li>El corpus és del 2004-2007: sense HTTPS generalitzat, sense escurçadors, sense typosquatting modern. Les conclusions de mètode haurien d''aguantar; les xifres absolutes no són extrapolables a un SOC d''avui.</li>
  <li>Una única partició 70/30 amb llavor fixa, sense validació creuada.</li>
</ul>
<p>És el mateix problema, vist des de l''altre costat, que treballo a <a href="/ca/blog/post/classificar-phishing-al-navegador-sense-enviar-la-url/">el classificador de phishing al navegador</a>: allà la pregunta era classificar bé sense enviar res a cap servidor; aquí, un cop classificat, què fa perdre menys temps a l''analista que l''ha de revisar. El següent experiment que tinc a la llista: repetir això amb quatre models de la mateixa família entrenats sobre particions disjuntes del corpus, replicant el mètode del BSC en lloc de només la seva intuïció, per comprovar si el desacord remunta en equiparar forces entre vistes. <a href="https://github.com/eduolihez/phishing-triage">El codi, els experiments i el README complet amb tots els números estan publicats</a>.</p>',
  'machine-learning,phishing,triaje,soc,scikit-learn,investigacion', 'ia-aplicada', 'ca', 1, '2026-09-04 09:00:00', '2026-09-04 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'el-desacord-entre-classificadors-perd-contra-alguna-cosa-mes-simple');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'El que dona temps a aprendre construint un sensor d''aigua en 24 hores',
  'el-que-dona-temps-a-aprendre-en-24-hores-de-hackathon',
  'Dewi App va ser el nostre prototip guanyador a la 8a Hackathon TecnoCampus: un sensor físic de cabal connectat a un web de consum d''aigua, muntat entre quatre persones en menys d''un dia.',
  '<p>Això se surt del terreny habitual d''aquest blog (res de SOC, res de blue team) però mereix un lloc perquè la restricció més dura que he tingut mai en un projecte no va ser tècnica, va ser el rellotge: vint-i-quatre hores, de la idea al prototip funcionant sobre un escenari.</p>
<h2>Què vam construir</h2>
<p>Dewi App va néixer a la 8a Hackathon TecnoCampus amb un objectiu simple: ajudar a monitoritzar i reduir el consum d''aigua domèstic. La part física va ser un sensor de cabal per Arduino, programat i calibrat aquella mateixa nit. La part web, una aplicació en Next.js i TypeScript que rebia aquestes dades i les convertia en alguna cosa llegible: consum, tendències, recomanacions per gastar menys.</p>
<h2>El que canvia quan el límit és el temps, no l''abast</h2>
<p>En un projecte sense data límit es pot discutir arquitectura durant hores. En una hackathon aquesta discussió és un luxe que no existeix: es tria l''opció que se sap muntar ràpid i s''avança. Això obliga a una disciplina que després trasllado a projectes amb més temps: decidir ràpid, mesurar si funciona, i no protegir-se darrere de «fer-ho bé» quan el que cal és tenir alguna cosa que funcioni ja.</p>
<h2>Un prototip, no un producte</h2>
<p>El mateix repositori ho deixa clar: és un prototip, no una cosa llesta per a producció. Falten autenticació real, persistència de dades de debò, integració en temps real amb el sensor més enllà de la demo. Està bé: no era l''objectiu de la nit. L''objectiu era demostrar que la idea se sosté, i vam guanyar la hackathon amb aquesta demostració.</p>
<p>L''equip va ser Marc Lumbreras, Nil Sentís, Jan Naranjo i jo. El prototip <a href="https://dewi-hackathon.vercel.app">continua desplegat</a>, tal com va sortir aquella nit.</p>',
  'hackathon,nextjs,arduino,prototipo,trabajo-en-equipo', 'carrera-personal', 'ca', 1, '2026-09-03 18:00:00', '2026-09-03 18:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'el-que-dona-temps-a-aprendre-en-24-hores-de-hackathon');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Revocar un token sense haver d''enderrocar la sessió sencera',
  'revocar-un-token-sense-enderrocar-la-sessio-sencera',
  'BinCat és un SDK de Python per emetre, validar i revocar tokens Fernet i JWT amb registre d''auditoria, amb un panell al damunt per fer-ho sense escriure codi.',
  '<p>Una petició que he vist repetir-se: revocar l''accés d''un token concret sense forçar tothom a tornar-se a autenticar. Moltes implementacions casolanes de tokens no deixen marge per a això: o el JWT és vàlid fins que caduca per si sol, o cal invalidar la sessió sencera. BinCat va néixer de resoldre just això: emetre, validar i revocar tokens de manera individual, amb registre de cada operació.</p>
<h2>Dos tipus de token, cadascun per al seu cas</h2>
<p>Fernet, de la llibreria <code>cryptography</code>, per a xifratge simètric quan el mateix sistema emet i valida. JWT signats criptogràficament amb claims amb estat, per a quan el token viatja entre serveis diferents. Els intervals d''expiració es configuren des de l''API o des del panell, i qualsevol token individual es pot revocar a l''instant sense tocar els altres, que és la diferència davant de dependre només de l''expiració natural.</p>
<h2>Què porta el paquet</h2>
<ul>
  <li>Un SDK de Python que s''integra directament en una aplicació existent.</li>
  <li>Un panell d''una sola pàgina, tema fosc, amb recompte de tokens totals, actius, revocats i expirats, i una consola de logs que traça l''activitat a mesura que passa.</li>
  <li>Una API REST amb sis endpoints: generar, validar, revocar, purgar i consultar el log de les últimes cinquanta operacions.</li>
  <li>Registre a SQLite de cada emissió, validació i revocació, per poder respondre després qui tenia accés i quan va deixar de tenir-ne.</li>
</ul>
<h2>La clau de xifratge no es toca a mà</h2>
<p>Si BinCat no troba cap clau a <code>.env</code> en arrencar, en genera una de criptogràficament segura pel seu compte. És la mateixa lògica que aplico a <a href="/ca/blog/post/comprovar-si-una-contrasenya-esta-filtrada-sense-enviar-la-a-ningu/">Password Sentinel</a>: com menys depèn la seguretat que algú recordi configurar alguna cosa bé, menys maneres hi ha que es quedi mal configurada. Si una clau es filtra, el procediment és simple: esborrar <code>.env</code>, deixar que se''n generi una de nova, i reemetre els tokens que estaven xifrats amb l''anterior. No hi ha rotació màgica que salvi aquest pas: cal reemetre.</p>
<p>Els tests corren contra una base de dades SQLite aïllada, així que mai toquen la de desenvolupament ni arrosseguen estat entre execucions.</p>',
  'python,criptografia,jwt,seguridad,tokens,sdk', 'herramientas', 'ca', 1, '2026-09-03 09:00:00', '2026-09-03 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'revocar-un-token-sense-enderrocar-la-sessio-sencera');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Blue Team Hub: per què vaig treure el vidre esmerilat de la meva pròpia eina',
  'blue-team-hub-per-que-vaig-treure-el-vidre-esmerilat',
  'Set eines de SOC gratuïtes i del costat del client, més vigilància en viu del catàleg KEV integrada a la portada. I la raó per la qual vaig redissenyar el lloc en blanc i negre.',
  '<p>Blue Team Hub és un portal estàtic amb set utilitats que faig servir jo mateix en el dia a dia: desarmador d''IOC, analitzador de capçaleres de correu (SPF/DKIM/DMARC i línia de temps de salts), generador de regles YARA amb linter en temps real, playbooks interactius de resposta a incidents amb consultes SIEM generades al moment, descodificador de payloads (Base64/URL/Hex i desofuscació de PowerShell), un hub d''OSINT, i vigilància del catàleg CISA KEV. Tot corre al navegador: res del que enganxis a cap eina surt de la teva màquina.</p>
<h2>KEV Watch ja no viu darrere d''un enllaç</h2>
<p>La vigilància de CISA KEV la genera <a href="/ca/blog/post/vigilar-el-cataleg-kev-de-cisa-sense-servidor/">kev-digest</a>, un projecte a part que comprova el catàleg cada tres hores. Al principi KEV Watch era una pàgina d''eina més, amb el seu propi enllaç al menú. La vaig moure a la mateixa portada, com una secció en línia amb la mateixa tipografia i retícula que la resta: no tenia sentit que l''única eina amb dades que canvien soles fos un clic més lluny que les altres.</p>
<h2>El redisseny que no esperava fer</h2>
<p>El lloc va néixer amb una estètica glassmorphism de vidre esmerilat, gradients i desenfocaments, molt en la línia del que qualsevol generador d''UI produeix per defecte ara mateix. Funcionava, però no deia res específic sobre el que és l''eina. Vaig provar dues direccions abans de quedar-me amb la definitiva: una consola tipus terminal amb tipografia monoespaiada fins i tot als titulars, i una edició tipus informe editorial amb serif i tinta càlida. Les vaig descartar totes dues: la primera se sentia a clixé de hacker, la segona pesava més del compte per a una cosa que s''utilitza de pressa.</p>
<p>El que va quedar és minimalisme gairebé suís: blanc, negre, retícula estricta, i un únic vermell reservat sense excepció per al que és urgent: un CVE crític, una entrada marcada com a ransomware. Res d''ombres, res de desenfocaments. La idea central, que només vaig acabar de confirmar després d''auditar el SEO i el posicionament en IA del meu propi portfolio, és que el pes decoratiu no és gratis: costa renderitzar, i comunica «SaaS de consum polit» en lloc d''«eina construïda per algú que la fa servir de debò». Per a una caixa d''eines de SOC, la precisió tipogràfica ven més credibilitat que el vidre.</p>
<h2>Com es desplega</h2>
<p>Cada push a la branca principal compila amb Astro i publica a GitHub Pages via Actions, sense intervenció manual. El mateix pipeline etiqueta versions i empaqueta el necessari per desplegar. És exactament el tipus d''automatització que aplico també a <a href="/ca/blog/post/automatitzar-informe-setmanal-del-soc-amb-python/">altres projectes</a>: si un pas es repeteix, no hauria de dependre que me''n recordi de fer-lo.</p>',
  'blue-team,soc,herramientas,astro,github-actions,cisa-kev', 'herramientas', 'ca', 1, '2026-09-02 09:00:00', '2026-09-02 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'blue-team-hub-per-que-vaig-treure-el-vidre-esmerilat');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Vigilar el catàleg KEV de CISA sense tenir un servidor encès',
  'vigilar-el-cataleg-kev-de-cisa-sense-servidor',
  'kev-digest comprova el catàleg CISA KEV cada tres hores, detecta què ha canviat i publica el resultat, tot sobre GitHub Actions i sense cap dependència externa.',
  '<p>El catàleg KEV (Known Exploited Vulnerabilities) de CISA és de les poques fonts que responen la pregunta que de debò ordena una cua de pedaços: de tot el que s''ha publicat, què s''està explotant ara mateix. <a href="/ca/blog/post/prioritzar-cve-sense-refiar-se-nomes-del-cvss/">Ja vaig escriure sobre per què creuar-lo amb NVD i EPSS canvia per complet l''ordre de prioritat</a>. El que em faltava era deixar de mirar-lo a mà.</p>
<h2>El disseny: sense dependències, sense servidor</h2>
<p>kev-digest és un script de Python que fa servir només llibreria estàndard (<code>urllib</code>, <code>json</code>, <code>hashlib</code>, <code>pathlib</code>) i corre cada tres hores en un cron de GitHub Actions. No hi ha base de dades: l''estat complet viu en un fitxer <code>seen_cves.json</code> versionat al mateix repositori. Cada canvi real (entrada nova, camp modificat, termini que entra a la finestra de set dies, o el cas que més m''interessa: un CVE que portava mesos al catàleg i de sobte passa a tenir ús confirmat en ransomware) s''afegeix al fitxer del dia a <code>digest/</code> i genera un commit. Si no hi ha novetats, no s''escriu res: amb vuit passades al dia, escriure sempre ompliria l''historial de commits buits.</p>
<h2>El guardià anti-encongiment</h2>
<p>La part que de debò em preocupava no era detectar canvis, era no destruir l''historial per una fallada de xarxa. Si el catàleg arriba buit o amb un deu per cent menys d''entrades que l''última vegada, l''script avorta sense desar res. Una descàrrega a mitges marcaria centenars de CVE com a retirats i gravaria aquella foto com a bona, esborrant la línia base d''un cop. Quan l''encongiment és real (CISA sí que retira entrades de tant en tant), es llança a mà amb <code>--force</code>. És la mateixa lògica que aplicaria a qualsevol pipeline que escriu estat persistent: millor no escriure res que escriure alguna cosa corrupta amb confiança.</p>
<h2>Enriquiment sense fer-se car</h2>
<p>Que alguna cosa sigui a KEV diu que s''explota, no si és un 9,8 o un 5,4. Les entrades noves s''enriqueixen amb EPSS (probabilitat d''explotació en 30 dies, consulta en bloc) i NVD (CVSS i severitat, amb cache a disc perquè té rate-limit). Només les entrades noves: demanar el CVSS de les més de mil sis-centes que ja són en seguiment a cada passada no aportaria res i esgotaria la quota.</p>
<h2>On acaba la dada</h2>
<p><code>data/latest.json</code> és la sortida pública, amb contracte de camps estable perquè alguna altra cosa el consumeix: la secció <a href="https://eduolihez.github.io/#kev-watch">KEV Watch de Blue Team Hub</a> descarrega aquest JSON ja processat cada tres hores i el pinta. El càlcul del diff viu en un sol lloc a propòsit: dues implementacions del mateix diff en dos llenguatges acabarien discrepant, i aquesta discrepància seria difícil de detectar fins que algú confiés en el número equivocat.</p>
<p>Ara mateix el catàleg té més de 1.694 CVE en seguiment, 352 amb ús confirmat en campanyes de ransomware. Tot això corre sense que hagi de recordar-me de mirar-ho, i sense cap servidor per mantenir.</p>',
  'cisa-kev,vulnerabilidades,github-actions,automatizacion,python,blue-team', 'automatizacion', 'ca', 1, '2026-09-01 09:00:00', '2026-09-01 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'vigilar-el-cataleg-kev-de-cisa-sense-servidor');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Active Directory: els deu primers canvis en qualsevol domini nou',
  'active-directory-els-deu-primers-canvis-en-qualsevol-domini-nou',
  'Abans de tocar GPO avançades, hi ha una llista curta que reviso sempre en un domini d''Active Directory nou. La majoria porten mal configurades des de la instal·lació.',
  '<p>Quan hereto un domini d''Active Directory que no vaig muntar jo, hi ha una llista ràpida que reviso abans de res, abans de ficar-me en GPO complexes. Són les fallades més comunes, les més barates d''arreglar, i amb més impacte real si s''exploten.</p>
<h2>Comptes i privilegis</h2>
<ol>
  <li><strong>Contrasenyes de comptes privilegiats que no caduquen.</strong> Sorprenentment comú, fins i tot en administradors de domini. Es revisa en un minut amb PowerShell.</li>
  <li><strong>Massa gent a Domain Admins.</strong> El grup hauria de tenir el mínim possible, i cap d''aquests comptes s''hauria de fer servir per al dia a dia.</li>
  <li><strong>Comptes de servei amb privilegis de més.</strong> Es creen «temporalment» amb permisos d''administrador de domini per instal·lar alguna cosa, i hi queden.</li>
</ol>
<h2>Configuració que s''hereta malament</h2>
<ol start="4">
  <li><strong>Delegació de Kerberos sense restriccions.</strong> És una de les rutes d''escalada de privilegis més explotades en AD real. Migrar a delegació restringida sempre que es pugui.</li>
  <li><strong>Política de contrasenyes per defecte.</strong> Continua sense exigir una longitud mínima competitiva. Pujar a 14 caràcters o més.</li>
  <li><strong>LAPS sense desplegar.</strong> Si l''administrador local comparteix contrasenya a tots els equips, un sol equip compromès dona accés lateral a tots els altres. És gratuït i fa anys que és quasi un estàndard.</li>
  <li><strong>SMBv1 encara actiu</strong> «per si de cas». Anys després que deixés de ser defensable, continua apareixent.</li>
</ol>
<h2>Visibilitat i recuperació</h2>
<ol start="8">
  <li><strong>Auditoria avançada sense activar.</strong> Sense registre de canvis de grup i autenticacions fallides, qualsevol investigació comença a cegues.</li>
  <li><strong>Grups aniuats sense documentar.</strong> Diversos nivells d''aniuament acaben donant accessos que ningú recorda haver concedit.</li>
  <li><strong>Sense pla de recuperació de l''AD mateix provat de debò.</strong> Si el domini cau, tota la resta cau amb ell. És la peça que menys es pot permetre fallar en silenci.</li>
</ol>
<p>Cap d''aquests deu punts necessita pressupost ni eines de tercers: és configuració nativa de Windows Server. És exactament el tipus de deute que s''acumula perquè «funciona així de sempre», fins que apareix en una auditoria o, pitjor, en un incident real.</p>',
  'active-directory,hardening,windows-server,sysadmin', 'blue-team-soc', 'ca', 1, '2026-08-28 09:00:00', '2026-08-28 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'active-directory-els-deu-primers-canvis-en-qualsevol-domini-nou');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'De suport tècnic a SOC: el que va canviar no va ser el lloc',
  'de-suport-tecnic-a-soc-el-que-va-canviar-no-va-ser-el-lloc',
  'El salt de donar suport a més de 100 usuaris a triar alertes en un SOC no va ser un canvi de títol d''un dia per l''altre. Va ser un canvi en la pregunta davant de cada tasca repetitiva.',
  '<p>Vaig començar donant suport tècnic a més de cent usuaris: contrasenyes bloquejades, administració d''Active Directory, el dia a dia habitual de qualsevol que comença en IT. No hi ha res dolent en aquesta feina: de fet és on vaig aprendre més del que esperava. Però hi ha un moment en què comences a veure patrons, i aquest moment és el que ningú t''explica per endavant.</p>
<h2>El tiquet número quaranta i tants</h2>
<p>La primera vegada que restableixes una contrasenya és un tràmit. La vegada quaranta i tants, comences a preguntar-te per què el procés continua sent manual. Aquest va ser el meu patró: no va ser una vocació sobtada, va ser la irritació acumulada de repetir el mateix sense que ningú es plantegés automatitzar-ho. Allà vaig començar a escriure els primers scripts en Python, no en un curs, sinó per resoldre tasques concretes del dia a dia.</p>
<h2>El pas intermedi que ningú esmenta</h2>
<p>De suport no vaig passar directe a SOC. Vaig passar abans per administrar FortiGate i FortiAnalyzer, i per respondre incidents de nivell 1 i 2. Aquest pas intermedi importa més del que sembla: entendre la xarxa des de dins, tocant tallafocs i veient trànsit real, és el que després fa que triar una alerta XDR tingui sentit en lloc de ser una etiqueta de severitat sense context.</p>
<h2>El canvi real no va ser de títol</h2>
<p>Passar a analista de SOC no va ser un canvi d''un dia per l''altre. Va ser un canvi en la pregunta que em feia davant de cada tasca repetitiva: de <em>com ho resolc</em> a <em>com faig que això no torni a passar</em>. Aquest gir és el que, amb el temps, porta de gestionar tiquets a gestionar risc.</p>
<h2>El que m''hauria agradat saber abans</h2>
<ul>
  <li><strong>El suport de nivell 1 no és un peatge, és formació.</strong> Veure per què un usuari fa alguna cosa «malament» ensenya a dissenyar sistemes que fallen menys.</li>
  <li><strong>Ningú et demanarà que automatitzis res.</strong> El primer script que vaig escriure per estalviar-me feina no me''l va demanar ningú.</li>
  <li><strong>El SOC no és una destinació, és continuar fent la mateixa pregunta.</strong> Continuo automatitzant coses que abans feia a mà, el mateix impuls que el primer script de restabliment de contrasenyes.</li>
</ul>
<p>Si ets a suport tècnic i sents que encara no estàs llest per fer el salt: probablement ja tens la part més difícil, que és entendre la infraestructura real, amb usuaris reals trencant-la de maneres que cap curs ensenya. El que falta no és més teoria: és començar a preguntar-te, davant de cada tasca repetitiva, com evitar que torni a passar.</p>',
  'carrera,soc,blue-team,automatizacion', 'carrera-personal', 'ca', 1, '2026-08-19 08:30:00', '2026-08-19 08:30:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'de-suport-tecnic-a-soc-el-que-va-canviar-no-va-ser-el-lloc');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Hardening de FortiGate: el que reviso abans de donar un desplegament per bo',
  'hardening-de-fortigate-abans-de-donar-un-desplegament-per-bo',
  'La configuració de fàbrica d''un FortiGate no està llesta per a producció només perquè bloqueja trànsit per defecte. La llista que reviso sempre, i per què la inspecció SSL s''ajorna tant.',
  '<p>La configuració de fàbrica d''un FortiGate és un punt de partida raonable, no un estat final. He heretat més d''un tallafocs ja en producció on ningú havia tocat res d''aquesta llista des del dia de la instal·lació. No és exhaustiva: és el que reviso sempre, en aquest ordre, abans de donar un desplegament per bo.</p>
<h2>Administració</h2>
<ul>
  <li>Només <strong>HTTPS</strong> a la interfície de gestió, mai HTTP, i mai exposada a la WAN.</li>
  <li>Accés restringit per <em>trusted host</em>: IP concretes, no qualsevol amb la contrasenya.</li>
  <li>Comptes nominals per administrador. Compartir l''usuari admin per defecte fa impossible saber després qui va canviar què.</li>
  <li>MFA a tots els comptes d''administració, sense excepció.</li>
</ul>
<h2>Polítiques</h2>
<p>El més comú que trobo en una auditoria no és una fallada tècnica sofisticada: és una política <code>ALL a ALL</code> que va quedar allà «temporalment» fa mesos. Reviso sempre:</p>
<ul>
  <li>Que no existeixi cap regla tan àmplia sense data de caducitat.</li>
  <li>Que totes les polítiques tinguin el <strong>logging activat</strong>. Sense logs, la resta de l''stack (SIEM, XDR) no té res per correlacionar.</li>
  <li>Que els serveis que no es fan servir estiguin deshabilitats, no només sense política que els permeti.</li>
</ul>
<h2>La inspecció SSL, que quasi sempre s''ajorna</h2>
<p>És el punt que més es retarda perquè «pot trencar alguna cosa», i sense ell el tallafocs és efectivament cec a quasi tot el trànsit modern, que va xifrat. El que faig perquè no trenqui res en activar-la:</p>
<ul>
  <li>Començar en mode d''inspecció de certificat si la inspecció completa no és viable de seguida: veure almenys l''SNI i el certificat ja aporta alguna cosa.</li>
  <li>Desplegar el certificat de la CA del FortiGate per GPO als equips del domini, per no generar avisos de certificat no fiable a cada sessió.</li>
  <li>Excepcions explícites i documentades per al que de debò no s''ha d''inspeccionar, mai una excepció perquè sí.</li>
</ul>
<h2>La regla que més aplico</h2>
<p>Si una política, una excepció o un compte d''administració no té una raó documentada de per què existeix, no hauria d''existir. La majoria de les exposicions que trobo en auditories no són fallades tècniques complexes: són configuracions «temporals» que ningú va tornar a mirar.</p>',
  'fortinet,fortigate,hardening,firewall,blue-team', 'blue-team-soc', 'ca', 1, '2026-08-02 09:00:00', '2026-08-02 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'hardening-de-fortigate-abans-de-donar-un-desplegament-per-bo');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Prioritzar CVE sense refiar-se només del CVSS',
  'prioritzar-cve-sense-refiar-se-nomes-del-cvss',
  'Un CVSS de 9,8 pot ser irrellevant i un de 6,5 una emergència. Com creuo NVD, el catàleg KEV de CISA i la probabilitat d''EPSS per decidir quina vulnerabilitat es pedaça primer.',
  '<p>L''error que més vegades he vist, i que vaig cometre jo també al principi, és ordenar una llista de CVE per CVSS i anomenar això priorització. El CVSS mesura gravetat tècnica en abstracte. No diu si algú està explotant aquesta fallada ara mateix. Són preguntes diferents, i tractar-les com si fossin la mateixa fa que es gastin setmanes en un CVE de 9,8 que ningú fa servir mentre un de 6,5 s''explota activament.</p>
<h2>Tres fonts, tres preguntes diferents</h2>
<p>Cadascuna de les següents respon alguna cosa que les altres dues no saben:</p>
<ul>
  <li><strong>NVD</strong> respon què és la fallada: CVSS, CWE, i la versió que la corregeix.</li>
  <li><strong>CISA KEV</strong> respon si s''està explotant de veritat, ara mateix, confirmat.</li>
  <li><strong>EPSS</strong> respon la probabilitat que s''exploti en els propers 30 dies, encara que encara no sigui a KEV.</li>
</ul>
<p>Cap no substitueix les altres dues. NVD sense les altres dona llistes llarguíssimes sense ordre real. KEV sol és binari: dins o fora. EPSS sol és un número sense context de què corregeix.</p>
<h2>El criteri que aplico</h2>
<p>Amb les tres creuades, l''ordre queda així, sense excepcions:</p>
<ol>
  <li>Si és a <strong>KEV</strong>, va primer. És igual el CVSS.</li>
  <li>Si no és a KEV però l''<strong>EPSS és alt</strong>, va després. És el senyal que comença a explotar-se.</li>
  <li>CVSS alt amb EPSS baix i fora de KEV pot esperar al cicle normal de pedaços.</li>
</ol>
<p>La sorpresa la primera vegada que aplico això sobre un tenant real sempre és la mateixa: la llista final no s''assembla gens a la que surt d''ordenar només per CVSS.</p>
<h2>Per què ho vaig automatitzar</h2>
<p>Creuar tres fonts a mà cada mes no escala, i és just el tipus de tasca que es salta quan hi ha pressa, que és precisament quan més falta fa. Ho vaig integrar al generador d''informes que faig servir per als clients: cada CVE que apareix s''enriqueix automàticament contra les tres fonts abans d''entrar al document, amb cache a disc per no tornar a preguntar per un CVE que ja s''ha consultat. <a href="https://github.com/eduolihez/vision-one-crem-report-generator">El codi està publicat</a> si a algú li serveix de referència.</p>
<h2>El que cap de les tres sap</h2>
<p>Ni NVD, ni KEV, ni EPSS saben si l''actiu afectat és un portàtil de proves o un controlador de domini. Això només ho sap qui coneix la xarxa. L''automatització ordena per senyal tècnic; el context de negoci continua posant-lo una persona, i aquí és on de debò es decideix què es pedaça aquesta setmana i què espera al mes que ve.</p>
<p><strong>Relacionat:</strong> <a href="/ca/blog/post/vigilar-el-cataleg-kev-de-cisa-sense-servidor/">vaig automatitzar la vigilància del mateix catàleg KEV</a> per no dependre de recordar-me de consultar-lo.</p>',
  'cve,vulnerabilidades,nvd,epss,gestion-de-riesgo', 'blue-team-soc', 'ca', 1, '2026-07-14 10:00:00', '2026-07-14 10:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'prioritzar-cve-sense-refiar-se-nomes-del-cvss');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Automatitzar l''informe setmanal del SOC amb Python',
  'automatitzar-informe-setmanal-del-soc-amb-python',
  'L''informe setmanal eren tres hores de copiar i enganxar. En automatitzar-lo amb Python, els problemes de veritat van ser la paginació, les zones horàries i les fallades en silenci.',
  '<p>Hi ha una tasca que apareix a tots els SOC: l''informe periòdic. Quantes alertes, de quin tipus, quantes tancades, quina tendència. Triga hores, surt quasi idèntic cada vegada i ningú no l''enyora quan desapareix. És el candidat perfecte per automatitzar.</p>
<p>Ho vaig muntar en Python. El codi va ser el fàcil. El que va costar va ser tota la resta.</p>

<h2>Separar les tres fases</h2>
<p>El primer intent va ser un script que consultava, calculava i escrivia el document alhora. Va funcionar una setmana i es va tornar impossible de tocar. Refet en tres parts independents:</p>
<ul>
  <li><strong>Extreure.</strong> Parlar amb l''API i desar la resposta crua, sense interpretar res.</li>
  <li><strong>Normalitzar.</strong> Passar aquesta resposta a una estructura pròpia, estable, que no canviï encara que canviï l''API.</li>
  <li><strong>Renderitzar.</strong> Convertir aquesta estructura en el document final.</li>
</ul>
<p>L''avantatge apareix a la primera incidència. Si l''informe surt estrany, se sap en quina fase mirar sense rellegir l''script sencer. I si el fabricant canvia un camp, només es toca la fase de normalitzar.</p>

<h2>La paginació, que sempre mossega</h2>
<p>L''error clàssic, i el vaig cometre: demanar les dades, rebre una llista amb bona pinta i donar-la per completa. Quasi cap API retorna tot d''un cop. Sol haver-hi un topall per pàgina i un cursor per continuar.</p>
<p>El pitjor d''aquesta fallada és que <strong>no trenca res</strong>. No hi ha excepció ni traça. Simplement l''informe diu 200 alertes on n''hi va haver 1.400, i el número sembla perfectament plausible. Va estar malament dues setmanes abans que algú ho notés.</p>
<p>Des de llavors, qualsevol consulta que pugui retornar més d''un element passa per una funció que esgota el cursor, i el resultat es contrasta amb el total que declara la mateixa API. Si no quadren, l''script s''atura.</p>

<h2>Zones horàries</h2>
<p>L''API respon en UTC. L''informe es llegeix en hora peninsular. Entre una cosa i l''altra hi ha una o dues hores segons l''època de l''any, i això desplaça el tall de la setmana.</p>
<p>El símptoma és subtil: les alertes del diumenge a la nit cauen a la setmana equivocada. Els totals del mes quadren, els setmanals no, i costa veure per què.</p>
<p>La regla que segueixo ara és simple i no l''he tornat a trencar: <strong>tot es maneja en UTC i amb dates conscients de zona horària fins a l''últim moment</strong>. La conversió a hora local passa només en escriure el text, mai en un càlcul.</p>

<h2>Que falli en alt, no en silenci</h2>
<p>Un script programat que falla sense avisar és pitjor que no tenir-lo, perquè l''absència d''informe s''interpreta com una setmana tranquil·la. El que vaig aprendre a cobrir:</p>
<ul>
  <li><strong>Reintents amb espera creixent</strong> davant de límits de peticions, en lloc de martellejar l''API.</li>
  <li><strong>Idempotència.</strong> Executar-lo dues vegades ha de produir el mateix informe, no duplicar res.</li>
  <li><strong>Un avís explícit en fallar</strong>, amb la fase que s''ha trencat. Un traceback en un log que ningú llegeix no és un avís.</li>
  <li><strong>Comprovacions de coherència:</strong> si el total de la setmana és zero, quasi segur que el trencat és l''script i no la realitat.</li>
</ul>

<h2>Què no vaig automatitzar</h2>
<p>L''anàlisi. L''script reuneix les dades, calcula les xifres i deixa el document muntat. La lectura de <em>per què</em> han pujat les deteccions d''un tipus concret, o si una caiguda és bona notícia o un sensor caigut, continua fent-la una persona.</p>
<p>Automatitzar la recollida retorna les hores que se n''anaven a copiar i enganxar. Automatitzar la conclusió produeix informes que ningú no es creu, i amb raó.</p>
<p>Aquell generador setmanal va créixer amb el temps fins a convertir-se en alguna cosa més completa: un sistema que també enriqueix cada CVE contra NVD, CISA KEV i EPSS abans de posar-lo a l''informe. El vaig publicar en obert: <a href="https://github.com/eduolihez/vision-one-crem-report-generator">el codi és a GitHub</a>.</p>',
  'python,automatizacion,soc,reporting,buenas-practicas', 'automatizacion', 'ca', 1, '2026-06-18 12:00:00', '2026-06-18 12:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'automatitzar-informe-setmanal-del-soc-amb-python');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Classificar phishing al navegador sense enviar la URL a cap servidor',
  'classificar-phishing-al-navegador-sense-enviar-la-url',
  'Les llistes de navegació segura funcionen, però impliquen explicar a algú per on navegues. A NorthGate Browser provo el contrari: portar un model ONNX petit al navegador.',
  '<p>Els navegadors fa anys que protegeixen contra el phishing amb llistes de reputació. Funciona bé i té un cost que quasi mai s''esmenta: per saber si un lloc és perillós, algú s''ha d''assabentar que vas a visitar-lo. Les implementacions serioses fan servir trucs per reduir-ho, però la forma del problema no canvia.</p>
<p><strong>NorthGate Browser</strong> és un projecte en desenvolupament primerenc on estic explorant l''altra direcció: en lloc d''enviar la URL al model, enviar el model al navegador.</p>

<h2>Què es pot saber només amb la URL</h2>
<p>Abans de descarregar res, la mateixa cadena ja diu bastant. Els senyals que faig servir surten tots d''aquí:</p>
<ul>
  <li><strong>Longitud i profunditat</strong> del domini i de la ruta.</li>
  <li><strong>Nombre de subdominis.</strong> <code>banco.seguro.login.ejemplo.tk</code> té una forma característica.</li>
  <li><strong>Entropia dels caràcters</strong>, que delata dominis generats per algorisme.</li>
  <li><strong>Presència de punycode</strong>, la via clàssica de l''atac homògraf.</li>
  <li><strong>Marca coneguda al subdomini però no al domini registrable.</strong> Aquest és el senyal més fort que he trobat, i també el més fàcil d''explicar: <code>paypal.com.verificacion-cuenta.xyz</code> no és PayPal.</li>
  <li><strong>Proporció de dígits i guions</strong>, i el TLD.</li>
</ul>
<p>Res d''això és concloent per separat. Junts, i amb prou exemples, se separen raonablement bé.</p>

<h2>Per què ONNX</h2>
<p>Entrenar és còmode en Python i executar dins d''un navegador no ho és. <strong>ONNX</strong> resol exactament aquest forat: s''entrena amb les eines de sempre, s''exporta a un format intermedi i s''executa des del runtime natiu, sense arrossegar Python al producte final.</p>
<p>En un navegador això importa per tres motius molt concrets:</p>
<ul>
  <li><strong>La mida es paga a cada instal·lació.</strong> Un model de desenes de megues no és viable dins d''un binari que la gent descarrega.</li>
  <li><strong>El pressupost de latència és minúscul.</strong> Això s''ha de resoldre abans que la pàgina pinti. Parlem d''un grapat de mil·lisegons, no de centenars.</li>
  <li><strong>No pot dependre de la xarxa.</strong> Si necessités connexió per decidir, hauríem tornat al punt de partida.</li>
</ul>
<p>La integració va en <strong>Rust</strong>, que és el llenguatge del nucli sobre el qual treballo, i encaixa bé: sense recol·lector d''escombraries, sense pauses imprevisibles en una ruta que s''executa a cada navegació.</p>

<h2>El llindar és la decisió difícil</h2>
<p>La part que més temps m''està portant no és el model, és on posar el tall. I és perquè els dos errors no costen el mateix:</p>
<ul>
  <li>Un <strong>fals negatiu</strong> deixa passar una pàgina de phishing. Dolent, però és l''estat actual sense cap protecció.</li>
  <li>Un <strong>fals positiu</strong> marca el banc real de l''usuari com a fraudulent. Això és pitjor del que sembla: ensenya la gent a ignorar l''avís. I un avís que s''ignora no protegeix de res, només dona sensació que sí.</li>
</ul>
<p>Per això el llindar està deliberadament conservador i el senyal es planteja com a advertència, no com a bloqueig. Prefereixo cobrir menys i que l''avís conservi el seu significat.</p>

<h2>Estat</h2>
<p>Està en desenvolupament primerenc i ho dic sense adorns: hi ha un pipeline d''extracció de característiques, un model que es comporta de manera raonable en validació i una integració que encara no consideraria llesta. El que té d''interessant el projecte, de moment, és la restricció de partida: <strong>si la URL no surt de l''equip, hi ha una categoria sencera de fuites que simplement no pot passar</strong>. Dissenyar amb aquesta limitació des del principi obliga a decisions força més honestes que afegir privadesa al final.</p>
<p><strong>Relacionat:</strong> <a href="/ca/blog/post/el-desacord-entre-classificadors-perd-contra-alguna-cosa-mes-simple/">vaig mesurar després si el desacord entre diversos classificadors ajuda a prioritzar quin correu revisar</a> — la resposta no va ser l''esperada.</p>',
  'machine-learning,onnx,rust,phishing,privacidad,navegadores', 'ia-aplicada', 'ca', 1, '2026-05-30 18:00:00', '2026-05-30 18:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'classificar-phishing-al-navegador-sense-enviar-la-url');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Triatge d''alertes en un SOC: en quin ordre mirar el que salta',
  'triatge-alertes-en-un-soc-en-quin-ordre-mirar',
  'La severitat d''una alerta no és la seva prioritat. Com ordeno la cua quan hi ha més alertes que hores, les tres preguntes amb què obro cadascuna i per què un fals positiu recurrent és error de la regla.',
  '<p>El primer que s''aprèn en un SOC és que la cua no es buida. Sempre hi ha més alertes que hores, i la feina no consisteix a mirar-les totes sinó a <strong>encertar l''ordre</strong>. Això és com ho enfoco jo.</p>

<h2>La severitat no és la prioritat</h2>
<p>Tota alerta arriba amb una severitat posada pel fabricant. És un punt de partida útil i un mal criteri únic, perquè aquesta etiqueta es calcula en el buit: descriu com de greu <em>seria</em> aquell esdeveniment en abstracte, sense saber res de la teva organització.</p>
<p>La prioritat real surt de creuar aquesta severitat amb el context:</p>
<ul>
  <li><strong>Quin actiu és.</strong> El mateix esdeveniment no pesa igual en un portàtil de becari que en un controlador de domini.</li>
  <li><strong>Quin usuari.</strong> Un compte amb privilegis d''administració canvia la conversa sencera.</li>
  <li><strong>Quan.</strong> Activitat normal a les onze del matí; la mateixa a les quatre de la matinada d''un diumenge mereix una mirada.</li>
  <li><strong>Què hi ha al voltant.</strong> Una alerta mitjana aïllada és soroll. Tres alertes mitjanes sobre el mateix host en deu minuts són una cadena.</li>
</ul>
<p>Aquest últim punt és on una plataforma XDR se separa d''un SIEM clàssic. Treballant amb <strong>Trend Micro Vision One</strong>, el que més m''ha canviat el triatge no és detectar més coses, sinó que els esdeveniments arribin ja <strong>correlacionats</strong>. Veure la cadena completa (correu, execució, connexió de sortida) evita l''error de tancar tres alertes per separat com a poc rellevants quan juntes expliquen una altra història.</p>

<h2>Les tres preguntes</h2>
<p>En obrir una alerta vaig sempre en el mateix ordre, i en aquest ordre concret:</p>
<ol>
  <li><strong>És real?</strong> Distingir detecció d''incident. La major part del volum mor aquí, i està bé que sigui així.</li>
  <li><strong>És rellevant?</strong> Pot ser perfectament real i no importar. Un escaneig bloquejat al perímetre és real i no és un incident.</li>
  <li><strong>Està contingut?</strong> Si ha passat alguna cosa, el que és urgent no és entendre-ho del tot: és que deixi d''estendre''s. Entendre ve després.</li>
</ol>
<p>L''ordre importa perquè l''error car és saltar-se la tercera per continuar investigant la primera. La curiositat tècnica estira molt, i contenir és avorrit comparat amb reconstruir. Contenir primer.</p>

<h2>Enriquir abans d''escalar</h2>
<p>Una alerta escalada sense context trasllada la feina al nivell següent i no estalvia res. Abans de moure alguna cosa cap amunt intento portar respost:</p>
<ul>
  <li>Què fa normalment aquell host o aquell usuari, per tenir amb què comparar.</li>
  <li>Si l''indicador apareix en fonts d''intel·ligència i des de quan.</li>
  <li>Si això ja s''havia vist abans i com es va tancar llavors.</li>
  <li>Què s''ha fet ja i què està pendent.</li>
</ul>
<p>El tercer es paga sol. La meitat de les alertes que arriben són variacions d''alguna cosa ja resolta, i sense registre de la decisió anterior l''anàlisi es repeteix sencera cada vegada.</p>

<h2>Un fals positiu recurrent és un error de la regla</h2>
<p>Aquesta és la part que més es descuida, perquè tancar ràpid sempre sembla més productiu que arreglar. Si una alerta es tanca com a fals positiu per sistema, el problema ja no és l''alerta: <strong>és la regla</strong>. Cada repetició costa atenció, i l''atenció és el recurs escàs d''un SOC.</p>
<p>Pitjor encara: una cua plena de soroll conegut educa l''equip a tancar de pressa. I el dia que entri alguna cosa de debò, arribarà amb el mateix aspecte que les mil anteriors.</p>
<p>Ajustar una regla no és abaixar la guàrdia. És decidir a consciència què mereix interrompre una persona, en lloc de deixar que ho decideixi un valor per defecte que va posar algú que no coneix la teva xarxa.</p>',
  'soc,blue-team,xdr,respuesta-a-incidentes,trend-micro-vision-one,triaje', 'blue-team-soc', 'ca', 1, '2026-04-22 09:30:00', '2026-04-22 09:30:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'triatge-alertes-en-un-soc-en-quin-ordre-mirar');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Comprovar si una contrasenya està filtrada sense enviar-la a ningú',
  'comprovar-si-una-contrasenya-esta-filtrada-sense-enviar-la-a-ningu',
  'Have I Been Pwned té més de 800 milions de contrasenyes filtrades. Es pot consultar sense revelar quina cerques: el truc es diu k-anonimat. Així el vaig implementar a Password Sentinel.',
  '<p>Quan vaig construir <strong>Password Sentinel</strong>, una extensió de navegador que avisa si una contrasenya apareix en filtracions conegudes, el problema no era tècnic sinó de confiança. Per saber si la teva contrasenya és en una bretxa cal comparar-la contra un corpus de centenars de milions. I aquest corpus no cap en una extensió.</p>
<p>La solució òbvia és preguntar-ho a un servidor. La solució òbvia és també terrible: implicaria que la meva extensió envia les teves contrasenyes a un tercer. Ningú no hauria d''instal·lar això, i jo no ho volia escriure.</p>

<h2>El truc: preguntar sense dir quines preguntes</h2>
<p>Have I Been Pwned resol això amb una tècnica anomenada <strong>k-anonimat</strong>. La idea és que en lloc de preguntar per la teva contrasenya, preguntes per un grup prou gran de candidates perquè la teva s''hi perdi dins.</p>
<p>El procediment té tres passos:</p>
<ul>
  <li>Es calcula el <code>SHA-1</code> de la contrasenya <strong>en local</strong>, dins del navegador.</li>
  <li>S''envien al servidor únicament els <strong>cinc primers caràcters</strong> hexadecimals d''aquest hash. Res més.</li>
  <li>El servidor retorna tots els hashes de la seva base que comencen per aquest prefix, i la comparació final es fa <strong>una altra vegada en local</strong>.</li>
</ul>
<pre><code>Contrasenya: correcthorsebatterystaple
SHA-1:       BE4A8DE9AFCEE30B29C0A0AB29F9E7A9CF4E1B2C
S''envia:     BE4A8
Es rep:      ~800 sufixos que comencen per BE4A8
Es compara:  al navegador, contra la llista rebuda</code></pre>

<h2>Per què els números funcionen</h2>
<p>Cinc caràcters hexadecimals donen <code>16^5</code>, una mica més d''un milió de prefixos possibles. Repartits sobre un corpus d''uns 850 milions de hashes, a cada prefix li toquen de l''ordre de <strong>800 candidats</strong>.</p>
<p>Això vol dir que el servidor sap que has preguntat per una d''unes 800 contrasenyes, sense cap manera de distingir quina. I no pot afinar amb peticions successives, perquè cada consulta retorna el grup sencer: no hi ha un segon intent que estrenyi el setge.</p>

<h2>Tres detalls que convé no passar per alt</h2>
<p><strong>SHA-1 aquí no és una fallada.</strong> És el primer que salta en llegir el protocol, i la resposta és que SHA-1 no s''està fent servir com a funció de seguretat: és l''índex del corpus. Que SHA-1 tingui col·lisions no ajuda ningú a esbrinar què vas preguntar, perquè la part sensible mai surt del navegador. Una altra cosa ben diferent seria fer servir SHA-1 per emmagatzemar contrasenyes, que sí és un error greu.</p>
<p><strong>TLS continua fent falta.</strong> El k-anonimat protegeix davant del servidor. No protegeix davant d''algú que observi la xarxa i vegi el prefix. Són dues capes diferents i les dues són necessàries.</p>
<p><strong>Zero aparicions no vol dir contrasenya bona.</strong> Aquest és el malentès més comú. Que una contrasenya no sigui al corpus només vol dir que encara no s''ha filtrat. <code>Barcelona2026!</code> probablement doni zero resultats, i continua sent una contrasenya pèssima: entra en qualsevol atac de diccionari amb regles. La comprovació de filtracions descarta el que ja se sap trencat; no certifica el que queda.</p>

<h2>El que em vaig endur d''escriure-ho</h2>
<p>El k-anonimat m''interessa menys per la criptografia que pel plantejament. La pregunta de partida no va ser <em>com xifro això</em>, sinó <strong>què és el mínim que necessita saber l''altra part per respondre''m</strong>. Quasi sempre és molt menys del que s''acaba enviant per costum.</p>
<p>És el mateix raonament que aplico a l''analítica d''aquest web: no deso adreces IP perquè per comptar visitants no me les fan falta. Deso un hash amb sal i amb això n''hi ha prou. Recollir dades que no necessites no és neutral: és assumir un risc a canvi de res.</p>
<p><strong>Relacionat:</strong> el mateix principi de minimitzar el que es confia a mans alienes apareix a <a href="/ca/blog/post/revocar-un-token-sense-enderrocar-la-sessio-sencera/">BinCat</a>, per revocar un token sense enderrocar tota la sessió.</p>',
  'criptografia,have-i-been-pwned,k-anonimato,extensiones,javascript,privacidad', 'herramientas', 'ca', 1, '2026-03-14 10:00:00', '2026-03-14 10:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'comprovar-si-una-contrasenya-esta-filtrada-sense-enviar-la-a-ningu');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Què fa un analista SOC: un dia de feina real i com començar',
  'que-fa-un-analista-soc-un-dia-de-feina-real',
  'Què fa un analista SOC en el seu dia a dia: revisar alertes, investigar, contenir i documentar. Nivells N1 a N3, eines, habilitats i com entrar-hi sense experiència.',
  '<p>Un analista SOC (Security Operations Center) vigila els sistemes d''una organització per detectar, investigar i contenir incidents de seguretat. A la pràctica, el seu dia consisteix a revisar alertes, decidir quines són reals, investigar les que ho són i escalar o contenir el que calgui. No és un lloc de «hackejar»: és un lloc d''analitzar, comparar i decidir amb rapidesa i amb poca informació.</p>
<h2>Com és un dia normal</h2>
<ol>
  <li><strong>Traspàs.</strong> Es comença llegint què va deixar obert el torn anterior: incidents en curs, alertes pendents de resposta, canvis a la infraestructura.</li>
  <li><strong>Cua d''alertes.</strong> S''obre la consola (en el meu cas Trend Micro Vision One) i s''ordena el que ha saltat. L''ordre importa més que la velocitat: ho explico a <a href="/ca/blog/post/triatge-alertes-en-un-soc-en-quin-ordre-mirar/">triatge d''alertes en un SOC</a>.</li>
  <li><strong>Investigació.</strong> Per a cada alerta real: quin actiu i quin usuari, què va passar abans i després, si l''indicador apareix en fonts d''intel·ligència, si això ja s''havia vist abans.</li>
  <li><strong>Contenció i escalat.</strong> Aïllar un equip, deshabilitar un compte, bloquejar un domini, o passar el cas al nivell següent amb tot el context ja reunit.</li>
  <li><strong>Documentació.</strong> Cada decisió queda escrita al tiquet. És la part menys vistosa i la que més estalvia l''endemà.</li>
  <li><strong>Millora.</strong> Afinar regles que generen soroll, revisar falsos positius recurrents i <a href="/ca/blog/post/automatitzar-informe-setmanal-del-soc-amb-python/">automatitzar informes</a> que es repeteixen.</li>
</ol>
<h2>Els nivells d''un SOC</h2>
<table>
  <thead><tr><th>Nivell</th><th>Què fa</th></tr></thead>
  <tbody>
    <tr><td>N1</td><td>Triatge: revisa alertes, descarta falsos positius, escala el rellevant.</td></tr>
    <tr><td>N2</td><td>Investigació i resposta: analitza incidents, conté, coordina amb altres equips.</td></tr>
    <tr><td>N3</td><td>Caça d''amenaces, anàlisi forense i de malware, enginyeria de detecció.</td></tr>
  </tbody>
</table>
<p>Els noms i els límits canvien d''una empresa a l''altra, i en un SOC petit una mateixa persona fa les tres coses.</p>
<h2>Amb quines eines es treballa</h2>
<ul>
  <li><strong>EDR / XDR</strong> per veure l''endpoint, el correu i la identitat. Què aporta cadascun és a <a href="/ca/blog/post/xdr-siem-i-edr-diferencies-en-un-soc/">XDR, SIEM i EDR</a>.</li>
  <li><strong>SIEM</strong> per centralitzar logs i cercar-hi.</li>
  <li><strong>Gestor de tiquets</strong> per registrar cada cas.</li>
  <li><strong>Fonts d''intel·ligència</strong> (VirusTotal, AbuseIPDB, el catàleg KEV de CISA) per saber si un indicador és conegut.</li>
  <li><strong>Consola de correu i d''identitat</strong> (Microsoft 365, Entra ID) per investigar <a href="/ca/blog/post/business-email-compromise-senyals-a-microsoft-365/">fraus de correu</a> i comptes compromesos.</li>
</ul>
<h2>Què cal saber per començar</h2>
<ul>
  <li>Xarxes bàsiques: TCP/IP, DNS, HTTP, què és normal en un trànsit.</li>
  <li>Windows i Active Directory: com s''autentica un usuari i quin rastre deixa.</li>
  <li>Llegir logs sense espantar-se, i saber què preguntar a una línia estranya.</li>
  <li>Una mica d''scripting (Python o PowerShell) per no repetir a mà el que es pot automatitzar.</li>
  <li>Escriure clar: un bon resum d''incident val tant com una bona detecció.</li>
</ul>
<p>Molta gent arriba des de suport tècnic o administració de sistemes, i és una bona ruta: entendre la infraestructura real pesa més que qualsevol curs. Ho explico a <a href="/ca/blog/post/de-suport-tecnic-a-soc-el-que-va-canviar-no-va-ser-el-lloc/">de suport tècnic a SOC</a>, i quines certificacions ajuden a <a href="/ca/blog/post/certificacions-per-comencar-com-a-analista-soc-quines-valen-la-pena/">certificacions per començar com a analista SOC</a>.</p>
<h2>Preguntes freqüents</h2>
<h3>Què fa un analista SOC?</h3>
<p>Monitoritza alertes de seguretat, decideix quines són incidents reals, les investiga i les conté o escala. A més documenta cada cas i ajuda a afinar les regles de detecció per reduir el soroll.</p>
<h3>Quina diferència hi ha entre un analista SOC i un pentester?</h3>
<p>L''analista SOC defensa: detecta i respon a atacs reals sobre els sistemes de l''organització. El pentester ataca de manera autoritzada per trobar debilitats abans que els atacants. Són perfils complementaris.</p>
<h3>Es pot entrar a un SOC sense experiència prèvia?</h3>
<p>Sí, en llocs de nivell 1, sobretot amb base en sistemes o xarxes, alguna certificació i pràctica en laboratoris. Els SOC solen valorar més la curiositat i la capacitat d''explicar un raonament que el títol.</p>
<h3>Cal treballar de nit?</h3>
<p>Depèn del SOC. Els que donen servei 24x7 treballen per torns; d''altres cobreixen només horari d''oficina i deixen la nit a un servei extern (MDR).</p>',
  'soc,analista-soc,blue-team,carrera,xdr', 'blue-team-soc', 'ca', 1, '2026-10-14 09:00:00', '2026-10-14 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'que-fa-un-analista-soc-un-dia-de-feina-real');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Ciberseguretat per a pimes a Barcelona i Badalona: 10 mesures per aplicar aquest mes',
  'ciberseguretat-per-a-pimes-a-barcelona-i-badalona-deu-mesures',
  'Deu mesures de ciberseguretat per a una pime amb eines que ja pagues: MFA, còpies de seguretat, baixes de comptes, DMARC i un procediment contra el frau.',
  '<p>Una pime no necessita un pressupost de gran empresa per protegir-se del que de debò li passa: correus de phishing, comptes robats, ransomware i fraus de canvi de compte bancari. Aquestes deu mesures cobreixen la major part del risc habitual d''una petita empresa a Barcelona, Badalona o qualsevol altre lloc, quasi totes es fan amb eines que ja pagues (Microsoft 365 o Google Workspace) i es poden aplicar en un mes.</p>
<h2>Les deu mesures, per ordre</h2>
<ol>
  <li><strong>MFA a tots els comptes de correu i d''administració.</strong> És la mesura que més risc treu per menys esforç. Millor si és <a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">resistent al phishing</a> almenys per a administradors i finances.</li>
  <li><strong>Còpies de seguretat que no siguin a l''abast de l''atacant.</strong> Una còpia al mateix servidor o en una unitat de xarxa sempre connectada es xifra amb la resta. La regla 3-2-1: tres còpies, dos suports, una fora. I provar de restaurar de debò, almenys una vegada.</li>
  <li><strong>Actualitzar sistemes i aplicacions.</strong> Activa les actualitzacions automàtiques i presta atenció especial a tot el que sigui exposat a internet (VPN, tallafocs, servidor de correu). Per decidir què urgeix, <a href="/ca/blog/post/prioritzar-cve-sense-refiar-se-nomes-del-cvss/">no miris només el CVSS</a>.</li>
  <li><strong>Un usuari per a cada persona, i sense permisos d''administrador al dia a dia.</strong> Qui llegeix correu no hauria de ser administrador del domini. Detall a <a href="/ca/blog/post/minim-privilegi-a-microsoft-entra-id/">mínim privilegi</a>.</li>
  <li><strong>Donar de baixa els comptes de qui se''n va, el mateix dia.</strong> És la fallada més repetida: <a href="/ca/blog/post/joiner-mover-leaver-comptes-orfes/">comptes òrfenes</a> que ningú revisa.</li>
  <li><strong>Protegir el domini de correu amb SPF, DKIM i DMARC.</strong> Evita que algú enviï correus en nom de la teva empresa. Com arribar a <a href="/ca/blog/post/spf-dkim-i-dmarc-de-p-none-a-p-reject/">p=reject</a> sense perdre correu legítim.</li>
  <li><strong>Un procediment per a canvis de compte bancari.</strong> Qualsevol canvi d''IBAN es confirma per telèfon, al número que ja tenies. És la defensa contra el <a href="/ca/blog/post/business-email-compromise-senyals-a-microsoft-365/">frau BEC</a>.</li>
  <li><strong>Antivirus amb EDR a tots els equips</strong> i el tallafocs amb la configuració revisada, no la de fàbrica.</li>
  <li><strong>Formació breu i repetida.</strong> Quinze minuts al trimestre amb exemples reals de phishing serveixen més que una xerrada anual. I una norma clara: dubtar i preguntar no és molestar.</li>
  <li><strong>Saber a qui trucar si passa alguna cosa.</strong> Un contacte tècnic, una persona amb autoritat per prendre decisions i el telèfon d''ajuda d''INCIBE (017). Millor tenir-ho escrit abans de necessitar-ho.</li>
</ol>
<h2>Si només tens una tarda</h2>
<p>MFA al correu, una còpia de seguretat desconnectada i la baixa dels comptes que ja no es fan servir. Amb aquestes tres, el risc cau molt.</p>
<h2>Normativa: què t''afecta</h2>
<p>Si tractes dades personals, el RGPD t''obliga a notificar a l''AEPD una bretxa en un termini màxim de 72 hores des que la coneixes, tret que sigui improbable que suposi risc per a les persones. Si ets proveïdor d''una empresa gran o d''un sector regulat, és probable que et arribin requisits per contracte; mira <a href="/ca/blog/post/nis2-a-espanya-estat-octubre-2026/">com està NIS2 a Espanya</a>.</p>
<h2>Recursos públics</h2>
<p>INCIBE ofereix informació i una línia d''ajuda gratuïta (017) per a empreses i ciutadans, i a Catalunya l''Agència de Ciberseguretat de Catalunya publica avisos i guies. Són un bon punt de partida abans de contractar res.</p>
<h2>Preguntes freqüents</h2>
<h3>Per on comença la ciberseguretat d''una pime?</h3>
<p>Pel correu i els comptes: MFA, baixes d''usuaris i còpies de seguretat fora de l''abast de l''atacant. És on es produeixen la majoria d''incidents reals.</p>
<h3>Una pime és objectiu d''atacs?</h3>
<p>Sí. Els atacs massius (phishing, ransomware) no trien per mida, sinó per com de fàcil sigui entrar. Les pimes solen tenir menys defenses i per això surten rendibles.</p>
<h3>Necessito un SOC propi?</h3>
<p>Normalment no. Una pime pot contractar un servei gestionat (MDR) que vigili alertes 24x7. El que sí necessita és tenir les bases cobertes i saber qui respon quan salta una alerta.</p>',
  'pymes,barcelona,badalona,ciberseguridad,mfa,backup', 'blue-team-soc', 'ca', 1, '2026-10-16 09:00:00', '2026-10-16 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'ciberseguretat-per-a-pimes-a-barcelona-i-badalona-deu-mesures');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'He fet clic a un phishing: què fer ara mateix',
  'he-fet-clic-a-un-phishing-que-fer-ara-mateix',
  'Què fer en els primers minuts després de fer clic a un phishing, segons el que va passar: només clic, contrasenya introduïda, fitxer obert o dades bancàries. I què evitar.',
  '<p>Si has fet clic en un enllaç de phishing, el que facis en els primers minuts importa més que el que passi després. L''essencial: no cal entrar en pànic, però sí actuar ja. Desconnecta l''equip de la xarxa si has descarregat o obert alguna cosa, canvia la contrasenya del compte afectat des d''un altre dispositiu, avisa qui gestioni la seguretat a la teva empresa i no esborris el correu, perquè serveix com a evidència.</p>
<h2>Què fer segons el que va passar</h2>
<h3>Vaig fer clic, però no vaig escriure res</h3>
<p>Tanca la pestanya. Si el navegador va descarregar un fitxer, no l''obris i esborra''l. Passa una anàlisi amb l''antivirus. En molts casos no ha passat res, però avisa igualment: altres persones poden haver rebut el mateix correu.</p>
<h3>Vaig escriure la meva contrasenya a la pàgina falsa</h3>
<ol>
  <li>Canvia la contrasenya ja, <strong>des d''un altre dispositiu</strong> si dubtes de l''equip.</li>
  <li>Tanca totes les sessions obertes d''aquest compte (a Microsoft 365: «Tancar sessió a tot arreu», o que l''administrador revoqui les sessions). Canviar la contrasenya sense tancar sessions pot deixar l''atacant a dins si ja té una sessió activa.</li>
  <li>Si fas servir aquesta contrasenya en altres serveis, canvia-la també allà.</li>
  <li>Revisa els mètodes d''MFA registrats: l''atacant pot haver afegit el seu.</li>
  <li>Revisa regles de safata d''entrada i reenviaments: són el primer que creen per amagar-se. Què buscar, a <a href="/ca/blog/post/business-email-compromise-senyals-a-microsoft-365/">senyals de BEC a Microsoft 365</a>.</li>
</ol>
<h3>Vaig descarregar i obrir un fitxer o vaig instal·lar alguna cosa</h3>
<ol>
  <li><strong>Desconnecta l''equip de la xarxa</strong> (cable i Wi-Fi). No l''apaguis si ho pots evitar: apagar-lo esborra informació útil per a la investigació.</li>
  <li>Avisa el responsable de seguretat o el teu proveïdor informàtic, i no continuïs fent servir aquest equip.</li>
  <li>Canvia les contrasenyes des d''un altre dispositiu, començant per correu i banca.</li>
</ol>
<h3>Vaig introduir dades d''una targeta o bancàries</h3>
<p>Truca al teu banc ja, bloqueja la targeta i demana que revisin els moviments. Si hi ha un càrrec no reconegut, denuncia davant de la Policia o els Mossos d''Esquadra.</p>
<h2>Què NO fer</h2>
<ul>
  <li>No esborris el correu ni el reenviïs a companys: es reenvia com a adjunt a l''equip de seguretat.</li>
  <li>No et quedis callat per vergonya. Un avís ràpid evita que altres hi caiguin, i qualsevol SOC prefereix vint avisos falsos a un incident tardà.</li>
  <li>No responguis a l''atacant.</li>
</ul>
<h2>Què mira l''equip de seguretat després</h2>
<p>Revisa si l''enllaç es va obrir des de més usuaris, si hi va haver un inici de sessió sospitós després del clic, si es van crear regles de safata o consentiments OAuth, i si l''equip va executar alguna cosa estranya. Amb un EDR o XDR es veu la cadena completa; és el que explico a <a href="/ca/blog/post/xdr-siem-i-edr-diferencies-en-un-soc/">XDR, SIEM i EDR</a>.</p>
<p>Perquè el pròxim clic sigui menys perillós: <a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">MFA resistent al phishing</a>, que no cau encara que l''usuari introdueixi tot a la web falsa.</p>
<h2>Preguntes freqüents</h2>
<h3>Què passa si faig clic en un enllaç de phishing?</h3>
<p>Depèn del que faci la pàgina: pot demanar-te credencials, descarregar un fitxer maliciós o només registrar que el correu és real. Fer clic sense més rarament compromet l''equip, però convé avisar.</p>
<h3>Em poden robar el compte encara que tingui MFA?</h3>
<p>Sí, amb phishing en temps real que roba també la sessió. Per això convé tancar sessions i revisar els mètodes d''MFA, i fer servir mètodes resistents al phishing.</p>
<h3>A qui aviso?</h3>
<p>En una empresa, a l''equip de seguretat o d''informàtica. Si ets particular i hi ha frau econòmic, al teu banc i a la policia. INCIBE té una línia gratuïta d''ajuda: 017.</p>',
  'phishing,respuesta-a-incidentes,guia-rapida,mfa,microsoft-365', 'blue-team-soc', 'ca', 1, '2026-10-19 09:00:00', '2026-10-19 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'he-fet-clic-a-un-phishing-que-fer-ara-mateix');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Ransomware: què fer en les primeres 24 hores',
  'ransomware-que-fer-en-les-primeres-24-hores',
  'Ordre d''actuació davant d''un ransomware: aïllar, tallar l''accés, protegir les còpies, preservar evidències, notificar a l''AEPD en 72 hores i recuperar des de còpies netes.',
  '<p>Davant d''un ransomware, les primeres 24 hores decideixen quant de dany es produeix. L''ordre d''actuació: aïllar els equips afectats per frenar la propagació, activar el pla de resposta i avisar les persones que prenen decisions, preservar evidències, avaluar l''abast, i només després pensar a recuperar. I quasi mai pagar: no garanteix recuperar les dades i les autoritats ho desaconsellen.</p>
<h2>Primera hora: contenir</h2>
<ol>
  <li><strong>Aïlla, no apaguis.</strong> Desconnecta de la xarxa (cable, Wi-Fi, VPN) els equips amb símptomes: fitxers amb extensions estranyes, notes de rescat, equips lents. Apagar-los pot destruir informació en memòria útil per a la investigació; si l''aïllament no és possible, llavors sí, apagar és millor que deixar que continuï xifrant.</li>
  <li><strong>Talla l''accés de l''atacant.</strong> Deshabilita els comptes compromesos (començant pels privilegiats), revoca sessions i bloqueja accessos remots (RDP, VPN) sospitosos. Si l''atacant té credencials d''administrador de domini, assumeix que tota la xarxa està compromesa.</li>
  <li><strong>Protegeix les còpies de seguretat.</strong> Desconnecta les còpies de la resta de la xarxa abans que el ransomware les xifri o les esborri. Els atacants les busquen expressament.</li>
  <li><strong>Reuneix l''equip de crisi.</strong> Tècnics, direcció, qui porti comunicació i assessoria legal. Una persona decideix, una altra documenta cada acció amb hora.</li>
</ol>
<h2>Primeres hores: entendre</h2>
<ul>
  <li><strong>Preserva evidències.</strong> Notes de rescat, llistes de fitxers afectats, logs del tallafocs i del controlador de domini, mostres de l''executable. No reinstal·lis equips encara.</li>
  <li><strong>Esbrina el vector d''entrada</strong> abans de restaurar: un accés remot exposat, un compte robat per phishing, una vulnerabilitat sense pedaç. Si no es tanca, l''atacant torna.</li>
  <li><strong>Avalua quines dades s''han exfiltrat.</strong> Avui el més habitual és la doble extorsió: xifren i a més roben dades per amenaçar amb publicar-les.</li>
</ul>
<h2>Avisos i obligacions</h2>
<ul>
  <li>Si hi ha dades personals afectades, el RGPD obliga a notificar la bretxa a l''AEPD en un màxim de 72 hores des que la coneixes, tret que sigui improbable que suposi un risc per a les persones.</li>
  <li>Si la teva empresa entra a l''àmbit de NIS2 o de la normativa sectorial, hi ha terminis de notificació específics (consulta <a href="/ca/blog/post/nis2-a-espanya-estat-octubre-2026/">on és NIS2 a Espanya</a>).</li>
  <li>Denuncia a la Policia Nacional, la Guàrdia Civil o els Mossos d''Esquadra, i informa INCIBE-CERT. També avisa la teva asseguradora si tens ciberassegurança: algunes pòlisses exigeixen avisar en termini.</li>
</ul>
<h2>Recuperació</h2>
<ol>
  <li>Restaura des de còpies <strong>netes</strong>, comprovant que la còpia és anterior a la intrusió.</li>
  <li>Reconstrueix els sistemes crítics des d''imatge neta en lloc de netejar a mà el que estava compromès.</li>
  <li>Canvia totes les credencials, especialment les de comptes de servei i administració, i revisa <a href="/ca/blog/post/joiner-mover-leaver-comptes-orfes/">comptes òrfenes</a> i accessos que no haurien d''existir.</li>
  <li>Reconnecta per fases, amb monitorització reforçada.</li>
</ol>
<h2>Pagar el rescat?</h2>
<p>Les autoritats ho desaconsellen: no hi ha garantia de rebre una clau que funcioni, finança els atacants i et marca com a pagador. És una decisió de la direcció amb assessorament legal i, si es contempla, amb una empresa especialitzada. Tenir còpies fora de línia és el que evita arribar a plantejar-se la pregunta.</p>
<h2>El que evita arribar aquí</h2>
<ul>
  <li><a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">MFA</a> a tots els accessos remots i comptes d''administració.</li>
  <li>Còpies de seguretat desconnectades i provades.</li>
  <li><a href="/ca/blog/post/errors-de-configuracio-al-cloud-mes-repetits/">Sense ports d''administració exposats a internet</a> i amb pedaços al dia.</li>
  <li>Un EDR o <a href="/ca/blog/post/xdr-siem-i-edr-diferencies-en-un-soc/">XDR</a> vigilat, amb algú que respongui a l''alerta.</li>
</ul>
<h2>Preguntes freqüents</h2>
<h3>Què és el ransomware?</h3>
<p>Un malware que xifra els fitxers d''una organització i exigeix un pagament a canvi de la clau per recuperar-los. Cada cop més, també roba les dades abans de xifrar per pressionar amb la seva publicació.</p>
<h3>Es poden recuperar els fitxers sense pagar?</h3>
<p>A vegades. Amb còpies netes, sí. En alguns casos hi ha desxifradors gratuïts per a certes famílies; el projecte No More Ransom reuneix els disponibles.</p>
<h3>Cal apagar l''ordinador infectat?</h3>
<p>El preferible és aïllar-lo de la xarxa sense apagar-lo, per conservar evidències. Si no pots aïllar-lo i continua xifrant, apaga''l.</p>',
  'ransomware,respuesta-a-incidentes,backup,rgpd,incidentes', 'blue-team-soc', 'ca', 1, '2026-10-21 09:00:00', '2026-10-21 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'ransomware-que-fer-en-les-primeres-24-hores');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Certificacions per començar com a analista SOC: quines valen la pena',
  'certificacions-per-comencar-com-a-analista-soc-quines-valen-la-pena',
  'Security+, SC-200, CySA+ i BTL1: què aporta cada certificació per a un primer lloc en un SOC, quines deixar per més endavant i què pesa més que qualsevol títol.',
  '<p>Per començar com a analista SOC no hi ha una certificació obligatòria, però algunes ajuden a passar el primer filtre i a ordenar el que cal aprendre. Les més habituals en ofertes de nivell 1 són CompTIA Security+, Microsoft SC-200, CompTIA CySA+ i Blue Team Level 1 (BTL1). Pesen molt menys que demostrar que saps investigar una alerta, així que l''ideal és combinar una certificació amb pràctica real en laboratoris.</p>
<h2>Les certificacions més útils per començar</h2>
<table>
  <thead><tr><th>Certificació</th><th>Per a qui</th><th>Què aporta</th></tr></thead>
  <tbody>
    <tr><td>CompTIA Security+</td><td>Punt de partida general</td><td>Base àmplia: amenaces, controls, risc, criptografia. Molt reconeguda en ofertes.</td></tr>
    <tr><td>Microsoft SC-200 (Security Operations Analyst)</td><td>Entorns Microsoft</td><td>Defender XDR, Sentinel i KQL: molt pràctica si el SOC fa servir Microsoft.</td></tr>
    <tr><td>CompTIA CySA+</td><td>Ja amb base de seguretat</td><td>Anàlisi d''amenaces, logs i resposta a incidents, orientada a SOC.</td></tr>
    <tr><td>Blue Team Level 1 (BTL1)</td><td>Qui vol pràctica</td><td>Examen pràctic de 24 hores sobre phishing, DFIR, intel·ligència i SIEM.</td></tr>
    <tr><td>Certificacions de fabricant (Trend Micro, Fortinet, Splunk...)</td><td>Segons l''eina del SOC</td><td>Demostren el maneig de la plataforma concreta que faràs servir.</td></tr>
  </tbody>
</table>
<p>Les certificacions de fabricant pesen segons el lloc: si el SOC treballa amb aquesta eina, són de les que més es noten.</p>
<h2>Les que deixaria per més endavant</h2>
<p>Les certificacions d''alt nivell (GIAC com GCIH o GCFA, o similars) són cares i es valoren més quan ja hi ha experiència. Val la pena fer-les quan la teva empresa les finança o quan ja saps en quina especialitat vols créixer: resposta a incidents, forense o intel·ligència.</p>
<h2>El que pesa més que qualsevol títol</h2>
<ul>
  <li><strong>Pràctica en laboratoris.</strong> Plataformes com TryHackMe, LetsDefend o Blue Team Labs Online permeten simular alertes reals d''un SOC. Un perfil amb casos resolts val més que una llista de cursos.</li>
  <li><strong>Alguna cosa pròpia per ensenyar.</strong> Un script que automatitzi una tasca, una anàlisi publicada, una eina petita. Per exemple, <a href="/ca/blog/post/automatitzar-informe-setmanal-del-soc-amb-python/">automatitzar un informe</a> o <a href="/ca/blog/post/vigilar-el-cataleg-kev-de-cisa-sense-servidor/">vigilar el catàleg KEV</a> demostren criteri, no només teoria.</li>
  <li><strong>Base de sistemes i xarxes.</strong> Molts bons analistes vénen de suport o administració: <a href="/ca/blog/post/de-suport-tecnic-a-soc-el-que-va-canviar-no-va-ser-el-lloc/">aquest camí funciona</a>.</li>
  <li><strong>Saber explicar.</strong> En una entrevista, explicar com investigaries una alerta pas a pas pesa més que recitar sigles. Si no saps com funciona un dia de feina, comença per <a href="/ca/blog/post/que-fa-un-analista-soc-un-dia-de-feina-real/">què fa un analista SOC</a>.</li>
</ul>
<h2>Una ruta raonable</h2>
<ol>
  <li>Base de xarxes, Windows i Linux, i Active Directory.</li>
  <li>Security+ si necessites el segell; si ja tens base, ves directe a SC-200 o BTL1.</li>
  <li>Pràctiques en laboratoris mentre estudies, i documenta el que fas.</li>
  <li>Certificació de l''eina concreta del SOC al qual aspires.</li>
  <li>Una especialitat (IAM, cloud, resposta a incidents) quan ja tinguis experiència.</li>
</ol>
<h2>Preguntes freqüents</h2>
<h3>Quina certificació demana més un SOC de nivell 1?</h3>
<p>Security+ és la que més apareix com a requisit general; SC-200 i les de fabricant pesen quan el SOC fa servir aquestes eines.</p>
<h3>Cal carrera universitària?</h3>
<p>No sempre. Molts SOC valoren experiència, certificacions i pràctica per sobre del títol, encara que alguns llocs el demanen.</p>
<h3>Quant costen?</h3>
<p>Varien molt i canvien cada any: convé consultar el preu actual a la web de l''organisme. Algunes empreses financen la formació, i els exàmens de fabricant de vegades són gratuïts o estan inclosos en programes de partners.</p>',
  'certificaciones,soc,carrera,security-plus,sc-200', 'carrera-personal', 'ca', 1, '2026-10-23 09:00:00', '2026-10-23 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'certificacions-per-comencar-com-a-analista-soc-quines-valen-la-pena');

INSERT INTO `posts` (`title`, `slug`, `summary`, `content`, `tags`, `category`, `lang`, `visible`, `published_at`, `created_at`)
SELECT
  'Auditar els permisos de Microsoft 365 en una tarda',
  'auditar-els-permisos-de-microsoft-365-en-una-tarda',
  'Auditoria bàsica de permisos de Microsoft 365 en unes hores: administradors, MFA, comptes sense ús, consentiments OAuth i reenviaments, amb PowerShell de només lectura.',
  '<p>Es pot fer una auditoria bàsica de permisos de Microsoft 365 en una tarda si es limita al que concentra més risc: administradors, convidats externs, comptes sense MFA o sense ús, aplicacions amb consentiment i reenviaments de correu. No substitueix una auditoria completa, però troba les fallades que fan servir els atacants i que quasi sempre s''acumulen sense que ningú les miri.</p>
<p>Necessites un rol de lectura (Global Reader o Security Reader) i el mòdul de PowerShell de Microsoft Graph. Tot el que segueix és de només lectura.</p>
<h2>1. Administradors (30 minuts)</h2>
<p>Llista qui té rols privilegiats i per què. Més de cinc administradors globals ja és un senyal d''alerta, i cadascun hauria de poder justificar-se. El detall de quins rols fer servir en el seu lloc és a <a href="/ca/blog/post/minim-privilegi-a-microsoft-entra-id/">mínim privilegi a Entra ID</a>.</p>
<pre><code>Connect-MgGraph -Scopes "RoleManagement.Read.Directory","User.Read.All"
Get-MgDirectoryRole -All | ForEach-Object {
  $rol = $_.DisplayName
  Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id |
    ForEach-Object { [pscustomobject]@{ Rol = $rol; Usuario = $_.AdditionalProperties.userPrincipalName } }
}</code></pre>
<h2>2. MFA (30 minuts)</h2>
<p>L''informe de registre de mètodes d''autenticació mostra qui no té MFA i qui fa servir mètodes febles.</p>
<pre><code>Connect-MgGraph -Scopes "AuditLog.Read.All"
Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Where-Object { -not $_.IsMfaRegistered } |
  Select-Object UserPrincipalName, IsAdmin</code></pre>
<p>Primer els administradors sense MFA, després finances i direcció. Per quins mètodes exigir, mira <a href="/ca/blog/post/mfa-resistent-al-phishing-per-que-sms-ja-no-basta/">MFA resistent al phishing</a>.</p>
<h2>3. Comptes sense ús i convidats (30 minuts)</h2>
<pre><code>Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All"
Get-MgUser -All -Property DisplayName,UserPrincipalName,UserType,SignInActivity,AccountEnabled |
  Where-Object { $_.AccountEnabled -and $_.SignInActivity.LastSignInDateTime -lt (Get-Date).AddDays(-90) } |
  Select-Object UserPrincipalName, UserType, @{n=''UltimAcces'';e={$_.SignInActivity.LastSignInDateTime}}</code></pre>
<p>Compte habilitat sense accés en 90 dies: pregunta al seu responsable. Els convidats externs (<code>UserType = Guest</code>) mereixen revisió a part: continuen col·laborant? A quins equips tenen accés? Aquest mateix problema, en versió de cicle de vida, és el de <a href="/ca/blog/post/joiner-mover-leaver-comptes-orfes/">les comptes òrfenes</a>. Tingues en compte que <code>SignInActivity</code> requereix llicència Entra ID P1.</p>
<h2>4. Aplicacions amb consentiment (30 minuts)</h2>
<p>Les aplicacions OAuth amb permisos com <code>Mail.Read</code> o <code>Files.Read.All</code> continuen tenint accés encara que canviïs la contrasenya.</p>
<pre><code>Connect-MgGraph -Scopes "Directory.Read.All"
Get-MgOauth2PermissionGrant -All |
  Select-Object ClientId, ConsentType, Scope</code></pre>
<p>Busca aplicacions desconegudes amb permisos amplis i consentiment d''usuari. Revoca el que ningú reconegui i restringeix qui pot donar consentiment.</p>
<h2>5. Reenviaments de correu (20 minuts)</h2>
<pre><code>Connect-ExchangeOnline
Get-Mailbox -ResultSize Unlimited |
  Where-Object { $_.ForwardingSmtpAddress -or $_.ForwardingAddress } |
  Select-Object UserPrincipalName, ForwardingSmtpAddress, ForwardingAddress</code></pre>
<p>Un reenviament a una adreça externa que ningú recorda haver creat és un dels senyals de <a href="/ca/blog/post/business-email-compromise-senyals-a-microsoft-365/">BEC</a>. Revisa també les regles de safata que reenvien o mouen correu.</p>
<h2>6. Polítiques d''accés (20 minuts)</h2>
<p>Comprova que existeixen les polítiques base i que cap compte està exclòs sense motiu. Llista i ordre a <a href="/ca/blog/post/acces-condicional-microsoft-365-politiques-base/">accés condicional: les polítiques base</a>. Mira també la puntuació de seguretat (Secure Score) al portal de Defender, que serveix com a llista de tasques prioritzada.</p>
<h2>Què fer amb el que trobis</h2>
<ol>
  <li>Anota cada troballa amb responsable i data, en un full.</li>
  <li>Arregla primer el que sigui de risc alt i esforç baix: MFA a administradors, baixes de comptes, reenviaments desconeguts.</li>
  <li>Repeteix cada trimestre. La utilitat d''una auditoria és en la comparació entre dates.</li>
</ol>
<h2>Preguntes freqüents</h2>
<h3>Cada quant convé revisar els permisos?</h3>
<p>Com a mínim cada trimestre, i sempre després de canvis grans (fusions, sortides de personal clau, migracions).</p>
<h3>Necessito llicències especials?</h3>
<p>Per al bàsic no. L''activitat d''inici de sessió requereix Entra ID P1, i les revisions d''accés automàtiques, Entra ID Governance.</p>
<h3>És segur executar aquestes ordres?</h3>
<p>Són de només lectura i no modifiquen res, però prova-les primer amb un compte de lectura i revisa l''abast dels permisos que concedeixes a Graph.</p>',
  'microsoft-365,entra-id,auditoria,powershell,iam', 'cloud-iam', 'ca', 1, '2026-10-25 09:00:00', '2026-10-25 09:00:00'
WHERE NOT EXISTS (SELECT 1 FROM `posts` WHERE `slug` = 'auditar-els-permisos-de-microsoft-365-en-una-tarda');



-- ===========================================================================
--  7. LIMPIEZA
--  Los helpers ya han hecho su trabajo: no deben quedarse en la base de datos.
-- ===========================================================================
DROP PROCEDURE IF EXISTS `add_column_if_missing`;
DROP PROCEDURE IF EXISTS `add_index_if_missing`;
DROP PROCEDURE IF EXISTS `seed_if_empty`;
DROP PROCEDURE IF EXISTS `repair_legacy_posts`;
