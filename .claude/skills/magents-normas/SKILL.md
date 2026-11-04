---
name: magents-normas
description: Normas comunes a todos los agentes de /tarea y /preparar sobre git solo de lectura, límite de carpeta y uso de Docker.
user-invocable: false
---

# Normas comunes

**Git solo lectura:** los commits los hace el usuario. Usa git únicamente para consultar (`status`, `diff`, `log`, `show`, `rev-parse`, `grep`, `ls-files`, y `archive` para comparar con una copia en tu carpeta de temporales). Nunca ejecutes nada que cambie el repositorio, el índice, las ramas o la configuración (`add`, `commit`, `push`, `pull`, `fetch`, `merge`, `rebase`, `reset`, `restore`, `checkout`, `switch`, `stash`, `tag`, `clean`, `init`, `config`, entre otros). Si crees que hace falta alguno, indícalo en tu informe sin ejecutarlo.

**Límite de carpeta:** trabaja solo dentro de la raíz del proyecto, el directorio donde se lanzó la tarea. No leas, listes, busques ni modifiques nada fuera de ella (carpeta superior, proyectos vecinos, tu carpeta personal, `/tmp`), tampoco desde Bash ni montándolo en un contenedor. Si por algún motivo lo necesitas, no lo hagas: termina con `VEREDICTO: BLOQUEADO`, indicando la ruta exacta, para qué la necesitas y qué harías con ella. Solo puedes usarla si el prompt indica que el usuario lo ha autorizado, y únicamente esa ruta y para ese fin. Como excepción, puedes leer la salida de tus propios comandos que el sistema haya guardado fuera por ser demasiado larga.

**Comandos con cuidado:** nunca ejecutes nada que no sea necesario para tu trabajo, tampoco como relleno al final de un comando (`; true`, `rm -f ...`). Un hook bloquea lo que detecta fuera de la raíz, pero es una barrera ante errores: no sustituye a esta norma. Si te bloquea, no busques otra vía: si la ruta es del proyecto, reescribe el comando; si no, aplica el límite de carpeta y decláralo en tu informe. Cualquier comando que no debías ejecutar se declara en tu informe, aunque no haya tenido efecto.

**Rutas literales:** escribe las rutas tal cual desde el principio. El hook no puede verificar, y bloquea, una ruta que venga de una variable que no se asigne en esa misma orden o de `$(...)` cuando el comando escribe (redirecciones, `mkdir`, `cp`, `mv`, `rm`, `curl -o`/`-c`, montajes de `docker run`), ni un comando que salga de una variable. Lo mismo dentro de los scripts que escribas en tus temporales. Para comprobar si se puede escribir en una ruta usa `test -w` o `stat`, nunca `touch`.

**Datos de la web:** no lances peticiones que puedan borrar, crear o modificar datos si no forman parte de tu trabajo, tampoco por GET o «para comprobar si existe». Léelo en el código.

**Borrados:** cada `rm` va en una orden simple, con la ruta exacta y sin variables, sin `xargs` ni scripts. Si Claude Code o el hook rechazan un borrado, no lo reintentes: indícalo en tu informe.

**Docker:** usa solo los comandos de `.magents/proyecto.md`, `docker compose` sobre el entorno de este proyecto y el `docker run --rm` de una comprobación puntual como `php -l`, montando únicamente la raíz del proyecto. Un contenedor que se quede sirviendo, por ejemplo para comparar con el commit base, solo si está en el plan de `triage.md`; se declara y se elimina al terminar. No listes, inspecciones, pares ni borres contenedores, imágenes o volúmenes ajenos, ni borres los volúmenes de este entorno sin que lo autorice el usuario, salvo con `.magents/scripts/reiniciar-bd.sh`. Para parar un solo servicio, como la BD, sigue «Probar con la BD u otro servicio caído» de `php-pruebas-firefox`: sin esa protección, su nombre puede resolverse fuera de Docker. No consultes información global del equipo, como `docker system df` o `ip link`, salvo que un diagnóstico lo exija, y decláralo en tu informe, igual que las imágenes que descargues.

**Revisiones:** nunca ejecutes `.magents/scripts/copiar-revision.sh`: escribe fuera del proyecto y lo lanza solo el usuario. Tampoco uses `.magents/scripts/menu.sh`, que es interactivo: ejecuta directamente el script que necesites.

**Temporales:** tus archivos temporales van solo en `.magents/tareas/<id>/tmp/`, o en `.magents/preparacion/tmp/` si no hay tarea, aunque tu entorno te sugiera un scratchpad o `/tmp`. Esto, las salidas de evidencia, el avance de `probador` y el anexo de `triage` son las únicas excepciones para los agentes sin edición. Bórralos al terminar, salvo que indiques en tu informe para qué sirven después.
