# Panel de administración: espacios y sistema visual

Fecha: 2026-10-06
Estado: pendiente de revisión
Alcance: pieza 1 de 4 (ver "Contexto y descomposición")

## Contexto y descomposición

El panel (`server/admin/`, PHP + MySQL, despliegue por FTP en CDMON) mezcla
contenido de eduolihez.com, PhishLab y apps externas en un único menú. Sin
`?app=` se asume el contexto de eduolihez.com, lo que mete al usuario en ese
sitio por defecto. Además `partials/layout.php` (1165 líneas) concentra CSS,
menú y lógica de selector.

Petición original: mejorar estética y organización de todo el panel, no entrar
por defecto en eduolihez.com, configurar usuarios de PhishLab y tener más
datos. Un correo enviado directamente al buzón no apareció en el panel con los
datos del remitente.

Se descompone en cuatro piezas independientes, en este orden, cada una con su
spec, plan e implementación:

1. **Estructura y estética del panel** (este documento).
2. Correo entrante: lectura del buzón de CDMON por IMAP y bandeja unificada
   (formulario + correo directo) con datos del remitente.
3. Workspace de PhishLab: usuarios, ajustes y datos de campañas.
4. Más datos: analítica enriquecida y resumen global por app.

## Objetivo y criterios de éxito

- Al entrar al panel se ve **Global**, no eduolihez.com.
- Cada página pertenece a un espacio y el menú solo muestra lo de ese espacio.
- Tema claro y oscuro con interruptor; sin parpadeo al cargar.
- Todas las páginas comparten la misma estructura visual.
- Ninguna URL actual deja de funcionar.

Fuera de alcance: cambiar el contenido o los datos de las páginas, el correo
entrante, la gestión ampliada de PhishLab y nuevas métricas (piezas 2 a 4).

## Decisiones tomadas

- Navegación: **selector de espacio** arriba del menú (opción A del mockup).
- Estética: **claro y oscuro con interruptor** (opción C).
- Enfoque técnico: **refactor in situ**. Sin mover archivos ni cambiar URLs;
  sin SPA (CDMON no tiene Node).

## Diseño

### 1. Espacios y navegación

`server/admin/partials/spaces.php` define los espacios:

| Espacio | Slug | Páginas |
|---|---|---|
| Global (por defecto) | `global` | Resumen, Bandeja (Mensajes), Analítica, Actividad, Seguridad, Ajustes, Backup, Integraciones, Gestionar apps |
| eduolihez.com | `site` | Proyectos, Certificaciones, Blog, su analítica |
| PhishLab | `phishlab` | Resumen, Usuarios (más adelante Campañas y Ajustes) |
| App registrada | `app:<slug>` | Resumen y eventos; generado desde la tabla `apps` |

- El espacio viaja en la URL como `?space=<slug>`. Si falta, se usa el último
  guardado en sesión **siempre que la página pertenezca a ese espacio**; si no,
  el espacio de origen de la página (para `analytics.php`, `index.php` y
  `messages.php` es `global`).
- `?app=<slug>` se mantiene como alias de `?space=app:<slug>`.
- Cada página tiene un espacio por defecto, para que las URLs actuales sigan
  funcionando.
- El slug se valida contra una lista blanca (`global`, `site`, `phishlab` y los
  slugs existentes en `apps`); un valor no válido se ignora y se aplica la regla
  anterior (sesión o espacio de origen de la página).
- `site` equivale a la app `eduolihez` y `phishlab` a la app `phishlab` (ambas
  ya existen en la tabla `apps`); el resto de apps usan `app:<slug>`.
- Selector desplegable arriba del menú; al cambiar lleva a la página de inicio
  del espacio. Los contadores del menú se calculan solo para el espacio visible.
- El menú de Global no vuelve a ocultar secciones según contexto.

Funciones puras, sin base de datos:

- `resolve_space(array $get, array $session, array $appSlugs, string $page): string`
- `space_nav(string $space, array $counts): array`

### 2. Sistema visual y tema

- Los estilos salen de `layout.php` a `assets/admin.css`, en capas: tokens
  (colores, espacios, radios, sombras), base, componentes (tarjeta, tabla,
  badge, formulario, botón, aviso) y layout.
- Tokens claros en `:root`, oscuros en `[data-theme="dark"]`.
- Preferencia en `localStorage`; si no hay, `prefers-color-scheme`.
- `assets/theme.js` se carga síncrono en `<head>` para evitar el parpadeo. Es
  un archivo externo porque la CSP (`script-src 'self'`) no admite scripts en
  línea.
- Botón de tema en el pie del menú; su lógica va en `assets/admin.js`.
- Gráficos y sparklines usan variables de color para funcionar en ambos temas.
- Plantilla común de página: cabecera (título, descripción, acciones),
  contenido en tarjetas, tablas con estilo único (cabecera fija, hover,
  estado vacío).
- Móvil: menú en cajón con botón de hamburguesa; se revisa el responsive
  existente en lugar de rehacerlo.
- Los `style="..."` sueltos pasan a clases a medida que se toca cada página.

### 3. Errores, pruebas y despliegue

- Si falta una tabla (`apps`, `lab_users`...), el menú sigue funcionando con
  contadores a 0, como hoy con `$countSafe`.
- PHPUnit sin BD en `server/tests/`: espacio por defecto, slug inválido, alias
  `?app=`, valor de sesión y espacios de apps generados desde una lista.
- Verificación manual de cada página en claro, oscuro y móvil, con capturas.
- Despliegue por FTP. `admin.css` y `theme.js` se enlazan con `?v=<filemtime>`
  para invalidar caché. No hay migraciones de BD.

## Riesgos

- `layout.php` lo usan todas las páginas: un fallo lo tumba todo. Se mitiga con
  commits pequeños y comprobando cada página antes de seguir.
- Páginas compartidas entre espacios (Analítica filtra por `?app=`).
- Los slugs de `apps` acaban en sesión y en enlaces: se validan por lista
  blanca.
- Al dejar de asumir eduolihez.com por defecto, enlaces antiguos sin `?app=`
  que esperaban ese contexto pueden mostrar Global; cada página conserva su
  espacio por defecto para evitarlo.
