---
name: magents-normas
description: Normas comunes a todos los agentes de /tarea y /preparar sobre git solo de lectura, límite de carpeta y uso de Docker.
user-invocable: false
---

# Normas comunes

**Git solo lectura:** los commits los hace el usuario. Usa git únicamente para consultar (`status`, `diff`, `log`, `show`, `rev-parse`). Nunca ejecutes nada que cambie el repositorio, el índice, las ramas o la configuración (`add`, `commit`, `push`, `pull`, `fetch`, `merge`, `rebase`, `reset`, `restore`, `checkout`, `switch`, `stash`, `tag`, `clean`, `init`, `config`, entre otros). Si crees que hace falta alguno, indícalo en tu informe sin ejecutarlo.

**Límite de carpeta:** trabaja solo dentro de la raíz del proyecto, el directorio donde se lanzó la tarea. No leas, listes, busques ni modifiques nada fuera de ella (carpeta superior, proyectos vecinos, tu carpeta personal, `/tmp`), tampoco desde Bash ni montándolo en un contenedor. Si por algún motivo lo necesitas, no lo hagas: termina con `VEREDICTO: BLOQUEADO`, indicando la ruta exacta, para qué la necesitas y qué harías con ella. Solo puedes usarla si el prompt indica que el usuario lo ha autorizado, y únicamente esa ruta y para ese fin.

**Docker:** usa solo los comandos de `.magents/proyecto.md`, `docker compose` sobre el entorno de este proyecto y el `docker run --rm` de una comprobación puntual como `php -l`, montando únicamente la raíz del proyecto. No listes, inspecciones, pares ni borres contenedores, imágenes o volúmenes ajenos, ni borres los volúmenes de este entorno sin que lo autorice el usuario, salvo con `.magents/scripts/reiniciar-bd.sh`. No consultes información global del equipo, como `docker system df` o `ip link`, salvo que un diagnóstico lo exija, y decláralo en tu informe, igual que las imágenes que descargues.

**Revisiones:** nunca ejecutes `.magents/scripts/copiar-revision.sh`: escribe fuera del proyecto y lo lanza solo el usuario.

**Temporales:** tus archivos temporales van solo en `.magents/tareas/<id>/tmp/`, o en `.magents/preparacion/tmp/` si no hay tarea, aunque tu entorno te sugiera un scratchpad o `/tmp`. Es la única excepción para los agentes sin edición. Bórralos al terminar, salvo que indiques en tu informe para qué sirven después.
