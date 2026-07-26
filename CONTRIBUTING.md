# Contribuir

Gracias por pasarte. Este repositorio es el código de **mi web personal**, no
una librería pensada para que la usen terceros, así que las expectativas son un
poco distintas a las de un proyecto al uso. Aquí están, para que nadie invierta
tiempo en algo que no voy a poder integrar.

## Has encontrado un fallo de seguridad

**No abras una issue.** Una issue es pública desde el momento en que se envía, y
eso expone el problema antes de que exista un arreglo.

Usa cualquiera de estos dos canales:

- [Aviso de seguridad privado en GitHub](https://github.com/eduolihez/eduolihez.com/security/advisories/new)
- Lo que indica [`/.well-known/security.txt`](https://eduolihez.com/.well-known/security.txt) (RFC 9116)

Respondo en un plazo de 48 horas. Está todo detallado en [`SECURITY.md`](SECURITY.md).

## Has encontrado un fallo normal

Abre una issue con la plantilla de *Fallo en la web*. Lo que más ayuda es la
**URL exacta** (con el idioma) y, si sabes sacarlos, los errores de la consola
del navegador. Buena parte de la web se pinta desde una API en PHP, así que un
error de red en la consola suele señalar el problema directamente.

## Quieres proponer un cambio

Las pull requests son bienvenidas para **correcciones**: un error de traducción,
un enlace roto, un problema de accesibilidad, una cabecera mal puesta. Ese tipo
de cosas las agradezco de verdad.

Para **cambios de diseño o de contenido** te pido que abras antes una issue. No
es por controlar: es que las decisiones visuales y los textos son míos y muy
probablemente diga que no, y prefiero decírtelo antes de que escribas el código
y no después.

### Si envías una PR

- Que el `npm run build` pase.
- Un cambio por PR. Es mucho más fácil de revisar y de revertir si hace falta.
- Explica **por qué**, no solo qué. El *qué* ya se ve en el diff.
- Los comentarios del código están en castellano y explican decisiones, no
  sintaxis. Si tocas algo con un motivo detrás, déjalo escrito.

## Levantar el proyecto

Está en el [README](README.md#puesta-en-marcha). Un aviso que ahorra
confusión: en local **no hay PHP**, así que los proyectos, las certificaciones y
el blog mostrarán su mensaje de error. Es lo esperado, no un fallo que hayas
provocado tú.

## Licencia

El código va bajo [MIT](LICENSE). El contenido personal (textos, fotografías, CV
y los PDF de las certificaciones) queda fuera de esa licencia. Al enviar una
contribución aceptas que se publique bajo los mismos términos.
