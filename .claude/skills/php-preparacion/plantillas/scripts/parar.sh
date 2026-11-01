#!/usr/bin/env bash
# Para el entorno local de pruebas. Conserva los datos de la BD.
# menu: confirmar-si-en-marcha: Elimina los contenedores: se pierden sus logs y temporales. La BD se conserva.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
magents_confirmar "${BASH_SOURCE[0]}"
cd "$(dirname "${BASH_SOURCE[0]}")/../entorno"

docker compose down --remove-orphans
echo "Entorno parado."
