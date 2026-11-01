#!/usr/bin/env bash
# Borra los datos de la BD de pruebas de este entorno y la recarga desde bd-inicial/.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if ! docker compose config --services | grep -qx bd; then
  echo "ERROR: este entorno no tiene servicio bd." >&2
  exit 1
fi

docker compose down -v --remove-orphans
./iniciar.sh
