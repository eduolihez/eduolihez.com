<div align="center">

# eduolihez.com

**Portfolio profesional de Eduardo Olivares Hernández** — Analista SOC / Blue Team

[![Web](https://img.shields.io/badge/web-eduolihez.com-4ade80?style=flat-square)](https://eduolihez.com)
[![Astro](https://img.shields.io/badge/Astro-7-BC52EE?style=flat-square&logo=astro&logoColor=white)](https://astro.build)
[![PHP](https://img.shields.io/badge/PHP-8-777BB4?style=flat-square&logo=php&logoColor=white)](https://www.php.net)
[![CodeQL](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

</div>

---

Sitio web y portfolio en **español, inglés y catalán**. El frontend se compila a HTML
estático con Astro; el contenido que cambia a menudo —proyectos, certificaciones y blog—
lo sirve una API propia en PHP contra MySQL, gestionada desde un panel de administración
hecho a medida.

La web está pensada como una demostración práctica: si trabajo asegurando sistemas ajenos,
lo mínimo es que el mío aguante una revisión. En
**[eduolihez.com/sobre-esta-web](https://eduolihez.com/sobre-esta-web/)** están explicados
los controles concretos y el motivo de cada uno.

## Arquitectura

```
┌─ src/          Astro · compila a HTML estático ──► dist/ ──► FTP ──┐
│                                                                    │
│                                                          ┌─────────▼────────┐
│  fetch /api/*.php  ◄─────────────────────────────────────┤  CDMON · Apache  │
│                                                          │  Cloudflare/TLS  │
└─ server/       PHP 8 + MySQL · API pública + /admin ─────►└─────────┬────────┘
                                                                     │
                                                            ┌────────▼───────┐
                                                            │ MySQL/MariaDB  │
                                                            └────────────────┘
```

El frontend no necesita Node en producción: se sube `dist/` ya compilado. `server/` se sube
tal cual, sin build. Ambas mitades comparten dominio, así que la API se consume con rutas
relativas y no hacen falta cabeceras CORS.

| Capa | Tecnología |
| --- | --- |
| Frontend | Astro 7 (SSG), Tailwind CSS, TypeScript, i18n nativo (ES/EN/CA) |
| Backend | PHP 8 con PDO, MySQL/MariaDB, sin framework |
| Infraestructura | CDMON, Apache, Cloudflare, TLS |
| CI | CodeQL (JS/TS), Semgrep (PHP), Dependabot |

## Estructura

| Ruta | Contenido |
| --- | --- |
| `src/` | Páginas, componentes, layouts, datos estáticos e i18n de Astro |
| `public/` | Recursos servidos tal cual: imágenes, PDFs de certificaciones, `robots.txt`, `security.txt` |
| `server/api/` | API pública de solo lectura + endpoint de contacto y de analítica |
| `server/admin/` | Panel de administración protegido por sesión |
| `server/lib/` | Núcleo compartido: arranque, helpers HTTP, subidas, parseo de user-agent |
| `database/` | `schema.sql` (idempotente: esquema, migración y contenido inicial) y `clean.sql` (vaciado) |
| `scripts/` | Utilidades puntuales: generación de iconos y CSS de una extensión |

## Seguridad

Un resumen de lo que lleva implementado. Cada punto está desarrollado, con su motivo, en
[la página técnica del sitio](https://eduolihez.com/sobre-esta-web/).

**Frontend**
- CSP con hashes SHA-256 recalculados en cada compilación; `script-src` sin `'unsafe-inline'`.
- HSTS a un año con `includeSubDomains`, deliberadamente sin `preload`.
- `X-Frame-Options: DENY`, COOP y CORP en `same-origin`, `Permissions-Policy` restrictiva.
- Cero recursos de terceros: fuentes autoalojadas, sin CDN ni analítica externa.

**Backend y panel**
- Consultas preparadas reales (`ATTR_EMULATE_PREPARES = false`), nunca concatenación.
- CSRF en todos los formularios, comparado en tiempo constante con `hash_equals`.
- Bloqueo de fuerza bruta por IP y ventana temporal.
- Sesiones con regeneración de ID tras el login, cookies `HttpOnly`/`Secure`/`SameSite=Lax`,
  y caducidad tanto por inactividad como absoluta.
- Login con verificación de hash ficticio para que el tiempo de respuesta no permita
  enumerar usuarios.
- Subidas validadas por MIME real (`finfo`) **y** `getimagesize()`, con tope de dimensiones,
  nombre aleatorio y ejecución de código desactivada en la carpeta de destino.
- Exportaciones CSV con neutralización de inyección de fórmulas.

**Privacidad**
- Analítica propia, sin cookies y sin terceros. La IP no se almacena: se guarda su SHA-256
  con sal. Se respeta `Do Not Track` y la retención está acotada con purga automática.

Para reportar un fallo de seguridad: [`SECURITY.md`](SECURITY.md) o
[`/.well-known/security.txt`](https://eduolihez.com/.well-known/security.txt).

## Puesta en marcha

Requiere Node 20 o superior. Para el backend, PHP 8 y una base de datos MySQL/MariaDB.

```bash
npm install
npm run dev      # http://localhost:4321
```

> En local no hay PHP, así que las secciones dinámicas (proyectos, certificaciones, blog)
> mostrarán su mensaje de error. Es el comportamiento esperado, no un fallo.

| Comando | Qué hace |
| --- | --- |
| `npm run dev` | Servidor de desarrollo con recarga en caliente |
| `npm run build` | Compila el sitio a `dist/` |
| `npm run preview` | Sirve `dist/` localmente para revisarlo antes de subir |
| `npm run icons` | Regenera favicons e iconos PWA |

### Despliegue

1. `npm run build`.
2. Subir el **contenido** de `dist/` a la raíz web (`public_html/`).
3. Subir `server/` a la raíz web, de forma que la API quede en `/api/` y el panel en `/admin/`.
4. Copiar `server/config.example.php` a `server/config.php` y rellenar las credenciales.
   Este archivo está en `.gitignore` y **nunca** debe subirse al repositorio.
5. Importar `database/schema.sql` desde phpMyAdmin. Es idempotente: sirve igual para una
   instalación nueva que para actualizar una base ya en producción.
6. Crear el usuario administrador en `/admin/setup.php` y **borrar ese archivo** del servidor.

## Visibilidad y SEO

- Grafo JSON-LD único (`Person`, `WebSite`, `ProfilePage`, `BreadcrumbList`, `FAQPage`)
  enlazado por `@id`, más `BlogPosting` por artículo.
- `hreflang` recíprocos con `x-default`, declarados solo donde la traducción existe.
- Sitemap generado en cada compilación, con `xhtml:link` por idioma y solo URLs indexables.
- `410 Gone` para contenido retirado a propósito y `301` para las rutas antiguas.
- [`/llms.txt`](https://eduolihez.com/llms.txt) con un resumen en texto plano para modelos
  de lenguaje, generado desde las mismas fuentes que la web.
- `robots.txt` con política explícita: rastreadores de IA permitidos, SEO comercial agresivo
  bloqueado.

## Licencia

Código bajo [licencia MIT](LICENSE).

El contenido personal —textos, fotografías, CV y los PDF de las certificaciones— no entra en
esa licencia y queda reservado. Puedes reutilizar la implementación; no la identidad.
