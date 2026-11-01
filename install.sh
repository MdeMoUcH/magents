#!/usr/bin/env bash
# Instala o actualiza los agentes y skills de magents en un proyecto PHP.
# Uso: ./install.sh /ruta/al/proyecto
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "Uso: $0 /ruta/al/proyecto" >&2
  exit 1
fi

origen="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.claude"
destino="$(cd "$1" && pwd)"

if [ "$origen" = "$destino/.claude" ]; then
  echo "El destino es el propio magents." >&2
  exit 1
fi

agentes=(preparador triage desarrollador revisor-codigo revisor-seguridad probador documentador)
skills=(preparar tarea magents-normas php-preparacion php-triage php-desarrollo php-revision-codigo php-revision-seguridad php-pruebas-firefox php-documentacion)

mkdir -p "$destino/.claude/agents" "$destino/.claude/skills"
for a in "${agentes[@]}"; do
  cp "$origen/agents/$a.md" "$destino/.claude/agents/$a.md"
done
for s in "${skills[@]}"; do
  rm -rf "${destino:?}/.claude/skills/$s"
  cp -r "$origen/skills/$s" "$destino/.claude/skills/$s"
done

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

# Estos scripts son fijos: si el entorno ya existe, se actualizan. El resto es propio de cada proyecto.
for script in iniciar.sh parar.sh; do
  if [ -e "$destino/.magents/entorno/$script" ]; then
    cp "$origen/skills/php-preparacion/plantillas/$script" "$destino/.magents/entorno/$script"
    chmod +x "$destino/.magents/entorno/$script"
  fi
done
if [ -e "$destino/.magents/entorno/iniciar.sh" ] && grep -q '^  bd:' "$destino/.magents/entorno/compose.yml" 2>/dev/null; then
  cp "$origen/skills/php-preparacion/plantillas/reiniciar-bd.sh" "$destino/.magents/entorno/reiniciar-bd.sh"
  chmod +x "$destino/.magents/entorno/reiniciar-bd.sh"
fi

echo "Instalado en $destino"
if ! command -v node >/dev/null 2>&1; then
  echo "AVISO: no se encuentra node (hace falta >= 20.19 para las pruebas en Firefox)." >&2
elif ! node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>20||(a===20&&b>=19)?0:1)'; then
  echo "AVISO: node $(node -v) es antiguo (hace falta >= 20.19 para las pruebas en Firefox)." >&2
fi
if ! command -v npx >/dev/null 2>&1; then
  echo "AVISO: no se encuentra npx (hace falta para lanzar el MCP de Firefox)." >&2
fi
if ! command -v firefox >/dev/null 2>&1; then
  echo "AVISO: no se encuentra firefox." >&2
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "AVISO: no se encuentra claude (hace falta Claude Code para usar los agentes)." >&2
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "AVISO: no se encuentra docker (/preparar lo necesita si el proyecto no tiene entorno propio; también sirve para php -l)." >&2
elif ! docker compose version >/dev/null 2>&1; then
  echo "AVISO: no se encuentra docker compose (/preparar lo necesita si el proyecto no tiene entorno propio)." >&2
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "AVISO: no se encuentra curl (iniciar.sh y las pruebas lo usan para comprobar que la web responde)." >&2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "AVISO: no se encuentra git (/tarea lo necesita para ver los cambios)." >&2
elif ! git -C "$destino" rev-parse --verify -q HEAD >/dev/null 2>&1; then
  echo "AVISO: el destino no es un repositorio git con al menos un commit; /tarea lo necesita para ver los cambios." >&2
elif [ -n "$(git -C "$destino" ls-files -- .claude)" ]; then
  echo "AVISO: .claude/ ya tiene archivos en git y .gitignore no los excluye; para dejar de versionarlos: git rm -r --cached .claude" >&2
fi
echo "Abre Claude Code en el proyecto, acepta la confianza de la carpeta (sin ella no arranca el MCP de Firefox) y ejecuta: /preparar"
echo "Después, para cada tarea: /tarea <descripción>"
