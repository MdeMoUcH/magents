#!/usr/bin/env bash
# Muestra los scripts de .magents/scripts/ y permite lanzarlos. Solo para uso interactivo.
set -uo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
magents_dir="$(dirname "$scripts_dir")"
proyecto="$(basename "$(dirname "$magents_dir")")"
compose="$magents_dir/entorno/compose.yml"
source "$scripts_dir/confirmar.sh"

if [ ! -t 0 ]; then
  echo "ERROR: menu.sh necesita una terminal." >&2
  exit 1
fi

mostrar_estado() {
  local direccion
  if [ ! -e "$magents_dir/proyecto.md" ]; then
    echo "entorno: sin preparar; ejecuta /preparar en Claude Code"
  elif [ ! -e "$compose" ]; then
    echo "entorno: propio del proyecto; consulta .magents/proyecto.md"
  elif ! command -v docker >/dev/null 2>&1; then
    echo "entorno: desconocido, sin docker"
  elif magents_en_marcha; then
    direccion="$(docker compose -f "$compose" port web 80 2>/dev/null)"
    echo "entorno: en marcha${direccion:+ (http://$direccion)}"
  else
    echo "entorno: parado"
  fi
}

# Primero los habituales; después cualquier otro script ejecutable.
listar_scripts() {
  local nombre ruta
  for nombre in iniciar.sh parar.sh reiniciar-bd.sh comprobar-entorno.sh copiar-revision.sh; do
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
    echo "Cancelado."
    return
  fi
  if [ "$script" = "copiar-revision.sh" ]; then
    read -r -p "¿Incluir los diffs? [S/n]: " respuesta || return
    case "$respuesta" in
      n | N | no | NO) argumentos=(--sin-diff) ;;
    esac
  fi
  # Ya confirmado aquí: el script no vuelve a preguntar.
  MAGENTS_CONFIRMADO=1 "$scripts_dir/$script" ${argumentos[@]+"${argumentos[@]}"}
  codigo=$?
  echo
  if [ "$codigo" -eq 0 ]; then
    echo "$script ha terminado bien."
  else
    echo "$script ha terminado con error (código $codigo)."
  fi
}

limpiar() {
  clear 2>/dev/null || true
}

# Espera una tecla y descarta el resto de lo pulsado, porque una flecha envía varios caracteres.
esperar_tecla() {
  local tecla
  echo
  echo
  read -r -s -n 1 -p "Toca cualquier tecla para continuar..." tecla || exit 0
  while read -r -s -n 1 -t 0.05 tecla; do :; done
}

aviso=""
while true; do
  limpiar
  mapfile -t lista < <(listar_scripts)
  if [ -n "$aviso" ]; then
    echo "$aviso"
    aviso=""
  fi
  echo
  echo "magents · $proyecto · $(mostrar_estado)"
  echo
  for i in "${!lista[@]}"; do
    printf '  %d) %-22s %s\n' "$((i + 1))" "${lista[$i]}" "$(descripcion "${lista[$i]}")"
  done
  echo "  0) Salir"
  echo
  read -r -p "Opción: " opcion || break
  case "$opcion" in
    0) break ;;
    '' | *[!0-9]*) aviso="Opción no válida." ;;
    *)
      if [ "$opcion" -ge 1 ] && [ "$opcion" -le "${#lista[@]}" ]; then
        limpiar
        lanzar "${lista[$((opcion - 1))]}"
        esperar_tecla
      else
        aviso="Opción no válida."
      fi
      ;;
  esac
done
