# Casos poco frecuentes de /tarea

Complementa a `SKILL.md`: sus reglas siguen valiendo aquí.

## Retomar una tarea

Con `continuar <NNNN>`, busca `.magents/tareas/<NNNN>-*/` y lee su `informes/estado.md` y sus informes. Si `estado.md` está en la raíz de la tarea y no en `informes/`, como en algunas tareas antiguas, muévelo a `informes/` antes de seguir. Conserva el id, el commit base y el contador de iteraciones. Si hay una línea `Pendiente:`, o una confirmación o un cambio de entorno sin resolver en el historial, resuélvelo antes de lanzar nada. Ejecuta también `.magents/scripts/comprobar-entorno.sh`, si existe, y actúa como en el punto 2 de «Preparación». Después relanza la primera fase sin veredicto guardado. No repitas la preparación. Si los archivos han cambiado desde el último informe, avisa al usuario antes de seguir. Si no encuentras la carpeta o no hay `estado.md` en ninguno de los dos sitios, díselo y para.

## Salir de la raíz

Si tú o un subagente necesitáis salir de la raíz del proyecto, pide antes permiso al usuario con AskUserQuestion, indicando la ruta exacta y el motivo. Si lo concede, vale solo para esa ruta, ese fin y esta tarea: anótalo en `estado.md` y pásalo de forma explícita en el prompt del subagente. El hook de `magents-normas` lo seguirá bloqueando hasta que **el usuario** añada esa ruta a `.magents/rutas-autorizadas.txt`, una por línea, y la quite al terminar. Díselo: ningún agente puede editar ese archivo, que no existe hasta que el usuario lo crea. Si lo niega, sigue sin ello o informa de lo que no se ha podido hacer.

El mismo archivo sirve para una carpeta del propio proyecto, fuera de `.magents/`, que `proyecto.md` mande limpiar o preparar a las pruebas: el hook solo deja escribir ahí a `desarrollador`. Si un agente informa de que el hook le impidió un borrado que `proyecto.md` le pide, no lo hagas tú por tu cuenta: enseña al usuario la línea exacta que añadir a `.magents/rutas-autorizadas.txt`, con la ruta absoluta de la carpeta, que en este caso puede dejar de forma permanente, y pregúntale con AskUserQuestion si la añade y se continúa el mismo agente, si lo borra él o si te autoriza a borrarlo a ti esta vez.

Lo mismo vale para un archivo del proyecto que un agente que no programa tenga que crear o cambiar para una prueba aceptada por el usuario, como un archivo de configuración temporal: el hook solo le deja escribir en `.magents/` y en sondas `magents-sonda-<algo>`.

## Corrección de entorno

Si el triage señala discrepancias con `proyecto.md`, enséñaselas al usuario en la consulta del paso 2, antes de la comprobación de entorno. Si hay que corregir la configuración o el entorno, lanza `preparador` en modo `generar` con lo que confirme y guarda su respuesta en `informes/preparacion-<n>.md`. Con `LISTO`, sigue con la comprobación de entorno, que ya no se puede omitir por no tener necesidades de prueba; si las pruebas se omiten por tarea menor, se omite igualmente. Con `BLOQUEADO`, aplica la regla de «Veredictos», con un máximo de tres bloqueos seguidos.

## Cambio de entorno que depende del código

A veces el entorno no se puede cambiar antes del desarrollo, porque el cambio solo funciona con el código nuevo: por ejemplo, un montaje de `compose.yml` sobre un archivo que la web aún no lee. El triage debe decirlo en su plan, separado del resto, y el usuario lo acepta en la consulta del paso 2. Entonces:

1. La comprobación de entorno se hace antes del desarrollo, con el entorno sin cambiar.
2. `desarrollador` hace primero el código y después, en la misma iteración, el cambio de `.magents/entorno/`, de `antes-de-iniciar.sh` y de `proyecto.md`, sin tocar los scripts fijos. Puede que la web en marcha deje de responder hasta el reinicio: debe decirlo en su informe.
3. Las revisiones miran también esos archivos, que no están en el diff de git.
4. Antes de las pruebas, reinicia el entorno con `.magents/scripts/iniciar.sh` y repite la comprobación de entorno, renombrando el informe anterior. Con `BLOQUEADO` por el cambio, vuelve a `desarrollador` como tras un rechazo.
5. Si una iteración posterior vuelve a cambiar el entorno, repite el punto 4.

Anota en el historial cada reinicio y qué archivos quedan en el proyecto como parte del entorno, como un punto de montaje vacío.

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
