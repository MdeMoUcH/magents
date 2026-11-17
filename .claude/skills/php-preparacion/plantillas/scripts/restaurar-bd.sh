#!/usr/bin/env bash
# Devuelve a la BD de este entorno tus datos, desde la copia que se guardó antes de restablecerla.
# menu: confirmar: Sustituye todo el contenido actual de la BD por el de la copia.
# Uso: restaurar-bd.sh [--copia <archivo>] [<migración.sql> ...]
#      restaurar-bd.sh --estado | --descartar
# Sin --copia usa la copia sin restaurar. Los .sql se aplican después, en orden, para llevar tus datos al esquema nuevo.
# Sale con 2 si la copia no se ha podido cargar y con 3 si falla una migración; la copia no se borra nunca.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bd-comun.sh"

listar_copias() {
  if [ -d "$bd_carpeta" ] && ls "$bd_carpeta"/*.sql >/dev/null 2>&1; then
    echo "Copias guardadas en .magents/bd-usuario/, de la más reciente a la más antigua:"
    (cd "$bd_carpeta" && ls -1 -- *.sql | sort -r | sed 's/^/  /')
  else
    echo "No hay copias guardadas."
  fi
}

copia=""
migraciones=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --estado)
      pendiente="$(bd_copia_pendiente)"
      if [ -n "$pendiente" ]; then
        echo "Pendiente: la BD es la de pruebas y la copia $pendiente está sin restaurar."
      else
        echo "Sin copia pendiente: la BD no se ha restablecido desde la última restauración."
      fi
      listar_copias
      exit 0
      ;;
    --descartar)
      pendiente="$(bd_copia_pendiente)"
      rm -f "$bd_pendiente"
      if [ -n "$pendiente" ]; then
        magents_ok "Descartada la restauración de $pendiente. El archivo sigue en .magents/bd-usuario/ y la BD se queda como está."
      else
        echo "No había ninguna copia pendiente."
      fi
      exit 0
      ;;
    --copia)
      copia="$(basename "${2:-}")"
      shift 2 || { magents_error "ERROR: falta el archivo de --copia."; exit 1; }
      ;;
    -*)
      magents_error "ERROR: opción desconocida: $1"
      exit 1
      ;;
    *)
      migraciones+=("$1")
      shift
      ;;
  esac
done

if ! bd_hay_servicio; then
  magents_error "ERROR: este entorno no tiene servicio bd."
  exit 1
fi
pendiente="$(bd_copia_pendiente)"
if [ -z "$copia" ]; then
  copia="$pendiente"
fi
if [ -z "$copia" ]; then
  magents_error "ERROR: no hay ninguna copia pendiente de restaurar. Para volver a una anterior, indícala con --copia <archivo>."
  listar_copias >&2
  exit 1
fi
if [ ! -s "$bd_carpeta/$copia" ]; then
  magents_error "ERROR: no existe la copia .magents/bd-usuario/$copia."
  listar_copias >&2
  exit 1
fi
for migracion in ${migraciones[@]+"${migraciones[@]}"}; do
  if [ ! -f "$migracion" ]; then
    magents_error "ERROR: no existe $migracion; no se ha restaurado nada."
    exit 1
  fi
done

magents_confirmar "${BASH_SOURCE[0]}"

if ! bd_arrancar; then
  magents_error "ERROR: el servicio bd no arranca; no se ha restaurado nada."
  exit 1
fi
if ! bd_admitida; then
  magents_error "ERROR: el servicio bd no es MySQL ni MariaDB; no se ha restaurado nada."
  exit 1
fi

# Sin copia pendiente, la BD actual puede tener datos tuyos que no están en ninguna copia.
if [ -z "$pendiente" ]; then
  if ! previa="$(bd_guardar antes-de-restaurar)"; then
    magents_error "ERROR: no se ha podido guardar la BD actual antes de sustituirla; no se ha restaurado nada."
    exit 1
  fi
  echo "BD actual guardada antes en .magents/bd-usuario/$previa"
fi

if ! bd_cargar "$bd_carpeta/$copia"; then
  magents_error "ERROR: la copia $copia no se ha podido cargar. La BD puede haber quedado a medias; la copia sigue intacta en .magents/bd-usuario/. Repite con: restaurar-bd.sh --copia $copia"
  exit 2
fi
rm -f "$bd_pendiente"
magents_ok "BD restaurada desde .magents/bd-usuario/$copia"

for migracion in ${migraciones[@]+"${migraciones[@]}"}; do
  if ! bd_aplicar "$migracion"; then
    magents_error "ERROR: ha fallado $migracion sobre tus datos. La BD tiene tus datos, pero sin ese cambio de esquema completo. Cuando esté corregido, repite con: restaurar-bd.sh --copia $copia <migraciones>"
    exit 3
  fi
  magents_ok "Aplicado: $migracion"
done
