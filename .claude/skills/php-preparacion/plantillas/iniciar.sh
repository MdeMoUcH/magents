#!/usr/bin/env bash
# Inicia el entorno local de pruebas o, si ya está en marcha, lo reinicia. Conserva los datos de la BD.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: hace falta curl para comprobar que la web responde." >&2
  exit 1
fi

MAGENTS_UID="$(id -u)"
MAGENTS_GID="$(id -g)"
export MAGENTS_UID MAGENTS_GID

docker compose down --remove-orphans
if ! docker compose up -d --build --wait --wait-timeout 900; then
  docker compose logs --tail 50 >&2 || true
  echo "ERROR: el entorno no ha arrancado." >&2
  exit 1
fi

direccion="$(docker compose port web 80)"
url="http://$direccion"
url_localhost="http://localhost:${direccion##*:}"
if ! respuesta="$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 30 "$url/")"; then
  echo "ERROR: $url no responde." >&2
  exit 1
fi
codigo="${respuesta%% *}"
destino="${respuesta#* }"

# Una redirección fuera del entorno local llevaría las pruebas a otra web, quizá a producción.
case "$destino" in
  "" | "$url" | "$url"/* | "$url_localhost" | "$url_localhost"/*) ;;
  *)
    echo "ERROR: $url redirige fuera del entorno local: $destino" >&2
    exit 1
    ;;
esac

if [ "$codigo" -ge 500 ]; then
  docker compose logs --tail 50 web >&2 || true
  echo "ERROR: $url devuelve HTTP $codigo." >&2
  exit 1
fi

echo "Entorno en marcha: $url (HTTP $codigo)"
