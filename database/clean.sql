-- ===========================================================================
--  SCRIPT DE LIMPIEZA DE DATOS - Portfolio Eduardo Olivares
--  Motor: MySQL / MariaDB (CDMON)
--  Uso: Vacía los datos dinámicos de la base de datos conservando la estructura.
-- ===========================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- 1. Vaciar tablas de estadísticas, visitas y logs
TRUNCATE TABLE `visits`;
TRUNCATE TABLE `activity_log`;
TRUNCATE TABLE `login_attempts`;
TRUNCATE TABLE `messages`;

-- 2. Vaciar tablas de contenido del portafolio
TRUNCATE TABLE `projects`;
TRUNCATE TABLE `certifications`;
TRUNCATE TABLE `experiences`;
TRUNCATE TABLE `posts`;

-- 3. Descomenta las siguientes líneas si deseas realizar un reinicio TOTAL
--    (Eliminará también la configuración del sitio y las credenciales de administrador)
-- TRUNCATE TABLE `settings`;
-- TRUNCATE TABLE `admin_users`;

SET FOREIGN_KEY_CHECKS = 1;
