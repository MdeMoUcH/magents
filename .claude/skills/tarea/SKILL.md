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

Si no hay descripción de la tarea, pregúntala. Si la descripción es `continuar <NNNN>`, lee «Retomar una tarea» en `${CLAUDE_SKILL_DIR}/casos.md` y síguelo.

Lee `${CLAUDE_SKILL_DIR}/../magents-normas/SKILL.md`: sus normas valen también para ti, y los subagentes ya las cargan.

## Flujo

```
triage → entorno → desarrollador → revisor-codigo → revisor-seguridad → probador → documentador
                        ↑                 │                 │               │
                        └──── RECHAZADO ──┴─────────────────┴───────────────┘
```

- Tras cualquier rechazo se vuelve a `desarrollador` y después se repiten **las tres verificaciones en orden**, porque un arreglo puede romper lo ya aprobado. Las revisiones son incrementales desde la segunda vez; las pruebas, siempre completas.
- Lanza cada verificación al terminar la anterior, nunca a la vez: si una rechaza, el trabajo de las siguientes se pierde.
- **Nunca** te saltes una fase, salvo la comprobación de entorno en el caso que indica el paso 3 y lo que se omita según «Tareas menores» del paso 2, ni des por aprobada una verificación que no se haya ejecutado, ni apliques tú los arreglos.
- Las acciones de producción están fuera del flujo salvo que el usuario las pida.

## Cómo lanzar cada fase

No indiques `model` al lanzarlos: cada uno usa el de su definición. Los subagentes no ven esta conversación. Pasa siempre en el prompt: el texto íntegro de la tarea, el id, la ruta `.magents/tareas/<id>/`, el commit base y lo específico de la fase. Guarda la respuesta final de cada uno, íntegra y sin resumir, en el archivo indicado dentro de `informes/`, donde también va `estado.md`.

| Fase | Subagente | Guardar en | Le pasas además |
|---|---|---|---|
| 1 | `triage` | `triage.md` | ruta de `.magents/proyecto.md`; respuestas previas del usuario, si las hay |
| Corrección de entorno | `preparador` | `preparacion-<n>.md` | modo `generar`; lo que haya confirmado el usuario |
| Entorno | `probador` | `entorno.md` | indicación de hacer solo la comprobación de entorno; rutas de `triage.md` y `.magents/proyecto.md`; carpeta de evidencia `capturas/entorno/`; métodos aceptados por el usuario |
| 2 | `desarrollador` | `desarrollo-<n>.md` | rutas de `triage.md` y `.magents/proyecto.md`; desde `n=2`, ruta del informe que rechazó |
| 3 | `revisor-codigo` | `revision-codigo-<n>.md` | rutas de `triage.md`, `desarrollo-<n>.md` y `.magents/proyecto.md`; verificaciones que se omiten, si las hay; si ya revisó una iteración, lo del paso 5 |
| 4 | `revisor-seguridad` | `revision-seguridad-<n>.md` | rutas de `triage.md` y `desarrollo-<n>.md`; si ya revisó una iteración, lo del paso 5 |
| 5 | `probador` | `pruebas-<n>.md` | rutas de `triage.md`, `desarrollo-<n>.md` y `.magents/proyecto.md`; commit base; carpeta de evidencia `capturas/<n>/`; métodos aceptados por el usuario; ejecución anterior de esta iteración, si la hay |
| 6 | `documentador` | `documentacion.md` | ruta de la carpeta de la tarea |

## Veredictos

Cada subagente termina con una línea `VEREDICTO: <valor>`. Si falta o es ambigua, pídele que la emita con SendMessage, o relanza la fase si no puedes; nunca la interpretes tú. Haz lo mismo si contradice su propio informe, como un `APROBADO` de `probador` con algún criterio en `PARCIAL` o `FALLA`: pídele que lo revise, indicando el criterio.

| Veredicto | Acción |
|---|---|
| `LISTO` (triage o entorno), `IMPLEMENTADO` (desarrollo), `DOCUMENTADO` | Siguiente fase |
| `APROBADO` | Siguiente fase |
| `RECHAZADO` | `n += 1` y volver a `desarrollador` |
| `DUDAS` / `BLOQUEADO` | Pregunta al usuario con AskUserQuestion, incluyendo el contexto, y pasa la respuesta a esa misma fase: si puedes, continúa el mismo subagente con SendMessage, que ya tiene el análisis hecho; si no, relánzala con la respuesta. Un `BLOQUEADO` del probador no es un rechazo: no gastes una iteración de desarrollo en él |

Antes de guardar una respuesta nueva de la misma fase, renombra el informe anterior añadiendo un número (`triage-1.md`, `entorno-1.md`, `pruebas-1-1.md`…); haz lo mismo con cualquier informe que se vaya a sobrescribir, como `documentacion.md`.

## Paso a paso

### 1. Preparación

1. Si no es un repositorio git o no tiene ningún commit, para y pide al usuario que lo inicialice y haga un commit inicial por su cuenta, porque sin commit base los revisores no pueden ver qué ha cambiado. Para también si algún `.magents/calibracion/*/estado.md` tiene una línea `Pendiente:`: queda en el código un defecto sembrado por `/calibrar`, que hay que ejecutar antes para deshacerlo.
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

### 2. Triage y consulta al usuario

Lanza `triage`. Cuando termine, junta en **una sola consulta** con AskUserQuestion, una pregunta por apartado, todo lo que su informe deje para el usuario. Enséñale antes el contenido de cada apartado, y escribe cada pregunta de forma que se entienda sola, nombrando los puntos. Si no hay nada que preguntar, sigue sin parar.

| Apartado de `triage.md` | Qué preguntas | Después |
|---|---|---|
| «Dudas» (veredicto `DUDAS`) | Cada duda, con sus opciones y la recomendación del triage | La respuesta vuelve al triage |
| «Fuera de alcance» | Qué incluye, con el motivo y lo que costaría cada punto. Recomienda incluir lo que sea consecuencia directa del cambio o el mismo problema en otro sitio, porque si no se convierte en otra tarea | Si incluye algo, la respuesta vuelve al triage. Lo que quede fuera lo recoge `documentador` en `.magents/deuda.md` |
| «Borrados» | Si se hacen, con la ruta y el motivo de cada uno | Uno que no acepte vuelve al triage, para que cambie el plan |
| «Discrepancias con .magents/proyecto.md» | Qué se corrige en la configuración o el entorno | «Corrección de entorno» de `casos.md`, antes del paso 3 |
| «Necesidades de prueba» con un método que no esté en «Métodos de prueba aceptados» de `proyecto.md`, o que cambien datos o archivos | Si lo acepta, y si vale solo para esta tarea o también para las siguientes | Anótalo en el historial y pásalo a `probador` y a `desarrollador` indicando que lo ha aceptado el usuario. Si vale para las siguientes, añádelo a «Métodos de prueba aceptados» |

Con `DUDAS`, añade a la misma consulta lo que el informe ya traiga de los demás apartados, para que el triage reciba todas las respuestas de una vez. Lo que vuelve al triage se le pasa como indica «Veredictos». Cuando devuelva `LISTO`, pregunta solo por lo que sea nuevo respecto a lo ya respondido.

**Tareas menores:** si «Verificaciones que se pueden omitir» de `triage.md` propone alguna, mira «Tareas menores» de `.magents/proyecto.md`. Con `sí`, se omiten sin preguntar; con `no`, no se omiten. Si no dice nada o dice `preguntar`, añádelo a la misma consulta, con el motivo del triage: si las omite en esta tarea, si además quiere que se omitan siempre que el triage lo proponga (anota entonces `sí` en `proyecto.md`) o que no se pregunte más (anota `no`). Anota en el historial lo que se omite. Una verificación omitida se hace igualmente si `revisor-codigo` no confirma su condición, y lo que el triage no propuso no se omite.

### 3. Comprobación de entorno

Es `probador` en modo de comprobación: confirma que se podrá probar antes de gastar desarrollo y revisiones. Si se omiten las pruebas por tarea menor, se omite también. Si no, sáltala solo si se cumple todo esto: «Necesidades de prueba» de `triage.md` dice «Ninguna», no ha habido corrección de entorno en esta tarea, `.magents/scripts/comprobar-entorno.sh` pasa justo antes y la URL base de `proyecto.md` responde con `curl`. Anótalo en el historial («Entorno: omitida, sin necesidades de prueba») y pasa al paso 4. Si `probador` se bloquea después por el entorno o el MCP, resuélvelo como cualquier `BLOQUEADO`: no cuenta como iteración.

Si se bloquea solo por un método de prueba y el usuario lo acepta, no la repitas: trátalo como en la última fila de la tabla del paso 2. Haz lo mismo si termina en `LISTO` pero propone un método de prueba o un cambio de datos o de archivos que no estén en `triage.md` ni entre los aceptados, como crear un archivo de configuración temporal: pregúntaselo al usuario antes de pasarlo a `desarrollador` o `probador`, y pásalo solo si lo acepta.

### 4. Desarrollo

Lanza `desarrollador`. Con `IMPLEMENTADO`, ejecuta `.magents/scripts/guardar-iteracion.sh <NNNN> <n> <commit base>`, que guarda el código de la iteración y, desde la segunda, deja en `informes/` un `delta-<m>-<n>.diff` por cada iteración anterior `m`. Si falla o no existe, anótalo en el historial y sigue: las revisiones serán completas.

### 5. Revisiones

Lanza `revisor-codigo` y, si aprueba, `revisor-seguridad`. Si esa fase ya revisó una iteración anterior de esta tarea, pásale además su último informe (`revision-codigo-<m>.md` o `revision-seguridad-<m>.md`), el informe que rechazó la iteración anterior, si lo hay, y `informes/delta-<m>-<n>.diff`, con la misma `m` que su informe, indicándole que haga la revisión incremental de su skill. Si no existe ese delta, o la fase aún no ha revisado ninguna iteración, la revisión es completa.

Si se omite alguna verificación por tarea menor, indícaselo a `revisor-codigo` y lee «Verificaciones omitidas» de su informe en cada iteración: con «Condición cumplida», anota en el historial «Seguridad: omitida, tarea menor» o «Pruebas: omitidas, tarea menor» y no lances esa fase; con «No se cumple», anótalo y lánzala como siempre, también la comprobación de entorno si se trataba de las pruebas.

**Sugerencias:** cuando termine la última revisión y antes de las pruebas, no tras cada revisión, enseña al usuario lo no bloqueante de las dos revisiones, en tres grupos:

- «Del cambio»: recomienda hacerlo ahora, porque si no se convierte en otra tarea.
- Sugerencias y endurecimientos: son notas; enuméralas en una línea cada una, sin recomendar aplicarlas.
- Preexistentes: no se preguntan, salvo que el informe deje una decisión; van a `.magents/deuda.md`.

Si no hay nada en ningún grupo, sigue sin preguntar. Si lo hay, pregúntale con AskUserQuestion qué aplica. Si acepta algo, anótalo en el historial y lanza `desarrollador` en una iteración nueva por decisión del usuario, no por rechazo, solo con esos cambios; después repite las tres verificaciones, como tras un rechazo. Anota también lo «del cambio» que aplace, para que `documentador` lo pase a la deuda.

### 6. Pruebas

Crea la carpeta de evidencia antes de lanzar `probador`. Si ya tiene contenido de una ejecución anterior, usa una nueva con sufijo (`capturas/<n>-2/`). Tras un `RECHAZADO` hay iteración nueva y se prueba todo. Para un corte, un `BLOQUEADO` o un criterio `PARCIAL`, sigue «Pruebas interrumpidas o parciales» de `casos.md`.

### 7. Documentación

Antes de lanzar `documentador`, borra `.magents/tareas/<id>/tmp/`, salvo lo que un informe pida conservar, para que la ficha describa lo que queda de verdad. De su informe:

- **Observaciones sin contrastar**: enséñaselas siempre al usuario, aunque el flujo haya terminado. Pueden ser un defecto que las pruebas no vieron.
- **Documentación del proyecto pendiente**: enséñasela con el texto propuesto y pregúntale con AskUserQuestion si se aplica ahora o queda como deuda. Si se aplica, anótalo en el historial, lanza `desarrollador` en una iteración nueva por decisión del usuario, no por rechazo, solo con esos cambios, y repite revisión de código, revisión de seguridad y documentación; las pruebas solo si los cambios afectan a lo que ve la web, como un texto de una página. Si queda como deuda, anótalo en el historial.

### 8. Al terminar

Resume al usuario: qué se hizo, archivos cambiados, número de iteraciones y motivos de los rechazos, evidencia de las pruebas, verificaciones omitidas por tarea menor, cambios de entorno que también pueda necesitar producción, riesgos preexistentes detectados, los ids de `.magents/deuda.md` que se han abierto y cerrado, y dónde está la documentación. Indica que los cambios están sin confirmar. Si el flujo terminó sin completarse, dilo de forma explícita y no recomiendes ningún commit.

Si el flujo se completó, borra `.magents/tareas/<id>/iteraciones/` y cierra con estos dos apartados, basados en `git diff <commit-base>` y `git status --porcelain` y sin incluir los cambios previos anotados en `estado.md` y `informes/cambios-previos.diff`:

- **Resumen de cambios:** unas pocas líneas con lo que cambia para quien use o mantenga la web.
- **Mensaje de commit recomendado:** en un bloque de código, listo para copiar, en español y empezando por el id (`<id>: ...`). Solo lo propones: no ejecutes el commit.

## En cualquier fase

- **Comandos declarados**: lee el apartado «Comandos que declarar» de cada informe. Si algo tuvo efecto fuera de lo previsto o deja algo pendiente, como un contenedor colgado, un archivo fuera de `tmp/` o datos cambiados, díselo al usuario en la línea de esa fase y anótalo en el historial. Lo que no tuvo efecto basta con que quede en el informe.
- **Decisiones del usuario**: si un informe deja un riesgo o una decisión para el usuario, pregúntale con AskUserQuestion antes de seguir, aunque el veredicto permita avanzar. No las tomes tú. Puedes prohibir de inmediato una acción peligrosa, pero no sustituir una prueba ni excluir nada de un criterio: lo que esa prohibición impida probar queda `PARCIAL` hasta que el usuario lo acepte. Anota su respuesta en el historial y, al pasarla a un subagente, indica que la ha aceptado el usuario.
- **Borrado rechazado**: si Claude Code o el hook rechazan un borrado, pregúntale al usuario: no lo reintentes ni dejes que un subagente lo reintente.
- **Límite**: como máximo **5 iteraciones** de desarrollo. Las abiertas por decisión del usuario, sin rechazo previo, no cuentan: se numeran igual, pero anótalas así en el historial. Si se rechaza la 5.ª que cuenta, para y presenta al usuario el historial y el problema pendiente.
- **Ciclo sin avance**: si el mismo problema vuelve a aparecer en dos rechazos seguidos, para antes del límite y pregunta.

## Casos poco frecuentes

Si ocurre alguno, lee su apartado en `${CLAUDE_SKILL_DIR}/casos.md` antes de actuar:

| Situación | Apartado |
|---|---|
| La tarea es `continuar <NNNN>` | «Retomar una tarea» |
| Tú o un subagente necesitáis una ruta de fuera de la raíz del proyecto | «Salir de la raíz» |
| Hay que corregir `proyecto.md` o el entorno | «Corrección de entorno» |
| Un subagente se detiene sin veredicto | «Fase interrumpida» |
| `probador` se corta, se bloquea o deja un criterio `PARCIAL` | «Pruebas interrumpidas o parciales» |
| El desarrollador responde que un hallazgo es erróneo | «Desacuerdo» |
| El usuario hace un commit durante la tarea | «Cambio de commit base» |
