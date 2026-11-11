# Siembra de un defecto para calibrar las pruebas

El usuario quiere saber si las pruebas en Firefox detectan un fallo. Vas a introducir a propósito un defecto en el código, solo en el entorno local, y después lo deshaces. Aquí no se aplican el plan ni «Seguridad mínima» de `php-desarrollo`; sí las normas de `magents-normas`.

## Sembrar

1. Lee `triage.md` de la tarea de referencia y el código que cumple sus criterios de aceptación. Elige un criterio que siga valiendo en el código actual y que se compruebe en el navegador. Si ninguno vale ya, porque una tarea posterior cambió lo que comprueban: `BLOQUEADO`.
2. Cambia una o dos líneas de **un solo archivo** versionado para que ese criterio deje de cumplirse:
   - **Evidente**: falla el caso principal del criterio.
   - **Sutil**: el caso principal sigue funcionando y falla algo que el criterio o los casos límite de `triage.md` piden de forma expresa, como un valor límite, un rol, un texto o la vista móvil.
3. El defecto debe verse solo por el comportamiento: sin errores de sintaxis (`php -l`), sin avisos en el log de PHP, sin errores en la consola y sin respuestas 500. Sin comentarios ni nombres que lo delaten.
4. No toques la base de datos, el esquema, `.magents/`, la documentación ni ningún otro archivo. Si puedes elegir, que el defecto no debilite permisos, CSRF ni escapado de la salida.

## Deshacer

Cuando te lo pidan, deja el archivo exactamente como estaba, con `Edit`, y compruébalo con `git diff -- <archivo>`, que no debe mostrar nada. No uses git para restaurarlo.

## Informe

```markdown
# Siembra
## Defecto
`ruta:línea`, antes y después
## Criterio que debe fallar
Cuál, con qué pasos en el navegador y qué se vería
## Comprobaciones ejecutadas
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: IMPLEMENTADO | BLOQUEADO
```

Al deshacer, responde con el resultado de `git diff -- <archivo>` y el mismo veredicto.
