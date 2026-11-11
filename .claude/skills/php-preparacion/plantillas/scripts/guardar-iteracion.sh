#!/usr/bin/env bash
# Guarda el código de una iteración de /tarea y deja en informes/ lo que cambia desde las anteriores. Lo lanza /tarea.
# Uso: guardar-iteracion.sh <NNNN> <iteración> <commit base>
set -euo pipefail

if [ "$#" -ne 3 ] || ! [[ "$1" =~ ^[0-9]{4}$ ]] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
  echo "Uso: $0 <NNNN> <iteración> <commit base>" >&2
  exit 1
fi
n="$2"
base="$3"

magents_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$(dirname "$magents_dir")"

tareas=(.magents/tareas/"$1"-*/)
if [ "${#tareas[@]}" -ne 1 ] || [ ! -d "${tareas[0]}informes" ]; then
  echo "ERROR: no hay una sola carpeta .magents/tareas/$1-*/ con informes/." >&2
  exit 1
fi
tarea="${tareas[0]%/}"
if ! git rev-parse -q --verify "$base^{commit}" >/dev/null; then
  echo "ERROR: $base no es un commit de este repositorio." >&2
  exit 1
fi
iteraciones="$tarea/iteraciones"

# Lo que la tarea ha cambiado, creado o borrado. Fuera, lo que suele llevar secretos, como en copiar-revision.sh.
rm -rf "${iteraciones:?}/$n" "$iteraciones/.delta"
mkdir -p "$iteraciones/$n"
copiados=0
while IFS= read -r -d '' ruta; do
  case "/$ruta" in
    */.env | */.env.* | *.pem | *.key) continue ;;
  esac
  printf '%s\0' "$ruta"
  # Un archivo borrado queda en la lista, sin copia.
  if [ -f "$ruta" ] || [ -L "$ruta" ]; then
    mkdir -p "$iteraciones/$n/$(dirname "$ruta")"
    cp -pP -- "$ruta" "$iteraciones/$n/$ruta"
    copiados=$((copiados + 1))
  fi
done < <(
  git diff -z --name-only --relative "$base" -- . ':(exclude).magents'
  git ls-files -z --others --exclude-standard -- . ':(exclude).magents'
) > "$iteraciones/$n.lista"
echo "Iteración $n guardada en $iteraciones/$n ($copiados archivos)."

# Deja en .delta/<iteración>/ cada archivo de la lista conjunta tal como estaba en esa iteración:
# su copia si la iteración lo había cambiado, o el del commit base si aún no lo había tocado.
montar() {
  local iteracion="$1" ruta
  local -A propios=()
  while IFS= read -r -d '' ruta; do
    propios[$ruta]=1
  done < "$iteraciones/$iteracion.lista"
  while IFS= read -r -d '' ruta; do
    mkdir -p "$iteraciones/.delta/$iteracion/$(dirname "$ruta")"
    if [ -n "${propios[$ruta]:-}" ]; then
      if [ -e "$iteraciones/$iteracion/$ruta" ] || [ -L "$iteraciones/$iteracion/$ruta" ]; then
        cp -pP -- "$iteraciones/$iteracion/$ruta" "$iteraciones/.delta/$iteracion/$ruta"
      fi
    elif git cat-file -e "$base:./$ruta" 2>/dev/null; then
      git show "$base:./$ruta" > "$iteraciones/.delta/$iteracion/$ruta"
    fi
  done < <(cat "$iteraciones/$2.lista" "$iteraciones/$3.lista" | sort -zu)
}

# Un delta por cada iteración anterior: cada revisión usa el de la última que revisó.
for lista in "$iteraciones"/*.lista; do
  anterior="$(basename "$lista" .lista)"
  [[ "$anterior" =~ ^[1-9][0-9]*$ ]] && [ "$anterior" -lt "$n" ] || continue
  montar "$anterior" "$anterior" "$n"
  montar "$n" "$anterior" "$n"
  mkdir -p "$iteraciones/.delta/$anterior" "$iteraciones/.delta/$n"
  delta="$tarea/informes/delta-$anterior-$n.diff"
  # diff sale con 1 cuando hay diferencias.
  (cd "$iteraciones/.delta" && diff -ruN "$anterior" "$n") > "$delta" || [ "$?" -eq 1 ]
  rm -rf "${iteraciones:?}/.delta"
  if [ -s "$delta" ]; then
    echo "$delta: $(grep -cE '^(diff|Binary|Los archivos binarios) ' "$delta") archivos, $(wc -l < "$delta") líneas."
  else
    echo "$delta: vacío, el código no ha cambiado desde la iteración $anterior."
  fi
done
