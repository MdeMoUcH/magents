# magents

Agentes de Claude Code para el desarrollo de webs en PHP. Cada tarea pasa por seis fases, cada una con su subagente y su skill:

```
triage → desarrollador → revisor-codigo → revisor-seguridad → probador → documentador
              ↑                 │                 │               │
              └──── RECHAZADO ──┴─────────────────┴───────────────┘
```

| Fase | Subagente | Skill | Permisos |
|---|---|---|---|
| Triage: analiza la tarea contra el código actual | `triage` | `php-triage` | Sin herramientas de edición |
| Desarrollo | `desarrollador` | `php-desarrollo` | Edición |
| Revisión de código | `revisor-codigo` | `php-revision-codigo` | Sin herramientas de edición |
| Revisión de seguridad | `revisor-seguridad` | `php-revision-seguridad` | Sin herramientas de edición |
| Pruebas en Firefox | `probador` | `php-pruebas-firefox` | Sin edición + MCP de Firefox |
| Documentación | `documentador` | `php-documentacion` | Edición, solo en `docs/` por instrucción |

La skill `/tarea` coordina el flujo. Tras un rechazo vuelve a desarrollo y repite las tres verificaciones en orden. Para en dos casos: si hay una duda para ti, o si no converge (5 iteraciones o el mismo problema dos veces seguidas).

Al terminar, los cambios quedan **sin confirmar** en el proyecto: los agentes no hacen commits, push ni despliegues.

## Requisitos

- [Claude Code](https://code.claude.com)
- Firefox
- Node.js 20.19 o superior, para el MCP de Firefox
- Docker, para el entorno de pruebas y `php -l` si no hay PHP en el equipo

## Instalación

```bash
./install.sh /ruta/al/proyecto
```

Copia `.claude/agents` y `.claude/skills` y añade `.magents/` al `.gitignore`. Volver a ejecutarlo actualiza esos agentes y skills, sin tocar los demás. Abre después Claude Code en el proyecto (o reinícialo) y acepta la confianza de la carpeta: sin ella no arranca el MCP de Firefox.

## Uso

```
/tarea Añadir un formulario de contacto que guarde los mensajes en la base de datos
```

La primera vez se crea `.magents/proyecto.md`. Conviene rellenarlo con la URL local, cómo arrancar el entorno, la versión de PHP de producción y la base de datos de prueba: el probador solo trabaja en local y se bloquea, en lugar de arriesgarse, si no puede confirmar que los datos son de prueba.

## Dónde queda cada cosa

| Ruta | Contenido | ¿En git? |
|---|---|---|
| `.magents/tareas/<id>/` | Estado e informes de cada fase e iteración | No |
| `.magents/proyecto.md` | Configuración del entorno | No |
| `docs/tareas/<id>.md` | Cambios y decisiones de la tarea | Sí |
| `docs/decisiones/` | Decisiones de arquitectura | Sí |
| `docs/CHANGELOG.md` | Historial de cambios | Sí |

## MCP de Firefox

`probador` define en su propia configuración el servidor oficial de Mozilla, [`@mozilla/firefox-devtools-mcp-moz`](https://firefox-source-docs.mozilla.org/ai-agent-tools/firefox-devtools-mcp.html), con la versión fijada. Solo se conecta durante las pruebas, con Firefox headless y un perfil temporal, y sin los módulos privilegiados. Quita `--headless` y sus valores en `.claude/agents/probador.md` si quieres ver el navegador.

La opción `--tools` es necesaria: el preset por defecto no incluye las herramientas de consola y red.

## Límite de carpeta

Los agentes solo trabajan dentro de la raíz del proyecto. Si necesitan algo de fuera, se bloquean y `/tarea` te pide permiso indicando la ruta y el motivo; el permiso vale solo para esa ruta, ese fin y esa tarea.

## Limitaciones

- El límite de carpeta es una instrucción, no un bloqueo técnico. Además, el MCP de Firefox y `npx` escriben por su cuenta sus registros, perfiles y caché en la carpeta personal (`~/.firefox-devtools-mcp/`, `~/.npm/`).

- Los permisos de solo lectura retiran las herramientas de edición, pero estos agentes conservan Bash: que no escriban con él depende de sus instrucciones, no de un bloqueo técnico.
- Si una sesión no se ejecuta en un modo que permita las acciones, Claude Code pedirá confirmación durante el flujo.
