---
name: php-documentacion
description: Método para documentar las decisiones tomadas y los cambios realizados en una tarea PHP ya aprobada, basándose en los informes de cada fase y el diff real.
user-invocable: false
---

# Documentación de la tarea

Lee todos los informes de `.magents/tareas/<id>/` y contrástalos con `git diff <commit-base>` y `git status --porcelain`. Si un informe y el diff no coinciden, manda el diff y señala la diferencia. Documenta solo lo que ha ocurrido; no inventes motivos: si una decisión no tiene motivo registrado, dilo.

## Qué escribir

Solo dentro de `docs/`:

1. **`docs/tareas/<id>.md`**, siempre:

   ```markdown
   # <Título>
   Fecha · Commit base
   ## Qué se pidió
   ## Qué se hizo
   ## Archivos cambiados
   `ruta`: qué cambió
   ## Decisiones
   Decisión, alternativas descartadas, motivo
   ## Despliegue
   SQL a ejecutar, configuración, orden. "Nada" si no hay
   ## Verificación
   Qué se probó en Firefox y resultado
   ## Historial de iteraciones
   Rechazos: fase, motivo y corrección
   ## Riesgos y deuda pendiente
   Problemas preexistentes detectados, incluidos los de seguridad
   ```

2. **`docs/decisiones/NNNN-<slug>.md`**, solo si hay una decisión de arquitectura que afecte al futuro del proyecto (dependencia nueva, cambio de esquema importante, patrón nuevo). Formato: Contexto, Decisión, Consecuencias. Numera siguiendo lo que ya exista.

3. **`docs/CHANGELOG.md`**: añade una línea arriba con la fecha, un resumen y el enlace a la ficha. Créalo si no existe.

## Reglas

- Sin secretos ni datos personales. Describe las vulnerabilidades preexistentes indicando dónde y qué tipo, sin instrucciones de explotación.
- Si el proyecto ya documenta en otro lugar o formato, respétalo e indícalo.
- Breve: la ficha es para quien dentro de un año pregunte por qué se hizo así.

## Formato del informe

```markdown
# Documentación
## Archivos escritos
## Diferencias entre informes y diff

VEREDICTO: DOCUMENTADO | BLOQUEADO
```
