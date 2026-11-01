#!/usr/bin/env bash
# Para el entorno local de pruebas. Conserva los datos de la BD.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

docker compose down --remove-orphans
echo "Entorno parado."
