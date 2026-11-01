# Configuración del proyecto para los agentes

Sin contraseñas de producción aquí. Este archivo no se versiona, porque `.magents/` está en `.gitignore`.

## Entorno local de pruebas

- URL base: <!-- p. ej. http://127.0.0.1:8088 -->
- Cómo arrancarlo: <!-- p. ej. docker compose up -d -->
- Cómo pararlo: <!-- p. ej. docker compose down -->
- Logs de errores PHP: <!-- p. ej. docker compose logs web -->
- Base de datos de prueba: <!-- cómo crearla o restaurarla; nunca la de producción -->
- Usuarios de prueba: <!-- rol y cómo obtener el acceso -->

## Stack

- Versión de PHP en producción: <!-- condiciona la sintaxis que se puede usar -->
- Servidor web: <!-- Apache con .htaccess, Nginx... -->
- Base de datos:
- Framework o estructura:
- Requisitos especiales: <!-- p. ej. short_open_tag=On -->

## Comprobaciones automáticas

- Tests: <!-- p. ej. vendor/bin/phpunit, o "no hay" -->
- Análisis estático / estilo: <!-- p. ej. vendor/bin/phpstan, o "no hay" -->

## Rutas que no se deben tocar

<!-- p. ej. uploads/, vendor/ -->
