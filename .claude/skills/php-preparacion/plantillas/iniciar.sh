#!/usr/bin/env bash
# Inicia el entorno local de pruebas o, si ya está en marcha, lo reinicia. Conserva los datos de la BD.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

MAGENTS_UID="$(id -u)"
MAGENTS_GID="$(id -g)"
export MAGENTS_UID MAGENTS_GID

docker compose down --remove-orphans
if ! docker compose up -d --build --wait --wait-timeout 180; then
  docker compose logs --tail 50 >&2 || true
  echo "ERROR: el entorno no ha arrancado." >&2
  exit 1
fi

url="http://$(docker compose port web 80)"
if ! codigo="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "$url/")"; then
  echo "ERROR: $url no responde." >&2
  exit 1
fi
if [ "$codigo" -ge 500 ]; then
  docker compose logs --tail 50 web >&2 || true
  echo "ERROR: $url devuelve HTTP $codigo." >&2
  exit 1
fi

echo "Entorno en marcha: $url (HTTP $codigo)"
