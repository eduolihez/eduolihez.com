-- ===========================================================================
--  ESQUEMA DE BASE DE DATOS - Portfolio Eduardo Olivares
--  Motor: MySQL / MariaDB (CDMON)
--  Charset: utf8mb4 (soporta acentos, emojis, etc.)
--
--  COMO IMPORTARLO EN CDMON:
--    1. Crea una base de datos MySQL desde el panel de CDMON.
--    2. Entra en phpMyAdmin -> pestana "Importar" -> selecciona este archivo.
--    (No incluye "CREATE DATABASE": importalo DENTRO de la base ya creada.)
--
--  Incluye datos de ejemplo (tus proyectos y certificaciones reales) para
--  que la web no salga vacia. Puedes editarlos luego desde el panel /admin.
-- ===========================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;

-- ---------------------------------------------------------------------------
-- Usuarios del panel de administracion
-- (La contrasena se establece con /admin/setup.php la primera vez.)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_users` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`      VARCHAR(60)  NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `last_login`    DATETIME     NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Intentos de login (control de fuerza bruta del panel)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `login_attempts` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ip_address`   VARCHAR(45)  NOT NULL,
  `username`     VARCHAR(60)  NULL,
  `success`      TINYINT(1)   NOT NULL DEFAULT 0,
  `attempted_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ip_time` (`ip_address`, `attempted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Proyectos (contenido dinamico, editable desde el panel)
-- ---------------------------------------------------------------------------
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
  `repo_url`       VARCHAR(255) NULL,
  `demo_url`       VARCHAR(255) NULL,
  `store_url`      VARCHAR(255) NULL,
  `featured`       TINYINT(1)   NOT NULL DEFAULT 0,
  `sort_order`     INT          NOT NULL DEFAULT 0,
  `status`         ENUM('published','draft') NOT NULL DEFAULT 'published',
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_status_order` (`status`, `featured`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Certificaciones (contenido dinamico, editable desde el panel)
-- ---------------------------------------------------------------------------
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
-- Mensajes del formulario de contacto (buzon persistente)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `messages` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) NOT NULL,
  `email`      VARCHAR(150) NOT NULL,
  `subject`    VARCHAR(150) NULL,
  `message`    TEXT         NOT NULL,
  `ip_address` VARCHAR(45)  NULL,                     -- soporta IPv6
  `user_agent` VARCHAR(255) NULL,
  `is_read`    TINYINT(1)   NOT NULL DEFAULT 0,
  `is_starred` TINYINT(1)   NOT NULL DEFAULT 0,
  `is_archived` TINYINT(1)  NOT NULL DEFAULT 0,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_read` (`is_read`),
  KEY `idx_created` (`created_at`),
  KEY `idx_ip_time` (`ip_address`, `created_at`)      -- para el rate-limit
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Visitas (analitica propia; la IP se guarda hasheada, sin datos personales)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `visits` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `path`       VARCHAR(255) NOT NULL,
  `referrer`   VARCHAR(255) NOT NULL DEFAULT '',
  `ip_hash`    CHAR(64)     NULL,                     -- sha256 con sal
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

-- ---------------------------------------------------------------------------
-- Registro de auditoria del panel (quien hizo que y cuando)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `activity_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id`   INT UNSIGNED NULL,
  `username`   VARCHAR(60)  NULL,
  `action`     VARCHAR(40)  NOT NULL,                 -- create | update | delete | login
  `entity`     VARCHAR(40)  NULL,                     -- project | certification | ...
  `entity_id`  INT UNSIGNED NULL,
  `details`    VARCHAR(255) NULL,
  `ip_address` VARCHAR(45)  NULL,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_time` (`created_at`),
  KEY `idx_entity` (`entity`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Ajustes del sitio (clave/valor). Para toggles como "Open to work".
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `settings` (
  `key`        VARCHAR(60)  NOT NULL,
  `value`      TEXT         NULL,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Blog / notas tecnicas (PREPARADO PARA EL FUTURO, no se usa aun)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `posts` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `slug`         VARCHAR(180) NOT NULL,
  `title_es`     VARCHAR(200) NOT NULL,
  `title_en`     VARCHAR(200) NULL,
  `excerpt_es`   VARCHAR(400) NULL,
  `excerpt_en`   VARCHAR(400) NULL,
  `body_es`      MEDIUMTEXT   NULL,
  `body_en`      MEDIUMTEXT   NULL,
  `cover_url`    VARCHAR(255) NULL,
  `tags`         VARCHAR(255) NULL,
  `status`       ENUM('published','draft') NOT NULL DEFAULT 'draft',
  `published_at` DATETIME     NULL,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_slug` (`slug`),
  KEY `idx_status_pub` (`status`, `published_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Experiencia (OPCIONAL / FUTURO).
-- Nota: actualmente la web lee la experiencia desde el codigo
-- (src/data/experience.ts). Esta tabla queda lista por si algun dia quieres
-- gestionarla tambien desde el panel.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `experiences` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `company`        VARCHAR(120) NOT NULL,
  `role_es`        VARCHAR(150) NOT NULL,
  `role_en`        VARCHAR(150) NULL,
  `location`       VARCHAR(120) NULL,
  `start_date`     VARCHAR(20)  NULL,
  `end_date`       VARCHAR(20)  NULL,
  `is_current`     TINYINT(1)   NOT NULL DEFAULT 0,
  `description_es` TEXT         NULL,
  `description_en` TEXT         NULL,
  `technologies`   TEXT         NULL,                 -- JSON o CSV
  `sort_order`     INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET foreign_key_checks = 1;

-- ===========================================================================
--  DATOS DE EJEMPLO (tus proyectos y certificaciones reales)
--  Puedes editarlos/borrarlos desde el panel /admin cuando quieras.
-- ===========================================================================

INSERT INTO `projects`
  (`title_es`, `title_en`, `summary_es`, `summary_en`, `stack`, `repo_url`, `demo_url`, `store_url`, `featured`, `sort_order`, `status`)
VALUES
  ('Dewi App',
   'Dewi App',
   'Prototipo web ganador de la 8a Hackathon TecnoCampus para monitorizar el consumo de agua en tiempo real.',
   'Award-winning web prototype (8th TecnoCampus Hackathon) to monitor water consumption in real time.',
   '["Next.js","TypeScript","Tailwind CSS"]',
   'https://github.com/eduolihez/hackathon-Dewi', NULL, NULL, 1, 1, 'published'),

  ('BinCat',
   'BinCat',
   'Sistema de gestion segura de tokens en Python con cifrado Fernet y almacenamiento en SQLite.',
   'Secure token management system in Python using Fernet encryption and SQLite storage.',
   '["Python","Cryptography (Fernet)","SQLite"]',
   'https://github.com/eduolihez/BinCat', NULL, NULL, 1, 2, 'published'),

  ('NorthGate Browser',
   'NorthGate Browser',
   'Navegador (fork de Mullvad/Firefox) con clasificador de phishing on-device en ONNX/Rust. En desarrollo temprano.',
   'Browser (Mullvad/Firefox fork) with an on-device phishing classifier in ONNX/Rust. Early stage.',
   '["Rust","ONNX","Firefox","Machine Learning"]',
   'https://github.com/eduolihez/northgate-browser', NULL, NULL, 1, 3, 'published'),

  ('Password Sentinel',
   'Password Sentinel',
   'Extension de Chrome que comprueba la seguridad de tus contrasenas con Have I Been Pwned, sin enviar datos a ningun servidor.',
   'Chrome extension that checks password safety against Have I Been Pwned, without sending data to any server.',
   '["JavaScript","Chrome Extension","Have I Been Pwned API"]',
   NULL, '/projects/passwdcentinel/', NULL, 0, 4, 'published'),

  ('PromptMaster Universal AI',
   'PromptMaster Universal AI',
   'Extension de Chrome que optimiza tus prompts para ChatGPT, Claude y Gemini.',
   'Chrome extension that optimizes your prompts for ChatGPT, Claude and Gemini.',
   '["JavaScript","Chrome Extension","Prompt Engineering"]',
   NULL, '/projects/promptmaster/', 'https://addons.mozilla.org/es-ES/firefox/addon/promptmaster/', 0, 5, 'published');

INSERT INTO `certifications`
  (`name`, `issuer`, `issue_date`, `credential_url`, `logo_url`, `category`, `visible`, `sort_order`)
VALUES
  ('Fortinet NSE', 'Fortinet', '2026', NULL, NULL, 'Network Security', 1, 1),
  ('Microsoft Certified: Azure AI Fundamentals', 'Microsoft', '2026', NULL, NULL, 'AI / Cloud', 1, 2),
  ('Trend Micro Vision One Platform - Advanced', 'Trend Micro', '2024', '/certificaciones/TrendAI/TrendAI%20Vision%20One%20Platform%20Advanced.pdf', NULL, 'XDR / SecOps', 1, 3),
  ('TryHackMe Pre-Security', 'TryHackMe', '2023', '/certificaciones/THM-R3JSJHVXSI.pdf', NULL, 'Cybersecurity', 1, 4),
  ('Introducción a la Ciberseguridad', 'Cisco Networking Academy', '2023', '/certificaciones/Cisco/Introduccion%20a%20la%20Ciberseguridad.pdf', NULL, 'Cybersecurity', 1, 5),
  ('Introduction to Modern AI', 'Cisco Networking Academy', '2024', '/certificaciones/Cisco/Introduction%20to%20Modern%20AI.pdf', NULL, 'AI / Cloud', 1, 6),
  ('Fundamentos profesionales en ciberseguridad', 'Microsoft / LinkedIn', '2023', '/certificaciones/LinkedIn/CertificadoDeFinalizacion_Fundamentos%20profesionales%20en%20ciberseguridad%20por%20Microsoft%20y%20LinkedIn.pdf', NULL, 'Cybersecurity', 1, 7),
  ('Microsoft Copilot para Seguridad', 'LinkedIn', '2024', '/certificaciones/LinkedIn/CertificadoDeFinalizacion_Microsoft%20Copilot%20para%20Seguridad.pdf', NULL, 'AI / Cloud', 1, 8),
  ('Iniciación al Desarrollo con IA', 'Google / Santander', '2024', '/certificaciones/Certificado_Iniciación_Al_Desarrollo_Con_IA.pdf', NULL, 'AI / Cloud', 1, 9),
  ('Domina la IA con Gemini', 'Google / Santander', '2024', '/certificaciones/Domina%20la%20IA%20con%20Gemini.pdf', NULL, 'AI / Cloud', 1, 10),
  ('First Certificate in English (B2)', 'Cambridge English', '2021', '/certificaciones/First%20Certificate.jpg', NULL, 'Idiomas', 1, 11),
  ('IC3 Digital Literacy GS6 Level 1', 'Certiport', '2023', '/certificaciones/IC3%20GS6%20Level%201.pdf', NULL, 'Sistemas', 1, 12),
  ('Python', 'OpenBootcamp', '2023', '/certificaciones/Python.pdf', NULL, 'Desarrollo', 1, 13),
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
  ('Certificado de Vela - Acceso', 'Federació Catalana de Vela', '2022', '/certificaciones/Certificat%20vela_prova%20acces.pdf', NULL, 'Otros', 1, 32);

-- Ajustes iniciales del sitio (todos editables desde /admin/settings.php).
INSERT IGNORE INTO `settings` (`key`, `value`) VALUES
  ('open_to_work',      '1'),   -- badge "Disponible" del hero
  ('contact_enabled',   '1'),   -- formulario de contacto activo
  ('analytics_enabled', '1'),   -- registro de visitas activo
  ('announcement_on',   '0'),   -- banner superior activo
  ('announcement_es',   ''),
  ('announcement_en',   ''),
  ('announcement_ca',   ''),
  ('announcement_url',  '');
