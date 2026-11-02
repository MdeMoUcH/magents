#!/usr/bin/env bash
# Detecta fallos de estructura del entorno sin arrancarlo. No cambia nada. Sale con 1 si hay problemas.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
magents_cabecera

magents_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
raiz="$(dirname "$magents_dir")"
proyecto_md="$magents_dir/proyecto.md"
entorno="$magents_dir/entorno"
scripts="$magents_dir/scripts"
problemas=0

problema() {
  magents_error "PROBLEMA: $1"
  problemas=$((problemas + 1))
}

# Un servicio parado deja de resolverse en Docker: su nombre se consultaría en el DNS del equipo.
# Lee la lista de servicios, sus IP fijas y los extra_hosts de web. Ignora los comentarios.
leer_compose() {
  awk '
    /^[[:space:]]*#/ { next }
    /^[^[:space:]]/ { en_servicios = ($0 ~ /^services:/); servicio = ""; next }
    !en_servicios { next }
    /^  [^[:space:]-][^:]*:/ { servicio = $1; sub(/:.*/, "", servicio); print "servicio", servicio; en_hosts = 0; next }
    /^    [^[:space:]]/ { en_hosts = (servicio == "web" && $0 ~ /^    extra_hosts:/) }
    /ipv4_address:/ { print "ip", servicio, $2; next }
    en_hosts && /^      / {
      linea = $0
      gsub(/["\047]/, "", linea); sub(/^ *(- *)?/, "", linea); sub(/[:=] */, " ", linea); sub(/ *(#.*)?$/, "", linea)
      print "host", linea
    }
  ' "$entorno/compose.yml"
}

comprobar_nombres_fijos() {
  local tipo a b nombre
  local servicios=()
  local -A ips=() hosts=()
  while read -r tipo a b; do
    case "$tipo" in
      servicio) servicios+=("$a") ;;
      ip) ips[$a]="$b" ;;
      host) hosts[$a]="$b" ;;
    esac
  done < <(leer_compose)

  [ "${#servicios[@]}" -gt 1 ] || return 0
  if ! grep -qE '^[[:space:]]+-[[:space:]]+subnet:' "$entorno/compose.yml"; then
    problema "compose.yml no define una subred propia: con un servicio parado, su nombre podría resolverse fuera de Docker."
  fi
  for nombre in "${servicios[@]}"; do
    if [ -z "${ips[$nombre]:-}" ]; then
      problema "el servicio $nombre no tiene IP fija (ipv4_address)."
    elif [ "$nombre" != "web" ] && [ "${hosts[$nombre]:-}" != "${ips[$nombre]}" ]; then
      problema "web no tiene $nombre en extra_hosts con la IP ${ips[$nombre]}: con $nombre parado, su nombre podría resolverse fuera de Docker."
    fi
  done
}

if [ ! -e "$proyecto_md" ]; then
  echo "Sin .magents/proyecto.md: aún no hay entorno que comprobar."
  exit 0
fi

# Rutas que cita proyecto.md, sin la puntuación final de la frase.
while IFS= read -r ruta; do
  ruta="${ruta%.}"
  if [ ! -e "$raiz/$ruta" ]; then
    problema "proyecto.md cita $ruta, que no existe."
  fi
done < <(grep -oE '\.magents/[A-Za-z0-9_./-]+' "$proyecto_md" | sort -u)

# Con entorno propio del proyecto no hay más que comprobar aquí.
if [ -e "$entorno/compose.yml" ]; then
  for script in iniciar.sh parar.sh; do
    if [ ! -x "$scripts/$script" ]; then
      problema "falta .magents/scripts/$script o no es ejecutable."
    elif ! bash -n "$scripts/$script" 2>/dev/null; then
      problema ".magents/scripts/$script tiene errores de sintaxis."
    fi
  done

  if [ -e "$scripts/antes-de-iniciar.sh" ]; then
    if ! bash -n "$scripts/antes-de-iniciar.sh" 2>/dev/null; then
      problema ".magents/scripts/antes-de-iniciar.sh tiene errores de sintaxis."
    fi
  elif grep -q 'pull_policy: *never' "$entorno/compose.yml"; then
    problema "compose.yml no construye su imagen y falta .magents/scripts/antes-de-iniciar.sh, así que nadie la construye."
  fi

  if grep -q '^  bd:' "$entorno/compose.yml" && [ ! -x "$scripts/reiniciar-bd.sh" ]; then
    problema "hay servicio bd y falta .magents/scripts/reiniciar-bd.sh o no es ejecutable."
  fi

  comprobar_nombres_fijos

  # Docker crearía como root un origen de montaje que no exista.
  while IFS= read -r origen; do
    if [ ! -e "$entorno/$origen" ]; then
      problema "compose.yml monta $origen, que no existe en .magents/entorno/."
    fi
  done < <(sed -nE 's/^[[:space:]]*-[[:space:]]+(\.\/[^:]+):.*/\1/p' "$entorno/compose.yml")

  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    if ! error="$(docker compose --project-directory "$entorno" -f "$entorno/compose.yml" config -q 2>&1)"; then
      problema "compose.yml no es válido: $error"
    fi
  else
    magents_aviso "AVISO: sin docker compose; no se ha validado compose.yml."
  fi
fi

if [ "$problemas" -gt 0 ]; then
  echo "Ejecuta /preparar en Claude Code y elige «Revisar» para arreglarlo." >&2
  exit 1
fi
magents_ok "Estructura del entorno correcta."
