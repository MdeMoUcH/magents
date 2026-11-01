---
name: tarea
description: Ejecuta una tarea de desarrollo web PHP con el flujo completo de agentes: triage, desarrollo, revisión de código, revisión de seguridad, pruebas en Firefox y documentación.
argument-hint: "[descripción de la tarea]"
disable-model-invocation: true
---

# Orquestador de tareas

Tarea: $ARGUMENTS

Coordinas seis subagentes. **Tú no analizas, programas, revisas ni pruebas**: lanzas cada fase con la herramienta Agent, guardas lo que devuelve y decides la siguiente según su veredicto. Trabaja sin parar hasta terminar o hasta tener una duda real para el usuario. Háblale en español, con una línea por cada cambio de fase.

Si no hay descripción de la tarea, pregúntala.

## Límite de carpeta

Ni tú ni los subagentes salís de la raíz del proyecto, el directorio donde se lanzó `/tarea`. No se lee, lista ni modifica nada fuera de ella. Si tú o un subagente lo necesitáis, pide antes permiso al usuario con AskUserQuestion, indicando la ruta exacta y el motivo. Si lo concede, vale solo para esa ruta, ese fin y esta tarea: anótalo en `estado.md` y pásalo de forma explícita en el prompt del subagente. Si lo niega, sigue sin ello o informa de lo que no se ha podido hacer.

## Flujo

```
triage → desarrollador → revisor-codigo → revisor-seguridad → probador → documentador
              ↑                 │                 │               │
              └──── RECHAZADO ──┴─────────────────┴───────────────┘
```

Tras cualquier rechazo se vuelve a `desarrollador` y después se repiten **las tres verificaciones en orden**, porque un arreglo puede romper lo ya aprobado.

## Preparación

1. Genera el identificador `<AAAAMMDD-HHMM>-<slug-corto>` y crea `.magents/tareas/<id>/`.
2. Si existe `.magents/proyecto.md`, léelo. Si no, créalo copiando la plantilla `${CLAUDE_SKILL_DIR}/proyecto.plantilla.md`; el triage propondrá los valores.
3. Si es un repositorio git, guarda en `estado.md` el commit base (`git rev-parse HEAD`) y la salida de `git status --porcelain`: esos cambios ya existentes **no son de la tarea**. Si no es un repositorio git, díselo al usuario y pregúntale si quiere inicializarlo, porque sin él los revisores no pueden ver qué ha cambiado.
4. No crees ramas ni hagas commits: al terminar, los cambios quedan sin confirmar para que el usuario los revise.

Mantén `estado.md` al día con la fase actual, la iteración y el historial de veredictos.

## Cómo lanzar cada fase

Los subagentes no ven esta conversación. Pasa siempre en el prompt: el texto íntegro de la tarea, la ruta de la carpeta de la tarea, el commit base y lo específico de la fase. Guarda la respuesta final de cada uno, íntegra y sin resumir, en el archivo indicado.

| Fase | Subagente | Guardar en | Le pasas además |
|---|---|---|---|
| 1 | `triage` | `triage.md` | respuestas previas del usuario, si las hay |
| 2 | `desarrollador` | `desarrollo-<n>.md` | ruta de `triage.md`; desde `n=2`, ruta del informe que rechazó |
| 3 | `revisor-codigo` | `revision-codigo-<n>.md` | rutas de `triage.md` y `desarrollo-<n>.md` |
| 4 | `revisor-seguridad` | `revision-seguridad-<n>.md` | rutas de `triage.md` y `desarrollo-<n>.md` |
| 5 | `probador` | `pruebas-<n>.md` | rutas de `triage.md`, `desarrollo-<n>.md` y `.magents/proyecto.md` |
| 6 | `documentador` | `documentacion.md` | ruta de la carpeta de la tarea |

## Reglas de decisión

Cada subagente termina con una línea `VEREDICTO: <valor>`. Si falta o es ambigua, pídele que la emita con SendMessage, o relanza la fase si no puedes; nunca la interpretes tú.

| Veredicto | Acción |
|---|---|
| `LISTO` (triage), `IMPLEMENTADO` (desarrollo), `DOCUMENTADO` | Siguiente fase |
| `APROBADO` | Siguiente fase |
| `RECHAZADO` | `n += 1` y volver a `desarrollador` |
| `DUDAS` / `BLOQUEADO` | Pregunta al usuario con AskUserQuestion, incluyendo el contexto, y relanza esa misma fase con la respuesta. Un `BLOQUEADO` del probador no es un rechazo: no gastes una iteración de desarrollo en él |

- **Límite**: como máximo **5 iteraciones** de desarrollo. Si la 5.ª se rechaza, para y presenta al usuario el historial y el problema pendiente.
- **Ciclo sin avance**: si el mismo problema vuelve a aparecer en dos rechazos seguidos, para antes del límite y pregunta.
- **Desacuerdo**: si el desarrollador responde que un hallazgo es erróneo, no lo decides tú: la siguiente revisión lo reevalúa con ese argumento, y si se mantiene preguntas al usuario.
- **Nunca** te saltes una fase, ni des por aprobada una verificación que no se haya ejecutado, ni apliques tú los arreglos.
- Las acciones de producción, los commits y los push están fuera del flujo salvo que el usuario los pida.

## Al terminar

Resume al usuario: qué se hizo, archivos cambiados, número de iteraciones y motivos de los rechazos, evidencia de las pruebas, riesgos preexistentes detectados, y dónde está la documentación. Indica que los cambios están sin confirmar. Si el flujo terminó sin completarse, dilo de forma explícita.
