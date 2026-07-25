# 🚀 Guía de despliegue en CDMON

Guía paso a paso para publicar el portfolio en tu hosting **CDMON** (cPanel,
PHP + MySQL). No necesitas conocimientos de servidores: solo seguir el orden.

Tiempo estimado: **30–40 min** la primera vez.

> **¿Ya tienes la web publicada y solo quieres aplicar la última
> actualización?** No hagas toda la guía: ve directo a
> [**Actualizar una web ya publicada (v2)**](#-actualizar-una-web-ya-publicada-v2).
> Son 6 pasos y unos 10 minutos.

---

## 🔄 Actualizar una web ya publicada (v2)

Esta actualización trae: revisión de seguridad, panel de administración muy
ampliado (analítica, seguridad, backup, buzón con filtros) y un SEO rehecho
para búsquedas locales y para las IAs.

**Hazlo en este orden. El paso 1 es obligatorio: sin él, el panel se detiene
con un aviso y no funciona.**

### 1. Aplica la migración de la base de datos ⚠️ IMPRESCINDIBLE

El panel nuevo usa tablas y columnas que aún no existen en tu base de datos.

1. Panel de CDMON → **phpMyAdmin**.
2. Selecciona tu base de datos en la columna izquierda.
3. Pestaña **Importar** → **Seleccionar archivo** → elige
   `database/migration-v2.sql` → **Continuar**.

Se puede ejecutar varias veces sin riesgo: comprueba qué existe antes de crear
nada, y **no toca** tus proyectos, certificaciones ni mensajes.

> Si entras al panel sin haber hecho esto, verás una pantalla amarilla
> explicándote exactamente este paso. No es un error: es el aviso.

### 2. Recompila el sitio en tu PC

```bash
npm install     # solo si cambiaste de ordenador
npm run build
```

Genera de nuevo `dist/`, ahora con la FAQ, los datos estructurados y los
archivos `llms.txt` y `sitemap.xml` (que ahora se generan solos).

### 3. Sube el contenido de `dist/` a `public_html/` (sobrescribiendo)

Archivos nuevos que deben aparecer arriba del todo:
`llms.txt`, `humans.txt`, `sitemap.xml`, `robots.txt`.

> **Borra el `sitemap.xml` antiguo si tu cliente FTP no lo sobrescribe.**
> Antes era un archivo fijo; ahora se genera en cada compilación con la fecha
> de actualización.

### 4. Sube el contenido de `server/` a `public_html/` (sobrescribiendo)

Archivos **nuevos** en esta versión:

| Archivo | Qué es |
|---|---|
| `lib/bootstrap.php` | Arranque común: errores, sesiones, ajustes, auditoría |
| `lib/ua.php` | Análisis de navegador/SO/bots para la analítica |
| `admin/security.php` | Centro de seguridad del panel |
| `admin/backup.php` | Copia de seguridad y restauración |

Y se han modificado casi todos los demás, así que **sube la carpeta entera**.
No subas `config.example.php`.

⚠️ **No sobrescribas tu `config.php`.** Si tu cliente FTP lo pregunta, di que
no. Contiene tus credenciales.

### 5. Añade los ajustes nuevos a tu `config.php`

Abre `public_html/config.php` (edítalo por FTP) y añade estas líneas dentro
del bloque `'security' => [ ... ]`:

```php
'session_idle_minutes' => 120, // cierra la sesión tras 2 h sin actividad
'session_max_hours'    => 12,  // duración máxima absoluta
'visit_max_per_minute' => 30,  // tope de visitas registradas por visitante
```

Dentro de `'uploads' => [ ... ]`:

```php
'max_dimension' => 6000,       // px máximos por lado de una imagen subida
```

Y al final, junto a `'debug' => false`:

```php
'timezone' => 'Europe/Madrid',
```

> Si no las añades, el código usa esos mismos valores por defecto y todo
> funciona igual. Ponerlas te permite ajustarlas cuando quieras.

### 6. Comprueba que ha ido bien

1. Entra en **`/admin`** → el panel debe abrirse con el nuevo dashboard.
2. Mira el bloque **Salud del sistema** y los avisos de arriba: si algo está
   mal configurado, te lo dice ahí con nombre y apellidos.
3. Ve a **Seguridad** → la tabla *Revisión de la configuración* debe salir
   todo en verde. Lo que salga en amarillo lleva la explicación al lado.
4. Abre **`https://TU-DOMINIO/llms.txt`** → debe verse tu resumen en texto.
5. Abre **`https://TU-DOMINIO/sitemap.xml`** → debe tener `<lastmod>` de hoy.

### 7. Avisa a Google (opcional pero recomendado)

1. [Google Search Console](https://search.google.com/search-console) → añade
   `eduolihez.com` si aún no lo tienes.
2. **Sitemaps** → envía `sitemap.xml`.
3. **Inspección de URLs** → pega `https://eduolihez.com/` → *Solicitar
   indexación*. Repite con `/en/` y `/ca/`.
4. Con la FAQ nueva, en unos días puedes comprobar en la
   [prueba de resultados enriquecidos](https://search.google.com/test/rich-results)
   que Google detecta `Person` y `FAQPage`.

---

## 0. Requisitos

- Tu hosting CDMON con **PHP 8+** y **una base de datos MySQL/MariaDB**.
- Un cliente FTP/SFTP: recomiendo [FileZilla](https://filezilla-project.org/) (gratis).
- Node.js instalado en tu PC (para compilar). Ya lo tienes.
- Tus datos de acceso FTP y de MySQL (los da CDMON en su panel).

---

## 1. Prepara tus archivos personales

Antes de compilar, coloca:

- **Foto:** `public/img/eduardo.jpg` (cuadrada, ≥512×512).
- **Imagen para redes:** `public/img/og-cover.png` — se genera un placeholder con
  `npm run icons`. Sustitúyelo por uno **1200×630** con tu foto/nombre cuando lo tengas.
- **CV:** `public/cv/CV-Eduardo-Olivares-ES.pdf`, `...-EN.pdf` y `...-CA.pdf`.
- **Iconos (favicon, PWA):** genéralos con `npm run icons` (crea PNGs reales sin
  dependencias). Se regeneran solos; no tienes que dibujar nada.

Y revisa tu dominio en dos sitios (si no es `eduolihez.com`):
- `src/config.ts` → `domain`
- `astro.config.mjs` → `site`

> Consulta `public/img/LEEME.txt` y `public/cv/LEEME.txt` para los nombres exactos.
> La web es **trilingüe** (ES `/`, EN `/en/`, CA `/ca/`).

---

## 2. Compila el sitio

En la carpeta del proyecto:

```bash
npm install      # solo la primera vez
npm run build
```

Esto genera la carpeta **`dist/`** con el sitio estático listo para subir.

---

## 3. Crea la base de datos en CDMON

1. Entra al **panel de CDMON → Bases de datos MySQL**.
2. **Crea una base de datos** nueva (p.ej. `portfolio`).
3. **Crea un usuario** MySQL y **asígnalo** a esa base con **todos los permisos**.
4. Apunta estos 4 datos, los necesitarás en el paso 5:
   - Host (normalmente `localhost`)
   - Nombre de la base de datos
   - Usuario
   - Contraseña

### Importar las tablas

1. Abre **phpMyAdmin** desde el panel de CDMON.
2. Selecciona a la izquierda **tu base de datos** recién creada.
3. Pestaña **Importar** → **Selecciona archivo** → elige `database/schema.sql`.
4. Pulsa **Continuar**. Debería crear las tablas y unos datos de ejemplo.

---

## 4. Prepara tu `config.php`

1. En tu PC, copia `server/config.example.php` y renómbralo a **`server/config.php`**.
2. Ábrelo y rellena:

```php
'db' => [
    'host' => 'localhost',
    'name' => 'TU_BASE_DE_DATOS',
    'user' => 'TU_USUARIO_DB',
    'pass' => 'TU_PASSWORD_DB',
    'charset' => 'utf8mb4',
],
'mail' => [
    'enabled' => true,
    'to'      => 'eduardo@eduolihez.com',
    'from'    => 'no-reply@eduolihez.com',   // usa una dirección de TU dominio
    ...
],
'security' => [
    ...
    'ip_salt' => 'PON_AQUI_UNA_CADENA_LARGA_Y_ALEATORIA',
],
```

> `config.php` **nunca** se sube a GitHub (está en `.gitignore`). Solo va al hosting.

---

## 5. Sube los archivos por FTP

Conéctate con FileZilla a tu hosting. La raíz web de CDMON suele llamarse
**`public_html`** (o `httpdocs`). Vas a dejarlo así:

```
public_html/                    ← RAÍZ WEB
├─ index.html  en/  ca/  404.html   ┐
├─ _astro/                          │  (todo el CONTENIDO de dist/)
├─ img/  cv/  favicon.svg  favicon-32.png
├─ .well-known/security.txt         │
├─ eduardo-olivares.vcf             │
├─ robots.txt  sitemap.xml          │
├─ llms.txt  humans.txt             ┘  (resumen para IAs y créditos)
│
├─ .htaccess                 ┐
├─ config.php                │
├─ db.php                    │  (todo el CONTENIDO de server/)
├─ lib/                      │
├─ api/                      │
├─ admin/                    │
└─ uploads/                  ┘  (imágenes subidas desde el panel)
```

### Cómo hacerlo

1. **Sube el CONTENIDO de `dist/`** (no la carpeta, sino lo que hay dentro)
   a `public_html/`.
2. **Sube el CONTENIDO de `server/`** a `public_html/` también.
   - Incluye `config.php` (el que rellenaste), `db.php`, `lib/`, `api/`, `admin/`,
     `uploads/` y el archivo **`.htaccess`**.
   - ⚠️ En FileZilla: menú **Servidor → Forzar mostrar archivos ocultos**, para
     que veas y subas los `.htaccess` (empiezan por punto) y `.well-known/`.
   - **No subas** `config.example.php` (opcional dejarlo, está bloqueado por
     `.htaccess`, pero mejor no subirlo).
3. **Permisos de la carpeta `uploads/`**: en FileZilla, clic derecho sobre
   `uploads` → **Permisos de archivo** → `755` (o `775` si 755 no deja subir
   imágenes). Es donde el panel guarda las imágenes de proyectos/certis.

> Resultado: `api/`, `admin/` y `uploads/` quedan como “hermanos” de `db.php` y
> `config.php`. Es lo que esperan las rutas del código. No cambies esa estructura.
>
> **CSP y seguridad:** no tienes que configurar nada. Las páginas estáticas ya
> traen su CSP estricta (hashes automáticos por build) y el panel fija la suya.

---

## 6. Crea tu usuario de administrador

1. En el navegador, ve a **`https://TU-DOMINIO/admin/setup.php`**.
2. Elige tu **usuario** y **contraseña** (mínimo 8 caracteres) y créalo.
   → Usa una larga de verdad: luego puedes cambiarla en **Panel → Seguridad**,
   donde se exigen 12 caracteres.
3. **MUY IMPORTANTE:** vuelve a FileZilla y **BORRA** `public_html/admin/setup.php`.
   (Por seguridad; una vez creado el admin ya no hace falta. El panel te
   recordará que lo borres mientras siga ahí.)
4. Entra en **`https://TU-DOMINIO/admin/`** con tus credenciales.

---

## 7. Comprueba que todo funciona

- **`https://TU-DOMINIO/`** → se ve el portfolio en español.
- **`https://TU-DOMINIO/en/`** → versión en inglés.
- Sección **Proyectos** y **Certificaciones** → cargan las tarjetas (vienen de MySQL).
- **Formulario de contacto** → envía un mensaje de prueba.
  - Debe aparecer en **`/admin/messages.php`**.
  - Y deberías recibir el email de aviso (revisa spam la primera vez).
- **Analítica** → tras unas visitas, revisa **`/admin/analytics.php`**.

Si Proyectos/Certis muestran “No se pudieron cargar”, revisa el paso 3–5
(base de datos y `config.php`). Pon temporalmente `'debug' => true` en
`config.php` para ver el detalle del error, y vuelve a `false` al terminar.

---

## 8. Notas sobre el email de contacto

- El aviso se envía con la función `mail()` de PHP (incluida en CDMON).
- Para que **no caiga en spam**, usa un `from` de **tu propio dominio**
  (p.ej. `no-reply@eduolihez.com`) y, si puedes, añade un registro **SPF** en el
  DNS de CDMON. Aunque falle el email, **el mensaje siempre se guarda en MySQL**
  y, como red de seguridad, también se intenta enviar por **Formspree**.
- ¿Prefieres SMTP autenticado (Gmail, etc.)? Se puede añadir PHPMailer más
  adelante; para empezar, `mail()` + Formspree es suficiente.

---

## 9. Actualizar el sitio más adelante

**Sin recompilar nada** (desde `/admin`, se ve al recargar la web):

| Qué | Dónde |
|---|---|
| Proyectos y certificaciones | Panel → Proyectos / Certificaciones |
| Badge "Disponible para trabajar" | Panel → Ajustes |
| Activar o desactivar el formulario de contacto | Panel → Ajustes |
| Activar o desactivar el registro de visitas | Panel → Ajustes |
| Aviso destacado en la franja superior | Panel → Ajustes |
| Leer, archivar y exportar mensajes | Panel → Mensajes |
| Cambiar tu contraseña, desbloquear IPs | Panel → Seguridad |
| Descargar/restaurar copia de seguridad | Panel → Backup |

**Recompilando** (`npm run build` + subir `dist/`):

| Qué | Archivo |
|---|---|
| Experiencia laboral | `src/data/experience.ts` |
| Habilidades | `src/data/skills.ts` |
| Preguntas frecuentes (FAQ + SEO + IA) | `src/data/faq.ts` |
| Textos de la interfaz (ES/EN/CA) | `src/i18n/ui.ts` |
| Datos personales, ubicación, redes | `src/config.ts` |
| Título y descripción de cada idioma | `src/pages/index.astro`, `en/`, `ca/` |
| Colores y estilos | `tailwind.config.mjs`, `src/styles/global.css` |

Pasos: edita → `npm run build` → sube el **contenido de `dist/`** a
`public_html/` (sobrescribe; **no toques** `api/`, `admin/`, `lib/`, `db.php`,
`config.php` ni `uploads/`).

> Al cambiar `src/data/faq.ts` se actualizan a la vez la sección visible de la
> web, el dato estructurado que lee Google y el archivo `/llms.txt` que leen
> las IAs. Un solo sitio, tres destinos.

---

## 10. Problemas frecuentes

| Síntoma | Causa probable / solución |
|---|---|
| Error 500 al abrir la web | Falta `config.php` o credenciales MySQL incorrectas. |
| “Falta config.php” en JSON | No subiste `config.php` a la raíz. |
| **Pantalla amarilla “Falta actualizar la base de datos”** | **No importaste `database/migration-v2.sql`. Hazlo desde phpMyAdmin.** |
| Proyectos no cargan | Revisa que importaste `schema.sql` y que la DB tiene datos. |
| El `.htaccess` no aparece en FTP | Activa “mostrar archivos ocultos” en FileZilla. |
| El panel da 419 / token inválido | Recarga la página de login (cookies de sesión). |
| Te expulsa del panel al rato | Normal: la sesión caduca a las 2 h sin actividad. Ajustable en `config.php`. |
| Te bloqueaste al fallar la contraseña | Espera 15 min, o desbloquea tu IP desde **Seguridad** entrando desde otra red. |
| La analítica no registra visitas | Comprueba **Ajustes → Registrar visitas**, y que aplicaste la migración. |
| No llega el email | Normal si no hay SPF; el mensaje igualmente está en `/admin/messages.php`. |
| Se ve sin estilos | No subiste la carpeta `_astro/` completa de `dist/`. |
| El sitio no carga por HTTP (solo HTTPS) | Es a propósito: HSTS está activo en `.htaccess`. |

---

¿Todo listo? 🎯 Tu portfolio ya está online, es rápido, bilingüe y lo gestionas
tú mismo desde `/admin`.
