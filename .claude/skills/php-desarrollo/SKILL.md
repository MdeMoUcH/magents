---
name: php-desarrollo
description: Método para implementar o corregir código en webs PHP siguiendo el plan del triage, las convenciones del proyecto y prácticas seguras.
user-invocable: false
---

# Desarrollo PHP

## Antes de escribir

Lee `triage.md`, `.magents/proyecto.md` y los archivos que vas a tocar. No modifiques las rutas de «Rutas que no se deben tocar»: si la tarea lo exige, termina con `BLOQUEADO`. Si vienes de un rechazo, lee el informe: arregla **todos** los hallazgos bloqueantes y busca el mismo fallo en el resto de tu cambio. Si un hallazgo te parece erróneo, no lo ignores: explica por qué en tu informe.

## Al escribir

- **Alcance**: solo lo que pide la tarea, sin refactorizar ni reformatear lo que no toca. Los problemas ajenos se anotan, no se arreglan.
- **Convenciones**: el código nuevo debe parecer escrito por quien escribió el de alrededor, en nombres, estructura y estilo. Reutiliza lo que ya existe.
- **Indentación**: con tabuladores, en archivos nuevos y en los que ya los usan, salvo en formatos que no los admiten, como YAML. En un archivo existente indentado con espacios, mantén los espacios, sin mezclar ni reformatear. En uno que ya mezcla ambos, sigue el estilo de las líneas de alrededor y no reformatees nada.
- **Comentarios**: breves y concisos, y solo donde aporten algo que el código no diga. Nunca pueden ocupar más que el código al que acompañan; lo normal es que ocupen mucho menos.
- **Compatibilidad**: no uses sintaxis más nueva que la versión de PHP de producción.
- **Cambios de esquema**: como script SQL en la ubicación que use el proyecto. No los ejecutes sobre bases de datos que no sean la local de prueba.
- **Scripts de despliegue**: los de un solo uso van en `.magents/tareas/<id>/despliegue/`, con prefijo de orden (`01-esquema.sql`, `02-datos.php`) y sin secretos. Indica en tu informe cuándo ejecutar cada uno y cómo revertirlo. Esa carpeta no se versiona: si el proyecto tiene su propio sistema de migraciones, las migraciones siguen yendo allí.
- **Dependencias**: no añadas ninguna sin que lo indique el plan.
- **Entorno**: modifica `.magents/entorno/` y `.magents/scripts/` solo si lo indica el plan, sin tocar `iniciar.sh`, `parar.sh` ni `reiniciar-bd.sh`; lo propio del proyecto va en `.magents/scripts/antes-de-iniciar.sh`. Para repetir pruebas que escriben, restablece la BD con `.magents/scripts/reiniciar-bd.sh`, que borra los datos, y vuelve a aplicar tus cambios de esquema. Esas carpetas no aparecen en el diff: detalla el cambio en tu informe, indica si producción también lo necesita y añade a «Pasos adicionales para probar» que hay que reiniciar el entorno.

## Seguridad mínima, siempre

- SQL con consultas preparadas. Identificadores dinámicos (columnas, `ORDER BY`) solo desde una lista blanca. Si la capa del proyecto no admite parámetros, usa el escapado del driver y señálalo en tu informe.
- Salida escapada según el contexto: `htmlspecialchars($v, ENT_QUOTES, 'UTF-8')` en HTML, `json_encode` en JS, `rawurlencode` en URL.
- Valida las entradas en el servidor, con tipos y rangos. Nada de `extract($_REQUEST)`, `eval` ni rutas de `include` que dependan del usuario.
- Formularios que cambian estado: POST con token CSRF. Comprueba la autenticación **y** la autorización sobre el recurso concreto.
- Contraseñas con `password_hash` y `password_verify`. Tokens con `random_bytes`. Nada de `md5` o `sha1` para credenciales en código nuevo. Si el sistema existente los usa y migrarlo queda fuera de la tarea, no lo arregles: anótalo.
- Subidas: tamaño, tipo real con `finfo`, nombre generado, y fuera de la raíz web o sin ejecución.
- Sin secretos en el código, ni `var_dump` o depuración sobrante. Los errores detallados van al log, no al usuario.

## Antes de terminar

1. `php -l` sobre cada archivo PHP cambiado, con la versión de producción: con el entorno en esa versión, `docker compose -f .magents/entorno/compose.yml exec -T web php -l <archivo>`; si no, `docker run --rm --pull never --name <nombre>_tmp-lint --network none -v "$PWD":/app:ro -w /app <imagen> timeout 120 php -l <archivo>`, con la imagen del entorno de esa versión si existe (`docker image ls <nombre>-web`) o, si no, `php:<versión>-cli` (el nombre, en «Docker» de `magents-normas`).
2. Ejecuta los tests y el análisis estático definidos en `.magents/proyecto.md`, si los hay.
3. Revisa tu diff completo y quita lo que no sea de la tarea.

Usa git solo para consultar: los commits los hace el usuario. No afirmes que algo funciona si no lo has ejecutado.

## Formato del informe

```markdown
# Desarrollo (iteración n)
## Cambios
`ruta`: qué y por qué
## Cambios de entorno
(solo si los hay: qué cambia en `.magents/entorno/` o `.magents/scripts/` y si producción también lo necesita)
## Decisiones
Decisión, alternativa descartada y motivo
## Hallazgos atendidos
(desde la iteración 2: cada hallazgo y cómo se resolvió, o por qué se discute)
## Comprobaciones ejecutadas
Comando y resultado real
## Pasos adicionales para probar
SQL a aplicar, configuración...
## Problemas ajenos detectados
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: IMPLEMENTADO | BLOQUEADO
```

Usa `BLOQUEADO` solo si necesitas una decisión del usuario, y explica cuál.
