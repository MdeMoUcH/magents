---
name: preparar
description: Detecta el stack de una web PHP, propone su configuración y, tras tu confirmación, genera en .magents/ un entorno Docker local con scripts para iniciarlo y pararlo.
disable-model-invocation: true
---

# Preparación del proyecto

Coordinas al subagente `preparador`: **tú no detectas ni generas nada**, lanzas cada modo con la herramienta Agent, guardas su respuesta íntegra y decides según su veredicto. Háblale al usuario en español. Los subagentes no ven esta conversación: pasa en cada prompt el modo y todo lo necesario.

Si te ejecutas de forma independiente, lee antes `${CLAUDE_SKILL_DIR}/../magents-normas/SKILL.md`: sus normas valen también para ti.

Si no es un repositorio git o no tiene ningún commit, para y pide al usuario que lo inicialice y haga un commit inicial por su cuenta: el preparador lo necesita para comprobar que el entorno no ensucia el proyecto.

## Pasos

1. **Entorno existente**: si `.magents/proyecto.md` ya tiene URL base y cómo arrancarlo, enséñaselos al usuario y pregúntale con AskUserQuestion si lo regenera o lo conserva. Si lo conserva, termina aquí. Regenerar nunca sobrescribe: el preparador guarda una copia de `.magents/entorno/`.
2. **Propuesta**: lanza `preparador` en modo `propuesta` y guarda su respuesta en `.magents/preparacion/propuesta.md`.
3. **Confirmación**: enseña al usuario la propuesta completa, con su contenido y no solo la ruta, y usa AskUserQuestion para sus preguntas y para confirmarla. Si cambia algo, recógelo. No generes nada sin su confirmación.
4. **Generación**: lanza `preparador` en modo `generar` con la ruta de la propuesta y lo confirmado, y guarda su respuesta en `.magents/preparacion/informe.md`.
5. **Resultado**: dile qué se ha creado, la URL, los comandos para iniciar y parar, y los supuestos pendientes.

## Reglas de decisión

Cada ejecución termina con una línea `VEREDICTO: <valor>`. Si falta o es ambigua, pídele que la emita; nunca la interpretes tú.

| Veredicto | Acción |
|---|---|
| `PROPUESTA` | Paso 3 |
| `LISTO` | Paso 5 |
| `BLOQUEADO` | Pregunta al usuario con AskUserQuestion, con el contexto, y relanza ese mismo modo con la respuesta. Tras tres bloqueos seguidos en un modo, para y preséntale el problema |

Si el usuario rechaza la propuesta o el flujo para sin `LISTO`, di de forma explícita que el entorno no está preparado.
