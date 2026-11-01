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

agentes=(triage desarrollador revisor-codigo revisor-seguridad probador documentador)
skills=(tarea php-triage php-desarrollo php-revision-codigo php-revision-seguridad php-pruebas-firefox php-documentacion)

mkdir -p "$destino/.claude/agents" "$destino/.claude/skills"
for a in "${agentes[@]}"; do
  cp "$origen/agents/$a.md" "$destino/.claude/agents/$a.md"
done
for s in "${skills[@]}"; do
  rm -rf "${destino:?}/.claude/skills/$s"
  cp -r "$origen/skills/$s" "$destino/.claude/skills/$s"
done

# Todo lo que generan los agentes va en .magents/, que no se versiona ni se sirve por web.
gitignore="$destino/.gitignore"
if ! grep -qxF '.magents/' "$gitignore" 2>/dev/null; then
  if [ -s "$gitignore" ] && [ -n "$(tail -c1 "$gitignore")" ]; then
    echo >> "$gitignore"
  fi
  echo '.magents/' >> "$gitignore"
fi

mkdir -p "$destino/.magents"
if [ ! -e "$destino/.magents/.htaccess" ]; then
  echo 'Require all denied' > "$destino/.magents/.htaccess"
fi

echo "Instalado en $destino"
if ! command -v node >/dev/null 2>&1; then
  echo "AVISO: no se encuentra node (hace falta >= 20.19 para las pruebas en Firefox)." >&2
elif ! node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>20||(a===20&&b>=19)?0:1)'; then
  echo "AVISO: node $(node -v) es antiguo (hace falta >= 20.19 para las pruebas en Firefox)." >&2
fi
if ! command -v firefox >/dev/null 2>&1; then
  echo "AVISO: no se encuentra firefox." >&2
fi
echo "Abre Claude Code en el proyecto y ejecuta: /tarea <descripción>"
