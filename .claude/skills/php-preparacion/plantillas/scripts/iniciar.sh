#!/usr/bin/env bash
# Inicia el entorno local de pruebas o, si ya está en marcha, lo reinicia. Conserva los datos de la BD.
# menu: confirmar-si-en-marcha: Recrea los contenedores: se pierden sus logs y temporales. La BD se conserva.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
magents_confirmar "${BASH_SOURCE[0]}"
# Los comandos de Docker se ejecutan desde entorno/, donde está compose.yml.
cd "$(dirname "${BASH_SOURCE[0]}")/../entorno"

if ! command -v curl >/dev/null 2>&1; then
  magents_error "ERROR: hace falta curl para comprobar que la web responde."
  exit 1
fi

# Con pull_policy: never Compose no construye ni descarga: sin esto se usaría una imagen antigua o ninguna.
if grep -q 'pull_policy: *never' compose.yml && [ ! -e ../scripts/antes-de-iniciar.sh ]; then
  magents_error "ERROR: compose.yml no construye su imagen y falta .magents/scripts/antes-de-iniciar.sh. Ejecuta /preparar en Claude Code y elige «Revisar», o crea ese script con el docker build."
  exit 1
fi

MAGENTS_UID="$(id -u)"
MAGENTS_GID="$(id -g)"
export MAGENTS_UID MAGENTS_GID

# Adaptación propia del proyecto, antes de parar nada: si falla, el entorno sigue como estaba.
if [ -e ../scripts/antes-de-iniciar.sh ]; then
  bash ../scripts/antes-de-iniciar.sh
fi

docker compose down --remove-orphans
if ! docker compose up -d --build --wait --wait-timeout 900; then
  docker compose logs --tail 50 >&2 || true
  magents_error "ERROR: el entorno no ha arrancado."
  exit 1
fi

direccion="$(docker compose port web 80)"
url="http://$direccion"
url_localhost="http://localhost:${direccion##*:}"
if ! respuesta="$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 30 "$url/")"; then
  magents_error "ERROR: $url no responde."
  exit 1
fi
codigo="${respuesta%% *}"
destino="${respuesta#* }"

# Una redirección fuera del entorno local llevaría las pruebas a otra web, quizá a producción.
case "$destino" in
  "" | "$url" | "$url"/* | "$url_localhost" | "$url_localhost"/*) ;;
  *)
    magents_error "ERROR: $url redirige fuera del entorno local: $destino"
    exit 1
    ;;
esac

if [ "$codigo" -ge 500 ]; then
  docker compose logs --tail 50 web >&2 || true
  magents_error "ERROR: $url devuelve HTTP $codigo."
  exit 1
fi

# La versión a la vista: una variable como PHP_VERSION se pierde si no se repite en cada arranque.
version_php="$(docker compose exec -T web php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
magents_ok "Entorno en marcha: $url (HTTP $codigo${version_php:+, PHP $version_php})"
