---
name: php-revision-codigo
description: "Método para revisar código PHP generado: cumplimiento del plan, errores de lógica, integración, convenciones y mantenibilidad, con veredicto APROBADO o RECHAZADO."
user-invocable: false
---

# Revisión de código PHP

Revisa con independencia: el informe del desarrollador dice qué pretendía hacer, no lo que hace realmente.

## Qué ver

`git diff <commit-base>` y `git status --porcelain` (lee también los archivos nuevos sin seguimiento). Lee además `.magents/tareas/<id>/despliegue/`, si existe, y lo cambiado en `.magents/entorno/` y `.magents/scripts/` (`find .magents/entorno .magents/scripts -type f -newer .magents/tareas/<id>/informes/triage.md`): git las ignora, así que no aparecen ahí, y `iniciar.sh`, `parar.sh` y `reiniciar-bd.sh` no se pueden modificar. Excluye los cambios previos anotados en `estado.md` y `informes/cambios-previos.diff`. Lee los archivos completos cuando el contexto importe y comprueba a quién afecta cada cambio.

## Qué comprobar

1. **Plan**: cada paso y criterio de aceptación de `triage.md` está implementado, no hay nada ajeno a la tarea y no se ha tocado ninguna ruta prohibida en `.magents/proyecto.md`.
2. **Lógica**: condiciones invertidas, casos límite, `null`, comparaciones `==` problemáticas (`0 == "a"`, `in_array` sin modo estricto), datos vacíos, errores de BD sin tratar.
3. **Integración**: llamadas con la firma correcta, rutas y `.htaccess`, nombres de campos que coinciden entre el formulario, el PHP y el SQL, plantillas, traducciones, migración incluida.
4. **Compatibilidad**: sintaxis y funciones disponibles en la versión de PHP de producción; `php -l` en los archivos cambiados (con `docker run --rm --name <prefijo>-tmp-lint -v "$PWD":/app:ro -w /app php:<versión>-cli` si no hay PHP en el host; el prefijo, en «Docker» de `magents-normas`).
5. **Rendimiento evidente**: N+1, consultas sin límite sobre tablas grandes.
6. **Convenciones**: encaja con el código de alrededor, reutiliza lo existente, sin depuración ni código muerto.
   - Indentación con tabuladores en archivos nuevos y en los que ya los usan, salvo en formatos que no los admiten, como YAML; en un archivo existente con espacios se mantienen los espacios, sin mezclar ni reformatear; en uno que ya mezcla ambos, lo nuevo sigue el estilo de las líneas de alrededor y no se sugiere reformatear.
   - Comentarios breves, que nunca ocupen más que el código al que acompañan y normalmente mucho menos.
7. **Tests**: ejecuta los definidos en `.magents/proyecto.md`, si los hay. Si necesitas confirmar un bloqueante con escrituras, puedes hacerlo en el entorno local y restablecer la BD al terminar con el comando de `proyecto.md`, volviendo a aplicar los pasos adicionales de desarrollo.

La seguridad la audita la fase siguiente; si ves algo evidente, anótalo igualmente.

## Criterio

- **Bloqueante**: fallo real con un escenario concreto, criterio de aceptación incumplido, rotura de código existente, o incumplimiento de la norma de comentarios. → `RECHAZADO`
- **Sugerencia**: mejora opcional, incluida la indentación, que por sí sola no merece una iteración. No bloquea; si hay otra iteración, el desarrollador la corrige.
- **Preexistente**: problema que ya estaba y que el cambio no empeora. Se anota, no bloquea.

No bloquees por gustos. Verifica cada hallazgo en el código antes de incluirlo. Si un hallazgo anterior fue discutido por el desarrollador, evalúa su argumento y resuelve.

## Formato del informe

```markdown
# Revisión de código (iteración n)
## Bloqueantes
- `ruta:línea`: problema. Escenario: entrada → resultado incorrecto. Corrección sugerida.
## Sugerencias
## Preexistentes
## Comprobaciones ejecutadas
Comando y resultado real

VEREDICTO: APROBADO | RECHAZADO | BLOQUEADO
```
