-- ===========================================================================
--  LIMPIEZA DE DATOS  ·  Portfolio Eduardo Olivares
--  Motor: MySQL / MariaDB (CDMON)
--
--  QUE HACE: vacia el contenido de la base de datos CONSERVANDO la estructura
--  (las tablas siguen existiendo, solo se quedan sin filas).
--
--  >>> ESTO NO SE PUEDE DESHACER. <<<
--  Antes de ejecutarlo, exporta una copia desde /admin/backup.php.
--
--  COMO USARLO (CDMON):
--    phpMyAdmin -> tu base de datos -> pestana "Importar" -> este archivo.
--
--  QUE NO BORRA (a proposito):
--    - `settings`     -> la configuracion del sitio (banner, open to work...)
--    - `admin_users`  -> tu usuario y contrasena del panel
--  Si quieres borrarlos tambien, descomenta el bloque 4 del final. Ojo: sin
--  usuarios tendrias que volver a subir /admin/setup.php para crear uno.
--
--  Este archivo NO crea ni modifica tablas: de eso se encarga schema.sql.
-- ===========================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------------
-- 1. Contenido del portfolio (proyectos, certificaciones y blog)
--    Tras esto la web se ve vacia hasta que vuelvas a crear contenido en
--    /admin o restaures una copia desde /admin/backup.php.
-- ---------------------------------------------------------------------------
TRUNCATE TABLE `projects`;
TRUNCATE TABLE `certifications`;
TRUNCATE TABLE `posts`;

-- ---------------------------------------------------------------------------
-- 2. Mensajes del formulario de contacto
--    Son datos personales de terceros. Si los necesitas, exportalos antes
--    desde el buzon (/admin/messages.php -> Exportar CSV).
-- ---------------------------------------------------------------------------
TRUNCATE TABLE `messages`;

-- ---------------------------------------------------------------------------
-- 3. Analitica y registros internos
--    Estas tres se purgan solas con el tiempo (400 / 90 / 365 dias). Vaciarlas
--    a mano sirve para empezar de cero o para liberar espacio.
-- ---------------------------------------------------------------------------
TRUNCATE TABLE `visits`;
TRUNCATE TABLE `login_attempts`;
TRUNCATE TABLE `activity_log`;

-- ---------------------------------------------------------------------------
-- 4. REINICIO TOTAL (desactivado)
--    Quita los "--" de las dos lineas siguientes SOLO si quieres borrar
--    tambien la configuracion del sitio y las credenciales del panel.
-- ---------------------------------------------------------------------------
-- TRUNCATE TABLE `settings`;
-- TRUNCATE TABLE `admin_users`;

SET FOREIGN_KEY_CHECKS = 1;
