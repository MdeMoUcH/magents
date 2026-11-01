#!/usr/bin/env bash
# Funciones de confirmación que cargan los demás scripts. No se ejecuta por sí solo.

magents_compose="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../entorno/compose.yml"

magents_en_marcha() {
  [ -e "$magents_compose" ] && command -v docker >/dev/null 2>&1 &&
    [ -n "$(docker compose -f "$magents_compose" ps --status running -q web 2>/dev/null)" ]
}

# Marca del script: «confirmar: motivo» o «confirmar-si-en-marcha: motivo».
magents_motivo() {
  local marca
  marca="$(sed -n 's/^# menu: //p' "$1" | head -1)"
  case "$marca" in
    confirmar:*) echo "${marca#confirmar:}" ;;
    confirmar-si-en-marcha:*)
      if magents_en_marcha; then
        echo "${marca#confirmar-si-en-marcha:}"
      fi
      ;;
  esac
  return 0
}

# Devuelve 0 si no hace falta confirmar o si la persona escribe «si».
magents_preguntar() {
  local motivo respuesta
  motivo="$(magents_motivo "$1")"
  [ -z "$motivo" ] && return 0
  echo "ATENCIÓN:$motivo"
  read -r -p "Escribe si para continuar: " respuesta || return 1
  [ "$respuesta" = "si" ]
}

# Para los scripts. No pregunta a los agentes, que no tienen quien responda, ni si ya se confirmó.
magents_confirmar() {
  if [ "${MAGENTS_CONFIRMADO:-}" = "1" ] || [ ! -t 0 ] || [ -n "${CLAUDECODE:-}" ]; then
    return 0
  fi
  if ! magents_preguntar "$1"; then
    echo "Cancelado."
    exit 1
  fi
  export MAGENTS_CONFIRMADO=1
}
