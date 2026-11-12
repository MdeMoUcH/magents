# magents

Agentes de Claude Code para el desarrollo de webs en PHP. Cada tarea pasa por seis fases, cada una con su subagente y su skill:

```
triage → entorno → desarrollador → revisor-codigo → revisor-seguridad → probador → documentador
                        ↑                 │                 │               │
                        └──── RECHAZADO ──┴─────────────────┴───────────────┘
```

`entorno` es `probador` comprobando, antes de desarrollar, que se va a poder probar: lo básico y las «Necesidades de prueba» que señale el triage. Si no hay ninguna y el entorno responde, se omite. Antes de la primera tarea, `/preparar` genera el entorno local con el agente `preparador`.

| Fase | Subagente | Skill | Permisos |
|---|---|---|---|
| Preparación (`/preparar`): detecta el stack y genera el entorno | `preparador` | `php-preparacion` | Edición, solo en `.magents/` |
| Triage: analiza la tarea contra el código actual | `triage` | `php-triage` | Sin herramientas de edición |
| Desarrollo | `desarrollador` | `php-desarrollo` | Edición |
| Revisión de código | `revisor-codigo` | `php-revision-codigo` | Sin herramientas de edición |
| Revisión de seguridad | `revisor-seguridad` | `php-revision-seguridad` | Sin herramientas de edición |
| Pruebas en Firefox | `probador` | `php-pruebas-firefox` | Sin edición + MCP de Firefox |
| Documentación | `documentador` | `php-documentacion` | Edición, solo en `.magents/` |

Salvo a `desarrollador`, el hook solo deja escribir a los agentes dentro de `.magents/`, también desde Bash, y en archivos de sonda llamados `magents-sonda-<algo>`, que borran al terminar. Todos los agentes usan el modelo de la sesión. Para fijar otro en uno, añade `model:` a su definición en `.claude/agents/`; una reinstalación la vuelve a quitar.

La skill `/tarea` coordina el flujo y `magents-normas` reúne las normas comunes de git, carpeta y Docker. Tras un rechazo vuelve a desarrollo y repite las tres verificaciones en orden: las pruebas, completas; las dos revisiones, solo sobre lo que ha cambiado desde la iteración que ya revisaron y lo que eso afecta, con el delta que deja `guardar-iteracion.sh` en `informes/`. Para en dos casos: si hay una duda para ti, o si no converge (5 iteraciones o el mismo problema dos veces seguidas). Las iteraciones que abres tú para aplicar sugerencias de las revisiones no cuentan para ese límite.

Para que una tarea no deje deuda que obligue a lanzar otra, el triage busca el mismo problema en otros sitios y las consecuencias del cambio, y lo incluye en el plan o te lo enseña antes de desarrollar como «Fuera de alcance». Todo lo que el triage deja para ti, sean dudas, fuera de alcance, borrados, discrepancias con `proyecto.md` o métodos de prueba nuevos, llega en una sola consulta. Las revisiones separan lo no bloqueante en tres grupos:
- «Del cambio»: lo que la tarea deja a medias. `/tarea` recomienda hacerlo en la misma tarea.
- Notas: sugerencias y endurecimientos sin escenario de fallo. No se recomiendan ni pasan a la deuda.
- Preexistentes.

Una tarea que solo cambia textos, estilos, comentarios o documentación puede ahorrarse la revisión de seguridad, y una que no cambia nada que la web sirva o ejecute, también las pruebas en Firefox. Lo propone el triage en «Verificaciones que se pueden omitir», lo decides tú (una vez por tarea, o para siempre en «Tareas menores» de `.magents/proyecto.md`, con `sí` o `no`) y la revisión de código lo confirma con el diff: si el cambio toca algo más, la verificación se hace. La revisión de código y la documentación no se omiten nunca.

Lo que quede pendiente, ya sean preexistentes, cosas aplazadas o documentación, lo recoge `documentador` en `.magents/deuda.md`, con un id, su gravedad y su origen, y lo cierra cuando una tarea lo resuelve. Puedes pedir varios puntos en una sola tarea, por ejemplo `/tarea resuelve D003 y D007`.

Al terminar, los cambios quedan **sin confirmar** en el proyecto, con un resumen y un mensaje de commit recomendado. Los commits los haces tú: los agentes solo usan git para consultar y no hacen despliegues.

## Documentación del proyecto

Los archivos que explican la web, como el `README.md` o una guía de instalación, se listan en «Documentación del proyecto» de `.magents/proyecto.md`. El triage incluye en el plan lo que cambia en ellos, la revisión de código rechaza si falta o si un documento contradice al código, y `documentador`, que no los toca, te enseña al final lo que haya quedado pendiente para que decidas si se aplica en otra iteración o queda como deuda.

## Estilo del código

Se respeta la forma de programar de cada proyecto. La indentación es con tabuladores, salvo en archivos existentes indentados con espacios, que los conservan, y en formatos que no los admiten, como YAML. En archivos que ya mezclan ambos, lo nuevo sigue el estilo de las líneas de alrededor. Los comentarios son breves y nunca ocupan más que el código. La revisión de código rechaza lo que incumpla la norma de comentarios; la indentación, por sí sola, solo es una sugerencia.

## Requisitos

- [Claude Code](https://code.claude.com)
- Firefox
- Git, con un repositorio que tenga al menos un commit
- Node.js 20.19 o superior, para el MCP de Firefox y para el hook de límite de carpeta, que sin `node` bloquea todas las órdenes de los agentes
- Claude Code 2.1.295 o superior, para que un fallo del hook bloquee en vez de dejar pasar
- Docker con Compose, si el proyecto no tiene entorno propio; también sirve para `php -l` si no hay PHP en el equipo
- curl
- rsync, para `copiar-revision.sh`

## Instalación

```bash
./install.sh /ruta/al/proyecto
```

Copia `.claude/agents` y `.claude/skills`, añade `.claude/` y `.magents/` al `.gitignore` y crea `.magents/.htaccess` con `Require all denied`, que solo protege en Apache. Volver a ejecutarlo actualiza esos agentes y skills, sin tocar los demás, y también los scripts fijos de `.magents/scripts/` si el proyecto ya tiene entorno, así que no los modifiques a mano: si encuentra cambios, o una versión instalada sin registro, guarda el script en `.magents/scripts/anterior/` y avisa. Si lo lanzas desde una terminal, pide confirmación antes de sustituir una instalación existente. Si venías de una versión con los scripts en `.magents/entorno/`, los mueve, guarda los antiguos en `.magents/scripts/anterior/` y corrige sus rutas en `proyecto.md`. Las demás plantillas no llegan a un entorno ya generado. Al terminar ejecuta `comprobar-entorno.sh` y muestra lo que encuentre, sin impedir la instalación. Abre después Claude Code en el proyecto (o reinícialo) y acepta la confianza de la carpeta: sin ella no arranca el MCP de Firefox.

## Uso

```
/preparar
/tarea Añadir un formulario de contacto que guarde los mensajes en la base de datos
/tarea continuar 0007
/calibrar
```

`/preparar` se ejecuta tras instalar, y `/tarea` lo lanza por su cuenta si falta. Vuelve a ejecutarlo tras reinstalar o si `comprobar-entorno.sh` avisa de algo. `/tarea continuar` retoma una tarea interrumpida; las pruebas en Firefox reutilizan lo ya aprobado si no ha cambiado el código.

### Calibrar las pruebas

`/calibrar [NNNN]` comprueba que un `APROBADO` de las pruebas significa algo. Sobre una tarea ya terminada, la última si no indicas otra, y con el código sin cambios pendientes, `desarrollador` siembra un defecto de una o dos líneas que incumple uno de sus criterios, `probador` la prueba sin saberlo y el defecto se deshace. Eliges si es evidente o sutil, y el resultado queda en `.magents/calibracion/<fecha y hora>/resultado.md`: `DETECTADO`, `A MEDIAS`, `NO DETECTADO` o `SIN RESULTADO`. Al terminar comprueba con `git status` que el código queda como estaba; si se interrumpe, `/tarea` no arranca hasta que vuelvas a ejecutar `/calibrar`, que deshace lo pendiente. Conviene pasarla tras cambiar `php-pruebas-firefox` o de modelo.

### Entorno local

`/preparar` detecta el stack y te enseña una propuesta. Con tu confirmación crea `.magents/proyecto.md` y, si el proyecto no tiene ya su propio entorno, `.magents/entorno/` y `.magents/scripts/`:

```bash
.magents/scripts/menu.sh      # Lista los scripts, muestra el estado y permite lanzarlos
.magents/scripts/iniciar.sh   # Inicia o reinicia, espera a que responda y muestra la URL
.magents/scripts/parar.sh     # Para el entorno
.magents/scripts/reiniciar-bd.sh   # Si hay BD: borra sus datos y la recarga desde bd-inicial/
.magents/scripts/comprobar-entorno.sh   # Busca fallos de estructura y muestra el estado, sin arrancar ni cambiar nada
```

`guardar-iteracion.sh` es de uso interno de `/tarea` y no aparece en el menú.

Lo que puede perder algo pide confirmación, tanto desde `menu.sh` como lanzado a mano: `reiniciar-bd.sh` y `copiar-revision.sh` siempre, e `iniciar.sh` y `parar.sh` si el entorno está en marcha, porque se pierden los logs y temporales de los contenedores. Sin terminal o dentro de Claude Code no pregunta, para que los agentes no se queden esperando; esto incluye los comandos `!` de Claude Code. Para no preguntar en un uso propio, define `MAGENTS_CONFIRMADO=1`. Un script añade esa confirmación con una línea `# menu: confirmar: <motivo>` o `# menu: confirmar-si-en-marcha: <motivo>` y cargando `confirmar.sh`, y su descripción sale de la línea 2. En una terminal, los scripts e `install.sh` muestran una cabecera, que se omite para agentes y tuberías. El color sigue la misma regla: morado para el logo, verde para lo correcto, rojo para los errores y amarillo para lo que requiere atención. `NO_COLOR=1` lo desactiva.

`iniciar.sh` y `parar.sh` conservan los datos de la BD, y el entorno escucha solo en `127.0.0.1`. Si hay más servicios que `web`, todos tienen IP fija en una subred `/28` propia, calculada a partir del puerto, y `web` los tiene en `extra_hosts`: así, con la BD parada, su nombre no se consulta fuera de Docker. Un entorno anterior sin esto no pasa `comprobar-entorno.sh`, y `/preparar` con «Revisar» lo corrige sin tocar el volumen de la BD. Antes de terminar, el preparador comprueba que arranca, que la web no apunta a producción ni redirige fuera de la URL local, y que `.git/` y `.magents/` no se sirven. Lo que un proyecto necesite antes de arrancar va en `.magents/scripts/antes-de-iniciar.sh`, que `iniciar.sh` ejecuta si existe y `install.sh` no toca. Si `compose.yml` usa `pull_policy: never` y falta ese script, `iniciar.sh` da error, porque nadie construiría la imagen.

Si ya hay entorno, `/preparar` te deja elegir:

- **Revisar** (recomendado): lo prueba, te enseña los problemas y sus arreglos, y aplica solo los que confirmes, dentro de `.magents/`, con copia previa y sin tocar el volumen de la BD. Conserva las adaptaciones del proyecto que funcionan. No se ejecuta si hay una tarea en curso, porque reiniciar pierde los logs del contenedor.
- **Regenerar**: crea uno nuevo y guarda el anterior en `.magents/entorno.anterior/<fecha y hora>/`. Esas copias se borran a mano y no se ejecutan donde están: para recuperar una, se mueve de vuelta a `entorno/`.
- **Conservar**: termina sin hacer nada.

`comprobar-entorno.sh` solo detecta fallos de estructura, muestra el estado sin que influya en el resultado, y lo ejecutan `install.sh` y `/tarea`. Los de funcionamiento los busca «Revisar». Los errores de PHP van a `docker compose logs web`, no a la página, gracias al `LogLevel info` de `magents.conf`. Si un entorno los envía a un archivo con `error_log`, `proyecto.md` indica cómo leerlo. Los agentes no borran ni vacían esos logs.

Te pedirá confirmar lo que el código no puede indicar, como la versión de PHP de producción. Si no hay esquema en el repositorio, deja un volcado **anonimizado** en `.magents/entorno/bd-inicial/`, que se carga solo cuando el volumen de la BD está vacío. El probador se bloquea, en lugar de arriesgarse, si no puede confirmar que los datos son de prueba.

### Copia para revisar

```bash
.magents/scripts/copiar-revision.sh [--sin-diff]
```

Copia el contenido de `.magents/` a `.magents/revision/<proyecto>/` de este repositorio, que git ignora, junto con `git log` y `git status`. Sirve para revisar desde aquí cómo han trabajado los agentes sin dar acceso a otras carpetas. Deja fuera `entorno/config`, `entorno/bd-inicial`, las copias de entornos anteriores, los temporales, las copias del código de cada iteración y los enlaces simbólicos. No incluye el código, salvo los cambios que muestran los diffs y los `delta-*.diff` de los informes. Las capturas sí se copian, así que borra de la copia las que muestren datos reales. Cada ejecución deja la copia igual que el origen, así que también recupera lo borrado de ella. Lo ejecutas tú, nunca los agentes. Se instala siempre y necesita `rsync`.

Por defecto añade `diffs/<id>.diff` por tarea: de su commit base a la base de la tarea siguiente, o al estado actual si es la última, incluidos sus archivos nuevos aún sin seguimiento. Excluye `.env`, `.env.*`, `*.pem` y `*.key`, pero puede contener contraseñas en otros archivos versionados, como un `config.ini`, así que revísalos antes de avisar. Con `--sin-diff` no los genera y borra los de una copia anterior.

## Dónde queda cada cosa

| Ruta | Contenido | ¿En git? |
|---|---|---|
| `.magents/tareas/<id>/README.md` | Cambios y decisiones de la tarea | No |
| `.magents/tareas/<id>/informes/` | Estado e informes de cada fase e iteración, y `delta-<m>-<n>.diff` con lo que cambia el código entre dos iteraciones | No |
| `.magents/tareas/<id>/iteraciones/` | Copia de los archivos cambiados en cada iteración, para calcular los deltas. Se borra al terminar la tarea | No |
| `.magents/tareas/<id>/despliegue/` | Scripts y SQL de un solo uso, revisados en las dos revisiones | No |
| `.magents/tareas/<id>/capturas/` | Evidencia de las pruebas, con una carpeta por ejecución: `entorno/`, `<n>/` y, si se repite, `<n>-2/` | No |
| `.magents/tareas/<id>/anexos/` | Cualquier otra información | No |
| `.magents/decisiones/` | Decisiones de arquitectura | No |
| `.magents/CHANGELOG.md` | Historial de cambios | No |
| `.magents/deuda.md` | Deuda pendiente del proyecto, abierta y cerrada, con id, gravedad y origen | No |
| `.magents/proyecto.md` | Configuración del entorno | No |
| `.magents/entorno/` | Configuración de Docker local | No |
| `.magents/scripts/` | Scripts para iniciar, parar, comprobar y restablecer el entorno, y para copiar lo necesario para una revisión | No |
| `.magents/preparacion/` | Propuesta, informe, revisiones y reparaciones de `/preparar` | No |
| `.magents/calibracion/` | Defecto sembrado, informe de las pruebas y resultado de cada `/calibrar` | No |

El `<id>` es un número correlativo por proyecto seguido del slug de la tarea, por ejemplo `0007-exportar-pedidos`.

## MCP de Firefox

`probador` define en su propia configuración el servidor oficial de Mozilla, [`@mozilla/firefox-devtools-mcp-moz`](https://firefox-source-docs.mozilla.org/ai-agent-tools/firefox-devtools-mcp.html), con la versión fijada. Solo se conecta durante las pruebas, con Firefox headless y un perfil temporal, y sin los módulos privilegiados. Quita `--headless` y sus valores en `.claude/agents/probador.md` si quieres ver el navegador.

La opción `--tools` es necesaria: el preset por defecto no incluye las herramientas de consola y red.

## Límite de carpeta

Los agentes solo trabajan dentro de la raíz del proyecto. Si necesitan algo de fuera, se bloquean y `/tarea` o `/preparar` te piden permiso indicando la ruta y el motivo; el permiso vale solo para esa ruta, ese fin y esa ejecución.

## Limitaciones

- El límite de carpeta lo refuerza un hook (`magents-normas/limite-carpeta.cjs`) en todos los agentes y en `/tarea`, `/preparar` y `/calibrar`: bloquea órdenes y archivos fuera de la raíz, `sudo`, `ssh`, `scp`, los borrados globales de Docker y las órdenes que le lleguen a un intérprete por una tubería, y revisa las de un heredoc. Tampoco deja enviar archivos con `curl` o `wget` a una máquina que no sea la del entorno local, conectar un cliente de base de datos (`mysql`, `psql`…) a otro servidor, ni `kill` sobre un grupo o sobre todos los procesos. De lo que se ejecuta dentro de un contenedor (`docker compose exec`, `docker run`) revisa las órdenes que escriben en el proyecto montado, según los montajes de `.magents/entorno/compose.yml`: un `rm -rf /var/www/html/*` se bloquea igual que fuera. Necesita `node`. Deja git solo para consultar: `commit`, `add`, `push`, `reset`, `clean`, `checkout`, `stash` y los demás que escriben se bloquean, también en el resto de una sesión en la que hayas usado `/tarea`, así que los commits los haces tú en tu terminal o con `!`. En Docker, solo deja parar, matar, reiniciar o entrar con `exec`, por su nombre completo, en los contenedores del entorno (`magents-cfw-<servicio>-<n>`) y en los desechables de los agentes, y exige que cada `docker run` lleve un nombre de desechable (`magents-cfw_tmp-<algo>`) y `--pull never`, para que ninguna imagen se descargue sin un `docker pull` a la vista. Así un agente puede parar los suyos si se cuelgan, sin poder tocar los de otro proyecto: el `_` no puede aparecer en el nombre de otro proyecto de magents, así que `magents-cfw_tmp-x` nunca es de `magents-cfw-test`. Tampoco deja usar `docker compose -p` con otro proyecto, cambiar de daemon (`-H`, `--context`, `DOCKER_HOST`), etiquetar imágenes que no sean del proyecto, ni `push`, `login`, `swarm`, `stack` o conectar redes. Es una barrera ante errores: no ve lo que haga el código PHP o JS al ejecutarse ni los scripts de `.magents/scripts/`. Para autorizar una ruta, añádela tú a `.magents/rutas-autorizadas.txt`; las rutas del sistema nunca se modifican. Sus pruebas: `node .claude/skills/magents-normas/limite-carpeta.test.cjs`.
- El MCP de Firefox y `npx` escriben por su cuenta sus registros, perfiles y caché en la carpeta personal (`~/.firefox-devtools-mcp/`, `~/.npm/`).
- Los agentes sin edición conservan Bash. El hook les bloquea las escrituras fuera de `.magents/` que ve en la orden (redirecciones, `cp`, `mv`, `rm`, `sed -i`…), pero no lo que escriba un programa al ejecutarse, como un script de PHP, ni las órdenes dentro de un contenedor de un entorno propio del proyecto, cuyos montajes no conoce: eso sigue dependiendo de sus instrucciones.
- `.magents/.htaccess` no protege en Nginx. Excluye `.magents/` si despliegas por FTP o rsync: subirla publicaría informes con vulnerabilidades detalladas.
- El aislamiento de producción se basa en sustituir la configuración y comprobarla: si queda en el código un destino que el preparador no detecte, el contenedor podría alcanzarlo, porque tiene salida a la red.
- Usar Docker equivale en la práctica a tener permisos de root en el equipo, y limitar los agentes a sus comandos es una instrucción, no un bloqueo técnico.
- Si una sesión no se ejecuta en un modo que permita las acciones, Claude Code pedirá confirmación durante el flujo.
