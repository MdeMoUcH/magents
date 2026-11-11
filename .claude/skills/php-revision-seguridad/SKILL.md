---
name: php-revision-seguridad
description: Método para auditar la seguridad del código PHP generado siguiendo el flujo de datos desde las entradas hasta los puntos peligrosos, con veredicto APROBADO o RECHAZADO.
user-invocable: false
---

# Revisión de seguridad PHP

Audita el código analizándolo: no lances ataques contra ningún sistema. Si encuentras secretos, indica el archivo y la línea, pero **no copies su valor** en el informe.

## Método

1. Obtén el cambio con `git diff <commit-base>` y `git status --porcelain`, incluidos los archivos nuevos. Excluye los cambios previos anotados en `estado.md` e `informes/cambios-previos.diff`. Audita además `.magents/tareas/<id>/despliegue/`, si existe, porque git la ignora: no debe contener secretos. Audita también lo cambiado en `.magents/entorno/` y `.magents/scripts/` (`find .magents/entorno .magents/scripts -type f -newer .magents/tareas/<id>/informes/triage.md`), que git también ignora: puertos solo en `127.0.0.1`, sin secretos, sin conexiones a producción y sin montar nada fuera del proyecto.
2. Lista las **entradas** que toca: `$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, `$_FILES`, `$_SERVER`, `php://input`, argumentos de URL reescrita y datos de la BD escritos por usuarios.
3. Sigue cada entrada **a través de las funciones**, también en el código existente, hasta llegar a un punto peligroso. Comprueba si la defensa es la adecuada para ese contexto.
4. Comprueba quién puede llegar a cada ruta nueva o modificada.

## Qué buscar

| Categoría | Puntos a revisar |
|---|---|
| Inyección SQL | Concatenación o interpolación; `ORDER BY`/columnas sin lista blanca; `addslashes`; casting olvidado; ORM propio que concatena |
| XSS | `echo` sin escapar; contexto incorrecto (atributo, JS, URL `javascript:`); `ENT_QUOTES` ausente; XSS almacenado |
| Ejecución / inclusión | `eval`, `assert`, `preg_replace /e`, `exec`, `shell_exec`, `system`, `passthru`, `include` con variables, `unserialize` de datos del usuario, llamadas dinámicas `$clase->$metodo()` |
| Control de acceso | Autenticación ausente; IDOR (el recurso no se comprueba contra el usuario); escalada de rol; asignación masiva; ruta `admin` que solo se protege en el menú |
| CSRF | Cambios de estado por GET; POST sin token; comparación sin `hash_equals` |
| Sesión y credenciales | `md5`/`sha1`/sin sal en contraseñas; falta de `session_regenerate_id` al iniciar sesión; cookies sin `HttpOnly`/`Secure`/`SameSite`; tokens con `rand`/`uniqid`; enumeración de usuarios; sin límite de intentos |
| Comparaciones | `==` con hashes o tokens (magic hashes `0e...`) |
| Archivos | Path traversal; subida de ejecutables; confiar en `$_FILES['type']` o la extensión; archivos sensibles accesibles desde la web (`.ini`, `.sql`, copias de seguridad) |
| Peticiones y redirecciones | SSRF con URL del usuario; redirección abierta; inyección de cabeceras o de correo; XXE |
| Exposición | Secretos en el código; `display_errors` en producción; depuración; datos personales en logs |
| Dependencias | `composer audit` si se ha añadido o cambiado alguna |

## Criterio

Cada hallazgo debe tener una vía de explotación concreta dentro del código.

- **Bloqueante** (`RECHAZADO`): vulnerabilidad explotable introducida o modificada por el cambio, o preexistente en una vía que el cambio expone más o sobre la que se apoya directamente la funcionalidad nueva (por ejemplo, una función nueva que depende de una consulta del ORM que concatena).
- **Del cambio**: vía de explotación concreta pero no bloqueante (gravedad baja, condiciones poco probables) en lo que crea o modifica la tarea, o en el mismo patrón que corrige en otro sitio. No bloquea, pero se recomienda corregirla en esta tarea, porque si no se convierte en otra. Si ya figura en «Fuera de alcance» de `triage.md`, no la repitas.
- **Preexistente**: vulnerabilidad ajena al cambio. **No bloquea**, pero se informa siempre con su gravedad, porque el usuario debe conocerla, y pasa a `.magents/deuda.md`. Si ya está allí, cita su id y no la describas de nuevo.
- **Endurecimiento**: mejora defensiva sin vía de explotación. No bloquea, no pasa a la deuda y no se recomienda aplicar: es una nota. Anota solo los que protejan lo que crea o modifica la tarea, en una línea cada uno y sin buscar más allá.

Una herramienta que no se ha podido ejecutar se declara en el informe. No afirmes que algo es seguro si no lo has seguido hasta el final.

## Formato del informe

```markdown
# Revisión de seguridad (iteración n)
## Superficie analizada
Entradas y rutas seguidas
## Bloqueantes
- [Gravedad] `ruta:línea` categoría (CWE). Vía de explotación: origen → destino. Corrección.
## Del cambio
## Preexistentes
## Endurecimiento
## Lo que no se pudo verificar
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: APROBADO | RECHAZADO | BLOQUEADO
```
