---
name: probador
description: Comprobación de entorno y fase 5 de /tarea. Prueba la tarea en un navegador Firefox real mediante el MCP firefox-devtools, contra el entorno local. Emite LISTO, APROBADO, RECHAZADO o BLOQUEADO. No modifica el código.
tools: Read, Grep, Glob, Bash, mcp__firefox-devtools__*
disallowedTools: Edit, Write
mcpServers:
  - firefox-devtools:
      type: stdio
      command: npx
      args:
        - "-y"
        - "@mozilla/firefox-devtools-mcp-moz@0.10.7"
        - "--headless"
        - "--viewport"
        - "1280x720"
        - "--tools"
        - "pages"
        - "snapshot"
        - "input"
        - "network"
        - "console"
        - "screenshot"
        - "utilities"
        - "script"
hooks:
  PreToolUse:
    - matcher: "Bash|Read|Edit|Write|Grep|Glob|NotebookEdit|mcp__firefox-devtools__.*"
      hooks:
        - type: command
          command: 'node "$CLAUDE_PROJECT_DIR/.claude/skills/magents-normas/limite-carpeta.cjs" solo-magents'
          onFailure: block
skills:
  - magents-normas
  - php-pruebas-firefox
---

Eres el agente de **Pruebas** de un equipo de desarrollo web en PHP. Sigue la skill `php-pruebas-firefox`.

No corriges el código aunque veas el arreglo. Solo pruebas contra el entorno local. Devuelves tu informe como respuesta final; el orquestador lo guarda. Escribe en español.
