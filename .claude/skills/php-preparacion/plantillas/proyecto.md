# Configuración del proyecto para los agentes

Sin contraseñas de producción aquí. Este archivo no se versiona, porque `.magents/` está en `.gitignore`.

## Entorno local de pruebas

- URL base: <!-- p. ej. http://127.0.0.1:8123 -->
- Cómo arrancarlo o reiniciarlo: <!-- p. ej. .magents/scripts/iniciar.sh -->
- Cómo pararlo: <!-- p. ej. .magents/scripts/parar.sh -->
- Logs de errores PHP: <!-- p. ej. docker compose -f .magents/entorno/compose.yml logs web -->
- Base de datos de prueba: <!-- cómo crearla; nunca la de producción -->
- Cómo restablecer la BD de prueba: <!-- p. ej. .magents/scripts/reiniciar-bd.sh -->
- Usuarios de prueba: <!-- rol y cómo obtener el acceso -->
- Aislamiento de producción: <!-- qué configuración se sustituye y cómo se ha comprobado -->

## Stack

- Versión de PHP en producción: <!-- condiciona la sintaxis que se puede usar; indica si es confirmada o supuesta -->
- Servidor web: <!-- Apache con .htaccess, Nginx... -->
- Base de datos:
- Framework o estructura:
- Requisitos especiales: <!-- p. ej. short_open_tag=On -->

## CFW

<!-- Solo si la web usa el framework CFW o se está migrando a él; si no, borra la sección.
- Si este proyecto es el propio CFW o una web hecha con él
- Versión de CFW: la de cfw/general/VERSION, o el commit de CFW del que parte
- Ficheros de general copiados a specific, con el motivo de cada uno
- Inicio de sesión sin navegador: cómo se hace en este entorno, porque la contraseña viaja cifrada
- Web de origen, si es una migración: qué hay en .magents/origen/ y si sus datos son reales -->

## Documentación del proyecto

<!-- Archivos versionados que explican la web a quien la usa, instala o actualiza, y qué cubre cada uno. P. ej.:
- README.md: qué es y cómo funciona
- INSTALACION.md: requisitos y puesta en marcha
- Textos de la web que listan requisitos o medidas: ruta del archivo
Las tareas que cambien lo que describen deben actualizarlos. -->

## Métodos de prueba aceptados

<!-- Métodos que el usuario acepta para todas las tareas, para no volver a preguntarlos -->

## Tareas menores

- Omitir las verificaciones que proponga el triage: <!-- sí, no o preguntar; sin valor, se pregunta en cada tarea -->

## Comprobaciones automáticas

- Tests: <!-- p. ej. vendor/bin/phpunit, o "no hay" -->
- Análisis estático / estilo: <!-- p. ej. vendor/bin/phpstan, o "no hay" -->

## Rutas que no se deben tocar

<!-- p. ej. uploads/, vendor/ -->
