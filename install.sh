#!/usr/bin/env bash
# Instala o actualiza los agentes y skills de magents en un proyecto PHP.
# Uso: ./install.sh [--cfw|--sin-cfw] /ruta/al/proyecto
set -euo pipefail

origen="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.claude"
source "$origen/skills/php-preparacion/plantillas/scripts/confirmar.sh"

# La skill cfw se instala sola si el destino lleva CFW; --cfw la fuerza (web que se va a migrar) y --sin-cfw la evita.
cfw=auto
case "${1:-}" in
  --cfw) cfw=si; shift ;;
  --sin-cfw) cfw=no; shift ;;
esac

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  magents_error "Uso: $0 [--cfw|--sin-cfw] /ruta/al/proyecto"
  exit 1
fi

destino="$(cd "$1" && pwd)"

if [ "$origen" = "$destino/.claude" ]; then
  magents_error "El destino es el propio magents."
  exit 1
fi

magents_cabecera

# Reinstalar sustituye los archivos de magents. Sin terminal, como en una prueba, no se pregunta.
if [ -t 0 ] && [ -e "$destino/.claude/skills/tarea/SKILL.md" ]; then
  magents_atencion "ATENCIÓN: se sustituirán en $destino los agentes y skills de magents, y se perderán sus cambios propios. Los scripts modificados se guardan en .magents/scripts/anterior/."
  echo
  read -r -p "Escribe si para continuar: " respuesta || respuesta=""
  echo
  if [ "$respuesta" != "si" ]; then
    magents_atencion "Cancelado."
    exit 1
  fi
fi

agentes=(preparador triage desarrollador revisor-codigo revisor-seguridad probador documentador)
skills=(preparar tarea calibrar magents-normas php-preparacion php-triage php-desarrollo php-revision-codigo php-revision-seguridad php-pruebas-firefox php-documentacion)

mkdir -p "$destino/.claude/agents" "$destino/.claude/skills"
for a in "${agentes[@]}"; do
  cp "$origen/agents/$a.md" "$destino/.claude/agents/$a.md"
done
for s in "${skills[@]}"; do
  rm -rf "${destino:?}/.claude/skills/$s"
  cp -r "$origen/skills/$s" "$destino/.claude/skills/$s"
done
if [ "$cfw" = auto ]; then
  cfw=no
  if [ -f "$destino/cfw/general/class/Page.php" ]; then
    cfw=si
  fi
fi
rm -rf "${destino:?}/.claude/skills/cfw"
if [ "$cfw" = si ]; then
  cp -r "$origen/skills/cfw" "$destino/.claude/skills/cfw"
  echo "Skill cfw instalada."
fi
# Solo sirve para desarrollar magents.
rm -f "$destino/.claude/skills/magents-normas/limite-carpeta.test.cjs"

# Ni magents ni lo que generan los agentes se versionan. El .htaccess protege .magents/ solo en Apache.
gitignore="$destino/.gitignore"
for ignorada in .claude/ .magents/; do
  if ! grep -qxF "$ignorada" "$gitignore" 2>/dev/null; then
    if [ -s "$gitignore" ] && [ -n "$(tail -c1 "$gitignore")" ]; then
      echo >> "$gitignore"
    fi
    echo "$ignorada" >> "$gitignore"
  fi
done

mkdir -p "$destino/.magents"
if [ ! -e "$destino/.magents/.htaccess" ]; then
  echo 'Require all denied' > "$destino/.magents/.htaccess"
fi

# Versiones anteriores dejaban cada copia del entorno suelta en .magents/.
for copia in "$destino/.magents"/entorno.anterior-*; do
  [ -d "$copia" ] || continue
  nombre="${copia##*/entorno.anterior-}"
  mkdir -p "$destino/.magents/entorno.anterior"
  if [ ! -e "$destino/.magents/entorno.anterior/$nombre" ] && mv "$copia" "$destino/.magents/entorno.anterior/$nombre" 2>/dev/null; then
    if [ -e "$destino/.magents/proyecto.md" ]; then
      sed -i "s#\.magents/entorno\.anterior-$nombre#.magents/entorno.anterior/$nombre#g" "$destino/.magents/proyecto.md"
    fi
  else
    magents_aviso "AVISO: no se ha podido mover .magents/entorno.anterior-$nombre a .magents/entorno.anterior/; se queda donde está."
  fi
done

# Estos scripts son fijos: si el entorno ya existe, se actualizan. El resto es propio de cada proyecto.
entorno="$destino/.magents/entorno"
scripts="$destino/.magents/scripts"
plantillas="$origen/skills/php-preparacion/plantillas/scripts"

instalados="$scripts/.instalados"

# Copia un script fijo. Si el actual no es el que instaló magents, lo guarda en anterior/.
instalar_script() {
  local script="$1" actual="$scripts/$1" nuevo="$plantillas/$1" copia hash
  if [ -e "$actual" ] && ! cmp -s "$actual" "$nuevo"; then
    hash="$(sha256sum "$actual" | cut -d' ' -f1)"
    if ! grep -qxF "$hash  $script" "$instalados" 2>/dev/null; then
      mkdir -p "$scripts/anterior"
      copia="$scripts/anterior/$script"
      if [ -e "$copia" ]; then
        copia="$copia.$(date +%Y%m%d-%H%M%S)"
      fi
      cp -p "$actual" "$copia"
      magents_aviso "AVISO: .magents/scripts/$script tenía cambios propios o de una versión sin registro; queda en ${copia#"$destino"/}. Lo propio del proyecto va en antes-de-iniciar.sh."
    fi
  fi
  cp "$nuevo" "$actual"
  chmod +x "$actual"
}

# Estos scripts no dependen del entorno: se instalan siempre, con la ruta de este magents.
mkdir -p "$scripts"
instalar_script copiar-revision.sh
instalar_script comprobar-entorno.sh
instalar_script confirmar.sh
instalar_script guardar-iteracion.sh
instalar_script menu.sh
dirname "$origen" > "$scripts/.ruta-magents"

# Fecha del commit de magents que se instala, para mostrarla en menu.sh.
raiz_magents="$(dirname "$origen")"
fecha_magents=""
if [ "$(git -C "$raiz_magents" rev-parse --show-toplevel 2>/dev/null)" = "$raiz_magents" ]; then
  fecha_magents="$(git -C "$raiz_magents" log -1 --format=%cd --date=format-local:'%Y-%m-%d %H:%M' 2>/dev/null || true)"
  if [ -n "$fecha_magents" ] && [ -n "$(git -C "$raiz_magents" status --porcelain 2>/dev/null)" ]; then
    fecha_magents="$fecha_magents +cambios"
  fi
fi
printf '%s\n' "${fecha_magents:-sin fecha}" > "$scripts/.version-magents"

if [ -e "$entorno/iniciar.sh" ] || [ -e "$scripts/iniciar.sh" ]; then
  # Versiones anteriores los tenían en entorno/: se guardan, por si tenían cambios propios.
  for script in iniciar.sh parar.sh reiniciar-bd.sh; do
    if [ -e "$entorno/$script" ]; then
      mkdir -p "$scripts/anterior"
      mv "$entorno/$script" "$scripts/anterior/$script"
      magents_aviso "AVISO: $script se ha movido a .magents/scripts/; el antiguo queda en .magents/scripts/anterior/ por si tenía cambios propios."
    fi
  done
  if [ -e "$entorno/antes-de-iniciar.sh" ] && [ ! -e "$scripts/antes-de-iniciar.sh" ]; then
    mv "$entorno/antes-de-iniciar.sh" "$scripts/antes-de-iniciar.sh"
  fi
  if [ -e "$destino/.magents/proyecto.md" ]; then
    sed -i -E 's#\.magents/entorno/(iniciar|parar|reiniciar-bd|antes-de-iniciar)\.sh#.magents/scripts/\1.sh#g' "$destino/.magents/proyecto.md"
  fi
  instalar_script iniciar.sh
  instalar_script parar.sh
  if grep -q '^  bd:' "$entorno/compose.yml" 2>/dev/null; then
    instalar_script reiniciar-bd.sh
  fi
fi

# Registro de lo instalado, para distinguir en la próxima instalación los cambios propios.
(cd "$scripts" && sha256sum copiar-revision.sh comprobar-entorno.sh confirmar.sh guardar-iteracion.sh menu.sh $(ls iniciar.sh parar.sh reiniciar-bd.sh 2>/dev/null)) > "$instalados"

magents_pintar "1;32" "Instalado en $destino"
echo
echo
# Solo informa: un entorno con problemas no impide instalar.
"$scripts/comprobar-entorno.sh" || true
if ! command -v node >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra node (hace falta >= 20.19 para las pruebas en Firefox)."
elif ! node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>20||(a===20&&b>=19)?0:1)'; then
  magents_aviso "AVISO: node $(node -v) es antiguo (hace falta >= 20.19 para las pruebas en Firefox)."
fi
if ! command -v npx >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra npx (hace falta para lanzar el MCP de Firefox)."
fi
if ! command -v firefox >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra firefox."
fi
if ! command -v claude >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra claude (hace falta Claude Code para usar los agentes)."
fi
if ! command -v docker >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra docker (/preparar lo necesita si el proyecto no tiene entorno propio; también sirve para php -l)."
elif ! docker compose version >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra docker compose (/preparar lo necesita si el proyecto no tiene entorno propio)."
fi
if ! command -v curl >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra curl (iniciar.sh y las pruebas lo usan para comprobar que la web responde)."
fi
if ! command -v rsync >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra rsync (copiar-revision.sh lo necesita)."
fi
if ! command -v git >/dev/null 2>&1; then
  magents_aviso "AVISO: no se encuentra git (/tarea lo necesita para ver los cambios)."
elif ! git -C "$destino" rev-parse --verify -q HEAD >/dev/null 2>&1; then
  magents_aviso "AVISO: el destino no es un repositorio git con al menos un commit; /tarea lo necesita para ver los cambios."
elif [ -n "$(git -C "$destino" ls-files -- .claude)" ]; then
  magents_aviso "AVISO: .claude/ ya tiene archivos en git y .gitignore no los excluye; para dejar de versionarlos: git rm -r --cached .claude"
fi
echo "Abre Claude Code en el proyecto, acepta la confianza de la carpeta (sin ella no arranca el MCP de Firefox) y ejecuta: /preparar"
echo "Después, para cada tarea: /tarea <descripción>"
