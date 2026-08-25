# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/),
y el versionado usa cuatro números (`MAJOR.MINOR.PATCH.MICRO`).

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
