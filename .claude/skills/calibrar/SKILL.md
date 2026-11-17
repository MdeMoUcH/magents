---
name: calibrar
description: "Comprueba que las pruebas en Firefox detectan un fallo: siembra un defecto en una tarea ya terminada, lanza al probador sin avisarle y deshace el cambio."
argument-hint: "[NNNN de una tarea terminada]"
disable-model-invocation: true
hooks:
  PreToolUse:
    - matcher: "Bash|Read|Edit|Write|Grep|Glob|NotebookEdit|mcp__firefox-devtools__.*"
      hooks:
        - type: command
          command: 'node "$CLAUDE_PROJECT_DIR/.claude/skills/magents-normas/limite-carpeta.cjs"'
          onFailure: block
---

# Calibración de las pruebas

Tarea de referencia: $ARGUMENTS

Un `APROBADO` de `probador` solo vale si un fallo le haría rechazar. Aquí se comprueba: `desarrollador` siembra un defecto que incumple un criterio de una tarea ya terminada, `probador` la prueba sin saberlo y el defecto se deshace. **Tú no programas ni pruebas**: lanzas a los dos con la herramienta Agent, guardas lo que devuelven y compruebas con git que el código queda como estaba. Háblale al usuario en español.

Lee `${CLAUDE_SKILL_DIR}/../magents-normas/SKILL.md`: sus normas valen también para ti. No indiques `model` al lanzar los subagentes, que no ven esta conversación.

## Antes de empezar

1. **Calibración a medias**: si algún `.magents/calibracion/*/estado.md` tiene una línea `Pendiente:`, no siembres nada: ve al paso 4 con su `siembra.md` y su `siembra.diff`, y termina ahí. El paso 4 empieza por volver a mostrar a git el archivo oculto.
2. **Código limpio**: si `git status --porcelain` muestra algo, para y dile al usuario que confirme o aparte sus cambios: el defecto se mezclaría con ellos y no se podría comprobar que se ha deshecho.
3. **Entorno**: ejecuta `.magents/scripts/comprobar-entorno.sh`, si existe. Si sale con error, para: hay que ejecutar `/preparar` con «Revisar». Después sigue el punto 5 de «Preparación» de `/tarea`, para guardar la BD del usuario.
4. **Tarea de referencia**: la indicada o, si no hay ninguna, la más reciente de `.magents/tareas/` que tenga `informes/documentacion.md`. Necesita `informes/triaje.md`, que en las tareas anteriores al cambio de nombre se llama `informes/triage.md` (usa ese y pásalo así donde esta skill dice `triaje.md`), y un `informes/pruebas-<n>.md` con `APROBADO`. Si no hay ninguna así, díselo al usuario y para.
5. **Tipo de defecto**: pregunta al usuario con AskUserQuestion, nombrando la tarea de referencia para que pueda cambiarla:
   - **Sutil** (recomendado): el caso principal del criterio sigue funcionando y falla algo que el criterio o los casos límite de `triaje.md` piden de forma expresa, como un valor límite, un rol, un texto o la vista móvil. Es lo que distingue un `PASA` de un `PARCIAL`.
   - **Evidente**: deja de cumplirse el caso principal de un criterio.

Crea `.magents/calibracion/<fecha y hora>/`, con el formato de fecha de `entorno.anterior/`, y guarda en `estado.md` de esa carpeta la tarea de referencia, el commit actual (`git rev-parse HEAD`) y el tipo de defecto.

## Pasos

1. **Siembra**: añade a `estado.md` la línea `Pendiente: deshacer la siembra` y lanza `desarrollador`. Pásale el id y la ruta de la tarea de referencia, las rutas de su `triaje.md` y de `.magents/proyecto.md`, el tipo de defecto, y que siga `.claude/skills/calibrar/siembra.md`, por encargo del usuario. Guarda su respuesta en `siembra.md` y la salida de `git diff` en `siembra.diff`. Con `BLOQUEADO`, o si `git status --porcelain` muestra algo más que el archivo de su informe, ve al paso 4 y termina sin resultado. Después ejecuta `.magents/scripts/ocultar-siembra.sh <archivo>`, con el archivo sembrado: mientras dure la prueba, `git status` y `git diff` no enseñan ese cambio, que si no señalaría a `probador` dónde mirar. Comprueba que `git status --porcelain` no muestra nada; si el script falla o no existe, anótalo en `estado.md` y sigue: el resultado valdrá menos, y debes decirlo en el informe.
2. **Prueba a ciegas**: lanza `probador` como en la fase 5 de `/tarea`, con el texto íntegro de la tarea de referencia, su id, su carpeta, su commit base, las rutas de `triaje.md`, del último `desarrollo-<n>.md` y de `.magents/proyecto.md`, los métodos de prueba que el usuario aceptó según su `estado.md` y, como carpeta de evidencia, una nueva dentro de la tarea de referencia, `.magents/tareas/<id>/capturas/<n>/`, con el número siguiente al mayor que exista ahí. **No le menciones la calibración, la siembra ni ninguna ejecución anterior**, ni le pases ninguna ruta de `.magents/calibracion/`: ni en el prompt ni en lo que le respondas después. Guarda su respuesta en `pruebas.md` de la calibración y, cuando termine, mueve esa carpeta de evidencia a `.magents/calibracion/<fecha y hora>/capturas/`. Si se bloquea por el entorno o el MCP, pregunta al usuario y continúalo como en `/tarea`; si no se resuelve, sigue al paso 4 sin resultado.
3. **Resultado**, según lo que diga `pruebas.md` del criterio sembrado:

   | Informe de `probador` | Resultado |
   |---|---|
   | `RECHAZADO`, con ese criterio en `FALLA` o el defecto descrito en «Fallos» | `DETECTADO` |
   | `BLOQUEADO`, con ese criterio en `PARCIAL` | `A MEDIAS`: no lo aprueba, pero tampoco ve el fallo |
   | `APROBADO`, o `RECHAZADO` por otro motivo | `NO DETECTADO` |
   | Sin veredicto, o bloqueado por el entorno | `SIN RESULTADO` |

   No lo decidas por lo que el probador debería haber visto: solo por lo que escribió.
4. **Deshacer**, siempre, también si algo falló antes: ejecuta primero `.magents/scripts/ocultar-siembra.sh --mostrar`, para que git vuelva a ver el archivo; si sale con error, enséñaselo al usuario y no borres la línea `Pendiente:`. Después continúa el mismo `desarrollador` con SendMessage, o relánzalo con las rutas de `siembra.md` y `siembra.diff`, para que deje el archivo como estaba. Después comprueba tú que `git status --porcelain` y `git diff` no muestran nada. Si muestran algo, dile al usuario qué archivo sigue cambiado y que puede restaurarlo con `git checkout -- <archivo>`, que ejecuta él; no borres la línea `Pendiente:`. Si está limpio, bórrala.
5. **Informe**: guarda en `resultado.md` la tarea de referencia, el tipo de defecto, el archivo y la línea, el criterio, el veredicto de `probador`, el resultado, si la siembra estuvo oculta a git durante la prueba y si su informe menciona la calibración o el cambio sin confirmar, y, copiada de su informe, la fila de ese criterio y lo que diga de él en «Sin probar». Enséñaselo al usuario. Con `NO DETECTADO` o `A MEDIAS`, indícale además qué pasos hizo `probador` en ese criterio y cuál habría hecho falta para verlo: es lo que hay que corregir en `php-pruebas-firefox` o en cómo el triaje escribe los criterios. Si `probador` rechazó por otro motivo, enséñaselo también: puede ser un fallo real.

Al terminar, también sin resultado, si `.magents/scripts/restaurar-bd.sh --estado` indica una copia pendiente, ejecuta `.magents/scripts/restaurar-bd.sh`, sin migraciones, para devolver al usuario sus datos; si falla, enséñale el error.

Una calibración prueba un solo defecto. No cambies skills ni código a partir del resultado: lo decide el usuario.
