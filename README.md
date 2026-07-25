# Portfolio — Eduardo Olivares Hernández

Portfolio profesional trilingüe (ES/EN/CA) orientado a reclutadores de ciberseguridad.
Diseño oscuro, minimalista y rápido, pensado para **hosting compartido CDMON**
(archivos estáticos + PHP/MySQL, sin Node en producción).

> 👉 **¿Empiezas de cero? Sigue la guía paso a paso: [GUIA.md](GUIA.md)** — cubre
> todo, desde instalarlo en tu ordenador hasta dejarlo online y gestionarlo.

## 🧱 Stack

| Capa | Tecnología |
|---|---|
| Frontend | **Astro 5** (salida 100% estática) + **Tailwind CSS** + TypeScript |
| Idiomas | i18n nativo — ES en `/`, EN en `/en/`, **CA** en `/ca/` |
| Backend | **PHP 8** (procedural, PDO) + **MySQL/MariaDB** |
| Contacto | PHP + MySQL con **respaldo Formspree** |
| Analítica | Propia (tabla `visits`, IP hasheada, sin cookies ni terceros) |
| Panel admin | PHP con login por sesión: contenido, buzón, analítica, seguridad, backup |
| SEO | Schema.org (Person/ProfilePage/FAQPage), `hreflang`, sitemap generado, `llms.txt` |

## 📂 Estructura

```
NewPortfolio/
├─ src/                       # Frontend Astro
│  ├─ components/             # Hero, Experience, Projects, Certifications, Faq, Contact...
│  ├─ data/
│  │  ├─ experience.ts        # Experiencia (estática, se edita aquí)
│  │  ├─ skills.ts            # Habilidades por categoría
│  │  └─ faq.ts               # FAQ → sección visible + Schema.org + llms.txt
│  ├─ i18n/                   # Traducciones ES/EN/CA
│  ├─ layouts/                # BaseLayout (head, SEO, header, footer)
│  ├─ pages/
│  │  ├─ index.astro          # ES · en/ · ca/ · 400 · 403 · 404 · 500
│  │  ├─ llms.txt.ts          # Resumen para IAs (generado al compilar)
│  │  └─ sitemap.xml.ts       # Sitemap con hreflang y lastmod (generado)
│  ├─ styles/global.css       # Tokens + estilos base
│  └─ config.ts               # ⚙️ Datos personales, ubicación, enlaces, endpoints
├─ public/                    # Imágenes, CV, favicon, robots.txt, humans.txt
├─ server/                    # Backend PHP (se sube al hosting)
│  ├─ config.example.php      # → copiar a config.php con tus credenciales
│  ├─ db.php                  # Conexión PDO
│  ├─ lib/
│  │  ├─ bootstrap.php        # Arranque: errores, ajustes, auditoría
│  │  ├─ http.php             # Helpers del API
│  │  ├─ ua.php               # Navegador / SO / bots / países
│  │  └─ upload.php           # Subida validada de imágenes
│  ├─ api/                    # projects · certifications · contact · visit · settings
│  ├─ admin/                  # Panel: contenido, mensajes, analítica, seguridad, backup
│  └─ .htaccess               # → va a la raíz del hosting
├─ database/
│  ├─ schema.sql              # Tablas + datos de ejemplo (instalación nueva)
│  └─ migration-v2.sql        # ⚠️ Actualización para bases de datos ya existentes
├─ DEPLOY.md                  # 👉 Guía paso a paso para subir a CDMON
├─ SEO.md                     # 🔎 Qué hace la web sola y qué tienes que hacer tú
└─ CLOUDFLARE.md              # ☁️ CDN, WAF, IP real, Turnstile
```

## 🚀 Desarrollo local

```bash
npm install
npm run dev      # http://localhost:4321
```

> En local **no hay PHP**, así que Proyectos/Certificaciones mostrarán su mensaje
> de error y el formulario usará el respaldo Formspree. Es lo esperado.
> Para probar el backend completo necesitas PHP+MySQL (ver DEPLOY.md) o
> [Laragon](https://laragon.org/)/XAMPP en local.

## 🏗️ Compilar para producción

```bash
npm run build    # genera la carpeta dist/
```

Sube el contenido de `dist/` + la carpeta `server/` a tu hosting CDMON.
**Todos los pasos detallados están en [DEPLOY.md](DEPLOY.md).**

## ✏️ Tareas de mantenimiento habituales

### Sin recompilar (desde `/admin`, se ve al recargar la web)

| Quiero... | Dónde |
|---|---|
| Añadir/editar proyectos y certificaciones | Proyectos · Certificaciones |
| Publicar, destacar, reordenar o duplicar | Botones de la propia lista |
| Activar/desactivar "Disponible para trabajar" | Ajustes |
| Encender/apagar el formulario de contacto | Ajustes |
| Encender/apagar el registro de visitas | Ajustes |
| Poner un aviso en la franja superior (ES/EN/CA) | Ajustes |
| Leer, buscar, archivar y exportar mensajes | Mensajes |
| Ver visitas, canales, navegadores, países, bots | Analítica |
| Cambiar contraseña, ver accesos, desbloquear IPs | Seguridad |
| Descargar o restaurar una copia de seguridad | Backup |

### Recompilando (`npm run build` + subir `dist/`)

| Quiero... | Dónde |
|---|---|
| Cambiar textos fijos (menú, botones...) | `src/i18n/ui.ts` (ES/EN/CA) |
| Editar mi experiencia | `src/data/experience.ts` |
| Editar mis habilidades (skills) | `src/data/skills.ts` |
| Editar las preguntas frecuentes | `src/data/faq.ts` (afecta a web + SEO + IAs) |
| Cambiar foto, CV, ubicación, enlaces | `src/config.ts` |
| Cambiar títulos/descripciones de SEO | `src/pages/index.astro`, `en/`, `ca/` |
| Regenerar iconos/favicon | `npm run icons` |

## 🔒 Seguridad incluida

- Contraseñas con `password_hash()` (bcrypt) + rehash automático; sesiones
  seguras (HttpOnly, SameSite, `use_strict_mode`) con **caducidad** por
  inactividad y absoluta.
- **Bloqueo por fuerza bruta** en el login, con desbloqueo manual desde el panel.
- **CSRF** en todo el panel, incluido el logout (que además es POST).
- Consultas **preparadas** (PDO, sin emulación) → sin inyección SQL.
- **CSP estricta** con hashes automáticos (sin `unsafe-inline` en scripts).
- Escapado anti-XSS en el panel; render seguro + saneo de URLs en el frontend.
- **Subida de imágenes** doblemente validada (MIME real + `getimagesize` + tope
  de dimensiones) y carpeta `uploads/` sin ejecución de código.
- **Exportaciones CSV** protegidas contra inyección de fórmulas en Excel.
- Correo de contacto a prueba de **inyección de cabeceras**.
- **IP real segura** por defecto (no se fía de cabeceras falsificables salvo con
  Cloudflare); IPs de analítica **hasheadas** (RGPD-friendly, sin cookies).
- Errores **nunca visibles** en producción (solo al log del hosting).
- **Registro de auditoría**: cada cambio del panel queda anotado con usuario,
  IP y fecha.
- HSTS, `nosniff`, `X-Frame-Options`, `Referrer-Policy` y `X-Robots-Tag` en el
  `.htaccess`; `.well-known/security.txt` (RFC 9116).

Guía de Cloudflare (CDN, WAF, país del visitante, Turnstile): [CLOUDFLARE.md](CLOUDFLARE.md).

## 🔎 SEO y visibilidad en IAs

Datos estructurados de Schema.org (`Person`, `WebSite`, `ProfilePage`,
`FAQPage`, `BreadcrumbList`) enlazados en un solo grafo, `hreflang` completo,
señales geográficas de Badalona/Barcelona, sitemap generado con `lastmod`,
FAQ visible y **`/llms.txt`** para que ChatGPT, Claude o Perplexity puedan
responder con precisión sobre ti.

**Lo que hace la web sola y lo que tienes que hacer tú: [SEO.md](SEO.md).**

## 📌 Antes de publicar (checklist rápida)

- [ ] Poner foto en `public/img/eduardo.webp` y una portada `og-cover.png` (1200×630).
- [ ] `npm run icons` (genera favicon y iconos PWA).
- [ ] Poner los CV en `public/cv/` (ES, EN y CA).
- [ ] Revisar dominio en `src/config.ts` y `astro.config.mjs`.
- [ ] `npm run build`.
- [ ] Seguir [DEPLOY.md](DEPLOY.md): subir archivos, crear DB, `config.php`, permisos de `uploads/`, crear admin.
- [ ] **Borrar `server/admin/setup.php`** tras crear tu usuario.
- [ ] Revisar **Panel → Seguridad**: la tabla de comprobación debe salir en verde.
- [ ] (Opcional) Configurar Cloudflare y Turnstile → [CLOUDFLARE.md](CLOUDFLARE.md).
- [ ] Enviar el sitemap a Google y Bing → [SEO.md](SEO.md).

## 🔄 ¿Ya lo tienes publicado y vas a actualizar?

Aplica **`database/migration-v2.sql`** desde phpMyAdmin *antes* de subir los
archivos nuevos. Pasos completos en
[DEPLOY.md → Actualizar una web ya publicada](DEPLOY.md#-actualizar-una-web-ya-publicada-v2).
