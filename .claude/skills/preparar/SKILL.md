---
name: preparar
description: Detecta el stack de una web PHP, propone su configuración y, tras tu confirmación, genera en .magents/ un entorno Docker local con scripts para iniciarlo y pararlo. Si ya existe, lo revisa y repara.
disable-model-invocation: true
hooks:
  PreToolUse:
    - matcher: "Bash|Read|Edit|Write|Grep|Glob|NotebookEdit|mcp__firefox-devtools__.*"
      hooks:
        - type: command
          command: 'node "$CLAUDE_PROJECT_DIR/.claude/skills/magents-normas/limite-carpeta.cjs"'
          onFailure: block
---

# Preparación del proyecto

Coordinas al subagente `preparador`: **tú no detectas ni generas nada**, lanzas cada modo con la herramienta Agent, guardas su respuesta íntegra y decides según su veredicto. Háblale al usuario en español. Los subagentes no ven esta conversación: pasa en cada prompt el modo y todo lo necesario. No indiques `model` al lanzarlo: usa el de su definición.

Si te ejecutas de forma independiente, lee antes `${CLAUDE_SKILL_DIR}/../magents-normas/SKILL.md`: sus normas valen también para ti.

Si tú o el preparador necesitáis salir de la raíz del proyecto, pide antes permiso al usuario con AskUserQuestion, indicando la ruta exacta y el motivo. Si lo concede, vale solo para esa ruta, ese fin y esta ejecución: pásalo de forma explícita en el prompt. El hook de `magents-normas` lo seguirá bloqueando hasta que **el usuario** añada esa ruta a `.magents/rutas-autorizadas.txt` y la quite al terminar. Díselo: ningún agente puede editar ese archivo. Si lo niega, sigue sin ello o informa de lo que no se ha podido hacer.

Si no es un repositorio git o no tiene ningún commit, para y pide al usuario que lo inicialice y haga un commit inicial por su cuenta: el preparador lo necesita para comprobar que el entorno no ensucia el proyecto.

## Pasos

1. **Entorno existente**: si `.magents/proyecto.md` ya tiene URL base y cómo arrancarlo, enséñaselos al usuario y pregúntale con AskUserQuestion si lo revisa (opción recomendada), lo regenera o lo conserva. Si lo conserva, termina aquí. Si lo revisa, sigue en «Revisar un entorno existente». Regenerar nunca sobrescribe: el preparador guarda una copia de `.magents/entorno/`.
2. **Propuesta**: lanza `preparador` en modo `propuesta` y guarda su respuesta en `.magents/preparacion/propuesta.md`.
3. **Confirmación**: enseña al usuario la propuesta completa, con su contenido y no solo la ruta, y usa AskUserQuestion para sus preguntas y para confirmarla. Si cambia algo, recógelo. No generes nada sin su confirmación.
4. **Generación**: lanza `preparador` en modo `generar` con la ruta de la propuesta y lo confirmado, y guarda su respuesta en `.magents/preparacion/informe.md`.
5. **Resultado**: dile qué se ha creado, la URL, los comandos para iniciar y parar, y los supuestos pendientes.

## Revisar un entorno existente

1. **Revisión**: lanza `preparador` en modo `revisar` con la salida de `.magents/scripts/comprobar-entorno.sh`, si existe. Guarda su respuesta en `.magents/preparacion/revision-<fecha y hora>.md`, en el mismo formato de fecha que `entorno.anterior/`.
2. **Sin problemas**: con `CORRECTO`, díselo al usuario y termina.
3. **Confirmación**: con `PROBLEMAS`, enséñale cada problema y su arreglo, y pregúntale con AskUserQuestion cuáles aplica. Si no aplica ninguno, indica que el entorno sigue con esos problemas y termina.
4. **Reparación**: lanza `preparador` en modo `reparar` con la ruta de la revisión y lo confirmado, sin indicarle qué comprobaciones omitir, porque lo decide su skill, y guarda su respuesta en `.magents/preparacion/reparacion-<fecha y hora>.md`.
5. **Resultado**: dile qué ha cambiado, dónde está la copia y qué sigue pendiente.

## Reglas de decisión

Cada ejecución termina con una línea `VEREDICTO: <valor>`. Si falta o es ambigua, pídele que la emita; nunca la interpretes tú.

| Veredicto | Acción |
|---|---|
| `PROPUESTA` | Paso 3 |
| `LISTO` | Paso 5, o el paso «Resultado» de la revisión si venías de `reparar` |
| `CORRECTO` / `PROBLEMAS` | Según «Revisar un entorno existente» |
| `BLOQUEADO` | Pregunta al usuario con AskUserQuestion, con el contexto, y relanza ese mismo modo con la respuesta. Tras tres bloqueos seguidos en un modo, para y preséntale el problema |

Si el usuario rechaza la propuesta o el flujo para sin `LISTO`, di de forma explícita que el entorno no está preparado.
