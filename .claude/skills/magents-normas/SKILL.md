---
name: magents-normas
description: Normas comunes a todos los agentes de /tarea, /preparar y /calibrar sobre git solo de lectura, límite de carpeta, uso de Docker y estilo.
user-invocable: false
---

# Normas comunes

**Git solo lectura:** los commits los hace el usuario. Usa git únicamente para consultar (`status`, `diff`, `log`, `show`, `rev-parse`, `grep`, `ls-files`, y `archive` para comparar con una copia en tu carpeta de temporales). Nunca ejecutes nada que cambie el repositorio, el índice, las ramas o la configuración (`add`, `commit`, `push`, `pull`, `fetch`, `merge`, `rebase`, `reset`, `restore`, `checkout`, `switch`, `stash`, `tag`, `clean`, `init`, `config`, entre otros). Si crees que hace falta alguno, indícalo en tu informe sin ejecutarlo: el hook bloquea todo lo que no sea consultar.

**Límite de carpeta:** trabaja solo dentro de la raíz del proyecto, el directorio donde se lanzó la tarea. No leas, listes, busques ni modifiques nada fuera de ella (carpeta superior, proyectos vecinos, tu carpeta personal, `/tmp`), tampoco desde Bash ni montándolo en un contenedor. Si por algún motivo lo necesitas, no lo hagas: termina con `VEREDICTO: BLOQUEADO`, indicando la ruta exacta, para qué la necesitas y qué harías con ella. Solo puedes usarla si el prompt indica que el usuario lo ha autorizado, y únicamente esa ruta y para ese fin. Como excepción, puedes leer la salida de tus propios comandos que el sistema haya guardado fuera por ser demasiado larga.

**Comandos con cuidado:** nunca ejecutes nada que no sea necesario para tu trabajo, tampoco como relleno al final de un comando (`; true`, `rm -f ...`). Un hook bloquea lo que detecta fuera de la raíz, pero es una barrera ante errores: no sustituye a esta norma. Si te bloquea, no busques otra vía: si la ruta es del proyecto, reescribe el comando; si no, aplica el límite de carpeta y decláralo en tu informe. Cualquier comando que no debías ejecutar se declara en tu informe, aunque no haya tenido efecto.

**Rutas literales:** escribe las rutas tal cual desde el principio. El hook no puede verificar, y bloquea, una ruta que venga de una variable, aunque la asignes en la misma orden, o de `$(...)` cuando el comando escribe (redirecciones, `mkdir`, `cp`, `mv`, `rm`, `curl -o`/`-c`, montajes de `docker run`), ni un comando que salga de una variable, ni las órdenes que le lleguen a un intérprete por una tubería (`... | sh`): escríbelas directamente o en un heredoc. Lo mismo dentro de los scripts que escribas en tus temporales. Para comprobar si se puede escribir en una ruta usa `test -w` o `stat`, nunca `touch`. Lo mismo vale para el nombre de un contenedor: en vez de un bucle `for` con `--name <nombre>_tmp-x-$v`, escribe una orden por nombre. Y una ruta de URL con barra inicial que pases como argumento, como `/admin/x`, el hook la toma por una ruta de archivo: pasa la URL completa (`http://127.0.0.1:<puerto>/admin/x`) o la ruta sin barra inicial.

**Comandos que declarar:** todo informe termina, justo antes del veredicto, con el apartado `## Comandos que declarar`, con ese nombre exacto, o «Ninguno». Va ahí, una línea por cada uno, con el comando, qué pasó y si tuvo efecto: lo que no debías ejecutar, aunque no tuviera efecto; lo que bloquearon el hook o Claude Code, y cómo lo resolviste; las imágenes descargadas y las consultas globales del equipo; y lo que quede fuera de tu carpeta de temporales o en Docker (un contenedor colgado, un archivo). No lo repartas por otros apartados.

**Datos de la web:** no lances peticiones que puedan borrar, crear o modificar datos si no forman parte de tu trabajo, tampoco por GET o «para comprobar si existe». Léelo en el código.

**Logs del entorno:** no borres ni vacíes el log de errores de PHP ni otros logs del entorno, aunque sea para empezar limpio: guardan lo que otras fases aún no han leído. Para ver solo lo nuevo, anota antes la hora (`docker compose logs --since`) o el número de líneas de un archivo de log, y mira a partir de ahí.

**Borrados:** cada `rm` va en una orden simple, con la ruta exacta y sin variables, sin `xargs` ni scripts. Si Claude Code o el hook rechazan un borrado, no lo reintentes: indícalo en tu informe.

**Docker:**

- **Qué puedes usar**: solo los comandos de `.magents/proyecto.md`, `docker compose` sobre el entorno de este proyecto y el `docker run --rm` de una comprobación puntual como `php -l`.
- **Montajes**: únicamente la raíz del proyecto, en solo lectura (`:ro`). Si necesitas escribir, monta además con escritura solo tu carpeta de temporales (`.magents/tareas/<id>/tmp/`).
- **Cada `docker run`** lleva tres cosas:
  - `--pull never`, para no descargar imágenes sin que se vea.
  - `--name <nombre>_tmp-<algo>`, donde `<nombre>` es el `name:` de `.magents/entorno/compose.yml` (o `magents-<carpeta del proyecto>` si no existe) y `<algo>` va en minúsculas, números, puntos o guiones.
  - Su comando dentro de `timeout` (`... <imagen> timeout 120 <comando>`), porque un comando que espera para siempre, como leer un FIFO o `/dev/stderr`, deja el contenedor colgado.
- **Tus contenedores y los del entorno**: solo puedes parar, matar, reiniciar o entrar con `exec` en los tuyos y en los del entorno (`<nombre>-<servicio>-<n>`), siempre por su nombre completo, nunca por id. Si uno tuyo queda colgado, páralo con `docker kill <nombre>_tmp-<algo>` y decláralo. Un contenedor que se quede sirviendo, por ejemplo para comparar con el commit base, solo si está en el plan de `triage.md`; se declara y se elimina al terminar.
- **Dentro del contenedor**: el proyecto está montado con escritura en el servicio `web`, así que lo que borres o cambies en su ruta montada cambia el proyecto. Vale lo mismo que fuera: rutas exactas y nada que no sea de tu trabajo.
- **Lo ajeno**: no listes, inspecciones, pares ni borres contenedores, imágenes o volúmenes ajenos, ni borres los volúmenes de este entorno sin que lo autorice el usuario, salvo con `.magents/scripts/reiniciar-bd.sh`.
- **Parar un servicio**: para parar uno solo, como la BD, sigue «Probar con la BD u otro servicio caído» de `php-pruebas-firefox`: sin esa protección, su nombre puede resolverse fuera de Docker.
- **Información global e imágenes**: no consultes información global del equipo, como `docker system df` o `ip link`, salvo que un diagnóstico lo exija, y decláralo en tu informe. Declara también las imágenes que descargues, siempre con `docker pull` aparte y solo si no existe ninguna imagen local que sirva (antes, `docker image ls <repositorio>`).

**`php -l`:** se pasa con la versión de PHP de producción. Con el entorno en esa versión, `docker compose -f .magents/entorno/compose.yml exec -T web php -l <archivo>`. Si no, `docker run --rm --pull never --name <nombre>_tmp-lint --network none -v "$PWD":/app:ro -w /app <imagen> timeout 120 php -l <archivo>`, con la imagen del entorno de esa versión si existe (`docker image ls <nombre>-web`) o, si no, `php:<versión>-cli`.

**Solo el entorno local:** no envíes archivos a otra máquina (`curl -d @archivo`, `-F`, `-T`) ni conectes un cliente de base de datos (`mysql`, `psql`…) a un servidor que no sea el del entorno. En `curl`, escribe la URL completa, con `http://`. El hook lo bloquea.

**Estilo**, en todo lo que escribas en el proyecto o en `.magents/entorno/`:

- **Indentación**: con tabuladores, en archivos nuevos y en los que ya los usan, salvo en formatos que no los admiten, como YAML. En un archivo existente indentado con espacios, mantén los espacios, sin mezclar ni reformatear. En uno que ya mezcla ambos, sigue el estilo de las líneas de alrededor y no reformatees nada.
- **Comentarios**: breves y concisos, y solo donde aporten algo que el código no diga. Nunca pueden ocupar más que el código al que acompañan; lo normal es que ocupen mucho menos.

**CFW:** si existe `.claude/skills/cfw/SKILL.md`, la web usa el framework CFW o se está migrando a él: léela antes de empezar tu fase y síguela.

**Revisiones:** nunca ejecutes `.magents/scripts/copiar-revision.sh`: escribe fuera del proyecto y lo lanza solo el usuario. Tampoco uses `.magents/scripts/menu.sh`, que es interactivo: ejecuta directamente el script que necesites.

**Temporales:** tus archivos temporales van solo en `.magents/tareas/<id>/tmp/`, o en `.magents/preparacion/tmp/` si no hay tarea, aunque tu entorno te sugiera un scratchpad o `/tmp`. Esto, las salidas de evidencia, el avance de `probador` y el anexo de `triage` son las únicas excepciones para los agentes sin edición. Bórralos al terminar, salvo que indiques en tu informe para qué sirven después. Salvo a `desarrollador`, el hook solo deja escribir dentro de `.magents/`. Si una comprobación necesita un archivo servido por la web, llámalo `magents-sonda-<algo>.php`, que el hook sí permite fuera de `.magents/`: bórralo al terminar, con su ruta exacta, y decláralo. Cualquier otro archivo del proyecto que haya que crear o cambiar para una prueba necesita que el usuario lo acepte y añada su ruta a `.magents/rutas-autorizadas.txt`.
