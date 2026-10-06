#!/usr/bin/env bash
# Empaqueta server/ (backend PHP + panel /admin) para subirlo por FTP a
# public_html/. Lee SIEMPRE de una referencia git (por defecto HEAD), nunca del
# arbol de trabajo: asi un config.php local, un archivo sin commitear o
# cualquier fichero ignorado no pueden colarse en el paquete.
set -euo pipefail

uso() {
  cat <<'EOF'
Uso: bash scripts/pack-admin.sh [opciones]

  --mode full|changes  full (defecto): todo server/ trackeado.
                       changes: solo lo anadido/modificado entre --from y --to;
                       lo borrado va a ELIMINAR.txt (se borra a mano en el host).
  --from REF           Origen del rango (solo changes). Por defecto, el tag
                       v*.*.*.* mas reciente alcanzable desde <to>^.
  --to REF             Destino (defecto: HEAD).
  --out DIR            Carpeta de salida (defecto: dist-admin). Debe no existir
                       o estar vacia; el script nunca borra nada: si hay un
                       paquete anterior, borralo tu (rm -rf DIR).
  --zip FILE           Ademas escribe un zip con todo el contenido de --out.
  -h, --help           Esta ayuda.

Salida: <out>/public_html/<ruta sin el "server/" inicial>, <out>/MANIFEST.txt y,
en changes, <out>/ELIMINAR.txt (solo si hay borrados).

Nunca se empaquetan: config.php, config.example.php, tests/, admin/setup.php.
Si no hay cambios en modo changes, sale con 0, avisa y no crea nada.
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

MODE=full
FROM=""
TO=HEAD
OUT=dist-admin
ZIP=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) uso; exit 0 ;;
    --mode) [ $# -ge 2 ] || die "--mode necesita un valor"; MODE="$2"; shift 2 ;;
    --from) [ $# -ge 2 ] || die "--from necesita un valor"; FROM="$2"; shift 2 ;;
    --to)   [ $# -ge 2 ] || die "--to necesita un valor"; TO="$2"; shift 2 ;;
    --out)  [ $# -ge 2 ] || die "--out necesita un valor"; OUT="$2"; shift 2 ;;
    --zip)  [ $# -ge 2 ] || die "--zip necesita un valor"; ZIP="$2"; shift 2 ;;
    *) uso >&2; die "opcion desconocida: $1" ;;
  esac
done

case "$MODE" in full|changes) ;; *) die "--mode debe ser full o changes (recibido: $MODE)" ;; esac
[ "$MODE" = changes ] || [ -z "$FROM" ] || die "--from solo tiene sentido con --mode changes"

INVOKE_DIR="$PWD"
# Raiz del repo: el script puede lanzarse desde cualquier directorio.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)" || die "no estoy dentro de un repositorio git"
cd "$REPO" || die "no se pudo entrar en $REPO"

# Las rutas de git (ls-tree, diff, archive) se toman LITERALES: un fichero
# trackeado llamado "c*.php" o "a[bc].php" no debe expandirse como glob y
# arrastrar otros (p.ej. config.php) al paquete.
export GIT_LITERAL_PATHSPECS=1

# --out y --zip relativos se interpretan desde el directorio de invocacion, no
# desde la raiz del repo (quien lanza el script espera eso).
absoluta() { case "$1" in /*|[A-Za-z]:*) printf '%s' "$1" ;; *) printf '%s/%s' "$INVOKE_DIR" "$1" ;; esac; }
OUT="$(absoluta "$OUT")"
[ -z "$ZIP" ] || ZIP="$(absoluta "$ZIP")"

TO_SHA="$(git rev-parse --verify --quiet "$TO^{commit}")" || die "--to '$TO' no existe"

if [ "$MODE" = changes ] && [ -z "$FROM" ]; then
  FROM="$(git describe --tags --abbrev=0 --match 'v*.*.*.*' "$TO_SHA^" 2>/dev/null)" \
    || die "no hay ningun tag v*.*.*.* anterior a '$TO'; pasa --from REF"
fi
FROM_SHA=""
if [ "$MODE" = changes ]; then
  FROM_SHA="$(git rev-parse --verify --quiet "$FROM^{commit}")" || die "--from '$FROM' no existe"
fi

# Lo que jamas se despliega (ni se sugiere borrar en el host).
# Sin distinguir mayusculas (server/Config.PHP, Setup.php...): nocasematch
# existe desde bash 3.1 y solo se activa dentro de la funcion.
excluida() {
  local rc=1
  shopt -s nocasematch
  case "$1" in
    server/config.php|server/config.example.php|server/admin/setup.php) rc=0 ;;
    server/tests/*) rc=0 ;;
  esac
  shopt -u nocasematch
  return $rc
}

FILES=()
DELETED=()
if [ "$MODE" = full ]; then
  while IFS= read -r -d '' f; do
    excluida "$f" || FILES+=("$f")
  done < <(git ls-tree -r --name-only -z "$TO_SHA" -- server)
else
  # --no-renames: un renombrado sale como borrado + alta, que es justo lo que
  # hay que hacer en el host.
  while IFS= read -r -d '' st && IFS= read -r -d '' f; do
    excluida "$f" && continue
    case "$st" in
      D) DELETED+=("$f") ;;
      *) FILES+=("$f") ;;
    esac
  done < <(git diff --no-renames --name-status -z "$FROM_SHA" "$TO_SHA" -- server)
fi

if [ ${#FILES[@]} -eq 0 ] && [ ${#DELETED[@]} -eq 0 ]; then
  [ "$MODE" = changes ] || die "no hay ficheros trackeados en server/ en '$TO'"
  echo "Sin cambios en server/ entre $FROM y $TO: no se genera paquete."
  exit 0
fi

# Salida: nunca se escribe sobre algo existente y no se borra nada.
if [ -e "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ]; then
  die "'$OUT' ya existe y no esta vacia. Borrala tu (rm -rf) o usa otra --out"
fi
if [ -n "$ZIP" ] && [ -e "$ZIP" ]; then
  die "'$ZIP' ya existe; borralo tu o usa otro --zip"
fi
mkdir -p "$OUT/public_html"

if [ ${#FILES[@]} -gt 0 ]; then
  git archive --format=tar "$TO_SHA" -- "${FILES[@]}" | tar -x -C "$OUT"
  # Sale como <out>/server/...; el hosting lo quiere en public_html/.
  cp -R "$OUT/server/." "$OUT/public_html/"
  rm -r "$OUT/server"
fi

if [ ${#DELETED[@]} -gt 0 ]; then
  {
    echo "# Borra estos ficheros del hosting a mano (rutas relativas a public_html/)."
    echo "# El paquete solo anade y sobrescribe: no elimina nada por si solo."
    for f in "${DELETED[@]}"; do echo "${f#server/}"; done
  } > "$OUT/ELIMINAR.txt"
fi

if command -v sha256sum >/dev/null 2>&1; then
  hash256() { sha256sum "$1" | cut -d' ' -f1; }
else
  hash256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

{
  echo "modo:   $MODE"
  [ "$MODE" = changes ] && echo "desde:  $FROM ($(git rev-parse --short "$FROM_SHA"))"
  echo "hasta:  $TO ($(git rev-parse --short "$TO_SHA"))"
  echo "fecha:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "ficheros: ${#FILES[@]}"
  echo "a eliminar: ${#DELETED[@]}"
  echo "----"
  for f in "${FILES[@]}"; do
    rel="${f#server/}"
    printf '%s  %s\n' "$(hash256 "$OUT/public_html/$rel")" "$rel"
  done
} > "$OUT/MANIFEST.txt"

# --- Guardas de seguridad: abortan sin borrar nada --------------------------
FALLO=0
echo "Guardas de seguridad:"
prohibidos="$(find "$OUT" \( -iname 'config.php' -o -iname 'config.example.php' -o -iname 'setup.php' \
  -o -iname 'telemetry.config.json' -o -iname '.git*' \) -print; find "$OUT" -type d -iname tests -print)"
if [ -n "$prohibidos" ]; then
  echo "  [FALLO] ficheros prohibidos en el paquete:"; echo "$prohibidos" | sed 's/^/    /'; FALLO=1
else
  echo "  [ok] sin config.php, config.example.php, setup.php, tests/, telemetry.config.json ni .git*"
fi
# Misma idea que NoSecretsTest: api_key/apikey/api-key/apiKey (clave con o sin
# comillas) seguido de :, = o => y 64 hex (mayusculas o minusculas).
secretos="$(grep -rliE "api[_-]?key[\"']?[[:space:]]*(:|=>|=)[[:space:]]*[\"']?[a-f0-9]{64}([^a-f0-9]|$)" "$OUT" 2>/dev/null || true)"
if [ -n "$secretos" ]; then
  echo "  [FALLO] posible apiKey de 64 hex en:"; echo "$secretos" | sed 's/^/    /'; FALLO=1
else
  echo "  [ok] sin apiKey de 64 hex"
fi
claves="$(grep -rlE -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$OUT" 2>/dev/null || true)"
if [ -n "$claves" ]; then
  echo "  [FALLO] clave privada en:"; echo "$claves" | sed 's/^/    /'; FALLO=1
else
  echo "  [ok] sin claves privadas"
fi
if [ "$FALLO" -ne 0 ]; then
  echo "ERROR: las guardas han fallado. No se genera zip. No se ha borrado nada: revisa/borra '$OUT' a mano." >&2
  exit 1
fi

# --- Zip opcional (sin dependencias: zip, o python, o bsdtar) ---------------
if [ -n "$ZIP" ]; then
  mkdir -p "$(dirname "$ZIP")"
  ( cd "$OUT"
    if command -v zip >/dev/null 2>&1; then
      zip -qr "$ZIP" .
    elif command -v python3 >/dev/null 2>&1 && python3 -c 'import zipfile' 2>/dev/null; then
      python3 -m zipfile -c "$ZIP" ./*
    elif command -v python >/dev/null 2>&1 && python -c 'import zipfile' 2>/dev/null; then
      python -m zipfile -c "$ZIP" ./*
    elif tar --version 2>/dev/null | grep -qi bsdtar; then
      tar -a -cf "$ZIP" .
    else
      exit 99
    fi
  ) || die "no se pudo crear el zip (hace falta zip, python3 o bsdtar)"
  [ -s "$ZIP" ] || die "el zip no se ha creado"
fi

echo
echo "Paquete listo ($MODE, $(git rev-parse --short "$TO_SHA"))"
echo "  ficheros a subir: ${#FILES[@]}"
[ ${#DELETED[@]} -eq 0 ] || echo "  ficheros a eliminar en el host: ${#DELETED[@]} (ver ELIMINAR.txt)"
echo "  carpeta: $OUT"
[ -z "$ZIP" ] || echo "  zip:     $ZIP"
cat <<'EOF'

Como subirlo por FTP:
  1. Arrastra el CONTENIDO de public_html/ sobre el public_html del hosting y sobrescribe.
  2. Si hay ELIMINAR.txt, borra a mano en el host los ficheros que lista.
  3. Nunca sobrescribas config.php del host (no va en el paquete).
EOF
