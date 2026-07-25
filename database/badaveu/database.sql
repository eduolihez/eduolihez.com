-- ============================================================
--  BadaVeu — Plataforma Ciutadana de Badalona
--  database.sql  |  v3.0  |  Estructura completa + Mock data
-- ============================================================
--  Ús: executar com a usuari amb privilegis sobre la BD.
--  AVÍS: El DROP TABLE eliminarà totes les dades existents.
-- ============================================================

-- ── 1. BASE DE DADES ──────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS `badaveu`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE `badaveu`;

-- ── 2. NETEJA (ordre invers de FK) ────────────────────────────
DROP TABLE IF EXISTS `historial_incidencias`;
DROP TABLE IF EXISTS `incidencias`;
DROP TABLE IF EXISTS `admins`;

-- ── 3. TAULA: admins ─────────────────────────────────────────
CREATE TABLE `admins` (
    `id`              INT            NOT NULL AUTO_INCREMENT,
    `usuario`         VARCHAR(255)   NOT NULL,
    `password`        VARCHAR(255)   NOT NULL COMMENT 'bcrypt hash',
    `role`            ENUM('superadmin','admin','gestor')
                                     NOT NULL DEFAULT 'gestor',
    `access_type`     ENUM('all','infraestructura','denuncia')
                                     NOT NULL DEFAULT 'all',
    `district_access` VARCHAR(255)   DEFAULT NULL
                      COMMENT 'Llista de districtes separats per comes, o NULL per a tots',
    `created_at`      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_usuario` (`usuario`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

-- ── 4. TAULA: incidencias ────────────────────────────────────
CREATE TABLE `incidencias` (
    -- Identificació
    `id`          INT          NOT NULL AUTO_INCREMENT,

    -- Contingut principal
    `titulo`      VARCHAR(150) NOT NULL
                  COMMENT 'Màxim 150 caràcters, sanititzat (htmlspecialchars)',
    `descripcion` TEXT         DEFAULT NULL
                  COMMENT 'Màxim 1500 caràcters, sanititzat',

    -- Classificació
    `categoria`    ENUM('infraestructura','denuncia')
                                NOT NULL,
    `tipo_problema` VARCHAR(100) NOT NULL
                    COMMENT 'Subtipus: Neteja, Mobiliari Urbà, Barrera Arquitectònica, etc.',

    -- Localització
    `direccion`   VARCHAR(255) DEFAULT NULL,
    `cp`          VARCHAR(10)  DEFAULT NULL,
    `lat`         DECIMAL(10,8) NOT NULL,
    `lng`         DECIMAL(11,8) NOT NULL,
    `barri`       VARCHAR(100) DEFAULT NULL,
    `districte`   VARCHAR(10)  DEFAULT NULL,

    -- Gestió
    `urgencia`    ENUM('baja','media','alta')
                                NOT NULL DEFAULT 'media',
    `afectacion`  ENUM('individual','col·lectiva')
                                NOT NULL DEFAULT 'individual',
    `estado`      ENUM('pendiente','proceso','resuelto')
                                NOT NULL DEFAULT 'pendiente',

    -- Contacte ciutadà (pot ser NULL)
    `email`       VARCHAR(255) DEFAULT NULL,

    -- Multimedia
    `foto_url`    VARCHAR(512) DEFAULT NULL
                  COMMENT 'Ruta relativa a uploads/. Nom generat amb uniqid(), sense nom original.',

    -- Popularitat
    `votos`       INT          NOT NULL DEFAULT 0,
    `views`       INT          NOT NULL DEFAULT 0,

    -- Soft delete: archivado=1 oculta la incidència sense eliminar-la físicament
    -- (preserva historial i permet auditoria / exportació posterior)
    `archivado`   TINYINT(1)   NOT NULL DEFAULT 0
                  COMMENT '0 = activa, 1 = arxivada (soft delete). Mai eliminar físicament.',

    -- Timestamps
    `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_estado`    (`estado`),
    KEY `idx_categoria` (`categoria`),
    KEY `idx_barri`     (`barri`),
    KEY `idx_districte` (`districte`),
    KEY `idx_created`   (`created_at`),
    KEY `idx_archivado` (`archivado`)   -- filtre principal en totes les queries de lectura

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

-- ── 5. TAULA: historial_incidencias ─────────────────────────
CREATE TABLE `historial_incidencias` (
    `id`              INT  NOT NULL AUTO_INCREMENT,
    `incidencia_id`   INT  NOT NULL,

    `estado_anterior` ENUM('pendiente','proceso','resuelto')
                          DEFAULT NULL
                          COMMENT 'NULL quan és la primera entrada',
    `estado_nuevo`    ENUM('pendiente','proceso','resuelto')
                          NOT NULL,

    `comentario_admin` TEXT DEFAULT NULL
                        COMMENT 'Missatge públic cap al ciutadà (màx 500 car.)',
    `admin_usuario`    VARCHAR(255) DEFAULT NULL,

    `fecha`           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_hist_incidencia` (`incidencia_id`),
    KEY `idx_hist_fecha`      (`fecha`),

    CONSTRAINT `fk_hist_incidencia`
        FOREIGN KEY (`incidencia_id`)
        REFERENCES  `incidencias` (`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  USUARI ADMINISTRADOR
--
--  Aquest fitxer NO crea cap administrador, i és a propòsit.
--
--  Abans hi havia un INSERT amb l'usuari 'admin@badaveu.cat', rol
--  'superadmin' i el seu hash bcrypt escrit aquí mateix. Aquest fitxer està
--  versionat en un repositori PÚBLIC, així que aquell hash el podia
--  descarregar qualsevol i provar de trencar-lo sense límit de temps ni
--  intents. El nom d'usuari i el rol ja eren informació pública. Si el
--  volcat s'importava sense canviar després la contrasenya, quedava un
--  accés de superadministrador obert.
--
--  Crea l'administrador TU, amb una contrasenya que només sàpigues tu:
--
--    1) Genera el hash a la teva màquina (no el desis enlloc):
--         php -r "echo password_hash('LA_TEVA_PASSWORD', PASSWORD_BCRYPT, ['cost' => 12]), PHP_EOL;"
--
--    2) Insereix-lo directament a phpMyAdmin, enganxant el hash del pas 1:
--         INSERT INTO `admins` (`usuario`, `password`, `role`, `access_type`, `district_access`)
--         VALUES ('el_teu_usuari', 'HASH_DEL_PAS_1', 'superadmin', 'all', NULL);
--
--  Mai enganxis la contrasenya en clar ni el hash en cap fitxer del projecte.
-- ============================================================


-- ============================================================
--  MOCK DATA — 6 incidències representatives de Badalona
--  (coordenades aproximades, dades realistes en CA/ES)
-- ============================================================

-- ── Incidència 1: Neteja ─────────────────────────────────────
INSERT INTO `incidencias`
    (titulo, descripcion, categoria, tipo_problema,
     direccion, cp, lat, lng, barri, districte,
     urgencia, afectacion, estado, votos, views, email, foto_url,
     archivado, created_at, updated_at)
VALUES (
    'Acumulació de bosses d\'escombraries al carrer Indústria',
    'Hi ha una gran acumulació de bosses d\'escombraries al costat dels contenidors del carrer Indústria, '
    'cantonada amb el carrer Progrés. Les bosses porten almenys 3 dies sense recollir i desprenen males olors. '
    'Afecta a tota la vorera i dificulta el pas de vianants.',
    'infraestructura',
    'Neteja',
    'Carrer Indústria, 45, cantonada Carrer Progrés', '08911',
    41.44831200, 2.24715600,
    'Centre', '2',
    'alta', 'col·lectiva', 'pendiente',
    12, 47, NULL, NULL,
    0,
    DATE_SUB(NOW(), INTERVAL 3 DAY), NULL
);

-- ── Incidència 2: Mobiliari Urbà ─────────────────────────────
INSERT INTO `incidencias`
    (titulo, descripcion, categoria, tipo_problema,
     direccion, cp, lat, lng, barri, districte,
     urgencia, afectacion, estado, votos, views, email, foto_url,
     archivado, created_at, updated_at)
VALUES (
    'Banc públic trencat al Passeig de la Salut',
    'Un dels bancs del Passeig de la Salut, a l\'alçada del número 18, presenta el seient '
    'completament trencat amb fragments de fusta esmolats que poden causar talls. '
    'S\'ha vist a nens petits intentant seure-hi. Cal reparar-lo o retirar-lo urgentment.',
    'infraestructura',
    'Mobiliari Urbà',
    'Passeig de la Salut, 18', '08912',
    41.45102300, 2.23387400,
    'La Salut', '3',
    'media', 'col·lectiva', 'proceso',
    8, 33, NULL, NULL,
    0,
    DATE_SUB(NOW(), INTERVAL 7 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY)
);

-- ── Incidència 3: Barrera Arquitectònica ─────────────────────
INSERT INTO `incidencias`
    (titulo, descripcion, categoria, tipo_problema,
     direccion, cp, lat, lng, barri, districte,
     urgencia, afectacion, estado, votos, views, email, foto_url,
     archivado, created_at, updated_at)
VALUES (
    'Rampa d\'accés obstruïda per vehicles aparcats il·legalment',
    'La rampa d\'accés per a persones amb mobilitat reduïda ubicada a la Plaça de la Vila, '
    'davant de la Biblioteca, està constantment bloquejada per vehicles que aparquen damunt la vorera. '
    'Una persona usuària de cadira de rodes ha hagut de baixar a la calçada posant-se en perill. '
    'Cal senyalització i vigilància.',
    'infraestructura',
    'Barrera Arquitectònica',
    'Plaça de la Vila, 1', '08911',
    41.44650800, 2.24432100,
    'Centre', '2',
    'alta', 'col·lectiva', 'resuelto',
    21, 88, 'ciutada@exemple.cat', NULL,
    0,
    DATE_SUB(NOW(), INTERVAL 14 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY)
);

-- ── Incidència 4: Il·luminació ───────────────────────────────
INSERT INTO `incidencias`
    (titulo, descripcion, categoria, tipo_problema,
     direccion, cp, lat, lng, barri, districte,
     urgencia, afectacion, estado, votos, views, email, foto_url,
     archivado, created_at, updated_at)
VALUES (
    'Quatre fanals apagats al Carrer Sant Anastasi',
    'Des de fa aproximadament 10 dies, quatre fanals consecutius del carrer Sant Anastasi '
    '(entre els números 12 i 28) estan apagats. La zona queda completament fosca a partir '
    'de les 21h, generant sensació d\'inseguretat entre els veïns, especialment a l\'hivern.',
    'infraestructura',
    'Il·luminació',
    'Carrer Sant Anastasi, 12-28', '08911',
    41.44523700, 2.24918300,
    'Centre', '2',
    'media', 'col·lectiva', 'pendiente',
    15, 62, NULL, NULL,
    0,
    DATE_SUB(NOW(), INTERVAL 10 DAY), NULL
);

-- ── Incidència 5: Parcs i Jardins ────────────────────────────
INSERT INTO `incidencias`
    (titulo, descripcion, categoria, tipo_problema,
     direccion, cp, lat, lng, barri, districte,
     urgencia, afectacion, estado, votos, views, email, foto_url,
     archivado, created_at, updated_at)
VALUES (
    'Arbre caigut bloqueja camí principal del Parc de la Pau',
    'Arrel del temporal de vent de la setmana passada, un arbre de gran port ha caigut '
    'al camí principal del Parc de la Pau, bloquejant completament el pas. '
    'El tronc sobresurt cap al carrer adjacent. Pot ser un perill per als vianants '
    'i per al trànsit. Cal retirada urgent.',
    'infraestructura',
    'Parcs i Jardins',
    'Parc de la Pau, accés principal pel Carrer Pau Casals', '08917',
    41.45387100, 2.21943600,
    'Morera-Pomar', '6',
    'alta', 'col·lectiva', 'proceso',
    18, 74, 'veins.lloreda@exemple.cat', NULL,
    0,
    DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY)
);

-- ── Incidència 6: Seguretat (Denúncia) ───────────────────────
INSERT INTO `incidencias`
    (titulo, descripcion, categoria, tipo_problema,
     direccion, cp, lat, lng, barri, districte,
     urgencia, afectacion, estado, votos, views, email, foto_url,
     archivado, created_at, updated_at)
VALUES (
    'Pintades vandalisme a la façana de l\'escola Antoni Botey',
    'Durant la nit del divendres al dissabte, desconeguts han fet pintades amb spray '
    'de gran mida a la façana principal de l\'escola Antoni Botey. Les pintades contenen '
    'símbols i missatges inapropiats visibles per als alumnes. La comunitat educativa '
    'demana actuació ràpida per netejar-les abans de l\'inici de la setmana.',
    'denuncia',
    'Seguretat',
    'Carrer Fluvià, 12', '08913',
    41.45678900, 2.22841500,
    'Llefià', '5',
    'alta', 'col·lectiva', 'pendiente',
    31, 115, NULL, NULL,
    0,
    DATE_SUB(NOW(), INTERVAL 1 DAY), NULL
);


-- ============================================================
--  HISTORIAL DE CANVIS D'ESTAT (vinculat als mocks anteriors)
-- ============================================================

-- Incidència 2 (Banc Passeig Salut): pendiente → proceso
INSERT INTO `historial_incidencias`
    (incidencia_id, estado_anterior, estado_nuevo, comentario_admin, admin_usuario, fecha)
VALUES (
    2,
    'pendiente', 'proceso',
    'S\'ha creat ordre de treball a Serveis Urbans. El banc serà revisat i reparat en un termini de 5 dies hàbils.',
    'admin@badaveu.cat',
    DATE_SUB(NOW(), INTERVAL 2 DAY)
);

-- Incidència 3 (Rampa PL Vila): pendiente → proceso → resuelto
INSERT INTO `historial_incidencias`
    (incidencia_id, estado_anterior, estado_nuevo, comentario_admin, admin_usuario, fecha)
VALUES (
    3,
    'pendiente', 'proceso',
    'Notificació traslladada a la Policia Local perquè efectuï controls periòdics a la zona.',
    'admin@badaveu.cat',
    DATE_SUB(NOW(), INTERVAL 10 DAY)
);

INSERT INTO `historial_incidencias`
    (incidencia_id, estado_anterior, estado_nuevo, comentario_admin, admin_usuario, fecha)
VALUES (
    3,
    'proceso', 'resuelto',
    'S\'han instal·lat dos pilons retràctils per protegir la rampa i s\'ha augmentat la vigilància policial. '
    'La rampa ja és accessible. Gràcies per reportar-ho, la vostra participació millora Badalona!',
    'admin@badaveu.cat',
    DATE_SUB(NOW(), INTERVAL 1 DAY)
);

-- Incidència 5 (Arbre Parc Pau): pendiente → proceso
INSERT INTO `historial_incidencias`
    (incidencia_id, estado_anterior, estado_nuevo, comentario_admin, admin_usuario, fecha)
VALUES (
    5,
    'pendiente', 'proceso',
    'Equip de jardineria desplaçat al Parc de la Pau. La retirada de l\'arbre es realitzarà demà a primera hora.',
    'admin@badaveu.cat',
    DATE_SUB(NOW(), INTERVAL 1 DAY)
);


-- ============================================================
--  ÍNDEXS ADDICIONALS DE RENDIMENT
-- ============================================================
ALTER TABLE `incidencias`
    ADD INDEX `idx_estado_created` (`estado`, `created_at` DESC),
    ADD INDEX `idx_lat_lng` (`lat`, `lng`);

ALTER TABLE `historial_incidencias`
    ADD INDEX `idx_hist_estado_nuevo` (`estado_nuevo`);


-- ============================================================
--  FI DEL FITXER
-- ============================================================
