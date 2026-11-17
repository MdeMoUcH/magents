#!/usr/bin/env bash
# Borra los datos de la BD de pruebas de este entorno y la recarga desde bd-inicial/. Antes guarda una copia de los tuyos.
# menu: confirmar: Borra TODOS los datos de la BD de este entorno. Antes guarda una copia, que se recupera con restaurar-bd.sh.
# Uso: reiniciar-bd.sh [--sin-copia]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bd-comun.sh"
magents_confirmar "${BASH_SOURCE[0]}"
cd "$(dirname "${BASH_SOURCE[0]}")/../entorno"

if ! docker compose config --services | grep -qx bd; then
  magents_error "ERROR: este entorno no tiene servicio bd."
  exit 1
fi

# Solo se copia la primera vez: con una copia pendiente, la BD actual ya es la de pruebas.
if [ "${1:-}" != "--sin-copia" ] && [ -z "$(bd_copia_pendiente)" ]; then
  if bd_arrancar && ! bd_admitida; then
    magents_aviso "AVISO: el servicio bd no es MySQL ni MariaDB: se restablece sin guardar copia."
  elif ! bd_arrancar || ! copia="$(bd_guardar)"; then
    magents_error "ERROR: no se ha podido guardar una copia de la BD antes de borrarla; no se ha borrado nada. Si no hay nada que conservar, repite con --sin-copia."
    exit 1
  else
    (umask 077 && printf '%s\n' "$copia" > "$bd_pendiente")
    echo "Copia de la BD anterior: .magents/bd-usuario/$copia (se recupera con restaurar-bd.sh)"
  fi
fi

docker compose down -v --remove-orphans
../scripts/iniciar.sh
