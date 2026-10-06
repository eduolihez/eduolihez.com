#!/usr/bin/env bash
# Tests de scripts/pack-admin.sh sobre un repositorio git desechable (mktemp -d).
# No toca el repo real. Uso: bash scripts/pack-admin.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
PACK="$SCRIPT_DIR/pack-admin.sh"
REAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)" || exit 1

PASS=0
FAIL=0
ok()  { echo "PASS  $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL  $1"; FAIL=$((FAIL + 1)); }
# check "descripcion" comando...  -> PASS si el comando sale con 0
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
# nocheck: PASS si el comando sale con != 0
nocheck() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }

# --- Seguridad del propio test -------------------------------------------------
# Este script hace "git init", "git config" y commits forzados de un config.php
# falso. Si el directorio temporal no se pudiera crear o entrar, eso ocurriria
# en el repositorio REAL. Por eso: nada de git hasta haber validado el
# directorio, y la limpieza solo borra lo que este script creo.
aborta() { echo "ABORTADO: $*" >&2; exit 1; }

# Modos de autocomprobacion (los lanza este mismo script mas abajo): simulan un
# mktemp roto y git queda sustituido por una funcion que delata cualquier uso.
SIM="${1:-}"
case "$SIM" in
  --simula-mktemp-falla)  mktemp() { return 1; } ;;
  --simula-mktemp-vacio)  mktemp() { echo ""; } ;;
  --simula-mktemp-ajeno)  mktemp() { pwd; } ;;   # devuelve un dir que no hemos creado
  "") ;;
  *) aborta "argumento desconocido: $SIM" ;;
esac
if [ -n "$SIM" ]; then
  git() { echo "GIT-LLAMADO: el test habria tocado git con un directorio temporal inutilizable" >&2; exit 97; }
fi

TMP_PREFIX="pack-admin-test"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/$TMP_PREFIX.XXXXXX")" || aborta "mktemp -d fallo"
[ -n "$TMP" ] && [ -d "$TMP" ] || aborta "directorio temporal vacio o inexistente ('$TMP')"
case "$(basename "$TMP")" in "$TMP_PREFIX".*) ;; *) aborta "'$TMP' no parece un directorio creado por este test" ;; esac
TMP="$(cd "$TMP" && pwd -P)" || aborta "no se puede entrar en '$TMP'"
[ "$TMP" != "$REAL_REPO" ] && [ "$TMP" != "$(pwd -P)" ] || aborta "el directorio temporal es el directorio actual o el repo real"

# Solo se borra lo que este script creo (nombre con nuestro prefijo).
limpiar() {
  case "$(basename "$TMP")" in
    "$TMP_PREFIX".*) [ -d "$TMP" ] && rm -rf "$TMP" ;;
  esac
}
trap limpiar EXIT

# Autocomprobacion: con un mktemp roto el test debe abortar (exit 1) SIN llegar
# a ejecutar git, y el repo real no cambia. Se lanza desde el repo real a
# proposito: si la guarda fallara, git (sustituido) delataria el intento.
if [ -z "$SIM" ]; then
  snap() { git -C "$REAL_REPO" status --porcelain; git -C "$REAL_REPO" rev-parse HEAD; git -C "$REAL_REPO" config --local --list; }
  ANTES="$(snap 2>&1)"
  for modo in --simula-mktemp-falla --simula-mktemp-vacio --simula-mktemp-ajeno; do
    SALIDA="$(cd "$REAL_REPO" && bash "$SELF" "$modo" 2>&1)"; RC=$?
    if [ "$RC" -eq 1 ] && echo "$SALIDA" | grep -q "ABORTADO" && ! echo "$SALIDA" | grep -q "GIT-LLAMADO"; then
      ok "guarda del test: aborta sin tocar git ($modo)"
    else
      bad "guarda del test: aborta sin tocar git ($modo) [rc=$RC]"
    fi
  done
  if [ "$ANTES" = "$(snap 2>&1)" ]; then ok "guarda del test: el repo real queda intacto"; else bad "guarda del test: el repo real queda intacto"; fi
fi
[ -z "$SIM" ] || aborta "modo $SIM: la guarda no ha abortado"

REPO="$TMP/repo"
mkdir -p "$REPO" || aborta "no se pudo crear $REPO"
cd "$REPO" || aborta "no se pudo entrar en $REPO"
# Ultima barrera antes de "git init": estamos dentro del temporal y, si git ve
# un repo aqui, es uno de dentro del temporal (nunca el real).
case "$(pwd -P)" in "$TMP"/*) ;; *) aborta "cwd fuera del directorio temporal: $(pwd -P)" ;; esac
if TOP="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  case "$TOP" in "$TMP"/*) ;; *) aborta "git ve un repo fuera del temporal: $TOP" ;; esac
fi
git init -q . || aborta "git init fallo"
git config core.ignorecase false   # NTFS lo activa; los casos de mayusculas necesitan indice sensible
git config user.name test
git config user.email test@example.invalid
git config commit.gpgsign false
git config tag.gpgsign false
git config core.autocrlf false

mkf() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

mkf server/admin/index.php "<?php // index v1"
mkf server/admin/borrar.php "<?php // se borrara"
mkf server/admin/setup.php "<?php // setup"
mkf server/admin/assets/app.css "body{}"
mkf server/lib/util.php "<?php // util"
mkf server/api/x.php "<?php // api"
mkf server/uploads/.htaccess "Deny from all"
mkf server/.htaccess "Options -Indexes"
mkf server/config.php "<?php // CONFIG SECRETA"
mkf server/config.example.php "<?php // ejemplo"
mkf server/tests/UnTest.php "<?php // test"
mkf server/tests/.htaccess "Deny from all"
# El script resuelve la raiz del repo desde su propia ubicacion: se prueba la
# copia que vive dentro del repo desechable, no el repo real.
mkdir -p scripts
cp "$PACK" scripts/pack-admin.sh
PACK="$REPO/scripts/pack-admin.sh"
mkf README.md "fuera de server"
mkf e2e/spec.js "fuera de server"
git add -A -f
git commit -q -m "base"
git tag v1.0.0.1

mkf server/admin/index.php "<?php // index v2"
git rm -q server/admin/borrar.php
mkf server/admin/nuevo.php "<?php // nuevo"
mkf server/config.php "<?php // CONFIG SECRETA v2"
mkf server/admin/setup.php "<?php // setup v2"
mkf server/tests/UnTest.php "<?php // test v2"
git add -A -f
git commit -q -m "cambios"
git tag v1.0.0.2

# Un fichero sin commitear (y uno ignorado) que NUNCA debe empaquetarse.
mkf server/admin/sin-commit.php "<?php // no commiteado"

out() { echo "$TMP/out-$1"; }
run() { bash "$PACK" "$@"; }

# 1. full: contiene lo esperado y excluye lo prohibido -----------------------
O="$(out full)"
if run --mode full --out "$O" >/dev/null 2>&1; then ok "full: termina con 0"; else bad "full: termina con 0"; fi
for f in admin/index.php admin/nuevo.php admin/assets/app.css lib/util.php api/x.php uploads/.htaccess .htaccess admin/borrar.php; do
  # borrar.php ya no existe en v1.0.0.2 (HEAD): no debe estar
  if [ "$f" = admin/borrar.php ]; then
    check "full: no incluye fichero borrado en HEAD ($f)" test ! -e "$O/public_html/$f"
  else
    check "full: incluye $f" test -f "$O/public_html/$f"
  fi
done
for f in config.php config.example.php admin/setup.php tests; do
  check "full: excluye $f" test ! -e "$O/public_html/$f"
done
check "full: no hay prefijo server/ en la salida" test ! -e "$O/public_html/server"
check "full: contenido es el de HEAD (v2)" grep -q "index v2" "$O/public_html/admin/index.php"
check "full: no empaqueta ficheros fuera de server/" test ! -e "$O/public_html/README.md"
check "full: no empaqueta el fichero sin commitear" test ! -e "$O/public_html/admin/sin-commit.php"
check "full: sin ELIMINAR.txt" test ! -e "$O/ELIMINAR.txt"
check "full: existe MANIFEST.txt" test -f "$O/MANIFEST.txt"

# 2. MANIFEST con sha256 correcto -----------------------------------------------
if command -v sha256sum >/dev/null 2>&1; then H="$(sha256sum "$O/public_html/admin/index.php" | cut -d' ' -f1)"
else H="$(shasum -a 256 "$O/public_html/admin/index.php" | cut -d' ' -f1)"; fi
check "MANIFEST: sha256 correcto de admin/index.php" grep -qx "$H  admin/index.php" "$O/MANIFEST.txt"
check "MANIFEST: cabecera con modo y SHA corto" grep -q "^hasta:  HEAD ($(git rev-parse --short HEAD))" "$O/MANIFEST.txt"

# 3. changes entre dos tags ----------------------------------------------------
O="$(out chg)"
if run --mode changes --from v1.0.0.1 --to v1.0.0.2 --out "$O" >/dev/null 2>&1; then ok "changes: termina con 0"; else bad "changes: termina con 0"; fi
check "changes: incluye el modificado" test -f "$O/public_html/admin/index.php"
check "changes: incluye el nuevo" test -f "$O/public_html/admin/nuevo.php"
check "changes: no incluye lo que no cambio" test ! -e "$O/public_html/lib/util.php"
for f in config.php admin/setup.php tests; do
  check "changes: excluye $f aunque cambio" test ! -e "$O/public_html/$f"
done
check "changes: ELIMINAR.txt lista el borrado" grep -qx "admin/borrar.php" "$O/ELIMINAR.txt"
check "changes: ELIMINAR.txt no lista excluidos" bash -c "! grep -q -e setup.php -e config.php '$O/ELIMINAR.txt'"
check "changes: ELIMINAR.txt explica el borrado manual" grep -qi "a mano" "$O/ELIMINAR.txt"

# 4. from por defecto: el tag v*.*.*.* mas reciente alcanzable desde <to>^ -----
O="$(out def)"
run --mode changes --to v1.0.0.2 --out "$O" >/dev/null 2>&1
check "changes: --from por defecto = tag previo (v1.0.0.1)" grep -q "^desde:  v1.0.0.1 " "$O/MANIFEST.txt"
nocheck "changes: sin tag previo y sin --from falla" run --mode changes --to v1.0.0.1 --out "$(out nofrom)"
check "changes: el fallo sin --from no crea salida" test ! -e "$(out nofrom)"
MSG="$(run --mode changes --to v1.0.0.1 --out "$(out nofrom2)" 2>&1 || true)"
check "changes: el mensaje sugiere --from" bash -c "echo '$MSG' | grep -q -- '--from'"

# 5. sin cambios: exit 0, aviso, sin salida ni zip -------------------------------
O="$(out vacio)"
if run --mode changes --from v1.0.0.2 --to HEAD --out "$O" --zip "$TMP/vacio.zip" >"$TMP/vacio.log" 2>&1; then ok "sin cambios: exit 0"; else bad "sin cambios: exit 0"; fi
check "sin cambios: avisa" grep -qi "sin cambios" "$TMP/vacio.log"
check "sin cambios: no crea carpeta" test ! -e "$O"
check "sin cambios: no crea zip" test ! -e "$TMP/vacio.zip"

# 6. --out no vacia se rechaza ----------------------------------------------------
O="$(out ocupada)"
mkdir -p "$O"
echo x > "$O/previo.txt"
nocheck "out no vacia: se rechaza" run --mode full --out "$O"
check "out no vacia: no se toca su contenido" test -f "$O/previo.txt"
check "out no vacia: no se mezcla nada" test ! -e "$O/MANIFEST.txt"
O2="$(out vaciaok)"
mkdir -p "$O2"
check "out vacia existente: se acepta" run --mode full --out "$O2"

# 7. guarda: apiKey de 64 hex trackeada aborta ---------------------------------
KEY="$(printf 'ab%.0s' $(seq 1 32))"
mkf server/api/leak.json "{\"apiKey\": \"$KEY\"}"
git add server/api/leak.json
git commit -q -m "leak"
O="$(out leak)"
nocheck "guarda apiKey: sale != 0" run --mode full --out "$O" --zip "$TMP/leak.zip"
check "guarda apiKey: no genera zip" test ! -e "$TMP/leak.zip"
LOG="$(run --mode full --out "$(out leak2)" 2>&1 || true)"
check "guarda apiKey: informa del fallo" bash -c "echo '$LOG' | grep -q FALLO"
git rm -q server/api/leak.json
mkf server/api/pk.pem "-----BEGIN RSA PRIVATE KEY-----"
git add server/api/pk.pem
git commit -q -m "pk"
nocheck "guarda clave privada: sale != 0" run --mode full --out "$(out pk)"
git rm -q server/api/pk.pem
git commit -q -m "limpio"

# 8. guarda: ficheros prohibidos (config.php force-added en subcarpeta) -----------
# Los excluidos de ruta fija ya se filtran; un telemetry.config.json trackeado
# debe frenar el paquete.
mkf server/api/telemetry.config.json "{}"
git add server/api/telemetry.config.json
git commit -q -m "telemetry"
nocheck "guarda telemetry.config.json: sale != 0" run --mode full --out "$(out tele)"
git rm -q server/api/telemetry.config.json
git commit -q -m "sin telemetry"

# 8b. config.php anidado (no es de ruta fija: lo frena la guarda posterior) ---
mkf server/admin/config.php "<?php // config anidada"
git add -f server/admin/config.php
git commit -q -m "config anidada"
nocheck "guarda config.php anidado (server/admin/config.php): sale != 0" run --mode full --out "$(out cfgnest)"
git rm -q server/admin/config.php
git commit -q -m "sin config anidada"

# Entradas del indice sin tocar el arbol de trabajo (en Windows/macOS no se
# pueden crear dos ficheros que solo difieren en mayusculas, ni uno con "*").
track() {
  local sha
  sha="$(printf '%s\n' "$2" | git hash-object -w --stdin)" || return 1
  git update-index --add --cacheinfo "100644,$sha,$1"
}
untrack() { GIT_LITERAL_PATHSPECS=1 git rm -q --cached -f -- "$@"; git commit -q -m "quita $*"; }
sin_prohibidos() { [ -d "$1" ] && [ -z "$(find "$1" \( -iname config.php -o -iname setup.php \) -print)" ]; }

# 8c. mayusculas: server/Config.PHP y server/admin/Setup.php se excluyen ------
track server/Config.PHP "<?php // CONFIG SECRETA mayusculas"
track server/admin/Setup.php "<?php // setup mayusculas"
git commit -q -m "mayusculas"
O="$(out mayus)"
if run --mode full --out "$O" >/dev/null 2>&1; then ok "mayusculas: full termina con 0"; else bad "mayusculas: full termina con 0"; fi
check "mayusculas: ni Config.PHP ni Setup.php (ni variantes) en el paquete" sin_prohibidos "$O"
O="$(out mayus-chg)"
run --mode changes --from HEAD~1 --to HEAD --out "$O" >/dev/null 2>&1
check "mayusculas: en changes tampoco se empaquetan ni se sugiere borrarlos" bash -c "! find '$O' -iname config.php -o -iname setup.php | grep -q . && ! { [ -f '$O/ELIMINAR.txt' ] && grep -qi -e config.php -e setup.php '$O/ELIMINAR.txt'; }"
untrack server/Config.PHP server/admin/Setup.php

# 8d. rutas con metacaracteres de glob se toman literales ------------------------
# "server/c*.php" como pathspec arrastraria server/config.php al paquete.
# (En Windows tar no puede extraer un fichero con "*": el exit puede ser != 0,
# lo que importa es que config.php no llegue a la salida.)
if track 'server/c*.php' "<?php // comodin" 2>/dev/null; then
  git commit -q -m "comodin"
  O="$(out glob-star)"
  run --mode full --out "$O" >/dev/null 2>&1
  check "glob: server/c*.php no arrastra server/config.php" bash -c "! find '$O' -iname config.php 2>/dev/null | grep -q ."
  untrack 'server/c*.php'
else
  echo "SKIP  glob: este sistema de ficheros/git no admite '*' en rutas (se cubre en Linux/CI)"
fi
track 'server/admin/s[e]tup.php' "<?php // corchetes"
git commit -q -m "corchetes"
O="$(out glob-br)"
run --mode full --out "$O" >/dev/null 2>&1
check "glob: server/admin/s[e]tup.php no arrastra setup.php" bash -c "! find '$O' -iname setup.php 2>/dev/null | grep -q ."
untrack 'server/admin/s[e]tup.php'

# 8e. guarda de secretos: mayusculas, comillas simples, api_key, .env, PHP -------
KEYUP="$(printf '%s' "$KEY" | tr 'a-f' 'A-F')"
secreto() {  # secreto "descripcion" ruta contenido
  track "$2" "$3"
  git commit -q -m "secreto"
  nocheck "guarda secretos: $1" run --mode full --out "$(out "sec-$(printf '%s' "$1" | tr -c 'a-zA-Z0-9' _)")"
  untrack "$2"
}
secreto "hex en mayusculas" server/api/s1.json "{\"apiKey\": \"$KEYUP\"}"
secreto "comillas simples (JS)" server/api/s2.js "const c = { apiKey: '$KEY' };"
secreto "api_key => (PHP)" server/api/s3.php "<?php return ['api_key' => '$KEY'];"
secreto "API_KEY= estilo .env" server/api/s4.env "API_KEY=\"$KEYUP\""
secreto "apikey sin comillas" server/api/s5.txt "apikey: $KEY"
# Falsos positivos: 64 hex sin nombre de clave y una clave corta no abortan.
track server/api/hash.json "{\"sha\": \"$KEY\", \"apiKey\": \"corta\"}"
git commit -q -m "benigno"
check "guarda secretos: 64 hex sin nombre de clave / clave corta no abortan" run --mode full --out "$(out benigno)"
untrack server/api/hash.json

# 9. --zip produce un zip valido ----------------------------------------------------
ziplist() {
  if command -v unzip >/dev/null 2>&1; then unzip -l "$1"
  elif command -v python3 >/dev/null 2>&1 && python3 -c 'import zipfile' 2>/dev/null; then python3 -m zipfile -l "$1"
  elif command -v python >/dev/null 2>&1; then python -m zipfile -l "$1"
  else tar -tf "$1"; fi
}
Z="$TMP/paquete.zip"
O="$(out zip)"
if run --mode full --out "$O" --zip "$Z" >/dev/null 2>&1; then ok "zip: termina con 0"; else bad "zip: termina con 0"; fi
check "zip: existe y no esta vacio" test -s "$Z"
ziplist "$Z" > "$TMP/zip.lst" 2>&1
check "zip: lista MANIFEST.txt" grep -q "MANIFEST.txt" "$TMP/zip.lst"
check "zip: lista public_html/admin/index.php" grep -q "public_html/admin/index.php" "$TMP/zip.lst"
check "zip: no lista config.php" bash -c "! grep -q 'config.php' '$TMP/zip.lst'"
nocheck "zip: existente se rechaza" run --mode full --out "$(out zip2)" --zip "$Z"

# 10. validaciones basicas -----------------------------------------------------------
nocheck "modo invalido se rechaza" run --mode raro --out "$(out m)"
nocheck "--to inexistente se rechaza" run --to no-existe --out "$(out t)"
check "--help sale con 0" run --help

# 11. se puede lanzar desde otro directorio y --out relativo cuelga de ahi ----------
mkdir -p "$TMP/otro"
( cd "$TMP/otro" && bash "$PACK" --mode full --out rel >/dev/null 2>&1 )
check "otro directorio: --out relativo respecto a donde se invoca" test -f "$TMP/otro/rel/MANIFEST.txt"

echo
echo "Resultado: $PASS PASS, $FAIL FAIL"
[ "$FAIL" -eq 0 ]
