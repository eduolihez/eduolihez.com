<div align="center">

# eduolihez.com

**Wiki y portfolio profesional de Eduardo Olivares Hernández**, analista SOC / Blue Team

[![Web](https://img.shields.io/badge/web-eduolihez.com-4ade80?style=flat-square)](https://eduolihez.com)
[![Astro](https://img.shields.io/badge/Astro-7-BC52EE?style=flat-square&logo=astro&logoColor=white)](https://astro.build)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![PHP](https://img.shields.io/badge/PHP-8-777BB4?style=flat-square&logo=php&logoColor=white)](https://www.php.net)
[![CodeQL](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml)
[![Tests](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

---

### [English version](README.en.md) · [Versió en Català](README.ca.md) · **[Versión en Español](README.md)**

</div>

---

Este es el código fuente de **eduolihez.com**, el sitio web personal y portfolio de
Eduardo Olivares, disponible en español, inglés y catalán.

El sitio está diseñado siguiendo el principio de defensa en profundidad, y sirve
también como demostración de seguridad ofensiva, hardening de servidores y desarrollo
web seguro. Los detalles técnicos del diseño están en
[eduolihez.com/sobre-esta-web](https://eduolihez.com/sobre-esta-web/).

---

## Índice
1. [Arquitectura y flujo de trabajo](#arquitectura-y-flujo-de-trabajo)
2. [Estructura del proyecto](#estructura-del-proyecto)
3. [Hardening](#hardening)
4. [Administración y base de datos](#administración-y-base-de-datos)
5. [SEO técnico y rastreo por IA](#seo-técnico-y-rastreo-por-ia)
6. [Instalación y despliegue](#instalación-y-despliegue)
7. [Más documentación](#más-documentación)
8. [Licencia](#licencia)

---

## Arquitectura y flujo de trabajo

El proyecto combina un generador de sitios estáticos con un backend propio para el
contenido dinámico:

```
┌─ src/          Astro (Frontend) · Compila a HTML estático ─► dist/ ──► Servidor Apache ─┐
│                                                                                         │
│                                                                               ┌─────────▼────────┐
│  fetch /api/*.php  ◄──────────────────────────────────────────────────────────┤  CDMON / Hosting │
│                                                                               │  Cloudflare / TLS│
└─ server/       PHP 8 + MySQL (Backend) · API Pública + Admin Panel ──────────►└─────────┬────────┘
                                                                                          │
                                                                                ┌─────────▼────────┐
                                                                                │ MySQL / MariaDB  │
                                                                                └──────────────────┘
```

* Frontend: Astro compila las páginas estáticas. En producción no hay carga de Node;
  solo se sirven archivos planos desde `dist/`.
* Backend: una API REST propia en PHP 8 habla con MySQL/MariaDB para gestionar el buzón
  de contacto, las visitas, los artículos del blog, las certificaciones y los proyectos.
* Integración: ambos viven en el mismo hosting y bajo el mismo dominio, así que no hay
  que configurar reglas de CORS cruzadas.

---

## Estructura del proyecto

El repositorio está organizado de forma modular para aislar responsabilidades:

```
├── .github/workflows/   # CI/CD: Análisis estático (CodeQL y Semgrep) y tests (Vitest)
├── database/            # Esquema MySQL idempotente y migración de base de datos
│   ├── schema.sql       # Tablas, índices, procedimientos de migración y seed inicial
│   └── clean.sql        # Utilidad para vaciado de tablas
├── public/              # Recursos estáticos servidos tal cual (PDFs, robots.txt, security.txt)
├── scripts/             # Herramientas auxiliares de compilación y generación de iconos
├── server/              # Backend en PHP
│   ├── admin/           # Panel de administración (Autenticación, formularios de edición)
│   ├── api/             # Endpoints públicos de la API de solo lectura y telemetría
│   ├── lib/             # Núcleo backend (bootstrap, subida de archivos, base de datos, utilidades HTTP)
│   └── config.example.php # Plantilla de configuración (BD, límites de subida)
└── src/                 # Frontend en Astro (Páginas, Layouts, Componentes, I18n)
```

---

## Hardening

Los controles implementados para cerrar los vectores de ataque habituales:

### Frontend
* Content Security Policy: `script-src` se configura únicamente con hashes SHA-256
  calculados en cada compilación, sin `'unsafe-inline'`. Si un atacante inyecta una
  etiqueta `<script>`, el navegador se niega a ejecutarla.
* Cabeceras de aislamiento: HSTS activo (1 año, con subdominios),
  `X-Frame-Options: DENY` contra clickjacking y directivas COOP/CORP restrictivas.
* Do Not Track: si el navegador envía la cabecera `DNT`, la analítica local se
  inhabilita por completo. Las IP de las estadísticas se hashean al momento con SHA-256
  y una sal de un solo uso; nunca se almacenan en texto plano.

### Backend e inyecciones
* Consultas preparadas de verdad: la emulación de PDO está desactivada
  (`ATTR_EMULATE_PREPARES = false`) para evitar desbordes y fallos de codificación de
  caracteres.
* CSRF con tokens de sesión verificados en tiempo constante (`hash_equals`).
* El banner superior admite Markdown y se renderiza en el cliente. El HTML se escapa por
  completo *antes* del parseo, para evitar XSS persistente.
* Sanitización de subidas: las imágenes pasan por `finfo` (MIME real) y `getimagesize()`
  (estructura interna). La carpeta de subidas tiene los handlers PHP apagados vía
  `.htaccess`, así que no ejecuta scripts, y los archivos guardados reciben nombres
  aleatorios.

---

## Administración y base de datos

* Mantenimiento preventivo: [bootstrap.php](server/lib/bootstrap.php)
  comprueba las tablas y columnas necesarias al iniciar el panel de administración. Si
  falta algún campo, por ejemplo tras desplegar una columna como `badges`, redirige a
  una pantalla de aviso con instrucciones en vez de reventar con un error en el cliente.
* Esquema idempotente: [schema.sql](database/schema.sql)
  se puede importar repetidamente en phpMyAdmin sobre bases de datos existentes sin
  borrar la información previa.

---

## SEO técnico y rastreo por IA

* Grafo único JSON-LD: los datos estructurados (`Person`, `WebSite`, `FAQPage`,
  `BreadcrumbList`) se unifican con identificadores `@id` cruzados en vez de quedar en
  bloques dispersos.
* hreflang recíproco: la distribución multilingüe incluye referencias cruzadas y
  `x-default` solo en las páginas que tienen traducción activa.
* Rastreo por IA: cumple la especificación de [llmstxt.org](https://llmstxt.org/)
  generando un archivo plano [`/llms.txt`](https://eduolihez.com/llms.txt) en cada
  build, para que los modelos de lenguaje indexen el portfolio sin HTML residual.
* Control de bots: `robots.txt` permite indexar a más de 20 rastreadores legítimos de IA
  y buscadores (GPTBot, ClaudeBot, PerplexityBot, Google-Extended, Amazonbot y otros),
  les bloquea `/admin/` y `/api/` a todos, y bloquea por completo a los rastreadores
  agresivos de SEO de pago (Semrush, Ahrefs, MJ12 y compañía).
* Blog citable sin JavaScript: los artículos viven en MySQL y se publican sin
  recompilar, así que un rastreador que no ejecuta JS los vería vacíos.
  [`/llms-blog.txt`](https://eduolihez.com/llms-blog.txt) sirve su texto íntegro y
  `/sitemap-posts.xml` los enumera, ambos generados en cada petición.

---

## Instalación y despliegue

### Requisitos
* Node.js v20+
* PHP 8.0+ con PDO habilitado
* Base de datos MySQL / MariaDB

### Instalación local (frontend)
```bash
# Instalar dependencias
npm install

# Iniciar servidor de desarrollo (Astro)
npm run dev
```

> [!NOTE]
> La base de datos y PHP no corren bajo el servidor de desarrollo de Astro
> (`localhost:4321`), así que es normal ver errores en las secciones dinámicas cuando
> trabajas en local. Para probar la integración completa, usa una pila local tipo XAMPP,
> Laragon o Docker.

### Comandos útiles
* `npm run build`: compila el frontend estático a `dist/`.
* `npm run preview`: lanza una vista previa local del directorio compilado.
* `npm run icons`: regenera la pila de favicons y gráficos de la web.
* `npm test`: ejecuta la suite de tests (Vitest) sobre el frontend en `src/`.

### Despliegue en servidor (CDMON / cPanel)
1. Compila el sitio localmente con `npm run build`.
2. Sube por FTP el contenido de `dist/` a la raíz de tu servidor, por ejemplo
   `public_html/`.
3. Sube la carpeta `server/` al mismo nivel, para mapear `/api/` y `/admin/`.
4. Copia `server/config.example.php` a `server/config.php` y configura tus variables de
   conexión. No subas este archivo al control de versiones.
5. Entra en phpMyAdmin e importa [schema.sql](database/schema.sql).
6. Abre `tudominio.com/admin/setup.php` para crear tu primera cuenta de administración.
   **Una vez creado el usuario, borra `setup.php` del servidor.**

---

## Más documentación

Este repositorio tiene más documentación de la que cabe en este README:

* [Wiki](https://github.com/eduolihez/eduolihez.com/wiki), punto de entrada a toda la
  documentación, incluido el plan de visibilidad IA/SEO.
* [TESTING.md](TESTING.md), framework de tests, cobertura y convenciones.
* [CONTRIBUTING.md](CONTRIBUTING.md), cómo reportar un fallo o proponer un cambio.
* [SECURITY.md](SECURITY.md), política de divulgación de vulnerabilidades.
* [CHANGELOG.md](CHANGELOG.md), historial de versiones.
* [PRODUCT.md](PRODUCT.md), para quién es esta web y qué problema resuelve.
* [DESIGN.md](DESIGN.md), sistema de diseño (tipografía, color, espaciado, motion).
* [TODOS.md](TODOS.md), trabajo pendiente conocido, con contexto de por qué no se hizo
  ya.

---

## Licencia

Este proyecto está bajo la [Licencia MIT](LICENSE).

El contenido personal queda excluido de la licencia MIT y con todos los derechos
reservados: imágenes de marca, fotografías, PDF de certificaciones y textos biográficos
del autor. Puedes usar la lógica y la arquitectura del proyecto para tu propio
desarrollo; lo que no se permite es clonar directamente la identidad visual y la
información del autor.
