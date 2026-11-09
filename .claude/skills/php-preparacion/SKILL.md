---
name: php-preparacion
description: Método para detectar el stack de una web PHP, proponer su configuración y generar y comprobar un entorno Docker local aislado de producción.
user-invocable: false
---

# Preparación del entorno

El prompt indica el modo: `propuesta`, `generar`, `revisar` o `reparar`. Las plantillas están en `.claude/skills/php-preparacion/plantillas/`.

## Reglas de seguridad

- **Producción**: la web del contenedor nunca debe poder conectar con la BD, el correo ni las API de producción. Sustituye su configuración desde `compose.yml`, con variables de entorno o montando un archivo encima (también `.env`), sin tocar los archivos del proyecto. Si no puedes garantizarlo: `BLOQUEADO`.
- **Secretos**: no copies a informes, `proyecto.md` ni `.magents/entorno/` ninguna contraseña, clave o token del proyecto. Nombra el archivo y la variable, nunca el valor.
- **Datos**: no te conectes a producción ni descargues un volcado. Usa el esquema del repositorio o el volcado anonimizado que el usuario deje en `.magents/entorno/bd-inicial/`.
- **Red**: publica los puertos solo en `127.0.0.1`.
- **Nombres de servicio**: el DNS de Docker solo resuelve un servicio mientras está en marcha. Parado, el nombre se consulta en el DNS del equipo y puede acabar en una IP pública, y la web intentaría autenticarse allí. Por eso, si hay más servicios que `web`, todos llevan IP fija en una subred propia y `web` los tiene en `extra_hosts`, también con un entorno propio del proyecto. Cambiar solo el nombre no lo evita. Esta norma no explica por qué el nombre acaba en una IP concreta: depende del equipo. No des esa causa por sabida.
- **Redirecciones**: la web local no debe redirigir fuera de la URL local. Las de `https`, `www` o URL base fija se neutralizan desde `compose.yml`, sin tocar el proyecto: variables de entorno o un archivo montado encima, también `.htaccess`.

## Modo `propuesta`

No escribas nada. Averigua:

1. **Stack**: versión de PHP (`composer.json`, Dockerfile, sintaxis usada), extensiones (`gd`, `intl` o `zip` necesitan librerías del sistema), framework o estructura, servidor, raíz web y requisitos como `short_open_tag`. El código solo da pistas sobre producción: marca la versión como `supuesta` si nadie la ha confirmado.
2. **Entorno existente**: si el proyecto ya tiene Docker o similar, propón reutilizarlo y no generes otro. Las reglas de seguridad y las comprobaciones se aplican igual.
3. **Conexiones externas**: todos los archivos de configuración y todo destino externo (BD, SMTP, API, pasarelas de pago, redirecciones de `.htaccess` o del código, URL absolutas en formularios, JS y plantillas), y cómo sustituir cada uno. Busca de forma expresa los dominios del proyecto en todo el código, porque una URL fija puede enviar datos a producción sin cambiar de página. Si alguna no se puede sustituir, indícala en la tabla de aislamiento. Si un archivo que hay que sustituir no existe, Docker lo crearía en el proyecto como root: pregunta al usuario si lo crea él o propón variables de entorno.
4. **Base de datos**: motor y versión, dónde está el esquema y si hay datos de prueba. Si no hay esquema, indica que el usuario debe aportar un volcado anonimizado.
5. **Escrituras**: rutas donde escribe la web. Las que estén en `.gitignore` no necesitan nada. Las demás ensuciarían el diff de los revisores: propón montarlas como `tmpfs` con `mode=1777`, solo si su contenido no está versionado y no hace falta conservarlo.
6. **Puerto**: elige uno libre al azar entre 8100 y 8899 (`ss -ltn`), para reducir choques con otros proyectos.
   **Subred**, si hay más servicios que `web`: con `n` = puerto − 8100, `__SUBRED__` es `10.<213 + n / 256, sin decimales>.<n % 256>`, y la red es `__SUBRED__.0/28`. Al salir del puerto, dos entornos de magents con puertos distintos no chocan. Compruébala con `ip -4 route show table all to match __SUBRED__.1 | grep -v '^default'`: si sale alguna ruta, esa red ya está en uso (VPN o red local), así que elige otra `/28` de `10.0.0.0/8` e indícalo. No uses `ip route get`, porque con una VPN da su interfaz para cualquier IP. Con el puerto fuera de ese intervalo, elige también una al azar.
7. **Comprobaciones y rutas**: tests, análisis estático y rutas que no se deben tocar.
8. **Documentación del proyecto**: archivos versionados que explican la web a quien la usa, la instala o la actualiza (`README`, guías de instalación o de migración, `docs/`, y textos de la propia web que listen requisitos o medidas), con qué cubre cada uno, para la sección «Documentación del proyecto» de `proyecto.md`. No incluyas nada de `.magents/`.

Si no hay entorno propio y Docker no está disponible: `BLOQUEADO`.

```markdown
# Propuesta de preparación
## Stack detectado
Cada valor con su evidencia (`ruta:línea`), indicando si es confirmado o supuesto
## Entorno propuesto
Reutilizar el existente o generar uno: imagen, extensiones, raíz web, servicios y puerto
## Aislamiento de producción
| Conexión | Archivo y variable | Cómo se sustituye |
## Base de datos y usuarios de prueba
## Escrituras
## Valores para .magents/proyecto.md
## Preguntas para el usuario
Solo lo que no se puede deducir: pregunta, por qué importa y tu recomendación
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: PROPUESTA | BLOQUEADO
```

## Modo `generar`

Aplica solo lo que el prompt indica como confirmado. Antes de empezar, guarda la salida de `git status --porcelain` y anota si el entorno ya estaba en marcha.

1. Si se ha confirmado regenerar y ya existe `.magents/entorno/`, para el entorno con `.magents/scripts/parar.sh` y mueve esa carpeta a `.magents/entorno.anterior/<fecha y hora>/`. Nunca la sobrescribas. Esas copias no se ejecutan donde están, porque usan el mismo nombre de proyecto y sus rutas relativas dejan de valer: para recuperar una, se mueve de vuelta a `entorno/`. Copia su `bd-inicial/` a la carpeta nueva para no perder el volcado. El volumen de la BD se conserva, así que `bd-inicial/` no se vuelve a cargar: indícalo si ha cambiado.
2. Crea `.magents/proyecto.md` desde `plantillas/proyecto.md`, o actualiza solo los valores confirmados.
3. Si se genera el entorno, copia de `plantillas/scripts/` a `.magents/scripts/` `iniciar.sh` y `parar.sh` sin alterarlos, también `reiniciar-bd.sh` si hay BD, y a `.magents/entorno/` `php.ini`, `magents.conf`, `Dockerfile` y `compose.yml` adaptados: rellena cada `__VALOR__` y borra lo que no aplique. `__PROYECTO__` va en minúsculas, con letras, números y guiones. Si `.git` es un archivo (worktree o submódulo), cambia su línea de `tmpfs` por un volumen `/dev/null:/var/www/html/.git:ro`. Crea también los archivos de configuración sustitutos en `.magents/entorno/config/`, solo con valores de prueba. Si hay BD, crea `.magents/entorno/bd-inicial/` aunque quede vacía, porque si no la crearía Docker como root. No montes una copia idéntica de un archivo del proyecto: los cambios del original no se probarían.
4. Si una versión antigua de PHP no se puede construir, no la cambies por otra más nueva: `BLOQUEADO`, y explica el error.
5. Nunca modifiques los scripts fijos, porque `install.sh` los sobrescribe. Si el arranque necesita algo propio del proyecto, ponlo en `.magents/scripts/antes-de-iniciar.sh`, que `iniciar.sh` ejecuta desde `.magents/entorno/` si existe y `install.sh` no toca. Todo script del entorno va en `.magents/scripts/`.
6. Si `apt-get` no descarga dentro de la red de Docker, por ejemplo con una VPN, construye desde ese script con `docker build --network=host -t <imagen> .`, donde `<imagen>` es `<name>-web:<versión de PHP>` con el `name:` de `compose.yml` (por ejemplo `magents-cfw-web:8.5`), porque el hook solo deja etiquetar imágenes de este proyecto, y en `compose.yml` cambia `build: .` por `image: <imagen>` y `pull_policy: never`. Compose no sirve para esto, porque construir con `network: host` le exige permisos adicionales.
7. En lo que escribas, usa tabuladores salvo en formatos que no los admitan, como YAML, o donde el archivo ya use espacios. Los comentarios son breves, solo donde aporten algo, y nunca ocupan más que lo que acompañan.

### Comprobaciones

Ejecuta todas y anota el comando y el resultado real:

1. `.magents/scripts/iniciar.sh`, o el comando del entorno propio, termina sin error y la URL responde.
2. `php -v` dentro del contenedor coincide con la versión confirmada.
3. Desde dentro del contenedor, cada conexión de la tabla de aislamiento apunta al sustituto, sin mostrar secretos. Si hay BD, la web se conecta a la de prueba.
4. Si hay más servicios que `web`: `.magents/scripts/comprobar-entorno.sh` pasa y cada nombre que usa la configuración de la web, también un alias, está en `/etc/hosts` del contenedor. Después, solo si pasa, para cada servicio con `docker compose stop <servicio>`: `getent ahosts <nombre>` dentro de `web` sigue dando su IP privada; no uses `getent hosts`, que consulta `AAAA` fuera de Docker aunque el nombre esté en `/etc/hosts`. Espera 60 s, con `sleep 60` en segundo plano porque Claude Code bloquea los `sleep` largos en primer plano, ya que antes de que caduque la caché ARP la conexión puede tardar todo su tiempo de espera, y la web debe dar su error en menos de 20 s. Vuelve a levantarlo con `docker compose up -d --wait <servicio>`. Si no pasa, no pares el servicio y anótalo.
5. `/.git/HEAD` y `/.magents/proyecto.md` no se sirven por la URL local.
6. Las páginas principales, como la de inicio y la de acceso, no redirigen fuera de la URL local (`curl -sI`).
7. Un `Warning`, un `Notice` y un `Deprecated` provocados con una sonda temporal llegan al log indicado en `proyecto.md` y no se muestran en la página. Borra la sonda.
8. `git status --porcelain` no ha cambiado.
9. El comando de parada termina sin error y no queda ningún contenedor de este entorno.

Si alguna falla y no lo puedes arreglar dentro de `.magents/`, termina con `BLOQUEADO`. Deja el entorno parado, salvo que ya estuviera en marcha: en ese caso vuelve a iniciarlo.

```markdown
# Preparación
## Archivos creados
## Comprobaciones
| Comprobación | Comando | Resultado |
## Supuestos pendientes de confirmar
## Pendiente del usuario
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: LISTO | BLOQUEADO
```

## Modo `revisar`

No cambies ningún archivo salvo la sonda temporal de las comprobaciones, que debes borrar. Reiniciar el entorno recrea el contenedor y pierde sus logs: si `git status` u otra señal indica una tarea en curso, no lo hagas y termina con `BLOQUEADO`, para que el usuario decida. Anota si estaba en marcha y déjalo igual al terminar. Si no está en marcha, arráncalo solo para las comprobaciones.

1. Ejecuta `.magents/scripts/comprobar-entorno.sh`, si existe, y parte de su salida.
2. Compara `.magents/entorno/` y `proyecto.md` con las plantillas y normas actuales de esta skill, también las secciones de `plantillas/proyecto.md` que falten en `proyecto.md`, como «Documentación del proyecto», que propones rellenar según el punto 8 de «Modo `propuesta`». Por ejemplo, un `LogLevel` que falta en `magents.conf`, un `proyecto.md` que describe un comportamiento que los scripts ya no tienen, o un paso de construcción que quedó solo en `.magents/scripts/anterior/`.
3. Ejecuta las comprobaciones de «Modo `generar`» con el entorno tal como está. Omite solo las que no se puedan repetir sin cambiar datos, e indícalo.

Separa lo que está mal de lo que solo es distinto. Una adaptación del proyecto, como otra versión de PHP, más extensiones o un `--network=host`, no es un problema si funciona. No propongas igualarla a la plantilla. Un archivo montado idéntico a su original sí es un problema, porque sus cambios no se probarían: propón quitar el montaje si la copia no sustituye nada.

```markdown
# Revisión del entorno
## Comprobaciones
| Comprobación | Comando | Resultado |
## Problemas
| Problema | Evidencia | Consecuencia | Arreglo propuesto, con los archivos que cambia |
## Adaptaciones que se conservan
## Sin comprobar
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: CORRECTO | PROBLEMAS | BLOQUEADO
```

## Modo `reparar`

Aplica solo los arreglos que el prompt indica como confirmados.

1. Si el entorno está en marcha, anótalo. Copia `.magents/entorno/`, sin `bd-inicial/`, que aquí no cambia y hay que conservar de `entorno/` si se recupera la copia, a `.magents/entorno.anterior/<fecha y hora>/`, y `proyecto.md` dentro de esa copia. Copia también `antes-de-iniciar.sh`, si vas a cambiarlo.
2. Escribe solo dentro de `.magents/`, salvo la sonda temporal de las comprobaciones, que debes borrar. No modifiques los scripts fijos, y pon lo propio del proyecto en `.magents/scripts/antes-de-iniciar.sh`, con las normas de estilo de «Modo `generar`».
3. No borres el volumen de la BD ni cambies `bd-inicial/`. Si un arreglo lo exigiera, termina con `BLOQUEADO`. Al añadir la subred propia, conserva `name:` y la clave del volumen, de los que depende su nombre, y aplícala con `.magents/scripts/iniciar.sh`, que borra la red antigua sin tocar los volúmenes.
4. Al actualizar `proyecto.md`, no borres lo que siga sin averiguar, como una causa sin investigar. Si un arreglo deja obsoleto un riesgo citado en `.magents/CHANGELOG.md`, añade arriba una línea con la fecha y lo que cambia, sin reescribir las anteriores.
5. Ejecuta `.magents/scripts/comprobar-entorno.sh` y todas las comprobaciones de «Modo `generar`», con el mismo criterio de `BLOQUEADO` y el mismo estado final del entorno. Una comprobación sin hacer o a medias da `BLOQUEADO`.

```markdown
# Reparación del entorno
## Arreglos aplicados
## Copia
## Comprobaciones
| Comprobación | Comando | Resultado |
## Pendiente
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: LISTO | BLOQUEADO
```
