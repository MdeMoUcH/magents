#!/usr/bin/env bash
# Colores, cabecera y confirmación que cargan los demás scripts. No se ejecuta por sí solo.

magents_compose="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../entorno/compose.yml"

# Se decide al cargar, porque dentro de $(...) la salida ya no es la terminal.
magents_color_salida=0
magents_color_error=0
if [ -z "${NO_COLOR:-}" ] && [ -z "${CLAUDECODE:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  if [ -t 1 ]; then
    magents_color_salida=1
  fi
  if [ -t 2 ]; then
    magents_color_error=1
  fi
fi

# Morado de 256 colores: el básico suele verse rosa.
magents_morado="35"
magents_gris="37"
if [ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]; then
  magents_morado="38;5;135"
  magents_gris="38;5;247"
fi

# Uso: magents_pintar <código de color> <texto>. Devuelve el texto sin salto de línea.
magents_pintar() {
  if [ "$magents_color_salida" = "1" ]; then
    printf '\033[%sm%s\033[0m' "$1" "$2"
  else
    printf '%s' "$2"
  fi
}

magents_ok() {
  magents_pintar 32 "$1"
  echo
}

# Uso: magents_mensaje <0 o 1, si hay color> <código de color> <texto>. La etiqueta inicial va en negrita.
magents_mensaje() {
  local etiqueta=""
  if [ "$1" != "1" ]; then
    echo "$3"
    return 0
  fi
  case "$3" in
    ATENCIÓN:* | AVISO:* | ERROR:* | PROBLEMA:*) etiqueta="${3%%:*}:" ;;
  esac
  printf '\033[1;%sm%s\033[0;%sm%s\033[0m\n' "$2" "$etiqueta" "$2" "${3#"$etiqueta"}"
}

magents_atencion() {
  magents_mensaje "$magents_color_salida" 33 "$1"
}

magents_error() {
  magents_mensaje "$magents_color_error" 31 "$1" >&2
}

magents_aviso() {
  magents_mensaje "$magents_color_error" 33 "$1" >&2
}

magents_banner() {
  if [ "$magents_color_salida" = "1" ]; then
    printf '\033[%sm' "$magents_morado"
  fi
  cat <<'BANNER'
   .---.
  [ o_o ]    m A g e n t s
  /|___|\    -------------
   d   b     PHP Web Agents
BANNER
  if [ "$magents_color_salida" = "1" ]; then
    printf '\033[0m'
  fi
  echo
}

# Solo para personas y una vez por ejecución: no ensucia la salida de agentes, tuberías ni scripts anidados.
# Deja también una línea en blanco al terminar, aunque sea con error.
magents_cabecera() {
  if [ "${MAGENTS_CABECERA_MOSTRADA:-}" = "1" ] || [ ! -t 1 ] || [ -n "${CLAUDECODE:-}" ]; then
    return 0
  fi
  magents_banner
  trap echo EXIT
  export MAGENTS_CABECERA_MOSTRADA=1
}

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
  magents_atencion "ATENCIÓN:$motivo"
  read -r -p "Escribe si para continuar: " respuesta || return 1
  [ "$respuesta" = "si" ]
}

# Para los scripts. No pregunta a los agentes, que no tienen quien responda, ni si ya se confirmó.
magents_confirmar() {
  magents_cabecera
  if [ "${MAGENTS_CONFIRMADO:-}" = "1" ] || [ ! -t 0 ] || [ -n "${CLAUDECODE:-}" ]; then
    return 0
  fi
  if ! magents_preguntar "$1"; then
    magents_atencion "Cancelado."
    exit 1
  fi
  export MAGENTS_CONFIRMADO=1
}
