<div align="center">

# eduolihez.com

**Wiki y Portfolio Profesional de Eduardo Olivares Hernández** — Analista SOC / Blue Team

[![Web](https://img.shields.io/badge/web-eduolihez.com-4ade80?style=flat-square)](https://eduolihez.com)
[![Astro](https://img.shields.io/badge/Astro-7-BC52EE?style=flat-square&logo=astro&logoColor=white)](https://astro.build)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![PHP](https://img.shields.io/badge/PHP-8-777BB4?style=flat-square&logo=php&logoColor=white)](https://www.php.net)
[![CodeQL](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml/badge.svg)](https://github.com/eduolihez/eduolihez.com/actions/workflows/codeql.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

---

### [🌐 English version](README.en.md) · [🌐 Versió en Català](README.ca.md) · **[🌐 Versión en Español](README.md)**

</div>

---

Bienvenido al repositorio y wiki técnica de **eduolihez.com**. Este es el código fuente del sitio web personal y portfolio profesional de Eduardo Olivares, disponible completamente en **español, inglés y catalán**.

El sitio se ha diseñado siguiendo el principio de **defensa en profundidad** y sirve como demostración de competencias técnicas en seguridad ofensiva, endurecimiento de servidores (hardening) y desarrollo web seguro. Todos los detalles técnicos sobre su diseño se describen en [eduolihez.com/sobre-esta-web](https://eduolihez.com/sobre-esta-web/).

---

## 📖 Índice Wiki
1. [Arquitectura y Flujo de Trabajo](#-arquitectura-y-flujo-de-trabajo)
2. [Estructura del Proyecto](#-estructura-del-proyecto)
3. [Seguridad Avanzada (Hardening)](#-seguridad-avanzada-hardening)
4. [Administración y Base de Datos](#-administración-y-base-de-datos)
5. [SEO Técnico e IA-Friendliness](#-seo-técnico-e-ia-friendliness)
6. [Instalación y Despliegue](#-instalación-y-despliegue)
7. [Licencia](#-licencia)

---

## 🏗️ Arquitectura y Flujo de Trabajo

El proyecto combina un generador de sitios estáticos (SSG) moderno con una infraestructura backend robusta para la gestión del contenido dinámico:

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

* **Frontend**: Astro compila las páginas estáticas. En producción, la carga de Node es inexistente; solo se sirven archivos planos desde la carpeta `dist/`.
* **Backend**: Una API REST propia e independiente en PHP 8 interactúa con la base de datos MySQL/MariaDB para gestionar el buzón de contacto, visitas, artículos de blog, certificaciones y proyectos.
* **Integración**: Ambos residen en el mismo hosting bajo el mismo dominio. Esto elimina la necesidad de configurar reglas de CORS cruzadas.

---

## 📂 Estructura del Proyecto

El repositorio está organizado de forma modular para aislar responsabilidades:

```
├── .github/workflows/   # CI/CD: Análisis estático (CodeQL y Semgrep)
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

## 🛡️ Seguridad Avanzada (Hardening)

Como portfolio de un profesional de ciberseguridad, se han implementado rigurosos controles para cerrar vectores de ataque comunes:

### Frontend
* **Content Security Policy (CSP)**: `script-src` configurado únicamente con hashes SHA-256 calculados automáticamente en cada compilación (evita `'unsafe-inline'`). Si un atacante inyecta una etiqueta `<script>`, el navegador se negará a ejecutarla.
* **Cabeceras de Aislamiento**: HSTS activo (1 año con subdominios), `X-Frame-Options: DENY` contra clickjacking, y directivas COOP/CORP restrictivas.
* **Privacidad por Diseño (Do Not Track)**: Respeto estricto a las peticiones `DNT` (si el navegador la envía, la analítica local se inhabilita por completo). Las direcciones IP de las estadísticas se hashean inmediatamente con `SHA-256` y una sal de un solo uso; nunca se almacenan en texto plano.

### Backend e Inyecciones
* **Consultas Preparadas Reales**: Deshabilitada la emulación de PDO (`ATTR_EMULATE_PREPARES = false`) para evitar desbordes o fallos de codificación de caracteres.
* **Seguridad en Formularios**: CSRF implementado con tokens de sesión verificados en tiempo constante (`hash_equals`).
* **Protección del Banner superior con Markdown**: El campo del banner de administración admite Markdown y se renderiza en el cliente de forma segura. El HTML se escapa por completo *antes* del parseo para evitar inyecciones XSS persistentes (Stored XSS).
* **Sanitización de Subidas**: Las imágenes se analizan con `finfo` (MIME real) y `getimagesize()` (estructura interna). La carpeta de subidas deshabilita la ejecución de scripts (handlers PHP apagados vía `.htaccess`) y asigna nombres aleatorios aleatorios a los archivos guardados.

---

## 🗄️ Administración y Base de Datos

* **Mantenimiento Preventivo**: El sistema incluye un validador en [bootstrap.php](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/server/lib/bootstrap.php) que comprueba las tablas y columnas necesarias al iniciar el panel de administración. Si detecta la falta de campos (ej. tras el despliegue de una columna como `badges`), redirige a una pantalla de aviso con instrucciones guiadas en vez de lanzar un error crítico en el cliente.
* **Esquema Idempotente**: El archivo [schema.sql](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/database/schema.sql) se puede importar repetidamente en phpMyAdmin sobre bases de datos existentes sin borrar la información previa del usuario.

---

## 🔍 SEO Técnico e IA-Friendliness

* **Grafo Único JSON-LD**: Datos estructurados (`Person`, `WebSite`, `FAQPage`, `BreadcrumbList`) unificados mediante identificadores `@id` cruzados en vez de bloques dispersos.
* **hreflang Recíproco**: La distribución multilingüe incluye referencias cruzadas y `x-default` únicamente en páginas con traducción activa.
* **IA Rastreabilidad**: Cumple con la especificación de [llmstxt.org](https://llmstxt.org/) generando un archivo plano [`/llms.txt`](https://eduolihez.com/llms.txt) en cada build, ideal para que los modelos de lenguaje (LLM) indexen el portfolio sin HTML residual.
* **Control de Bots**: Filtro selectivo en `robots.txt` que permite indexar a los rastreadores legítimos de IA (GPTBot, ClaudeBot, etc.) y bloquea los rastreadores agresivos de SEO de pago.

---

## 🚀 Instalación y Despliegue

### Requisitos
* Node.js v20+
* PHP 8.0+ con PDO habilitado
* Base de datos MySQL / MariaDB

### Instalación Local (Entorno Frontend)
```bash
# Instalar dependencias
npm install

# Iniciar servidor de desarrollo (Astro)
npm run dev
```

> [!NOTE]
> Dado que la base de datos dinámica y PHP no corren directamente bajo el servidor de desarrollo de Astro (`localhost:4321`), es normal ver mensajes de error en las secciones dinámicas locales. Para probar la integración completa, utiliza una pila local tipo XAMPP, Laragon o Docker.

### Comandos Útiles
* `npm run build`: Compila el frontend estático a la carpeta `dist/`.
* `npm run preview`: Lanza una vista previa local del directorio compilado.
* `npm run icons`: Regenera la pila de favicons y gráficos de la web.

### Instrucciones de Despliegue en Servidor (CDMON / CPanel)
1. Compila el sitio localmente con `npm run build`.
2. Sube por FTP el contenido de `dist/` a la raíz de tu servidor (ej. `public_html/`).
3. Sube la carpeta `server/` al mismo nivel de tu servidor para mapear `/api/` y `/admin/`.
4. Copia `server/config.example.php` a `server/config.php` y configura tus variables de conexión. **Importante**: No subas este archivo al control de versiones.
5. Accede a phpMyAdmin e importa [schema.sql](file:///c:/Users/eduol/Documents/GitHub/eduolihez.com/database/schema.sql).
6. Entra en `tudominio.com/admin/setup.php` para crear tu primera cuenta de administración. **Una vez creado el usuario, borra el archivo `setup.php` del servidor.**

---

## 📄 Licencia

Este proyecto está bajo la [Licencia MIT](LICENSE). 

* Quedan excluidos de la licencia MIT y reservados todos los derechos sobre el contenido personal (imágenes de marca, fotografías, archivos PDF de certificaciones y textos biográficos del autor). Puedes emplear la lógica y arquitectura del proyecto para tu propio desarrollo; se prohíbe el clonado directo de la identidad visual e información del autor.
