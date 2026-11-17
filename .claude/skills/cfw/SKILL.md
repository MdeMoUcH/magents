---
name: cfw
description: Reglas para trabajar en webs hechas con el framework CFW o que se migran a él, en cualquier fase de /tarea. Solo se instala en proyectos relacionados con CFW.
user-invocable: false
---

# Webs con CFW

CFW es un framework MVC en PHP: `cfw/general/` es el núcleo y `cfw/specific/` lo propio de cada web, que tiene prioridad. Esta skill se suma a la de tu fase; no la sustituye.

## Antes de empezar

1. Lee `DESARROLLO.md` de la raíz del proyecto, que explica cómo se construye sobre CFW. Si no existe, la web lleva un CFW anterior: lee `README.md` y, de `cfw/general/class/`, las clases que toque la tarea.
2. Mira la versión en `cfw/general/VERSION` y en «CFW» de `.magents/proyecto.md`. Cada web lleva su copia de CFW: lo que sepas de otra versión no vale si el código dice otra cosa.
3. Si el código y la documentación no coinciden, manda el código, y la diferencia va al informe.

## Si el proyecto es el propio CFW

Lo es si «CFW» de `.magents/proyecto.md` lo dice o, si no dice nada, si `cfw/specific/` no tiene páginas, clases ni ORM propios y no hay un remoto de git llamado `cfw`. Entonces el núcleo es el trabajo y cambian tres cosas:

- No valen «El núcleo no se toca» ni «Mejoras para CFW» de «Reglas», ni la comprobación de que el núcleo no ha cambiado de «Revisión de código».
- Todo cambio se mira como lo recibirá un sitio al actualizar: si le obliga a tocar algo o cambia un comportamiento, va en `MIGRACION.md`; si cambia cómo se construye sobre CFW, en `DESARROLLO.md`; y nada propio de un sitio entra en `cfw/specific/`, que aquí solo lleva los `index.php` de protección.
- Un cambio que rompa a los sitios existentes es una duda para el usuario, porque decide el número de versión.

Lo demás de esta skill vale igual.

## Reglas

- **El núcleo no se toca.** En una web, ninguna tarea cambia `cfw/general/`, `cfw/includes.php`, `cfw/index.php`, `index.php` ni los estáticos del núcleo, salvo que la tarea sea actualizar CFW. Lo que haga falta va en `cfw/specific/`. Esta regla no vale en el repositorio del propio CFW: ahí el núcleo es el trabajo.
- **Copiar a `specific` es el último recurso.** Antes, una página que herede, un texto o una plantilla nueva. Si se copia un fichero de `general`, queda anotado en «CFW» de `proyecto.md`, con el motivo.
- **Mejoras para CFW.** Lo que serviría a cualquier web, o un fallo del núcleo, no se arregla en la web: va a «Fuera de alcance» o a «Preexistentes» de tu informe con la marca «Para CFW», y el `documentador` lo pasa a `.magents/deuda.md` con tipo «cfw». Si el fallo impide la tarea, es una duda para el usuario.
- **Protecciones.** No des por hecha ninguna protección del framework: compruébala en el código de esta web. En especial, que una URL empiece por `/admin/` no protege nada.

## Qué mirar en cada fase

- **Preparación** (`/preparar`), con CFW 2.0.0 o posterior; compruébalo en `AppConf` de esta web, porque un CFW anterior lee solo `cfw/config.ini`: la configuración del entorno (`db.*`, `urlbase`, `desarrollo`…) se monta en solo lectura sobre `cfw/servidor.ini`, la capa de cada servidor, que no se versiona, y no sobre `cfw/config.ini`, que es de CFW. Ese archivo no existe en el proyecto, y Docker lo crearía como root: `.magents/scripts/antes-de-iniciar.sh` lo crea vacío antes de arrancar si no existe. `pathbase` no hace falta. Las carpetas donde la web escribe (`cfw/data/` y las de subidas) deben poder escribirse con el usuario del contenedor, y lo que las pruebas tengan que limpiar ahí, como `cfw/data/intentos`, va en `.magents/rutas-autorizadas.txt`, que solo edita el usuario.
- **Triage**: en qué carpeta va cada cambio; si hay ya una página, plantilla, texto o método del `Orm` que lo resuelva; si algún fichero de `specific` sustituye a uno de `general` implicado; qué idiomas tiene la web, para los textos nuevos; y si la URL nueva necesita regla en el `.htaccess`.
- **Desarrollo**: sigue «Trampas frecuentes» de `DESARROLLO.md`. Textos en los `.ini` de todos los idiomas, datos escapados según el contexto en que se pintan, como indica «Plantillas» de `DESARROLLO.md` (`escapar()` en texto y en atributos entre comillas; las URL, además, validadas por su esquema; nada en atributos de evento ni en `style`; `json_js()` sin comillas dentro de un `<script>`), `require_once` de lo nuevo.
- **Revisión de código**: además de lo habitual, que nada del núcleo haya cambiado (`git diff --stat <commit base> -- cfw/general index.php cfw/includes.php cfw/index.php`), y cada trampa de `DESARROLLO.md` sobre el diff.
- **Revisión de seguridad**: en cada página nueva o cambiada, quién puede llegar a cada método público, si el constructor llama a `exigirUsuario()` o `exigirAdmin()`, si lo que cambia datos exige POST, qué columnas puede escribir un `insert` o `update` con datos de la petición, y cada valor asignado a una plantilla sin escapar según su contexto («Plantillas» de `DESARROLLO.md`): `escapar()` no basta en una URL (`javascript:`), en un atributo sin comillas, en un atributo de evento ni dentro de un `<script>`. `Orm::filtro()` codifica al guardar, pero no protege lo que se pinta sin pasar por la BD ni lo que se guardó por otra vía.
- **Pruebas**: con sesión de administrador, de usuario normal y sin sesión en lo que tenga permisos, y un POST sin `csrf` en cada formulario nuevo. Para iniciar sesión sin navegador, sigue lo que indique `proyecto.md`: la contraseña viaja cifrada.

## Actualizar CFW o migrar una web a CFW

Si la tarea es llevar una web a la versión actual de CFW, sea desde un CFW anterior o desde PHP sin framework, lee `.claude/skills/cfw/migracion.md`.
