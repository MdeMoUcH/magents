# magents

Agentes de Claude Code para el desarrollo de webs en PHP. Cada tarea pasa por seis fases, cada una con su subagente y su skill:

```
triage → entorno → desarrollador → revisor-codigo → revisor-seguridad → probador → documentador
                        ↑                 │                 │               │
                        └──── RECHAZADO ──┴─────────────────┴───────────────┘
```

`entorno` es `probador` comprobando, antes de desarrollar, que se va a poder probar. Antes de la primera tarea, `/preparar` genera el entorno local con el agente `preparador`.

| Fase | Subagente | Skill | Permisos |
|---|---|---|---|
| Preparación (`/preparar`): detecta el stack y genera el entorno | `preparador` | `php-preparacion` | Edición, solo en `.magents/` por instrucción |
| Triage: analiza la tarea contra el código actual | `triage` | `php-triage` | Sin herramientas de edición |
| Desarrollo | `desarrollador` | `php-desarrollo` | Edición |
| Revisión de código | `revisor-codigo` | `php-revision-codigo` | Sin herramientas de edición |
| Revisión de seguridad | `revisor-seguridad` | `php-revision-seguridad` | Sin herramientas de edición |
| Pruebas en Firefox | `probador` | `php-pruebas-firefox` | Sin edición + MCP de Firefox |
| Documentación | `documentador` | `php-documentacion` | Edición, solo en `.magents/` por instrucción |

La skill `/tarea` coordina el flujo y `magents-normas` reúne las normas comunes de git, carpeta y Docker. Tras un rechazo vuelve a desarrollo y repite las tres verificaciones en orden. Para en dos casos: si hay una duda para ti, o si no converge (5 iteraciones o el mismo problema dos veces seguidas).

Al terminar, los cambios quedan **sin confirmar** en el proyecto, con un resumen y un mensaje de commit recomendado. Los commits los haces tú: los agentes solo usan git para consultar y no hacen despliegues.

## Estilo del código

Se respeta la forma de programar de cada proyecto. La indentación es con tabuladores, salvo en archivos existentes indentados con espacios, que los conservan, y en formatos que no los admiten, como YAML. En archivos que ya mezclan ambos, lo nuevo va con tabuladores. Los comentarios son breves y nunca ocupan más que el código. La revisión de código rechaza lo que incumpla estas normas de indentación y comentarios.

## Requisitos

- [Claude Code](https://code.claude.com)
- Firefox
- Git, con un repositorio que tenga al menos un commit
- Node.js 20.19 o superior, para el MCP de Firefox
- Docker con Compose, si el proyecto no tiene entorno propio; también sirve para `php -l` si no hay PHP en el equipo
- curl
- rsync, para `copiar-revision.sh`

## Instalación

```bash
./install.sh /ruta/al/proyecto
```

Copia `.claude/agents` y `.claude/skills`, añade `.claude/` y `.magents/` al `.gitignore` y crea `.magents/.htaccess` con `Require all denied`, que solo protege en Apache. Volver a ejecutarlo actualiza esos agentes y skills, sin tocar los demás, y también los scripts fijos de `.magents/scripts/` si el proyecto ya tiene entorno, así que no los modifiques a mano. Si venías de una versión con los scripts en `.magents/entorno/`, los mueve, guarda los antiguos en `.magents/scripts/anterior/` y corrige sus rutas en `proyecto.md`. Las demás plantillas no llegan a un entorno ya generado. Abre después Claude Code en el proyecto (o reinícialo) y acepta la confianza de la carpeta: sin ella no arranca el MCP de Firefox.

## Uso

```
/preparar
/tarea Añadir un formulario de contacto que guarde los mensajes en la base de datos
/tarea continuar 0007
```

`/preparar` se ejecuta una vez tras instalar, y `/tarea` lo lanza por su cuenta si falta. La última forma retoma una tarea interrumpida.

### Entorno local

`/preparar` detecta el stack y te enseña una propuesta. Con tu confirmación crea `.magents/proyecto.md` y, si el proyecto no tiene ya su propio entorno, `.magents/entorno/` y `.magents/scripts/`:

```bash
.magents/scripts/iniciar.sh   # Inicia o reinicia, espera a que responda y muestra la URL
.magents/scripts/parar.sh     # Para el entorno
.magents/scripts/reiniciar-bd.sh   # Si hay BD: borra sus datos y la recarga desde bd-inicial/
```

Los dos primeros conservan los datos de la BD, y el entorno escucha solo en `127.0.0.1`. Antes de terminar, el preparador comprueba que arranca, que la web no apunta a producción ni redirige fuera de la URL local, y que `.git/` y `.magents/` no se sirven. Si vuelves a ejecutar `/preparar`, guarda una copia del entorno anterior en lugar de sobrescribirlo. Lo que un proyecto necesite antes de arrancar va en `.magents/scripts/antes-de-iniciar.sh`, que `iniciar.sh` ejecuta si existe y `install.sh` no toca. Los errores de PHP van a `docker compose logs web`, no a la página.

Te pedirá confirmar lo que el código no puede indicar, como la versión de PHP de producción. Si no hay esquema en el repositorio, deja un volcado **anonimizado** en `.magents/entorno/bd-inicial/`, que se carga solo cuando el volumen de la BD está vacío. El probador se bloquea, en lugar de arriesgarse, si no puede confirmar que los datos son de prueba.

### Copia para revisar

```bash
.magents/scripts/copiar-revision.sh [--sin-diff]
```

Copia el contenido de `.magents/` a `.magents/revision/<proyecto>/` de este repositorio, que git ignora, junto con `git log` y `git status`. Sirve para revisar desde aquí cómo han trabajado los agentes sin dar acceso a otras carpetas. Deja fuera `entorno/config`, `entorno/bd-inicial`, las copias de entornos anteriores, los temporales y los enlaces simbólicos. No incluye el código. Las capturas sí se copian, así que borra de la copia las que muestren datos reales. Cada ejecución deja la copia igual que el origen, así que también recupera lo borrado de ella. Lo ejecutas tú, nunca los agentes. Se instala siempre y necesita `rsync`.

Por defecto añade `diffs/<id>.diff` por tarea: de su commit base a la base de la tarea siguiente, o al estado actual si es la última. Excluye `.env`, `.env.*`, `*.pem` y `*.key`, pero puede contener contraseñas en otros archivos versionados, como un `config.ini`, así que revísalos antes de avisar. Los archivos nuevos sin seguimiento no entran y solo aparecen en `git-status.txt`. Con `--sin-diff` no los genera y borra los de una copia anterior.

## Dónde queda cada cosa

| Ruta | Contenido | ¿En git? |
|---|---|---|
| `.magents/tareas/<id>/README.md` | Cambios y decisiones de la tarea | No |
| `.magents/tareas/<id>/informes/` | Estado e informes de cada fase e iteración | No |
| `.magents/tareas/<id>/despliegue/` | Scripts y SQL de un solo uso, revisados en las dos revisiones | No |
| `.magents/tareas/<id>/capturas/` | Capturas de las pruebas | No |
| `.magents/tareas/<id>/anexos/` | Cualquier otra información | No |
| `.magents/decisiones/` | Decisiones de arquitectura | No |
| `.magents/CHANGELOG.md` | Historial de cambios | No |
| `.magents/proyecto.md` | Configuración del entorno | No |
| `.magents/entorno/` | Configuración de Docker local | No |
| `.magents/scripts/` | Scripts para iniciar, parar y restablecer el entorno, y para copiar lo necesario para una revisión | No |
| `.magents/preparacion/` | Propuesta e informe de `/preparar` | No |

El `<id>` es un número correlativo por proyecto seguido del slug de la tarea, por ejemplo `0007-exportar-pedidos`.

## MCP de Firefox

`probador` define en su propia configuración el servidor oficial de Mozilla, [`@mozilla/firefox-devtools-mcp-moz`](https://firefox-source-docs.mozilla.org/ai-agent-tools/firefox-devtools-mcp.html), con la versión fijada. Solo se conecta durante las pruebas, con Firefox headless y un perfil temporal, y sin los módulos privilegiados. Quita `--headless` y sus valores en `.claude/agents/probador.md` si quieres ver el navegador.

La opción `--tools` es necesaria: el preset por defecto no incluye las herramientas de consola y red.

## Límite de carpeta

Los agentes solo trabajan dentro de la raíz del proyecto. Si necesitan algo de fuera, se bloquean y `/tarea` te pide permiso indicando la ruta y el motivo; el permiso vale solo para esa ruta, ese fin y esa tarea.

## Limitaciones

- El límite de carpeta y la regla de git solo lectura son instrucciones, no bloqueos técnicos. Además, el MCP de Firefox y `npx` escriben por su cuenta sus registros, perfiles y caché en la carpeta personal (`~/.firefox-devtools-mcp/`, `~/.npm/`).

- Los permisos de solo lectura retiran las herramientas de edición, pero estos agentes conservan Bash: que no escriban con él depende de sus instrucciones, no de un bloqueo técnico.
- `.magents/.htaccess` no protege en Nginx. Excluye `.magents/` si despliegas por FTP o rsync: subirla publicaría informes con vulnerabilidades detalladas.
- El aislamiento de producción se basa en sustituir la configuración y comprobarla: si queda en el código un destino que el preparador no detecte, el contenedor podría alcanzarlo, porque tiene salida a la red.
- Usar Docker equivale en la práctica a tener permisos de root en el equipo, y limitar los agentes a sus comandos es una instrucción, no un bloqueo técnico.
- Si una sesión no se ejecuta en un modo que permita las acciones, Claude Code pedirá confirmación durante el flujo.
