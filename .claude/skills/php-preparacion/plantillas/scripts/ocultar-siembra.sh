#!/usr/bin/env bash
# Oculta a git el archivo con el defecto sembrado por /calibrar, y lo vuelve a mostrar. Lo lanza /calibrar.
# Uso: ocultar-siembra.sh <archivo versionado> | ocultar-siembra.sh --mostrar
# Mientras está oculto, git status y git diff no enseñan sus cambios: así las pruebas no saben qué archivo mirar.
# No cambia el archivo ni crea commits: solo una marca del índice de git, que --mostrar quita siempre.
set -euo pipefail

magents_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$(dirname "$magents_dir")"
registro="$magents_dir/calibracion/.ocultos"

# Archivos con la marca, uno por línea y sin comillas aunque el nombre tenga eñes o espacios.
ocultos() {
  git ls-files -v -z | tr '\0' '\n' | sed -n 's/^S //p'
}

if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <archivo versionado> | $0 --mostrar" >&2
  exit 1
fi

if [ "$1" = "--mostrar" ]; then
  # Lo anotado y, por si el registro se perdió, cualquier otro archivo con la marca.
  {
    [ ! -f "$registro" ] || cat "$registro"
    ocultos
  } | sort -u | while IFS= read -r archivo; do
    [ -n "$archivo" ] || continue
    git update-index --no-skip-worktree -- "$archivo" 2>/dev/null || true
    echo "Visible de nuevo: $archivo"
  done
  rm -f "$registro"
  if [ -n "$(ocultos)" ]; then
    echo "ERROR: siguen ocultos a git: $(ocultos | tr '\n' ' ')" >&2
    exit 1
  fi
  exit 0
fi

archivo="$1"
if ! git ls-files --error-unmatch -- "$archivo" >/dev/null 2>&1; then
  echo "ERROR: $archivo no es un archivo versionado de este repositorio." >&2
  exit 1
fi
mkdir -p "$(dirname "$registro")"
printf '%s\n' "$archivo" >> "$registro"
git update-index --skip-worktree -- "$archivo"
if [ -n "$(git status --porcelain -- "$archivo")" ]; then
  git update-index --no-skip-worktree -- "$archivo"
  echo "ERROR: git sigue enseñando los cambios de $archivo; no se ha ocultado." >&2
  exit 1
fi
echo "Oculto a git: $archivo. Se vuelve a mostrar con: $0 --mostrar"
