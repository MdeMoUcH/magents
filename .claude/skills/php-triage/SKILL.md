---
name: php-triage
description: Método para analizar una tarea de una web PHP contra el código actual y convertirla en un plan con criterios de aceptación verificables.
user-invocable: false
---

# Triage de tareas PHP

Tu resultado es lo único que el desarrollador y los revisores sabrán de la tarea: tiene que bastarles sin volver a investigar.

## Pasos

1. **Entiende el stack real**, no lo supongas: versión de PHP (`composer.json`, Dockerfile, sintaxis usada), framework o MVC propio, servidor (`.htaccess`, configuración de Nginx), base de datos y capa de acceso (PDO, mysqli, ORM propio), plantillas, front-end, tests.
2. **Localiza el código implicado**: sigue el recorrido de la petición desde la ruta hasta el controlador, el modelo, la plantilla y el SQL. Lee los archivos; no te quedes en los nombres.
3. **Busca lo reutilizable**: helpers, clases y patrones existentes que resuelvan parte de la tarea.
4. **Identifica las convenciones**: idioma de nombres, indentación, estilo de etiquetas PHP, manejo de errores, traducciones.
5. **Mide el impacto**: quién más usa lo que se va a tocar, cambios de esquema, datos existentes. Si la tarea corrige un problema o crea un mecanismo, busca dónde más aparece ese problema o dónde debería aplicarse el mecanismo, y prevé las consecuencias del cambio, como una línea de log que puede repetirse, un mensaje o código de respuesta que cambia o un comportamiento que la documentación describe. Inclúyelo en el plan o ponlo en «Fuera de alcance», con el motivo: lo que la tarea deje a medias se convierte en otra tarea. Lee también `.magents/deuda.md`, si existe: sus puntos abiertos en el código afectado van en «Fuera de alcance» con su id, salvo que la tarea los pida.
6. **Revisa la documentación del proyecto**: cada archivo de «Documentación del proyecto» de `.magents/proyecto.md` y cualquier otro que describa lo que cambia. Si la tarea cambia requisitos, instalación, opciones de configuración, rutas, permisos, dependencias o un comportamiento que se explique en ellos, su actualización es parte del plan y tiene criterio de aceptación. Si `proyecto.md` no tiene esa sección, búscalos tú y señálalo en «Discrepancias con .magents/proyecto.md», con la lista que propones.
7. **Contrasta lo esperado**: cada texto, idioma, código HTTP, redirección o efecto sobre la sesión o los datos que un criterio dé como resultado, compruébalo en el código y en la configuración del entorno (`.magents/entorno/config/` y los archivos de datos), no en lo que suele hacer una web. Por ejemplo, el idioma que sale con la opción de idiomas del entorno, o si una página sin permiso cierra la sesión o solo redirige. Cita `ruta:línea` junto al criterio cuando no sea evidente.
8. **Detecta dudas**: pregunta solo lo que cambie la implementación y no se pueda deducir del código. Lo demás, decídelo y anótalo como supuesto.

## Proyectos antiguos

No propongas modernizar lo que no se pide. Respeta el estilo existente, aunque sea antiguo, y sugiere las mejoras aparte. Si el proyecto usa `<?` o `mysql_*`, indica si el código nuevo puede o no usar sintaxis moderna según la versión de PHP de producción. Si esa versión no se puede determinar y afecta a la tarea, es una duda.

## Tareas menores

Las tres verificaciones son la norma. Propón omitir una solo si **todo** el plan cumple su condición; ante la duda, ninguna:

- **Revisión de seguridad**: el plan solo cambia textos fijos, traducciones, estilos, imágenes, comentarios o documentación. No si toca código que lea entradas, consulte la BD, muestre datos o trate sesión, permisos, archivos, cabeceras o redirecciones; ni JavaScript, configuración, dependencias o el entorno; ni documentación que indique permisos, credenciales, configuración o comandos que alguien vaya a ejecutar.
- **Pruebas en Firefox**: el plan no cambia nada que la web sirva o ejecute: solo documentación, comentarios o archivos que no se sirven. Escribe entonces los criterios de aceptación para comprobarlos leyendo.

La revisión de código y la documentación no se omiten nunca. Lo decide el usuario, y la revisión de código confirma después con el diff que la condición se cumple; si no, la verificación se hace.

## Experimentos

Ejecutar da mejores planes que solo leer, y puedes hacerlo si cambia el plan: usa contenedores desechables, con el proyecto en solo lectura y `--network none` siempre que sea posible. No escribas en la BD de prueba: un login también escribe, porque actualiza datos del usuario. Si necesitas datos o escrituras, deja el experimento para el desarrollador o el probador. Declara en tu informe lo que hayas ejecutado y lo que quede en Docker.

## `.magents/proyecto.md`

Léelo, pero compruébalo contra el código. Si no coincide, por ejemplo en la versión de PHP o en la base de datos, señálalo en tu informe. Señala también si el entorno arranca con una versión de PHP distinta de la de producción. Si la tarea necesita algo que el entorno no tiene, como una extensión de PHP, señálalo como discrepancia e indica qué necesita y cómo comprobarlo, sin detallar la implementación: lo resuelve el preparador. Nunca propongas modificar `iniciar.sh`, `parar.sh` ni `reiniciar-bd.sh`: lo propio del proyecto va en `.magents/scripts/antes-de-iniciar.sh`.

## Formato del informe

```markdown
# Triage: <tarea>
## Entendimiento de la tarea
## Stack y convenciones relevantes
## Código afectado
`ruta:línea` y qué papel tiene
## Plan de implementación
Pasos concretos, archivo por archivo
## Criterios de aceptación
- [ ] CA1: comportamiento observable y comprobable en el navegador, o leyendo el resultado si propones omitir las pruebas
(en la versión de PHP con la que arranca el entorno; pide otras solo si la tarea lo hace de forma expresa o si el cambio usa funciones cuyo comportamiento o firma cambian entre la versión mínima de producción y la del entorno; en ese caso, solo para los criterios afectados y con el motivo escrito junto al criterio. Tampoco repitas tus experimentos en varias versiones sin uno de esos motivos. Si un criterio usa un `confirm`, indica que se probará sustituyéndolo con clic real, y usa los «Métodos de prueba aceptados» de `proyecto.md`)
## Necesidades de prueba
(siempre: lo que las pruebas necesitan más allá de navegar por la web con la BD de prueba y los usuarios de `proyecto.md`, como otra versión de PHP, parar un servicio, datos, usuarios o archivos especiales, pruebas por CLI o con `docker run`, o un método que no esté en «Métodos de prueba aceptados», cada uno con lo que hay que comprobar antes de desarrollar; o «Ninguna». Si quieres una referencia del estado anterior, como capturas antes de un cambio visual, inclúyela aquí)
## Verificaciones que se pueden omitir
(siempre: «Ninguna», o la revisión de seguridad, las pruebas en Firefox o ambas, cada una con el motivo según «Tareas menores»)
## Documentación del proyecto
(siempre: cada archivo de «Documentación del proyecto» de `proyecto.md`, y los demás que afecte la tarea, con qué cambia y dónde, o «Nada» y por qué)
## Fuera de alcance
(siempre: lo relacionado que el plan no incluye, como el mismo problema en otros sitios, consecuencias del cambio o puntos abiertos de `.magents/deuda.md` en el código afectado, cada uno con `ruta:línea`, el id de deuda si lo tiene, por qué queda fuera y lo que costaría incluirlo; o «Nada»)
## Borrados
(solo si los hay: ruta exacta de cada archivo o carpeta del proyecto, y por qué; el usuario los verá antes de desarrollar)
## Casos límite y riesgos
Incluye los puntos sensibles para seguridad: entradas, permisos, datos
## Supuestos
## Discrepancias con .magents/proyecto.md
(solo si las hay)
## Dudas
(solo si las hay: pregunta, por qué importa, opciones y tu recomendación)
## Comandos que declarar
(«Ninguno», o cada uno según «Comandos que declarar» de `magents-normas`)

VEREDICTO: LISTO | DUDAS | BLOQUEADO
```

Usa `DUDAS` solo si no se puede hacer un plan fiable sin la respuesta.

Este informe lo leen todas las fases: mantenlo en lo que necesitan para trabajar. Si un inventario largo o los detalles de tus experimentos no caben en pocas líneas, déjalos en `informes/triage-anexo.md`, escrito con `Bash`, y resume aquí su conclusión y su ruta.
