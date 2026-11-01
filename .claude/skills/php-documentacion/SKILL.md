---
name: php-documentacion
description: Método para documentar las decisiones tomadas y los cambios realizados en una tarea PHP ya aprobada, basándose en los informes de cada fase y el diff real.
user-invocable: false
---

# Documentación de la tarea

Lee todos los informes de `.magents/tareas/<id>/informes/` y contrástalos con `git diff <commit-base>` y `git status --porcelain`. Excluye los cambios previos de `informes/cambios-previos.diff`, si existe. Si un informe y el diff no coinciden, manda el diff y señala la diferencia. Los cambios en `.magents/entorno/` no aparecen en el diff: compruébalos en sus archivos. Documenta solo lo que ha ocurrido; no inventes motivos: si una decisión no tiene motivo registrado, dilo.

## Qué escribir

Solo dentro de `.magents/`, que git ignora. No modifiques `informes/` ni `despliegue/`.

1. **`.magents/tareas/<id>/README.md`**, siempre. Si hace falta conservar otra información, va en `anexos/`, junto a la ficha.

   ```markdown
   # <Título>
   Fecha · Commit base
   ## Qué se pidió
   ## Qué se hizo
   ## Archivos cambiados
   `ruta`: qué cambió
   ## Decisiones
   Decisión, alternativas descartadas, motivo
   ## Cambios de entorno
   Qué cambió en `.magents/entorno/` y si producción también lo necesita. "Nada" si no hay
   ## Despliegue
   SQL y scripts de `despliegue/`, configuración, orden, cuándo ejecutar cada uno y cómo revertirlo. "Nada" si no hay
   ## Verificación
   Qué se probó en Firefox y resultado
   ## Historial de iteraciones
   Rechazos: fase, motivo y corrección
   ## Riesgos y deuda pendiente
   Problemas preexistentes detectados, incluidos los de seguridad
   ```

2. **`.magents/decisiones/NNNN-<slug>.md`**, solo si hay una decisión de arquitectura que afecte al futuro del proyecto (dependencia nueva, cambio de esquema importante, patrón nuevo). Formato: Contexto, Decisión, Consecuencias. Numera siguiendo lo que ya exista.

3. **`.magents/CHANGELOG.md`**: añade una línea arriba con la fecha, el id, un resumen y el enlace a la ficha. Créalo si no existe.

## Reglas

- Sin secretos ni datos personales, tampoco en las capturas: mira cada una de `capturas/`, borra las que los muestren e indícalo en tu informe. Describe las vulnerabilidades preexistentes indicando dónde y qué tipo, sin instrucciones de explotación.
- No toques la documentación propia del proyecto. Si habría que actualizarla, indícalo en tu informe.
- Breve: la ficha es para quien dentro de un año pregunte por qué se hizo así.

## Formato del informe

```markdown
# Documentación
## Archivos escritos
## Diferencias entre informes y diff

VEREDICTO: DOCUMENTADO | BLOQUEADO
```
