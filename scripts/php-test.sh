#!/usr/bin/env bash
# Corre PHPUnit (server/) con PHP local, sin Docker ni Composer.
# Uso: bash scripts/php-test.sh [args de phpunit]
# PHP: usa $PHP_BIN si está definido; si no, el PHP de winget si existe; si no, `php` del PATH.
set -e

PHAR=".superpowers/tools/phpunit.phar"
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
  echo "  mkdir -p .superpowers/tools && curl -sSfL -o $PHAR https://phar.phpunit.de/phpunit-10.5.phar" >&2
  exit 1
fi

FLAGS=()
if ! "$PHP_BIN" -m | grep -qix mbstring; then
  FLAGS+=(-d "extension_dir=$(dirname "$PHP_BIN")/ext" -d extension=mbstring)
fi

exec "$PHP_BIN" "${FLAGS[@]}" "$PHAR" "$@"
