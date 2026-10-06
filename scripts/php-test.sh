#!/usr/bin/env bash
# Corre PHPUnit (server/) con PHP local, sin Docker ni Composer.
# Uso: bash scripts/php-test.sh [args de phpunit]
# PHP: usa $PHP_BIN si está definido; si no, el PHP de winget si existe; si no, `php` del PATH.
set -e

PHAR=".superpowers/tools/phpunit.phar"
# PHPUnit fijado: version exacta + SHA-256. El enlace sin version (phpunit-10.5.phar) cambia con cada
# parche, asi que no sirve para fijar nada. Para subir de version: baja la nueva, comprueba su firma
# GPG (phpunit-<v>.phar.asc, clave D840 6D0D 8294 7747 2937 7831 4AA3 9408 6372 C20A) y actualiza ambas lineas.
PHPUNIT_VERSION="10.5.66"
PHPUNIT_SHA256="42bcac97bbf9fb1aecf5a7d6a1b37123a11e7e295458978f0e268999f6d9e50f"
WINGET_PHP="/c/Users/$USER/AppData/Local/Microsoft/WinGet/Packages/PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe/php.exe"
[ -f "$WINGET_PHP" ] || WINGET_PHP="${LOCALAPPDATA:-}/Microsoft/WinGet/Packages/PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe/php.exe"

if [ -n "${PHP_BIN:-}" ]; then
  :
elif [ -f "$WINGET_PHP" ]; then
  PHP_BIN="$WINGET_PHP"
else
  PHP_BIN="php"
fi

if [ ! -f "$PHAR" ]; then
  echo "Falta $PHAR. Descárgalo con:" >&2
  echo "  mkdir -p .superpowers/tools && curl -sSfL -o $PHAR https://phar.phpunit.de/phpunit-$PHPUNIT_VERSION.phar" >&2
  exit 1
fi

# No se ejecuta un phar que no coincida con el hash fijado (descarga corrupta o cambiada).
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA256="$(sha256sum "$PHAR" | cut -d' ' -f1)"
else
  ACTUAL_SHA256="$(shasum -a 256 "$PHAR" | cut -d' ' -f1)"
fi
if [ "$ACTUAL_SHA256" != "$PHPUNIT_SHA256" ]; then
  echo "SHA-256 de $PHAR no coincide con el fijado para PHPUnit $PHPUNIT_VERSION." >&2
  echo "  esperado: $PHPUNIT_SHA256" >&2
  echo "  obtenido: $ACTUAL_SHA256" >&2
  echo "Vuelve a descargarlo (comando de arriba) o, si subes de version, actualiza PHPUNIT_VERSION y PHPUNIT_SHA256." >&2
  exit 1
fi

FLAGS=()
if ! "$PHP_BIN" -m | grep -qix mbstring; then
  FLAGS+=(-d "extension_dir=$(dirname "$PHP_BIN")/ext" -d extension=mbstring)
fi

exec "$PHP_BIN" "${FLAGS[@]}" "$PHAR" "$@"
