---
name: php-revision-codigo
description: "Método para revisar código PHP generado: cumplimiento del plan, errores de lógica, integración, convenciones y mantenibilidad, con veredicto APROBADO o RECHAZADO."
user-invocable: false
---

# Revisión de código PHP

Revisa con independencia: el informe del desarrollador dice qué pretendía hacer, no lo que hace realmente.

## Qué ver

`git diff <commit-base>` y `git status --porcelain` (lee también los archivos nuevos sin seguimiento). Lee además `.magents/tareas/<id>/despliegue/`, si existe, y lo cambiado en `.magents/entorno/` y `.magents/scripts/` (`find .magents/entorno .magents/scripts -type f -newer .magents/tareas/<id>/informes/triage.md`): git las ignora, así que no aparecen ahí, y `iniciar.sh`, `parar.sh` y `reiniciar-bd.sh` no se pueden modificar. Excluye los cambios previos anotados en `estado.md` y `informes/cambios-previos.diff`. Lee los archivos completos cuando el contexto importe y comprueba a quién afecta cada cambio.

## Revisión incremental

Si el prompt te da tu informe anterior y un delta (`informes/delta-<m>-<n>.diff`: lo que ha cambiado el código desde la iteración `m`, la última que revisaste), no repitas la revisión entera:

1. Comprueba en el código actual cada bloqueante del informe que rechazó, sea tuyo o de otra fase, y que el arreglo no se limita al caso señalado.
2. Revisa el delta con todo lo de «Qué comprobar»: lee completos los archivos que toca y comprueba a quién afecta cada cambio, también en lo que ya habías aprobado.
3. Lo que el delta no toca ni afecta ya está revisado: no lo repitas. Copia de tu informe anterior los puntos no bloqueantes que sigan vigentes, para que este informe esté completo sin el anterior.
4. Vuelve a comprobar los pasos y criterios del plan a los que afecta el delta y, si hay verificaciones omitidas, su condición sobre el diff completo. `php -l`, solo en los archivos del delta; los tests, enteros.

Lo cambiado en `.magents/entorno/`, `.magents/scripts/` y `despliegue/` no está en el delta: míralo siempre. Haz la revisión completa si no hay delta, si rehace el planteamiento o toca más de la mitad de lo que ha cambiado la tarea, o si dudas de que tu informe anterior siga valiendo. Indica en «Alcance» cuál has hecho. El veredicto vale para el cambio entero.

## Qué comprobar

1. **Plan**: cada paso y criterio de aceptación de `triage.md` está implementado, no hay nada ajeno a la tarea y no se ha tocado ninguna ruta prohibida en `.magents/proyecto.md`.
2. **Lógica**: condiciones invertidas, casos límite, `null`, comparaciones `==` problemáticas (`0 == "a"`, `in_array` sin modo estricto), datos vacíos, errores de BD sin tratar.
3. **Integración**: llamadas con la firma correcta, rutas y `.htaccess`, nombres de campos que coinciden entre el formulario, el PHP y el SQL, plantillas, traducciones, migración incluida.
4. **Compatibilidad**: sintaxis y funciones disponibles en la versión de PHP de producción; `php -l` en los archivos cambiados, como indica «`php -l`» de `magents-normas`.
5. **Rendimiento evidente**: N+1, consultas sin límite sobre tablas grandes.
6. **Convenciones**: encaja con el código de alrededor, reutiliza lo existente, sin depuración ni código muerto, y cumple «Estilo» de `magents-normas`. En un archivo que ya mezcla tabuladores y espacios no sugieras reformatear.
7. **Documentación del proyecto**: están hechos los cambios de «Documentación del proyecto» de `triage.md`, y ningún archivo de esa lista, ni otro que lo explique, contradice lo que hace ahora el código (requisitos, opciones, rutas, permisos, comportamiento). Un cambio de documentación del plan sin hacer, o un documento que queda contradiciendo al código, es bloqueante. Lo que solo mejoraría la redacción es sugerencia.
8. **Tests**: ejecuta los definidos en `.magents/proyecto.md`, si los hay. Si necesitas confirmar un bloqueante con escrituras, puedes hacerlo en el entorno local y restablecer la BD al terminar con el comando de `proyecto.md`, volviendo a aplicar los pasos adicionales de desarrollo.
9. **Verificaciones omitidas**: si el prompt indica que en esta tarea se omite la revisión de seguridad o las pruebas, comprueba con el diff completo, no con el plan, que se cumple su condición de «Tareas menores» de `.claude/skills/php-triage/SKILL.md`. Si se omiten las pruebas, comprueba tú cada criterio de aceptación leyendo el resultado. Responde en «Verificaciones omitidas». Que una condición no se cumpla no es un rechazo: `/tarea` hará esa verificación.

La seguridad la audita la fase siguiente; si ves algo evidente, anótalo igualmente.

## Criterio

- **Bloqueante**: fallo real con un escenario concreto, criterio de aceptación incumplido, rotura de código existente, documentación del proyecto que contradice al código, o incumplimiento de la norma de comentarios. → `RECHAZADO`
- **Del cambio**: algo que la tarea deja a medias sin incumplir ningún criterio, sobre lo que crea o modifica o como consecuencia directa: el mismo problema que corrige en otro sitio, un mecanismo nuevo que otra página debería usar, una línea de log que puede crecer sin límite o un texto que queda desfasado. Lleva su escenario. No bloquea, pero se recomienda hacerlo en esta tarea, porque si no se convierte en otra. Si ya figura en «Fuera de alcance» de `triage.md`, no lo repitas.
- **Sugerencia**: mejora opcional sin escenario de fallo, incluida la indentación, que por sí sola no merece una iteración. No bloquea; si hay otra iteración, el desarrollador la corrige.
- **Preexistente**: problema que ya estaba y que el cambio no empeora, con su escenario y su gravedad (alta, media o baja). Se anota, no bloquea, y pasa a `.magents/deuda.md`. Si ya está allí, cita su id y no lo describas de nuevo. Una mejora ajena al cambio sin escenario de fallo no es un preexistente: no la anotes.

No bloquees por gustos. Verifica cada hallazgo en el código antes de incluirlo. Si un hallazgo anterior fue discutido por el desarrollador, evalúa su argumento y resuelve.

## Formato del informe

```markdown
# Revisión de código (iteración n)
## Alcance
Completa, o incremental desde la iteración m (`delta-<m>-<n>.diff`)
## Bloqueantes
- `ruta:línea`: problema. Escenario: entrada → resultado incorrecto. Corrección sugerida.
## Del cambio
## Sugerencias
## Preexistentes
## Verificaciones omitidas
(solo si el prompt indica alguna: cada una con «Condición cumplida», o «No se cumple», con `ruta:línea` y lo que toca)
## Comprobaciones ejecutadas
Comando y resultado real
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: APROBADO | RECHAZADO | BLOQUEADO
```
