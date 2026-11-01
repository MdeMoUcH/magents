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

## Comprobaciones automáticas

- Tests: <!-- p. ej. vendor/bin/phpunit, o "no hay" -->
- Análisis estático / estilo: <!-- p. ej. vendor/bin/phpstan, o "no hay" -->

## Rutas que no se deben tocar

<!-- p. ej. uploads/, vendor/ -->
