#!/usr/bin/env bash
# Colores, cabecera y confirmación que cargan los demás scripts. No se ejecuta por sí solo.

magents_carpeta="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
magents_compose="$magents_carpeta/entorno/compose.yml"

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

# Etiqueta en negrita, para las líneas de estado. Uso: magents_etiqueta <texto>. Sin salto de línea.
magents_etiqueta() {
  magents_pintar 1 "$1:"
  printf ' '
}

# Una línea con el estado del entorno y su URL, si está en marcha.
magents_estado() {
  local direccion
  magents_etiqueta "Entorno"
  if [ ! -e "$magents_carpeta/proyecto.md" ]; then
    magents_pintar 33 "sin preparar; ejecuta /preparar en Claude Code"
  elif [ ! -e "$magents_compose" ]; then
    printf 'propio del proyecto; consulta .magents/proyecto.md'
  elif ! command -v docker >/dev/null 2>&1; then
    magents_pintar 33 "desconocido, sin docker"
  elif magents_en_marcha; then
    direccion="$(docker compose -f "$magents_compose" port web 80 2>/dev/null)"
    magents_pintar 32 "en marcha"
    if [ -n "$direccion" ]; then
      printf ' '
      magents_pintar 36 "(http://$direccion)"
    fi
  else
    magents_pintar 33 "parado"
  fi
}

# PHP en ejecución y línea de producción de proyecto.md, tal cual: es texto libre y no se compara.
magents_resumen_php() {
  local version produccion
  version="$(docker compose -f "$magents_compose" exec -T web php -r 'echo PHP_VERSION;' 2>/dev/null)" || return 0
  [ -n "$version" ] || return 0
  produccion="$(sed -nE 's/^[-* ]*(\*\*)?Versión de PHP( en producción)?(\*\*)?:(\*\*)? *//p' "$magents_carpeta/proyecto.md" | head -1 | sed -E 's/<!--.*//; s/\. .*//; s/[[:space:]]+$//')"
  magents_etiqueta "PHP"
  magents_pintar 36 "$version"
  if [ -n "$produccion" ]; then
    printf ' '
    magents_pintar "$magents_gris" "(producción: $produccion)"
  fi
  echo
}

magents_resumen_servicios() {
  local todos en_marcha servicio marcha="" parados=""
  todos="$(docker compose -f "$magents_compose" config --services 2>/dev/null)" || return 0
  en_marcha="$(docker compose -f "$magents_compose" ps --status running --services 2>/dev/null)"
  for servicio in $todos; do
    if grep -qxF "$servicio" <<<"$en_marcha"; then
      marcha="$marcha${marcha:+, }$servicio"
    else
      parados="$parados${parados:+, }$servicio"
    fi
  done
  magents_etiqueta "Servicios"
  [ -z "$marcha" ] || magents_pintar 32 "$marcha en marcha"
  [ -z "$marcha" ] || [ -z "$parados" ] || printf '; '
  [ -z "$parados" ] || magents_pintar "1;33" "$parados parado$([[ "$parados" == *,* ]] && echo s)"
  echo
}

magents_resumen_copias() {
  local copias=() tamano
  shopt -s nullglob
  copias=("$magents_carpeta"/entorno.anterior/*/ "$magents_carpeta"/entorno.anterior-*/)
  shopt -u nullglob
  [ "${#copias[@]}" -gt 0 ] || return 0
  tamano="$(du -sch "${copias[@]}" 2>/dev/null | tail -1 | cut -f1)"
  magents_etiqueta "Copias anteriores"
  magents_pintar 36 "${#copias[@]}"
  printf ' (%s)\n' "${tamano:-?}"
}

# Solo informa: no cambia nada ni influye en el código de salida de quien lo llame.
magents_resumen_entorno() {
  magents_estado
  echo
  if [ -e "$magents_compose" ] && magents_en_marcha; then
    magents_resumen_php
    magents_resumen_servicios
  fi
  magents_resumen_copias
  return 0
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
