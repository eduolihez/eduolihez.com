#!/usr/bin/env bash
# Tests de scripts/pack-admin.sh sobre un repositorio git desechable (mktemp -d).
# No toca el repo real. Uso: bash scripts/pack-admin.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACK="$SCRIPT_DIR/pack-admin.sh"

TMP="$(mktemp -d)"
# Solo se borra el directorio temporal que creamos arriba.
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()  { echo "PASS  $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL  $1"; FAIL=$((FAIL + 1)); }
# check "descripcion" comando...  -> PASS si el comando sale con 0
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
# nocheck: PASS si el comando sale con != 0
nocheck() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }

REPO="$TMP/repo"
mkdir -p "$REPO"
cd "$REPO"
git init -q .
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
