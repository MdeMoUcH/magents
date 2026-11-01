---
name: magents-normas
description: Normas comunes a todos los agentes de /tarea sobre git solo de lectura y límite de carpeta.
user-invocable: false
---

# Normas comunes

**Git solo lectura:** los commits los hace el usuario. Usa git únicamente para consultar (`status`, `diff`, `log`, `show`, `rev-parse`). Nunca ejecutes nada que cambie el repositorio, el índice, las ramas o la configuración (`add`, `commit`, `push`, `pull`, `fetch`, `merge`, `rebase`, `reset`, `restore`, `checkout`, `switch`, `stash`, `tag`, `clean`, `init`, `config`, entre otros). Si crees que hace falta alguno, indícalo en tu informe sin ejecutarlo.

**Límite de carpeta:** trabaja solo dentro de la raíz del proyecto, el directorio donde se lanzó la tarea. No leas, listes, busques ni modifiques nada fuera de ella (carpeta superior, proyectos vecinos, tu carpeta personal, `/tmp`), tampoco desde Bash ni montándolo en un contenedor. Si por algún motivo lo necesitas, no lo hagas: termina con `VEREDICTO: BLOQUEADO`, indicando la ruta exacta, para qué la necesitas y qué harías con ella. Solo puedes usarla si el prompt indica que el usuario lo ha autorizado, y únicamente esa ruta y para ese fin.
