#!/usr/bin/env bash
# Copia a magents lo útil de .magents/ para revisar cómo han trabajado los agentes.
# Lo ejecuta solo el usuario, porque escribe fuera del proyecto.
# menu: confirmar: Sustituye la copia anterior en magents y borra de ella lo que ya no exista aquí.
# Uso: copiar-revision.sh [--sin-diff]
set -euo pipefail

con_diff=1
case "${1:-}" in
  "") ;;
  --sin-diff) con_diff=0 ;;
  *)
    echo "Uso: $0 [--sin-diff]" >&2
    exit 1
    ;;
esac

source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
magents_confirmar "${BASH_SOURCE[0]}"

# Commit base de una tarea, según su estado.md.
commit_base() {
  local estado="$1/informes/estado.md" hash
  hash="$(grep -i 'base efectivo' "$estado" 2>/dev/null | grep -oE '\b[0-9a-f]{7,40}\b' | head -1 || true)"
  if [ -z "$hash" ]; then
    hash="$(grep -iA2 'commit base' "$estado" 2>/dev/null | grep -oE '\b[0-9a-f]{7,40}\b' | head -1 || true)"
  fi
  echo "$hash"
}

# Un diff por tarea: de su base a la base de la siguiente, o al estado actual si es la última.
generar_diffs() {
  local ids=() bases=() tarea base i siguiente archivo
  for tarea in "$origen"/tareas/[0-9]*/; do
    [ -d "$tarea" ] || continue
    base="$(commit_base "$tarea")"
    if [ -z "$base" ] || ! git -C "$proyecto" rev-parse -q --verify "$base^{commit}" >/dev/null; then
      magents_aviso "AVISO: sin commit base válido en $(basename "$tarea"); no se genera su diff."
      continue
    fi
    ids+=("$(basename "$tarea")")
    bases+=("$base")
  done
  mkdir -p "$destino/diffs"
  for i in "${!ids[@]}"; do
    siguiente="${bases[$((i + 1))]:-}"
    archivo="$destino/diffs/${ids[$i]}.diff"
    git -C "$proyecto" diff "${bases[$i]}" ${siguiente:+"$siguiente"} -- . \
      ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*' ':(exclude,glob)**/*.pem' ':(exclude,glob)**/*.key' \
      > "$archivo"
    if [ ! -s "$archivo" ]; then
      magents_aviso "AVISO: diff vacío en ${ids[$i]}."
    fi
  done
  if [ -n "$(git -C "$proyecto" ls-files --others --exclude-standard)" ]; then
    magents_aviso "AVISO: los archivos nuevos sin seguimiento no están en los diffs; aparecen en git-status.txt."
  fi
}
scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
origen="$(dirname "$scripts")"
proyecto="$(dirname "$origen")"

if ! command -v rsync >/dev/null 2>&1; then
  magents_error "ERROR: hace falta rsync."
  exit 1
fi

magents="$(cat "$scripts/.ruta-magents")"
if [ ! -d "$magents/.claude" ]; then
  magents_error "ERROR: no se encuentra magents en $magents. Vuelve a ejecutar su install.sh."
  exit 1
fi

destino="$magents/.magents/revision/$(basename "$proyecto")"
mkdir -p "$destino"

# Fuera: datos y configuración sustituta, copias de entornos y temporales. --no-links evita enlaces a otras rutas.
rsync -a --delete --no-links \
  --exclude '/entorno/bd-inicial' \
  --exclude '/entorno/config' \
  --exclude '/entorno.anterior' \
  --exclude '/entorno.anterior-*' \
  --exclude '/tareas/*/tmp' \
  --exclude '/preparacion/tmp' \
  "$origen/" "$destino/magents/"

git -C "$proyecto" log --oneline -50 > "$destino/git-log.txt" 2>/dev/null || true
git -C "$proyecto" status --porcelain > "$destino/git-status.txt" 2>/dev/null || true

# Se regeneran siempre, para no dejar diffs antiguos.
rm -rf "${destino:?}/diffs"
if [ "$con_diff" = 1 ]; then
  if ! git -C "$proyecto" rev-parse --verify -q HEAD >/dev/null 2>&1; then
    magents_error "ERROR: los diffs necesitan un repositorio git con al menos un commit; usa --sin-diff si no lo hay."
    exit 1
  fi
  generar_diffs
fi

magents_ok "Copiado en $destino"
magents_atencion "Antes de avisar, borra de la copia las capturas o informes que muestren datos reales."
if [ "$con_diff" = 1 ]; then
  magents_atencion "Revisa también diffs/: incluyen el código y la configuración versionada, y pueden contener contraseñas."
fi
