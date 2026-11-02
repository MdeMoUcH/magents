#!/usr/bin/env bash
# Muestra los scripts de .magents/scripts/ y permite lanzarlos. Solo para uso interactivo.
set -uo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
magents_dir="$(dirname "$scripts_dir")"
proyecto="$(basename "$(dirname "$magents_dir")")"
source "$scripts_dir/confirmar.sh"

if [ ! -t 0 ]; then
  magents_error "ERROR: menu.sh necesita una terminal."
  exit 1
fi

# Primero los habituales; después cualquier otro script ejecutable.
listar_scripts() {
  local nombre ruta
  for nombre in comprobar-entorno.sh copiar-revision.sh iniciar.sh parar.sh reiniciar-bd.sh; do
    [ -x "$scripts_dir/$nombre" ] && echo "$nombre"
  done
  for ruta in "$scripts_dir"/*.sh; do
    nombre="$(basename "$ruta")"
    case "$nombre" in
      menu.sh | confirmar.sh | antes-de-iniciar.sh | iniciar.sh | parar.sh | reiniciar-bd.sh | comprobar-entorno.sh | copiar-revision.sh) ;;
      *) [ -x "$ruta" ] && echo "$nombre" ;;
    esac
  done
}

descripcion() {
  sed -n '2s/^#[[:space:]]*//p' "$scripts_dir/$1"
}

lanzar() {
  local script="$1" respuesta codigo
  local argumentos=()
  if ! magents_preguntar "$scripts_dir/$script"; then
    magents_atencion "Cancelado."
    return
  fi
  if [ "$script" = "copiar-revision.sh" ]; then
    read -r -p "¿Incluir los diffs? [S/n]: " respuesta || return
    case "$respuesta" in
      n | N | no | NO) argumentos=(--sin-diff) ;;
    esac
  fi
  # Ya confirmado aquí: el script no vuelve a preguntar.
  MAGENTS_CONFIRMADO=1 MAGENTS_CABECERA_MOSTRADA=1 "$scripts_dir/$script" ${argumentos[@]+"${argumentos[@]}"}
  codigo=$?
  echo
  if [ "$codigo" -eq 0 ]; then
    magents_ok "$script ha terminado bien."
  else
    magents_error "$script ha terminado con error (código $codigo)."
  fi
}

limpiar() {
  clear 2>/dev/null || true
}

# Espera una tecla y descarta el resto de lo pulsado, porque una flecha envía varios caracteres.
descartar_teclas() {
  local tecla
  while read -r -s -n 1 -t 0.05 tecla; do :; done
}

esperar_tecla() {
  local tecla
  echo
  echo
  read -r -s -n 1 -p "Toca cualquier tecla para continuar..." tecla || exit 0
  descartar_teclas
}

# Con una sola cifra basta una tecla. Con más de nueve opciones hay que confirmar con Intro.
leer_opcion() {
  if [ "${#lista[@]}" -le 9 ]; then
    read -r -n 1 -p "Opción: " opcion || return 1
    descartar_teclas
  else
    read -r -p "Opción: " opcion || return 1
  fi
}

if [ -t 1 ] && [ -z "${CLAUDECODE:-}" ]; then
  trap echo EXIT
fi

version_magents="$(cat "$scripts_dir/.version-magents" 2>/dev/null || true)"
version_magents="${version_magents:-sin fecha}"
# En amarillo si se instaló con cambios sin commit: la fecha no refleja del todo lo instalado.
if [[ "$version_magents" == *"+cambios" ]]; then
  version_magents="$(magents_pintar 33 "$version_magents")"
fi

aviso=""
while true; do
  limpiar
  magents_banner
  mapfile -t lista < <(listar_scripts)
  if [ -n "$aviso" ]; then
    magents_atencion "$aviso"
    aviso=""
  fi
  echo "  magents ($version_magents) · $proyecto · $(magents_estado)"
  echo
  for i in "${!lista[@]}"; do
    # El relleno va dentro del color: los códigos invisibles descuadrarían %-22s.
    printf '  %s %s %s\n\n' "$(magents_pintar 1 "$((i + 1)))")" "$(magents_pintar "1;32" "$(printf '%-22s' "${lista[$i]}")")" "$(magents_pintar "$magents_gris" "$(descripcion "${lista[$i]}")")"
  done
  echo "  $(magents_pintar 1 "0) Salir")"
  echo
  leer_opcion || break
  case "$opcion" in
    0) break ;;
    '' | *[!0-9]*) aviso="Opción no válida." ;;
    *)
      if [ "$opcion" -ge 1 ] && [ "$opcion" -le "${#lista[@]}" ]; then
        limpiar
        magents_banner
        lanzar "${lista[$((opcion - 1))]}"
        esperar_tecla
      else
        aviso="Opción no válida."
      fi
      ;;
  esac
done
