# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/),
y el versionado usa cuatro números (`MAJOR.MINOR.PATCH.MICRO`).

## [1.7.0.0] - 2026-09-06

Multi-project dashboard (`admin.eduolihez.com`) e ingesta de telemetría
(`api.eduolihez.com`), diseñado con `/office-hours` + `/plan-eng-review`
(ver `docs/designs/admin-dashboard.md`). Entrega 1 (funcional) + Entrega 2
(re-skin visual del resto de `/admin`).

### Added

- **Registro de apps** (`apps` + `app_events` en `database/schema.sql`,
  `server/admin/apps.php` + `app-edit.php`): cada proyecto (eduolihez.com,
  y los que vengan después) tiene su propia fila, clave de API (hasheada
  con SHA-256, solo se enseña una vez al generarla/rotarla) y lista de
  orígenes permitidos.
- **`server/api/events.php`**: endpoint de ingesta (`POST /events.php`) para
  que otros proyectos manden telemetría — auth por clave de API, validación
  de Origin como defensa en profundidad, deduplicación por `event_id`,
  rate-limit por IP y por clave, purga probabilística a 400 días.
- **`admin.eduolihez.com`**: selector de apps en la barra lateral del panel
  y `server/admin/analytics.php` filtrable por `?app=<slug>`, para que cada
  app vea sus propios datos. El enrutado real vive en un Worker de
  Cloudflare (ver `CLOUDFLARE.md` §5) — CDMON no soporta subdominios sin
  darlos de alta en su propio panel, así que el Worker reescribe la
  petición en el borde hacia la ruta que ya funciona en producción.
- **Re-skin visual** (Entrega 2): tema claro, minimal, tipo Linear/Vercel,
  deliberadamente distinto del portfolio público y del panel oscuro
  original. Extraído a un bloque `.subdash` compartido en
  `server/admin/partials/layout.php` para que cada página de `/admin` lo
  reutilice sin duplicar CSS. La barra lateral y la topbar se quedan
  oscuras a propósito (continuidad de navegación). Aplicado a todas las
  páginas del panel; `login.php` y `setup.php` (documentos aislados)
  llevan su propia versión del mismo tema.

### Fixed

- Dos sitios pintaban texto sobre un fondo del color equivocado bajo el
  tema claro (`style="background:var(--bg)"` en el mensaje citado de
  `messages.php`, y `var(--soft)` en miniaturas de `certifications.php` /
  `posts.php` / `post-edit.php`) — reemplazados por las clases `.card.inset`
  y `.soft-box`, que sí reaccionan al re-skin por página.

## [1.6.0.7] - 2026-09-04

Auditoría SEO completa (10 agentes en paralelo: técnico, contenido, schema,
sitemap, rendimiento, visual, GEO, Google APIs, backlinks, SXO) y arreglo de
todos los hallazgos accionables desde el propio repositorio.

### Fixed

- **Blog (`/blog/`) renderizado en build-time en vez de client-side.** Causaba
  CLS crítico (0.374 móvil / 0.762 escritorio) y era invisible para
  rastreadores sin JavaScript (GPTBot, ClaudeBot, PerplexityBot). Ahora usa el
  mismo patrón que `BlogPreview.astro`: `fetchAllPostSummaries()` en build-time
  (`src/pages/blog/index.astro`), con el filtro por etiqueta ya no reconstruye
  las tarjetas, solo muestra/oculta las que ya están en el HTML
  (`initStaticBlogFilters()` en `src/scripts/blog.ts`).
- **Imágenes de portada del blog sin `width`/`height`.** Añadido
  `width="1200" height="630"` + `aspect-ratio` explícito (misma proporción que
  genera `src/lib/cover.ts`), eliminando el resto del CLS y el recorte de
  texto en las miniaturas.
- **Proyectos y certificaciones invisibles sin JavaScript.** `<Projects />` y
  `<Certifications />` ahora traen un primer pintado real en build-time
  (`src/lib/projects.ts`, `src/lib/certifications.ts`, con reintento y fallo
  suave vía `src/lib/buildFetch.ts`) que el script cliente sustituye al
  cargar, igual que ya hacía el blog.
- **Blog EN/CA oculto hasta que haya contenido real.** El enlace "Blog" ya no
  aparece en cabecera/pie para EN/CA (`Header.astro`, `Footer.astro`), y
  `/en/blog/` + `/ca/blog/` redirigen a la home de su idioma
  (`server/.htaccess`) en vez de mostrar un listado vacío.
- **Dos subdominios de proyectos retirados devolvían 521** desde julio
  (`mesbadalona.eduolihez.com`, `passwdcentinel.eduolihez.com`) — uno de ellos
  la página más clicada del dominio, ya desindexada por Google. Arreglado con
  dos Redirect Rules 301 en Cloudflare (ver `CLOUDFLARE.md`).
- **Fechas de experiencia laboral no eran ISO 8601** en el JSON-LD
  (`OrganizationRole.startDate`/`endDate`). Añadidos `startDateISO`/
  `endDateISO` reales en `src/data/experience.ts`, usados en `Seo.astro`.
- **CV**: el modal de "en actualización" ahora también ofrece contacto directo
  por email, no solo LinkedIn (`Hero.astro`, `src/i18n/ui.ts`).
- **Cabecera se rompía en tablet (768px)**: el selector de idioma podía
  desaparecer por falta de margen. El punto de corte a navegación móvil sube
  de `md` (768px) a `lg` (1024px) (`Header.astro`).
- **Contraste de color insuficiente** en texto terciario (footer, fechas):
  `--color-text-faint` de `#78849a` a `#8e99ad` (`src/styles/global.css`).
- **Selector de idioma sin nombre accesible claro** para lectores de
  pantalla: el `aria-label` ("Idioma") no incluía el texto visible ("ES") —
  ahora sí (`Header.astro`).

### Changed

- `sitemap.xml` ya no emite `priority`/`changefreq` (Google los ignora desde
  hace años) y calcula `lastmod` desde el último commit real que tocó los
  archivos de cada página (`gitLastMod()` en `src/pages/sitemap.xml.ts`), en
  vez de la fecha del build en cada URL.
- `/blog/` ya no comparte grupo de hreflang con `/en/blog/`/`/ca/blog/` en el
  sitemap (esas rutas ahora redirigen, no sirven contenido equivalente).
- CSS del sitio (~12KB) ahora se inserta inline en el HTML
  (`inlineStylesheets: 'always'` en `astro.config.mjs`) en vez de servirse
  como `<link>` externo que bloqueaba el primer render.
- El HTML estático envía `charset=utf-8` en la cabecera HTTP, no solo en el
  `<meta>` (`server/.htaccess`).

### Removed

- Sitemap HTTP obsoleto (`http://eduolihez.com/sitemap.xml`, sin enviar desde
  noviembre de 2025) eliminado de Search Console.

## [1.6.0.0] - 2026-09-01

### Added

- Nueva entrada en Experiencia: el rol actual (SOC / Cybersecurity Analyst en
  Dagram) ya describía "automatización de informes en Python" sin enlazarlo a
  nada. Se añade un campo `link` opcional en `Experience`
  (`src/data/experience.ts` + `src/components/Experience.astro`) y se usa
  para apuntar al repositorio público recién publicado del generador de
  informes ([vision-one-crem-report-generator](https://github.com/eduolihez/vision-one-crem-report-generator)).
- `database/schema.sql`: migración idempotente (mismo patrón que las
  ampliaciones ya existentes de `projects`/`certifications`) que añade el
  proyecto **CREM Report Generator**, enlaza el post ya publicado
  *"Automatizar el informe semanal del SOC con Python"* al repositorio, y
  suma 4 artículos nuevos al blog: priorización de CVEs (NVD/KEV/EPSS),
  checklist de hardening de FortiGate, un post de carrera (soporte → SOC) y
  checklist de hardening de Active Directory. Como el blog y los proyectos
  viven en MySQL y no en el build, este archivo no se aplica solo: hay que
  reimportarlo por phpMyAdmin contra la base de datos de producción para que
  el contenido nuevo aparezca en la web.

## [1.5.0.0] - 2026-08-25

### Security

- Cerrado un fallo real en la validación de URLs de los formularios de
  `/admin` (logo/imagen/repo/demo/tienda/credencial) y en el equivalente del
  frontend público (`safeUrl()`): un valor como `/\evil.example/x` empezaba
  por `/` y pasaba el check, pero los navegadores tratan `\` como `/` al
  interpretar una URL con esquema http(s) — compatibilidad heredada de
  Internet Explorer, parte del propio estándar WHATWG URL — así que se
  resolvía como `//evil.example/x`: un dominio externo, no una ruta interna.
  Una segunda ronda de revisión encontró una variante del mismo problema con
  tabuladores/saltos de línea incrustados en la URL (`/\t/evil.example/x`),
  que el navegador también reduce a `//evil.example/x` aunque el texto no
  contenga `\` ni `//` de forma literal. Corregido en los dos sitios, con
  tests que fijan el comportamiento para ambas variantes.
- El modo "reemplazar todo" de la copia de seguridad (`/admin/backup.php`)
  exige ahora escribir `BORRAR` en un campo de confirmación además de subir
  el archivo — antes, un envío accidental del formulario ya bastaba para
  vaciar y reimportar toda la base de datos.
- La regla de esquema de URL (antes copiada tres veces, una por formulario)
  vive ahora en un único sitio (`server/lib/validate.php`), para que futuras
  correcciones no se apliquen a un formulario sí y a otro no.

### Added

- Primera suite de tests de PHP del proyecto (PHPUnit), cubriendo la
  limpieza de texto del blog para IA (`llms-blog.php`) y la validación de
  URLs de `/admin` — ver `TESTING.md`. Instalación e infraestructura
  separadas de los tests de TypeScript (`npm test`), sin CI todavía: hay que
  correr `composer install && composer test` una vez en una máquina con PHP
  8.1+ para confirmar que la suite pasa de verdad (se escribió sin intérprete
  de PHP a mano en esta sesión).
- Cobertura de tests ampliada en Proyectos y Certificaciones: apertura/cierre
  de modal, los 5 filtros por categoría, drill-down de emisor con migas de
  pan, y paginación ("cargar más").

### Fixed

- `fetchWithRetry()` (usado por Blog, Proyectos y Certificaciones al cargar
  datos) podía reintentar más veces de las configuradas si el fallo persistía
  en todos los intentos, por un `.catch()` duplicado en la cadena de
  reintentos.
- El listener de tecla Escape para cerrar el modal de Proyectos se
  acumulaba en `document` cada vez que la página se recargaba vía
  transición de cliente de Astro, en vez de reemplazarse.

### Changed

- `safeUrl()`, `fetchWithRetry()` y el helper de estado de carga —antes
  triplicados en `blog.ts`, `projects.ts` y `certifications.ts`— viven ahora
  en un único módulo compartido (`src/scripts/shared.ts`).
- `server/admin/analytics.php`: el patrón `max(array_column($rows, 'c'))`,
  repetido 13 veces, se consolidó en un helper (`max_count()`).

## [1.4.0.0] - 2026-08-25

### Added

- Blue Team Hub (el conjunto de herramientas gratuitas para analistas SOC en
  `eduolihez.github.io`) aparece ahora como proyecto en el portfolio
  (`/projects/`) y en el resumen para IAs (`llms.txt`), con enlace externo
  claramente señalizado.
- Zéora se une a los proyectos destacados de la portada (el carrusel que se
  sirve desde la base de datos), donde antes no aparecía.
- Cabecera `Content-Security-Policy: frame-ancestors 'none'` en todas las
  páginas HTML, y `X-XSS-Protection: 0` explícito — refuerzo de las cabeceras
  de seguridad del sitio.
- 9 certificaciones de Fortinet nuevas (Credly), cada una con su enlace de
  verificación.

### Fixed

- El badge de PromptMaster estaba marcado como "Open Source" en todo el
  sitio (portfolio, pie de página, base de datos) cuando en realidad es de
  código privado — corregido en todas partes.
- Certificación de Python: emisor correcto (Certiport, no OpenBootcamp) y
  nombre oficial ("IT Specialist - Python").
- Reordenada la categoría de varias certificaciones (los dos cursos de
  Google/Santander y la de la Federació Catalana de Vela pasan a "Otros";
  la de LinkedIn/Microsoft se unifica bajo "LinkedIn").
- Restaurados 5 proyectos (Dewi App, BinCat, NorthGate Browser, Password
  Sentinel, PromptMaster) que habían desaparecido de la portada tras un
  vaciado accidental de la base de datos durante una actualización de
  esquema; el propio archivo de esquema (`database/schema.sql`) queda
  además más seguro frente a reimportaciones futuras.

## [1.3.0.0] - 2026-08-24

### Added

- La analítica propia del panel (`/admin/analytics.php`) ahora mide
  comportamiento, no solo tráfico: tasa de rebote, duración media en
  pantalla y profundidad de scroll alcanzada, además de qué páginas abren y
  cierran cada visita (entrada / salida).
- Atribución de campañas: si un enlace de entrada trae `utm_source`,
  `utm_medium` o `utm_campaign`, el panel los agrupa en una tabla nueva
  ("Atribución UTM").
- Dos desgloses técnicos nuevos: idioma declarado por el navegador (para ver
  si hay demanda de un idioma que la web aún no ofrece) y tamaño de
  pantalla por rango.
- La exportación CSV incluye ahora todos estos campos nuevos.

### Changed

- El hash de IP con el que se cuentan visitantes únicos ahora incorpora
  también el user-agent, para distinguir mejor visitantes que comparten IP
  (oficina, wifi doméstica, CGNAT) sin guardar ningún dato nuevo.
- La nota de privacidad de `/sobre-esta-web/` y del propio panel explica el
  nuevo identificador de sesión: vive solo en `sessionStorage` mientras la
  pestaña está abierta, nunca es persistente ni se cruza entre visitas —
  sigue sin hacer falta banner de cookies.

## [1.2.0.0] - 2026-08-24

### Added

- El panel de administrador muestra muchos más datos de un vistazo: entradas
  de blog (antes ausentes del panel), canales de tráfico y dispositivos de
  los últimos 30 días, tendencia de visitantes únicos, mensajes destacados y
  archivados con su tendencia semanal, y qué tan reciente es cada tipo de
  contenido (último proyecto, certificación y entrada de blog tocados).
- Cada tarjeta de tráfico del panel incluye ahora un mini-gráfico de
  tendencia.
- Acceso rápido para crear una nueva entrada de blog desde el panel.

### Changed

- "Salud del sistema" pasa de tabla a una rejilla de casillas con indicador
  de color, más fácil de leer de un vistazo; ahora incluye también los
  intentos de acceso fallidos (7 y 30 días).
- "Actividad reciente" pasa de tabla a línea de tiempo con color según el
  tipo de acción.
- El menú lateral del panel se reorganiza en grupos (Contenido, Actividad,
  Sistema) con indicadores de recuento junto a cada sección.

### Fixed

- Las nuevas casillas de accesos fallidos ya no muestran "todo en orden"
  cuando la consulta a la base de datos falla; ahora distinguen "0
  incidentes" de "no se pudo comprobar", para no ocultar un ataque de fuerza
  bruta real detrás de un fallo transitorio de BD.

## [1.1.4.0] - 2026-08-23

### Fixed

- Las 4 puntuaciones de rendimiento en "Cómo está construida esta web"
  (antes fijas en 100) muestran ahora una medición real contra producción,
  cada una con su color según el umbral que usa el propio Lighthouse.

## [1.1.3.0] - 2026-08-23

### Added

- El aviso de "cargando" en Blog, Proyectos y Certificaciones ahora tiene
  voz propia (`>_ cargando...`) en vez de un spinner genérico.
- La página "Cómo está construida esta web" presenta cada control como una
  lista verificada, no como texto corrido.

### Fixed

- El aviso de reintento en el Blog se quedaba mostrando el error mientras
  reintentaba, sin indicar que algo estaba pasando (mismo fallo ya corregido
  antes en Proyectos).
- Los círculos de métricas de rendimiento ya no llevan un borde grueso ni
  un resplandor de color, para ir en línea con el resto del sitio.

## [1.1.2.0] - 2026-08-23

### Fixed

- Las secciones con animación de aparición al hacer scroll ya no se quedan
  invisibles para quien tiene activado "menos movimiento" en su sistema.
- Los enlaces de contacto (email, LinkedIn, GitHub, vCard) usan el mismo
  estilo de icono que el resto del sitio.

## [1.1.1.0] - 2026-08-23

### Added

- Enlace directo al repositorio de código en la cabecera (y en el menú
  móvil), junto al selector de idioma.

## [1.1.0.0] - 2026-08-23

### Added

- Sitemap y feed de texto plano dedicados a los artículos del blog, para que
  buscadores y asistentes de IA que no ejecutan JavaScript puedan indexar y
  citar el contenido.
- Botón de reintento con aviso de carga unificado en Blog, Proyectos y
  Certificaciones cuando falla la petición al servidor.
- Enlace "saltar al contenido" y textos de navegación del pie traducidos en
  los tres idiomas (antes solo existían en español).

### Para colaboradores

- Suite de tests automatizados (Vitest) para el frontend en `src/`, con
  verificación de build en cada push/PR (`npm test`, ver `TESTING.md`).

### Changed

- Corregidos los acentos y la ortografía en todo el contenido en español y
  catalán (inicio, experiencia, habilidades, proyectos, certificaciones,
  contacto, FAQ, pie de página).
- Enlaces del pie de página corregidos: desde la versión en inglés o catalán
  volvían a la portada en español en vez de mantener el idioma.
- Contacto, insignias de proyecto y páginas de error unificados bajo un
  mismo sistema de color.
- Páginas de error (400/403/404/410/500) rediseñadas con una estética de
  terminal/sistema en inglés, consistente entre sí.
- `robots.txt` bloquea explícitamente `/admin/` y `/api/` a buscadores y
  rastreadores de IA, y anuncia los nuevos recursos del blog.
- Las fuentes se precargan para evitar el parpadeo de texto; el panel de
  administración sirve sus propias fuentes en vez de depender de Google
  Fonts.
- Contraste de texto secundario (fechas, empresas, pie de página) elevado
  para cumplir el mínimo de accesibilidad WCAG AA.

### Fixed

- El bloqueo por intentos fallidos de inicio de sesión podía saltarse
  falsificando la cabecera de IP; ahora también se cuenta por usuario.
- El panel de administración mostraba sin escapar el nombre de usuario en
  el avatar.
- Si faltaba la clave de cifrado de IPs, el sistema caía en silencio a un
  valor por defecto adivinable; ahora falla de forma explícita.
- El archivo pensado para que la IA lea los artículos del blog se estaba
  bloqueando por error junto con el resto de páginas técnicas.
- El aviso de reintento en Proyectos se quedaba mostrando el error mientras
  reintentaba, sin indicar que algo estaba pasando.
