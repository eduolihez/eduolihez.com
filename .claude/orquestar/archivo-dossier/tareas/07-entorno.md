# Entorno de pruebas del admin (T07a) — sin contraseñas

Todo vive en `.playwright-mcp/` (excluido de git). No toca el servicio MariaDB instalado ni `server/config.php`.

1. MariaDB desechable (puerto 3399, solo localhost):
   `"/c/Program Files/MariaDB 13.0/bin/mariadb-install-db.exe" --datadir="E:\Proyectos\Github\eduolihez.com\.playwright-mcp\mariadb-test-data" --port=3399`
   `"/c/Program Files/MariaDB 13.0/bin/mariadbd.exe" --datadir="...\.playwright-mcp\mariadb-test-data" --port=3399 --bind-address=127.0.0.1 --console` (en segundo plano)
2. BD y usuario: `CREATE DATABASE eduolihez_test CHARACTER SET utf8mb4;` + usuario `e2e_test`@`127.0.0.1`/`localhost` con contraseña aleatoria (guardada fuera del repo, en `%TEMP%\t07a-secrets\env`, variables `DBPW` y `APW`), `GRANT ALL ON eduolihez_test.*`. Esquema: `mariadb -uroot -h127.0.0.1 -P3399 --default-character-set=utf8mb4 eduolihez_test < database/schema.sql`.
3. Espejo `.playwright-mcp/t07a-env/` (porque `server/config.php` del repo no es de test y no se lee): `sh .playwright-mcp/t07a-env/sync.sh` copia `server/` (sin config.php ni uploads) y `e2e/`. Su `server/config.php` se genera desde `config.example.php` con host `127.0.0.1`, name `eduolihez_test`, user `e2e_test`, pass de `DBPW` y `charset => 'utf8mb4;port=3399'` (db.php no admite puerto; el guard de e2e solo mira host y name). `npm ci` dentro de `t07a-env/e2e`.
4. PHP sin php.ini: `t07a-env/php-test.ini` con `extension_dir` y `extension=pdo_mysql,mbstring,openssl,fileinfo,curl,sodium,intl`.
   Servidor: `cd .playwright-mcp/t07a-env && php -c php-test.ini -S 127.0.0.1:8081 -t server`
5. Seed: `cd t07a-env/e2e && DB_HOST=127.0.0.1 DB_PORT=3399 DB_NAME=eduolihez_test DB_USER=e2e_test DB_PASS="$DBPW" E2E_USER=e2e E2E_PASSWORD="$APW" php -c ../php-test.ini seed/seed.php`
6. Suite: `E2E_USER=e2e E2E_PASSWORD="$APW" E2E_CHROME_PATH="C:/Program Files/Google/Chrome/Application/chrome.exe" npx playwright test`
7. Capturas y comprobaciones (overflow, objetivos 44 px, aria-current, script/style inline): `E2E_USER=e2e E2E_PASSWORD="$APW" node shots.cjs` desde `t07a-env/` → `.playwright-mcp/t07a/`.
8. Parar: `mariadb-admin -uroot -h127.0.0.1 -P3399 shutdown` y matar el `php -S` del 8081.
