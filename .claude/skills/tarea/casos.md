# Casos poco frecuentes de /tarea

Complementa a `SKILL.md`: sus reglas siguen valiendo aquí.

## Retomar una tarea

Con `continuar <NNNN>`, busca `.magents/tareas/<NNNN>-*/` y lee su `informes/estado.md` y sus informes. Conserva el id, el commit base y el contador de iteraciones. Si hay una línea `Pendiente:`, o una confirmación o un cambio de entorno sin resolver en el historial, resuélvelo antes de lanzar nada. Ejecuta también `.magents/scripts/comprobar-entorno.sh`, si existe, y actúa como en el punto 2 de «Preparación». Después relanza la primera fase sin veredicto guardado. No repitas la preparación. Si los archivos han cambiado desde el último informe, avisa al usuario antes de seguir. Si no encuentras la carpeta o no hay `estado.md`, díselo y para.

## Salir de la raíz

Si tú o un subagente necesitáis salir de la raíz del proyecto, pide antes permiso al usuario con AskUserQuestion, indicando la ruta exacta y el motivo. Si lo concede, vale solo para esa ruta, ese fin y esta tarea: anótalo en `estado.md` y pásalo de forma explícita en el prompt del subagente. El hook de `magents-normas` lo seguirá bloqueando hasta que **el usuario** añada esa ruta a `.magents/rutas-autorizadas.txt`, una por línea, y la quite al terminar. Díselo: ningún agente puede editar ese archivo. Si lo niega, sigue sin ello o informa de lo que no se ha podido hacer.

Lo mismo vale para un archivo del proyecto que un agente que no programa tenga que crear o cambiar para una prueba aceptada por el usuario, como un archivo de configuración temporal: el hook solo le deja escribir en `.magents/` y en sondas `magents-sonda-<algo>`.

## Corrección de entorno

Si el triage señala discrepancias con `proyecto.md`, enséñaselas al usuario en la consulta del paso 2, antes de la comprobación de entorno. Si hay que corregir la configuración o el entorno, lanza `preparador` en modo `generar` con lo que confirme y guarda su respuesta en `informes/preparacion-<n>.md`. Con `LISTO`, sigue con la comprobación de entorno, que ya no se puede omitir. Con `BLOQUEADO`, aplica la regla de «Veredictos», con un máximo de tres bloqueos seguidos.

## Fase interrumpida

Si un subagente se detiene sin veredicto, anótalo en el historial con lo que dejó a medias. Al relanzar esa fase, indícale qué se interrumpió y qué restos quedan. No cuenta como iteración.

## Pruebas interrumpidas o parciales

- **Tras un corte**: si puedes, continúa el mismo subagente con SendMessage e indícale que siga «Si se retoma» de `php-pruebas-firefox`.
- **Tras un `BLOQUEADO`**: continúalo igual, con la respuesta del usuario.
- **Si no puedes continuarlo**: relánzalo y pásale en el prompt la carpeta de evidencia más reciente de esa iteración que tenga `progreso.md`, para que reutilice lo que siga valiendo.
- **Criterio `PARCIAL`**: si termina con `BLOQUEADO` por un criterio `PARCIAL`, enseña al usuario qué queda fuera. Si acepta esa exclusión, anótalo en el historial y relanza `probador` solo para ese criterio, indicándole la exclusión aceptada.

## Desacuerdo

Si el desarrollador responde que un hallazgo es erróneo, no lo decides tú: la siguiente revisión lo reevalúa con ese argumento, y si se mantiene preguntas al usuario.

## Cambio de commit base

Si el usuario hace un commit antes de que empiece el desarrollo, cambia el commit base por el nuevo en su apartado de `estado.md`, anota el anterior en el historial y actualiza los cambios previos. Una vez empezado el desarrollo, el commit base ya no cambia.
