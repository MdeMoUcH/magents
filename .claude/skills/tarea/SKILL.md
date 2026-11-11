---
name: tarea
description: "Ejecuta una tarea de desarrollo web PHP con el flujo completo de agentes: triage, desarrollo, revisión de código, revisión de seguridad, pruebas en Firefox y documentación."
argument-hint: "[descripción de la tarea | continuar <NNNN>]"
disable-model-invocation: true
hooks:
  PreToolUse:
    - matcher: "Bash|Read|Edit|Write|Grep|Glob|NotebookEdit|mcp__firefox-devtools__.*"
      hooks:
        - type: command
          command: 'node "$CLAUDE_PROJECT_DIR/.claude/skills/magents-normas/limite-carpeta.cjs"'
          onFailure: block
---

# Orquestador de tareas

Tarea: $ARGUMENTS

Coordinas siete subagentes. **Tú no analizas, programas, revisas ni pruebas**: lanzas cada fase con la herramienta Agent, guardas lo que devuelve y decides la siguiente según su veredicto. Trabaja sin parar hasta terminar o hasta tener una duda real para el usuario. Háblale en español, con una línea por cada cambio de fase.

Si no hay descripción de la tarea, pregúntala. Si la descripción es `continuar <NNNN>`, ve a «Retomar una tarea».

## Normas comunes

Lee `${CLAUDE_SKILL_DIR}/../magents-normas/SKILL.md`: sus normas valen también para ti, y los subagentes ya las cargan.

Si tú o un subagente necesitáis salir de la raíz del proyecto, pide antes permiso al usuario con AskUserQuestion, indicando la ruta exacta y el motivo. Si lo concede, vale solo para esa ruta, ese fin y esta tarea: anótalo en `estado.md` y pásalo de forma explícita en el prompt del subagente. El hook de `magents-normas` lo seguirá bloqueando hasta que **el usuario** añada esa ruta a `.magents/rutas-autorizadas.txt`, una por línea, y la quite al terminar. Díselo: ningún agente puede editar ese archivo. Si lo niega, sigue sin ello o informa de lo que no se ha podido hacer.

## Flujo

```
triage → entorno → desarrollador → revisor-codigo → revisor-seguridad → probador → documentador
                        ↑                 │                 │               │
                        └──── RECHAZADO ──┴─────────────────┴───────────────┘
```

`entorno` es `probador` en modo de comprobación: confirma que se podrá probar antes de gastar desarrollo y revisiones. Sáltala solo si se cumple todo esto: «Necesidades de prueba» de `triage.md` dice «Ninguna», no ha habido corrección de entorno en esta tarea, `.magents/scripts/comprobar-entorno.sh` pasa justo antes y la URL base de `proyecto.md` responde con `curl`. Anótalo en el historial («Entorno: omitida, sin necesidades de prueba») y pasa a `desarrollador`. Si `probador` se bloquea después por el entorno o el MCP, resuélvelo como cualquier `BLOQUEADO` y no cuenta como iteración. Tras cualquier rechazo se vuelve a `desarrollador` y después se repiten **las tres verificaciones en orden**, porque un arreglo puede romper lo ya aprobado. Lanza cada verificación al terminar la anterior, nunca a la vez: si una rechaza, el trabajo de las siguientes se pierde.

## Preparación

1. Si no es un repositorio git o no tiene ningún commit, para y pide al usuario que lo inicialice y haga un commit inicial por su cuenta, porque sin commit base los revisores no pueden ver qué ha cambiado.
2. Si `.magents/proyecto.md` no existe o le falta la URL base o cómo arrancar el entorno, lee `${CLAUDE_SKILL_DIR}/../preparar/SKILL.md` y sigue sus pasos antes de continuar. Si no termina con `LISTO`, para: sin entorno no se puede probar la tarea, y el usuario tendrá que lanzar `/tarea` de nuevo cuando lo tenga.
   Si ya existe y también `.magents/scripts/comprobar-entorno.sh`, ejecútalo. Si sale con error, enseña los problemas al usuario y pregúntale con AskUserQuestion si los revisa ahora, siguiendo «Revisar un entorno existente» de `${CLAUDE_SKILL_DIR}/../preparar/SKILL.md`, o si para. Solo sigue con la tarea si el script pasa después.
3. Genera el identificador `<NNNN>-<slug-corto>`: `NNNN` es el mayor número que aparezca en `.magents/tareas/`, más uno, con cuatro dígitos (`0001` si no hay ninguno). Un número usado por una tarea abandonada no se reutiliza. Crea `.magents/tareas/<id>/informes/` y `.magents/tareas/<id>/capturas/`.
4. Guarda en `estado.md` el texto íntegro de la tarea, el commit base (`git rev-parse HEAD`) y la salida de `git status --porcelain`: esos cambios ya existentes **no son de la tarea**. Si hay alguno, guarda también `git diff HEAD` en `informes/cambios-previos.diff`, avisa al usuario de que pueden mezclarse con los de la tarea si afectan a los mismos archivos y pregúntale si continúa o prefiere confirmarlos antes.

Mantén `estado.md` al día: en cada cambio de fase, **sustituye** los apartados «Fase actual» e «Iteración de desarrollo», sin dejar el valor antiguo, y añade los veredictos al historial. Si quedas esperando algo del usuario, anótalo en una línea `Pendiente: <qué falta y qué hay que hacer después>`, y bórrala al resolverlo. Usa siempre este formato, con la fecha en cada línea del historial:

```markdown
# Estado de la tarea <id>

## Tarea

<texto íntegro>

## Commit base

<hash completo>

## Cambios previos (git status --porcelain)

<salida, o «(ninguno)»>

## Fase actual

<fase>

## Iteración de desarrollo

<n>

## Historial

- <AAAA-MM-DD>: <fase> <n> → <veredicto> (informes/<archivo>). <lo que importe para seguir>
- <AAAA-MM-DD>: <decisión del usuario o hecho, y qué se hace después>
```

Si el usuario hace un commit antes de que empiece el desarrollo, cambia el commit base por el nuevo en su apartado de `estado.md`, anota el anterior en el historial y actualiza los cambios previos. Una vez empezado el desarrollo, el commit base ya no cambia.

## Retomar una tarea

Con `continuar <NNNN>`, busca `.magents/tareas/<NNNN>-*/` y lee su `informes/estado.md` y sus informes. Conserva el id, el commit base y el contador de iteraciones. Si hay una línea `Pendiente:`, o una confirmación o un cambio de entorno sin resolver en el historial, resuélvelo antes de lanzar nada. Ejecuta también `.magents/scripts/comprobar-entorno.sh`, si existe, y actúa como en el paso 2 de «Preparación». Después relanza la primera fase sin veredicto guardado. No repitas la preparación. Si los archivos han cambiado desde el último informe, avisa al usuario antes de seguir. Si no encuentras la carpeta o no hay `estado.md`, díselo y para.

## Cómo lanzar cada fase

No indiques `model` al lanzarlos: cada uno usa el de su definición. Los subagentes no ven esta conversación. Pasa siempre en el prompt: el texto íntegro de la tarea, el id, la ruta `.magents/tareas/<id>/`, el commit base y lo específico de la fase. Guarda la respuesta final de cada uno, íntegra y sin resumir, en el archivo indicado dentro de `informes/`, donde también va `estado.md`.

| Fase | Subagente | Guardar en | Le pasas además |
|---|---|---|---|
| 1 | `triage` | `triage.md` | ruta de `.magents/proyecto.md`; respuestas previas del usuario, si las hay |
| Corrección de entorno | `preparador` | `preparacion-<n>.md` | modo `generar`; lo que haya confirmado el usuario |
| Entorno | `probador` | `entorno.md` | indicación de hacer solo la comprobación de entorno, salvo si se omite (ver arriba); rutas de `triage.md` y `.magents/proyecto.md`; carpeta de evidencia `capturas/entorno/` |
| 2 | `desarrollador` | `desarrollo-<n>.md` | rutas de `triage.md` y `.magents/proyecto.md`; desde `n=2`, ruta del informe que rechazó |
| 3 | `revisor-codigo` | `revision-codigo-<n>.md` | rutas de `triage.md`, `desarrollo-<n>.md` y `.magents/proyecto.md` |
| 4 | `revisor-seguridad` | `revision-seguridad-<n>.md` | rutas de `triage.md` y `desarrollo-<n>.md` |
| 5 | `probador` | `pruebas-<n>.md` | rutas de `triage.md`, `desarrollo-<n>.md` y `.magents/proyecto.md`; commit base; carpeta de evidencia `capturas/<n>/`; ejecución anterior de esta iteración, si la hay |
| 6 | `documentador` | `documentacion.md` | ruta de la carpeta de la tarea |

Antes de lanzar `documentador`, borra `.magents/tareas/<id>/tmp/`, salvo lo que un informe pida conservar, para que la ficha describa lo que queda de verdad. Crea la carpeta de evidencia antes de lanzar `probador`. Si ya tiene contenido de una ejecución anterior, usa una nueva con sufijo (`capturas/<n>-2/`).

## Reglas de decisión

Cada subagente termina con una línea `VEREDICTO: <valor>`. Si falta o es ambigua, pídele que la emita con SendMessage, o relanza la fase si no puedes; nunca la interpretes tú. Haz lo mismo si contradice su propio informe, como un `APROBADO` de `probador` con algún criterio en `PARCIAL` o `FALLA`: pídele que lo revise, indicando el criterio.

| Veredicto | Acción |
|---|---|
| `LISTO` (triage o entorno), `IMPLEMENTADO` (desarrollo), `DOCUMENTADO` | Siguiente fase |
| `APROBADO` | Siguiente fase |
| `RECHAZADO` | `n += 1` y volver a `desarrollador` |
| `DUDAS` / `BLOQUEADO` | Pregunta al usuario con AskUserQuestion, incluyendo el contexto, y pasa la respuesta a esa misma fase: si puedes, continúa el mismo subagente con SendMessage, que ya tiene el análisis hecho; si no, relánzala con la respuesta. Antes de guardar su nueva respuesta, renombra el informe anterior añadiendo un número (`triage-1.md`, `entorno-1.md`, `pruebas-1-1.md`…); haz lo mismo con cualquier informe que se vaya a sobrescribir, como `documentacion.md`. Un `BLOQUEADO` del probador no es un rechazo: no gastes una iteración de desarrollo en él |

- **Discrepancias con `proyecto.md`**: si el triage señala alguna, enséñasela al usuario antes de la comprobación de entorno. Si hay que corregir la configuración o el entorno, lanza `preparador` en modo `generar` con lo que confirme y guarda su respuesta en `informes/preparacion-<n>.md`. Con `LISTO`, sigue con la comprobación de entorno. Con `BLOQUEADO`, aplica la regla de esa tabla, con un máximo de tres bloqueos seguidos.
- **Fase interrumpida**: si un subagente se detiene sin veredicto, anótalo en el historial con lo que dejó a medias. Al relanzar esa fase, indícale qué se interrumpió y qué restos quedan. No cuenta como iteración.
- **Continuar o relanzar `probador` en la misma iteración**: tras un corte, si puedes, continúa el mismo subagente con SendMessage e indícale que siga «Si se retoma» de `php-pruebas-firefox`. Tras un `BLOQUEADO`, continúalo igual con la respuesta del usuario. Si no puedes continuarlo, relánzalo y pásale en el prompt la carpeta de evidencia más reciente de esa iteración que tenga `progreso.md`, para que reutilice lo que siga valiendo. Tras un `RECHAZADO` hay iteración nueva y se prueba todo.
- **Métodos de prueba**: si la comprobación de entorno se bloquea solo por un método de prueba y el usuario lo acepta, no la repitas: anota la aceptación en el historial y pásala a `probador`. Pregúntale también si vale para futuras tareas; si dice que sí, añádela a «Métodos de prueba aceptados» de `.magents/proyecto.md`. Haz lo mismo si la comprobación termina en `LISTO` pero propone un método de prueba o un cambio de datos o de archivos que no estén en `triage.md` ni en esos métodos aceptados, como crear un archivo de configuración temporal: pregúntaselo al usuario antes de pasarlo a `desarrollador` o `probador`, y pásalo solo si lo acepta, indicando que lo ha aceptado él.
- **Borrados del plan**: si `triage.md` incluye borrados, enséñaselos al usuario antes de desarrollar. Un borrado rechazado se le pregunta: no lo reintentes ni dejes que un subagente lo reintente.
- **Comandos declarados**: lee el apartado «Comandos que declarar» de cada informe. Si algo tuvo efecto fuera de lo previsto o deja algo pendiente, como un contenedor colgado, un archivo fuera de `tmp/` o datos cambiados, díselo al usuario en la línea de esa fase y anótalo en el historial. Lo que no tuvo efecto basta con que quede en el informe.
- **Observaciones de `documentador`**: enséñale siempre al usuario las que no se hayan contrastado, aunque el flujo haya terminado. Pueden ser un defecto que las pruebas no vieron.
- **Documentación del proyecto pendiente**: si el informe de `documentador` la tiene, enséñasela al usuario con el texto propuesto y pregúntale con AskUserQuestion si se aplica ahora o queda como deuda. Si se aplica, anótalo en el historial, lanza `desarrollador` en una iteración nueva por decisión del usuario, no por rechazo, solo con esos cambios, y repite revisión de código, revisión de seguridad y documentación; las pruebas solo si los cambios afectan a lo que ve la web, como un texto de una página. Si queda como deuda, anótalo en el historial.
- **Criterios parciales**: si el probador termina con `BLOQUEADO` por un criterio `PARCIAL`, enseña al usuario qué queda fuera. Si acepta esa exclusión, anótalo en el historial y relanza `probador` solo para ese criterio, indicándole la exclusión aceptada.
- **Decisiones del usuario**: si un informe deja un riesgo o una decisión para el usuario, pregúntale con AskUserQuestion antes de seguir, aunque el veredicto permita avanzar. No las tomes tú. Puedes prohibir de inmediato una acción peligrosa, pero no sustituir una prueba ni excluir nada de un criterio: lo que esa prohibición impida probar queda `PARCIAL` hasta que el usuario lo acepte. Anota su respuesta en el historial y, al pasarla a un subagente, indica que la ha aceptado el usuario.
- **Sugerencias aceptadas**: pregunta por las sugerencias y endurecimientos opcionales de las dos revisiones a la vez, al terminar la revisión de seguridad y antes de las pruebas, no tras cada revisión. Si el usuario acepta alguno, anótalo en el historial y lanza `desarrollador` en una iteración nueva por decisión del usuario, no por rechazo, solo con esos cambios; después repite las tres verificaciones, como tras un rechazo.
- **Límite**: como máximo **5 iteraciones** de desarrollo. Las abiertas por decisión del usuario, sin rechazo previo, no cuentan: se numeran igual, pero anótalas así en el historial. Si se rechaza la 5.ª que cuenta, para y presenta al usuario el historial y el problema pendiente.
- **Ciclo sin avance**: si el mismo problema vuelve a aparecer en dos rechazos seguidos, para antes del límite y pregunta.
- **Desacuerdo**: si el desarrollador responde que un hallazgo es erróneo, no lo decides tú: la siguiente revisión lo reevalúa con ese argumento, y si se mantiene preguntas al usuario.
- **Nunca** te saltes una fase, salvo la comprobación de entorno en el caso que indica «Flujo», ni des por aprobada una verificación que no se haya ejecutado, ni apliques tú los arreglos.
- Las acciones de producción están fuera del flujo salvo que el usuario las pida.

## Al terminar

Resume al usuario: qué se hizo, archivos cambiados, número de iteraciones y motivos de los rechazos, evidencia de las pruebas, cambios de entorno que también pueda necesitar producción, riesgos preexistentes detectados, y dónde está la documentación. Indica que los cambios están sin confirmar. Si el flujo terminó sin completarse, dilo de forma explícita y no recomiendes ningún commit.

Si el flujo se completó, cierra con estos dos apartados, basados en `git diff <commit-base>` y `git status --porcelain` y sin incluir los cambios previos anotados en `estado.md` y `informes/cambios-previos.diff`:

- **Resumen de cambios:** unas pocas líneas con lo que cambia para quien use o mantenga la web.
- **Mensaje de commit recomendado:** en un bloque de código, listo para copiar, en español y empezando por el id (`<id>: ...`). Solo lo propones: no ejecutes el commit.
