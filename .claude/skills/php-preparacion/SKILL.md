---
name: php-preparacion
description: Método para detectar el stack de una web PHP, proponer su configuración y generar y comprobar un entorno Docker local aislado de producción.
user-invocable: false
---

# Preparación del entorno

El prompt indica el modo: `propuesta` o `generar`. Las plantillas están en `.claude/skills/php-preparacion/plantillas/`.

## Reglas de seguridad

- **Producción**: la web del contenedor nunca debe poder conectar con la BD, el correo ni las API de producción. Sustituye su configuración desde `compose.yml`, con variables de entorno o montando un archivo encima (también `.env`), sin tocar los archivos del proyecto. Si no puedes garantizarlo: `BLOQUEADO`.
- **Secretos**: no copies a informes, `proyecto.md` ni `.magents/entorno/` ninguna contraseña, clave o token del proyecto. Nombra el archivo y la variable, nunca el valor.
- **Datos**: no te conectes a producción ni descargues un volcado. Usa el esquema del repositorio o el volcado anonimizado que el usuario deje en `.magents/entorno/bd-inicial/`.
- **Red**: publica los puertos solo en `127.0.0.1`.
- **Redirecciones**: la web local no debe redirigir fuera de la URL local. Las de `https`, `www` o URL base fija se neutralizan desde `compose.yml`, sin tocar el proyecto: variables de entorno o un archivo montado encima, también `.htaccess`.

## Modo `propuesta`

No escribas nada. Averigua:

1. **Stack**: versión de PHP (`composer.json`, Dockerfile, sintaxis usada), extensiones (`gd`, `intl` o `zip` necesitan librerías del sistema), framework o estructura, servidor, raíz web y requisitos como `short_open_tag`. El código solo da pistas sobre producción: marca la versión como `supuesta` si nadie la ha confirmado.
2. **Entorno existente**: si el proyecto ya tiene Docker o similar, propón reutilizarlo y no generes otro. Las reglas de seguridad y las comprobaciones se aplican igual.
3. **Conexiones externas**: todos los archivos de configuración y todo destino externo (BD, SMTP, API, pasarelas de pago, redirecciones de `.htaccess` o del código, URL absolutas en formularios, JS y plantillas), y cómo sustituir cada uno. Busca de forma expresa los dominios del proyecto en todo el código, porque una URL fija puede enviar datos a producción sin cambiar de página. Si alguna no se puede sustituir, indícala en la tabla de aislamiento. Si un archivo que hay que sustituir no existe, Docker lo crearía en el proyecto como root: pregunta al usuario si lo crea él o propón variables de entorno.
4. **Base de datos**: motor y versión, dónde está el esquema y si hay datos de prueba. Si no hay esquema, indica que el usuario debe aportar un volcado anonimizado.
5. **Escrituras**: rutas donde escribe la web. Las que estén en `.gitignore` no necesitan nada. Las demás ensuciarían el diff de los revisores: propón montarlas como `tmpfs` con `mode=1777`, solo si su contenido no está versionado y no hace falta conservarlo.
6. **Puerto**: elige uno libre al azar entre 8100 y 8899 (`ss -ltn`), para reducir choques con otros proyectos.
7. **Comprobaciones y rutas**: tests, análisis estático y rutas que no se deben tocar.

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

VEREDICTO: PROPUESTA | BLOQUEADO
```

## Modo `generar`

Aplica solo lo que el prompt indica como confirmado. Antes de empezar, guarda la salida de `git status --porcelain` y anota si el entorno ya estaba en marcha.

1. Si se ha confirmado regenerar y ya existe `.magents/entorno/`, para el entorno con su `parar.sh` y mueve la carpeta a `.magents/entorno.anterior-<fecha y hora>/`. Nunca la sobrescribas. Copia su `bd-inicial/` a la carpeta nueva para no perder el volcado. El volumen de la BD se conserva, así que `bd-inicial/` no se vuelve a cargar: indícalo si ha cambiado.
2. Crea `.magents/proyecto.md` desde `plantillas/proyecto.md`, o actualiza solo los valores confirmados.
3. Si se genera el entorno, copia a `.magents/entorno/` `iniciar.sh` y `parar.sh` sin alterarlos, también `reiniciar-bd.sh` si hay BD, y `php.ini`, `magents.conf`, `Dockerfile` y `compose.yml` adaptados: rellena cada `__VALOR__` y borra lo que no aplique. `__PROYECTO__` va en minúsculas, con letras, números y guiones. Si `.git` es un archivo (worktree o submódulo), cambia su línea de `tmpfs` por un volumen `/dev/null:/var/www/html/.git:ro`. Crea también los archivos de configuración sustitutos en `.magents/entorno/config/`, solo con valores de prueba. Si hay BD, crea `.magents/entorno/bd-inicial/` aunque quede vacía, porque si no la crearía Docker como root.
4. Si una versión antigua de PHP no se puede construir, no la cambies por otra más nueva: `BLOQUEADO`, y explica el error.
5. Nunca modifiques los scripts fijos, porque `install.sh` los sobrescribe. Si el arranque necesita algo propio del proyecto, ponlo en `.magents/entorno/antes-de-iniciar.sh`, que `iniciar.sh` ejecuta si existe y `install.sh` no toca.
6. Si `apt-get` no descarga dentro de la red de Docker, por ejemplo con una VPN, construye desde ese script con `docker build --network=host -t <imagen> .`, y en `compose.yml` cambia `build: .` por `image: <imagen>` y `pull_policy: never`. Compose no sirve para esto, porque construir con `network: host` le exige permisos adicionales.

### Comprobaciones

Ejecuta todas y anota el comando y el resultado real:

1. `iniciar.sh`, o el comando del entorno propio, termina sin error y la URL responde.
2. `php -v` dentro del contenedor coincide con la versión confirmada.
3. Desde dentro del contenedor, cada conexión de la tabla de aislamiento apunta al sustituto, sin mostrar secretos. Si hay BD, la web se conecta a la de prueba.
4. `/.git/HEAD` y `/.magents/proyecto.md` no se sirven por la URL local.
5. Las páginas principales, como la de inicio y la de acceso, no redirigen fuera de la URL local (`curl -sI`).
6. Un `Warning`, un `Notice` y un `Deprecated` provocados con una sonda temporal llegan al log indicado en `proyecto.md` y no se muestran en la página. Borra la sonda.
7. `git status --porcelain` no ha cambiado.
8. El comando de parada termina sin error y no queda ningún contenedor de este entorno.

Si alguna falla y no lo puedes arreglar dentro de `.magents/`, termina con `BLOQUEADO`. Deja el entorno parado, salvo que ya estuviera en marcha: en ese caso vuelve a iniciarlo.

```markdown
# Preparación
## Archivos creados
## Comprobaciones
| Comprobación | Comando | Resultado |
## Supuestos pendientes de confirmar
## Pendiente del usuario

VEREDICTO: LISTO | BLOQUEADO
```
