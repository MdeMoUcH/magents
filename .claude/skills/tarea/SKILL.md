---
name: tarea
description: Ejecuta una tarea de desarrollo web PHP con el flujo completo de agentes: triage, desarrollo, revisión de código, revisión de seguridad, pruebas en Firefox y documentación.
argument-hint: "[descripción de la tarea | continuar <NNNN>]"
disable-model-invocation: true
---

# Orquestador de tareas

Tarea: $ARGUMENTS

Coordinas seis subagentes. **Tú no analizas, programas, revisas ni pruebas**: lanzas cada fase con la herramienta Agent, guardas lo que devuelve y decides la siguiente según su veredicto. Trabaja sin parar hasta terminar o hasta tener una duda real para el usuario. Háblale en español, con una línea por cada cambio de fase.

Si no hay descripción de la tarea, pregúntala. Si la descripción es `continuar <NNNN>`, ve a «Retomar una tarea».

## Normas comunes

Lee `${CLAUDE_SKILL_DIR}/../magents-normas/SKILL.md`: sus normas de git y de carpeta valen también para ti, y los subagentes ya las cargan.

Si tú o un subagente necesitáis salir de la raíz del proyecto, pide antes permiso al usuario con AskUserQuestion, indicando la ruta exacta y el motivo. Si lo concede, vale solo para esa ruta, ese fin y esta tarea: anótalo en `estado.md` y pásalo de forma explícita en el prompt del subagente. Si lo niega, sigue sin ello o informa de lo que no se ha podido hacer.

## Flujo

```
triage → entorno → desarrollador → revisor-codigo → revisor-seguridad → probador → documentador
                        ↑                 │                 │               │
                        └──── RECHAZADO ──┴─────────────────┴───────────────┘
```

`entorno` es `probador` en modo de comprobación: confirma que se podrá probar antes de gastar desarrollo y revisiones. Tras cualquier rechazo se vuelve a `desarrollador` y después se repiten **las tres verificaciones en orden**, porque un arreglo puede romper lo ya aprobado.

## Preparación

1. Genera el identificador `<NNNN>-<slug-corto>`: `NNNN` es el mayor número que aparezca en `.magents/tareas/`, más uno, con cuatro dígitos (`0001` si no hay ninguno). Un número usado por una tarea abandonada no se reutiliza. Crea `.magents/tareas/<id>/informes/`.
2. Si existe `.magents/proyecto.md`, léelo. Si no, créalo copiando la plantilla `${CLAUDE_SKILL_DIR}/proyecto.plantilla.md`; el triage propondrá los valores.
3. Si no es un repositorio git o no tiene ningún commit, para y pide al usuario que lo inicialice y haga un commit inicial por su cuenta, porque sin commit base los revisores no pueden ver qué ha cambiado.
4. Guarda en `estado.md` el texto íntegro de la tarea, el commit base (`git rev-parse HEAD`) y la salida de `git status --porcelain`: esos cambios ya existentes **no son de la tarea**. Si hay alguno, guarda también `git diff HEAD` en `informes/cambios-previos.diff`, avisa al usuario de que pueden mezclarse con los de la tarea si afectan a los mismos archivos y pregúntale si continúa o prefiere confirmarlos antes.

Mantén `estado.md` al día con la fase actual, la iteración y el historial de veredictos.

## Retomar una tarea

Con `continuar <NNNN>`, busca `.magents/tareas/<NNNN>-*/` y lee su `informes/estado.md` y sus informes. Conserva el id, el commit base y el contador de iteraciones, y relanza la primera fase sin veredicto guardado. No repitas la preparación. Si los archivos han cambiado desde el último informe, avisa al usuario antes de seguir. Si no encuentras la carpeta o no hay `estado.md`, díselo y para.

## Cómo lanzar cada fase

Los subagentes no ven esta conversación. Pasa siempre en el prompt: el texto íntegro de la tarea, el id, la ruta `.magents/tareas/<id>/`, el commit base y lo específico de la fase. Guarda la respuesta final de cada uno, íntegra y sin resumir, en el archivo indicado dentro de `informes/`, donde también va `estado.md`.

| Fase | Subagente | Guardar en | Le pasas además |
|---|---|---|---|
| 1 | `triage` | `triage.md` | respuestas previas del usuario, si las hay |
| Entorno | `probador` | `entorno.md` | indicación de hacer solo la comprobación de entorno; rutas de `triage.md` y `.magents/proyecto.md` |
| 2 | `desarrollador` | `desarrollo-<n>.md` | rutas de `triage.md` y `.magents/proyecto.md`; desde `n=2`, ruta del informe que rechazó |
| 3 | `revisor-codigo` | `revision-codigo-<n>.md` | rutas de `triage.md`, `desarrollo-<n>.md` y `.magents/proyecto.md` |
| 4 | `revisor-seguridad` | `revision-seguridad-<n>.md` | rutas de `triage.md` y `desarrollo-<n>.md` |
| 5 | `probador` | `pruebas-<n>.md` | rutas de `triage.md`, `desarrollo-<n>.md` y `.magents/proyecto.md` |
| 6 | `documentador` | `documentacion.md` | ruta de la carpeta de la tarea |

## Reglas de decisión

Cada subagente termina con una línea `VEREDICTO: <valor>`. Si falta o es ambigua, pídele que la emita con SendMessage, o relanza la fase si no puedes; nunca la interpretes tú.

| Veredicto | Acción |
|---|---|
| `LISTO` (triage o entorno), `IMPLEMENTADO` (desarrollo), `DOCUMENTADO` | Siguiente fase |
| `APROBADO` | Siguiente fase |
| `RECHAZADO` | `n += 1` y volver a `desarrollador` |
| `DUDAS` / `BLOQUEADO` | Pregunta al usuario con AskUserQuestion, incluyendo el contexto, y relanza esa misma fase con la respuesta. Un `BLOQUEADO` del probador no es un rechazo: no gastes una iteración de desarrollo en él |

- **Propuesta para `proyecto.md`**: si el triage incluye una, enséñasela al usuario y aplícala a `.magents/proyecto.md` con lo que confirme, antes de la comprobación de entorno.
- **Límite**: como máximo **5 iteraciones** de desarrollo. Si la 5.ª se rechaza, para y presenta al usuario el historial y el problema pendiente.
- **Ciclo sin avance**: si el mismo problema vuelve a aparecer en dos rechazos seguidos, para antes del límite y pregunta.
- **Desacuerdo**: si el desarrollador responde que un hallazgo es erróneo, no lo decides tú: la siguiente revisión lo reevalúa con ese argumento, y si se mantiene preguntas al usuario.
- **Nunca** te saltes una fase, ni des por aprobada una verificación que no se haya ejecutado, ni apliques tú los arreglos.
- Las acciones de producción están fuera del flujo salvo que el usuario las pida.

## Al terminar

Resume al usuario: qué se hizo, archivos cambiados, número de iteraciones y motivos de los rechazos, evidencia de las pruebas, riesgos preexistentes detectados, y dónde está la documentación. Indica que los cambios están sin confirmar. Si el flujo terminó sin completarse, dilo de forma explícita y no recomiendes ningún commit.

Si el flujo se completó, cierra con estos dos apartados, basados en `git diff <commit-base>` y `git status --porcelain` y sin incluir los cambios previos anotados en `estado.md` y `informes/cambios-previos.diff`:

- **Resumen de cambios:** unas pocas líneas con lo que cambia para quien use o mantenga la web.
- **Mensaje de commit recomendado:** en un bloque de código, listo para copiar, en español y empezando por el id (`<id>: ...`). Solo lo propones: no ejecutes el commit.
