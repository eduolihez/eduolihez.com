# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/),
y el versionado usa cuatro números (`MAJOR.MINOR.PATCH.MICRO`).

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
