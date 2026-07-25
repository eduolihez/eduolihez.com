# 📘 Guía completa: setup + configuración de la web

Guía de principio a fin, pensada para seguir **en orden** sin conocimientos de
servidores. Al terminar tendrás tu portfolio online, trilingüe (ES/EN/CA) y
gestionable desde un panel privado.

> Documentos relacionados: **[DEPLOY.md](DEPLOY.md)** (resumen de despliegue) ·
> **[CLOUDFLARE.md](CLOUDFLARE.md)** (CDN, países y captcha).

---

## 🗺️ Mapa rápido (de qué va cada cosa)

```
1. Ordenador (local) ─ npm install / dev / build ──► genera la carpeta dist/
2. Personalizas ────── src/config.ts, imágenes, CV, textos, experiencia, skills
3. CDMON ───────────── creas base de datos MySQL + importas schema.sql
4. Backend ─────────── rellenas server/config.php (credenciales)
5. FTP ─────────────── subes dist/ + server/ a public_html/
6. Admin ───────────── creas tu usuario y gestionas la web sin recompilar
```

- **Contenido fijo** (foto, textos, experiencia, skills, diseño) → se edita en el
  código y requiere **recompilar** (`npm run build`) y volver a subir.
- **Contenido dinámico** (proyectos, certificaciones, "Open to work", mensajes,
  analítica) → se gestiona desde **`/admin`**, **sin recompilar**.

---

## Parte 0 — Qué necesitas

- **Node.js 18+** en tu ordenador → <https://nodejs.org> (instala la versión LTS).
- Un cliente **FTP/SFTP**: [FileZilla](https://filezilla-project.org/) (gratis).
- Tu **hosting CDMON** con **PHP 8+** y **una base de datos MySQL** (ambos vienen
  en los planes normales).
- Tus datos de acceso **FTP** y **MySQL** (los da CDMON en su panel).

Comprueba que tienes Node:
```bash
node --version    # debe salir v18 o superior
```

---

## Parte 1 — Ponlo en marcha en tu ordenador (local)

Desde la carpeta del proyecto (`NewPortfolio`):

```bash
npm install       # instala dependencias (solo la primera vez)
npm run dev       # arranca el servidor de desarrollo
```

Abre **<http://localhost:4321>**. Verás la web en vivo; cada cambio que guardes
se recarga solo.

> ⚠️ **En local no hay PHP ni MySQL.** Por eso, en `npm run dev`:
> - Proyectos y Certificaciones mostrarán "No se pudieron cargar" (normal).
> - El formulario usará el respaldo **Formspree**.
> - El panel `/admin` **no** funciona en local (necesita PHP).
>
> Todo eso funciona una vez subido a CDMON. Si quieres probar el backend en
> local, instala [Laragon](https://laragon.org/) o XAMPP (opcional, avanzado).

Para parar el servidor: `Ctrl + C`.

---

## Parte 2 — Personaliza tus datos

### 2.1. Datos principales → `src/config.ts`

Es el **archivo central**. Ábrelo y revisa:

| Campo | Qué es |
|---|---|
| `domain` | Tu dominio final (ej. `https://eduolihez.com`). |
| `name` / `shortName` | Tu nombre completo / corto. |
| `jobTitle` | Titular corto (aparece en datos SEO). |
| `avatar` | Ruta de tu foto (`/img/eduardo.webp`). |
| `ogImage` | Imagen para redes (1200×630). |
| `cv.es` / `cv.en` / `cv.ca` | Rutas de tus PDF de CV. |
| `vcard` | Ruta de la tarjeta de contacto `.vcf`. |
| `social.linkedin/github/email` | Tus enlaces. |
| `apiBase` | **Déjalo en `''`** (el backend va en el mismo dominio). |
| `formspree` | Tu endpoint de respaldo (ya puesto). |
| `turnstileSiteKey` | Solo si activas el captcha (ver CLOUDFLARE.md). |

> Si cambias de dominio, actualízalo **también** en `astro.config.mjs` → `site`.

### 2.2. Imágenes

Coloca en `public/`:

- **`public/img/eduardo.webp`** — tu foto (cuadrada, ≥512×512).
- **`public/img/og-cover.png`** — portada para LinkedIn (1200×630). Se genera un
  placeholder automáticamente; sustitúyelo por uno con tu foto/nombre cuando puedas.

Genera los **iconos/favicon** (PNG reales, sin dibujar nada):
```bash
npm run icons
```
Esto crea `favicon-32.png` y los iconos PWA (192/512/apple-touch) a partir del logo.

> Optimiza las imágenes antes de subir (<https://squoosh.app>): foto < 80 KB.

### 2.3. CV descargables

Pon tus PDF en `public/cv/` con estos nombres exactos:
- `CV-Eduardo-Olivares-ES.pdf`
- `CV-Eduardo-Olivares-EN.pdf`
- `CV-Eduardo-Olivares-CA.pdf`

### 2.4. Textos de la interfaz (ES/EN/CA) → `src/i18n/ui.ts`

Menú, botones, títulos de sección, etc. Cada texto tiene su versión en `es`, `en`
y `ca`. Edita el valor y guarda.

### 2.5. Experiencia → `src/data/experience.ts`

Tu timeline profesional. Cada puesto tiene `role`, `period`, `description` en
`es`/`en` (en catalán cae a español) y su lista de `tech`. El orden del array es
el orden en pantalla (arriba = más reciente).

### 2.6. Habilidades → `src/data/skills.ts`

Skills agrupadas por categoría. Edita las listas o añade grupos.

> **Proyectos y certificaciones NO se editan aquí**: son dinámicos, se gestionan
> desde `/admin` (Parte 8).

### 2.7. Datos personales en la vCard y security.txt (opcional)

- `public/eduardo-olivares.vcf` — tu tarjeta de contacto (nombre, email, enlaces).
- `public/.well-known/security.txt` — contacto de seguridad (actualiza `Expires`
  una vez al año).

---

## Parte 3 — Compila la web

```bash
npm run build
```

Genera la carpeta **`dist/`** (el sitio estático listo para subir). Hazlo cada
vez que cambies contenido fijo, diseño o textos.

Para ver el resultado final **con la CSP real** (como en producción):
```bash
npm run preview   # sirve dist/ en http://localhost:4321
```

---

## Parte 4 — Base de datos MySQL en CDMON

1. Panel de **CDMON → Bases de datos MySQL**.
2. **Crea una base de datos** (ej. `portfolio`).
3. **Crea un usuario** MySQL y **asígnalo** a esa base con **todos los permisos**.
4. Apunta 4 datos: **host** (normalmente `localhost`), **nombre de la base**,
   **usuario** y **contraseña**.

### Importar las tablas
1. Abre **phpMyAdmin** desde CDMON.
2. Selecciona a la izquierda **tu base de datos**.
3. Pestaña **Importar** → elige el archivo **`database/schema.sql`** → **Continuar**.

Esto crea todas las tablas y **datos de ejemplo** (tus 5 proyectos y 7 certis).

---

## Parte 5 — Configura el backend → `server/config.php`

1. En tu ordenador, **copia** `server/config.example.php` y renómbralo a
   **`server/config.php`**.
2. Rellénalo:

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
    'to'      => 'eduardo@eduolihez.com',        // dónde recibes los avisos
    'from'    => 'no-reply@eduolihez.com',      // usa una dirección de TU dominio
    'subject_prefix' => '[Portfolio] ',
],

'security' => [
    'allowed_origin' => '',                     // mismo dominio: déjalo vacío
    'contact_max_per_window' => 5,              // anti-spam del formulario
    'contact_window_minutes' => 60,
    'ip_salt' => 'PON_AQUI_UNA_CADENA_LARGA_Y_ALEATORIA',   // ← cámbiala
    'trust_proxy' => false,                     // true SOLO con Cloudflare
    'login_max_attempts' => 5,                  // bloqueo de fuerza bruta
    'login_lockout_minutes' => 15,
],

'turnstile' => [                                // captcha opcional (déjalo vacío)
    'site_key'   => '',
    'secret_key' => '',
],

'uploads' => [                                  // subida de imágenes del panel
    'dir'         => __DIR__ . '/uploads',
    'url_base'    => '/uploads',
    'max_bytes'   => 3 * 1024 * 1024,           // 3 MB
    'allowed_ext' => ['jpg', 'jpeg', 'png', 'webp', 'gif'],
],

'debug' => false,                               // true solo mientras depuras
```

> 🔐 `config.php` **nunca** se sube a GitHub (está en `.gitignore`). Solo va al
> hosting. Cambia **`ip_salt`** por una cadena larga y aleatoria propia.

---

## Parte 6 — Sube los archivos por FTP

Conéctate con FileZilla. La raíz web de CDMON suele ser **`public_html`**. Deja
la estructura así:

```
public_html/                    ← RAÍZ WEB
├─ index.html  en/  ca/  404.html      ┐
├─ _astro/                             │  (todo el CONTENIDO de dist/)
├─ img/  cv/  favicon.svg  favicon-32.png
├─ .well-known/security.txt            │
├─ eduardo-olivares.vcf                │
├─ robots.txt  sitemap.xml             ┘
│
├─ .htaccess                 ┐
├─ config.php                │
├─ db.php                    │  (todo el CONTENIDO de server/)
├─ lib/                      │
├─ api/                      │
├─ admin/                    │
└─ uploads/                  ┘
```

### Pasos
1. **Sube el CONTENIDO de `dist/`** (lo de dentro, no la carpeta) a `public_html/`.
2. **Sube el CONTENIDO de `server/`** a `public_html/` (incluye `config.php`,
   `db.php`, `lib/`, `api/`, `admin/`, `uploads/` y **`.htaccess`**).
   - ⚠️ FileZilla: menú **Servidor → Forzar mostrar archivos ocultos** para ver
     los `.htaccess` y `.well-known/`.
   - **No subas** `config.example.php`.
3. **Permisos de `uploads/`**: clic derecho → **Permisos** → `755` (o `775` si no
   te deja subir imágenes desde el panel).

> `api/`, `admin/` y `uploads/` deben quedar como "hermanos" de `db.php` y
> `config.php`. No cambies esa estructura (las rutas del código lo esperan).
>
> **No hay que configurar la seguridad a mano:** las páginas estáticas ya traen
> su CSP (hashes automáticos) y el panel fija la suya.

---

## Parte 7 — Crea tu usuario de administrador

1. Ve a **`https://TU-DOMINIO/admin/setup.php`**.
2. Elige **usuario** y **contraseña** (mínimo 8 caracteres). Créalo.
3. **⚠️ BORRA `admin/setup.php`** por FTP (por seguridad; ya no hace falta).
4. Entra en **`https://TU-DOMINIO/admin/`** con tus credenciales.

---

## Parte 8 — Gestiona la web desde `/admin`

| Sección | Para qué |
|---|---|
| **Panel** | Resumen: proyectos, certis, mensajes sin leer, visitas. |
| **Proyectos** | Crear/editar/borrar proyectos. Título, resumen y descripción en ES/EN, stack, enlaces (repo/demo/tienda), imagen (subida o URL), destacado, orden, publicado/borrador. |
| **Certificaciones** | Crear/editar/borrar. Nombre, emisor, fecha, URL de verificación, logo (subida o URL), orden, visible. |
| **Mensajes** | Buzón del formulario. Leer, responder, marcar, borrar y **exportar CSV**. |
| **Analítica** | Visitas por día, países, dispositivos y orígenes, con rango de fechas. |
| **Ajustes** | Interruptor **"Disponible para trabajar"** (muestra/oculta el badge del hero). |

> Todo esto se aplica **al instante**, sin recompilar ni volver a subir nada.

**Añade tus 6 certificaciones que faltan** aquí (el seed trae 7 de tus 13).

---

## Parte 9 — Comprobaciones finales

- `https://TU-DOMINIO/` → web en español (y `/en/`, `/ca/`).
- Proyectos y Certificaciones **cargan** (vienen de MySQL).
- Envía un **mensaje de prueba** → aparece en `/admin/messages.php` y te llega el
  email (revisa spam la primera vez).
- Comparte tu enlace en LinkedIn → debe salir la **tarjeta con imagen** (og-cover).

Si algo dinámico falla, pon `'debug' => true` en `config.php` para ver el detalle
del error y vuelve a `false` al terminar.

---

## Parte 10 — (Opcional) Cloudflare + captcha

Para CDN, protección, país del visitante y captcha invisible, sigue
**[CLOUDFLARE.md](CLOUDFLARE.md)**. Resumen:
1. Conecta el dominio a Cloudflare.
2. Pon `'trust_proxy' => true` en `config.php` (para IP real y países).
3. (Opcional) Activa Turnstile: claves + añadir `challenges.cloudflare.com` a la
   CSP en `astro.config.mjs` + recompilar.

---

## Parte 11 — Actualizar la web más adelante

**Cambios dinámicos** (proyectos, certis, ajustes, leer mensajes) → desde
`/admin`, sin tocar código.

**Cambios de diseño/textos/experiencia/skills**:
1. Edita el código en tu ordenador.
2. `npm run build`.
3. Sube de nuevo el **contenido de `dist/`** a `public_html/` (sobrescribe).
   **No toques** `api/`, `admin/`, `db.php`, `config.php`, `uploads/`.

> Si editas algún `<script>` de un componente, la CSP se recalcula sola en el
> build (hashes). Solo si añades un script externo de otro dominio tendrás que
> añadirlo en `astro.config.mjs → experimental.csp`.

---

## Parte 12 — Problemas frecuentes

| Síntoma | Solución |
|---|---|
| Error 500 al abrir la web | Falta `config.php` o credenciales MySQL mal. |
| "Falta config.php" (JSON) | No subiste `config.php` a la raíz. |
| Proyectos/certis no cargan | ¿Importaste `schema.sql`? ¿La base tiene datos? |
| No puedo subir imágenes en el panel | Permisos de `uploads/` a `775`. |
| El `.htaccess` no aparece en FTP | Activa "mostrar archivos ocultos" en FileZilla. |
| El panel da 419 / token inválido | Recarga la página de login (cookies de sesión). |
| Bloqueado en el login | Espera los minutos de `login_lockout_minutes`. |
| No llega el email | Normal sin SPF; el mensaje está igual en `/admin/messages.php`. |
| Se ve sin estilos | No subiste la carpeta `_astro/` completa de `dist/`. |
| `astro dev` da error de scan | No pongas literales `<script>`/`<style>` dentro de comentarios `.astro`. |

---

## ✅ Checklist final

- [ ] `npm install` y la web se ve en `npm run dev`.
- [ ] Foto, `og-cover`, iconos (`npm run icons`) y CV (ES/EN/CA) colocados.
- [ ] Revisado `src/config.ts` (dominio, enlaces) y `astro.config.mjs → site`.
- [ ] Textos/experiencia/skills a tu gusto.
- [ ] `npm run build`.
- [ ] Base de datos creada e importado `schema.sql`.
- [ ] `server/config.php` rellenado (¡`ip_salt` cambiada!).
- [ ] Subido `dist/` + `server/` a `public_html/`; permisos de `uploads/`.
- [ ] Admin creado en `/admin/setup.php` y **`setup.php` borrado**.
- [ ] Mensaje de prueba enviado y recibido.
- [ ] Tus 6 certis restantes añadidas desde `/admin`.
- [ ] (Opcional) Cloudflare + Turnstile.

🎯 ¡Listo! Tu portfolio está online, es rápido, trilingüe, seguro y lo gestionas
tú mismo.
