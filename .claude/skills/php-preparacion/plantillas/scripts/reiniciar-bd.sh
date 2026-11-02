#!/usr/bin/env bash
# Borra los datos de la BD de pruebas de este entorno y la recarga desde bd-inicial/.
# menu: confirmar: Borra TODOS los datos de la BD de pruebas de este entorno.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
magents_confirmar "${BASH_SOURCE[0]}"
cd "$(dirname "${BASH_SOURCE[0]}")/../entorno"

if ! docker compose config --services | grep -qx bd; then
  magents_error "ERROR: este entorno no tiene servicio bd."
  exit 1
fi

docker compose down -v --remove-orphans
../scripts/iniciar.sh
