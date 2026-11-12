# Actualizar CFW y migrar webs a CFW

Complementa a `SKILL.md`: sus reglas siguen valiendo aquí.

## Actualizar una web que ya comparte historia con CFW

Es una web creada como clon de CFW, con el remoto `cfw`. El usuario hace `git fetch cfw` y `git merge <etiqueta>`; los agentes no escriben en git. La tarea empieza con el `merge` ya hecho y sin confirmar, o confirmado como commit base:

1. Lee en `MIGRACION.md` los apartados de todas las versiones entre la anterior y la nueva.
2. Por cada fichero de `general` copiado a `specific` (lista en «CFW» de `proyecto.md`), compara la copia con el nuevo original y lleva a la copia lo que haya cambiado, o propón eliminar la copia si ya no hace falta.
3. Aplica lo que `MIGRACION.md` pida a la configuración, el `.htaccess`, el esquema y los estáticos del sitio. Los cambios de esquema van como archivo SQL para que el usuario los aplique también en producción.
4. Actualiza la versión en «CFW» de `proyecto.md`.

Los criterios de aceptación incluyen lo que la web ya hacía: ver «Inventario».

## Migrar una web a CFW

Vale igual para una web con un CFW anterior que para una sin framework: no se actualiza sobre su código. Se parte de un clon del CFW actual y se trae lo que la web hace.

- **Punto de partida**: el proyecto es un clon de CFW en una etiqueta, con magents instalado. La web de origen está copiada, solo para leerla, en `.magents/origen/`, y el volcado de su base de datos en `.magents/entorno/bd-inicial/`, de donde lo carga el entorno. `copiar-revision.sh` no copia ninguna de las dos carpetas. Si falta, pídela: no salgas de la carpeta a buscarla.
- **No cabe en una tarea.** La primera tarea es el inventario y el plan por etapas, sin tocar código. Cada etapa es después una `/tarea`.
- **Nada del origen se copia tal cual**: se reescribe como página, ORM, plantilla y textos de `specific`, con las reglas de `DESARROLLO.md`. Tampoco se arrastran sus mecanismos de sesión, acceso, contraseñas o subida de archivos: se usan los de CFW.

### Si el origen lleva un CFW anterior

- **Qué cambió en su núcleo.** El origen no trae la versión de su CFW ni comparte historia con el actual. Compara su `cfw/general/`, su `index.php` y su `.htaccess` con los del proyecto, fichero a fichero, y separa tres cosas: lo que es solo antigüedad (CFW lo cambió después), lo que la web modificó a propósito en el núcleo y lo que no se sabe. Lo segundo entra en el inventario; lo tercero es una duda. Si el usuario dispone del CFW de aquella época, pídeselo en `.magents/origen-cfw/`: con él la separación es exacta.
- **Su `specific` no se copia entero.** Cada página, clase, ORM, plantilla y texto se revisa contra `MIGRACION.md` y `DESARROLLO.md`: constructores que deben llamar a `exigirAdmin()` o `exigirUsuario()`, formularios sin `csrf`, contraseñas enviadas en md5 o en claro, datos pintados sin `escapar()`, `menu.php` de idiomas y copias de ficheros de `general` que ya no coinciden con el actual.
- **Sus copias de ficheros de `general`** se rehacen sobre el fichero actual, llevando solo el cambio que la web necesitaba, o se eliminan si CFW ya lo trae.
- **Usuarios**: las contraseñas en md5 valen tal cual y se convierten en el primer login. Comprueba el tamaño de la columna `pass` y el valor de `activo`, que ahora se exige para entrar.
- **PHP**: el origen puede usar sintaxis o funciones que PHP 8.2 ya no admite. Lo que se traiga se pasa por `php -l` con la versión del proyecto, y los avisos de `Deprecated` del log cuentan.

### Inventario

Se guarda en `.magents/migracion.md` y lo mantiene el `documentador`. Recoge, leyendo el origen:

- Cada URL pública y de administración, con su método, sus parámetros, quién puede usarla y qué hace.
- Formularios, correos que envía, archivos que sube o genera, tareas programadas y destinos externos.
- Tablas y columnas, con las que guardan contraseñas, datos personales o rutas de archivos, y la codificación de los textos guardados: `Orm::filtro()` guarda con entidades HTML y el origen quizá no.
- Usuarios y permisos: cómo se guarda la contraseña y si CFW la puede aceptar (md5 sí, y la convierte en el primer login).
- Lo que el origen tiene y CFW no, marcando lo que serviría a cualquier web: va «Para CFW».
- Lo que no se entiende o no se puede comprobar leyendo: son dudas para el usuario.

El inventario sale solo de leer: la web de origen no se arranca. Por eso el usuario lo repasa antes de planificar las etapas, y lo que añada o corrija entra con su id. Lo que solo se vería con la web en marcha, como un comportamiento que dependa de los datos o del servidor, se anota como duda.

Cada elemento lleva un id (`M001`…) y un estado: pendiente, migrado en la tarea `<NNNN>`, descartado por el usuario o sustituido por una función de CFW.

### Plan por etapas

Orden habitual: esquema y datos; acceso y usuarios; páginas públicas, por bloques; administración; estáticos y aspecto; redirecciones de las URL antiguas; puesta en producción. Cada etapa lista los ids del inventario que cubre, y sus criterios de aceptación dicen qué se compara con el origen y cómo.

Una etapa termina cuando sus ids están migrados o descartados. No se da la migración por terminada con ids pendientes.

### Datos

Los cambios de esquema y la conversión de datos van como archivos SQL o scripts repetibles, probados contra una copia en el entorno local. La copia es la real de producción, por decisión del usuario: no hace falta anonimizarla. Aun así, no copies correos, nombres ni contraseñas a los informes, a la ficha ni a `migracion.md`: cita la tabla, la columna y el id de la fila. Las capturas sí pueden mostrar datos de la copia: en una migración, el `documentador` no las borra por eso, solo si muestran contraseñas, claves u otros secretos.
