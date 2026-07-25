# 🔎 Guía de SEO: que te encuentren en Badalona y Barcelona

Este documento explica **qué hace ya la web sola** y **qué tienes que hacer tú
fuera de la web**. La segunda parte es la que de verdad mueve la aguja: el
código ya está todo lo optimizado que puede estar, pero Google no posiciona a
nadie solo por tener buen HTML.

---

## Parte 1 · Lo que ya está hecho en el código

No tienes que tocar nada de esto. Es solo para que sepas qué hay y por qué.

### Palabras clave locales donde importan

| Sitio | Qué dice ahora |
|---|---|
| `<title>` | "Eduardo Olivares \| Analista SOC en **Badalona, Barcelona**" |
| Meta descripción | Puesto + ubicación + tecnologías + certificaciones |
| `<h1>` | Tu nombre (correcto: la marca personal es el nombre) |
| Hero | "Badalona, Barcelona (España)" visible |
| Pie de página | Ubicación + email visibles en todas las páginas |
| FAQ | Preguntas del tipo "¿da servicio en Badalona y Barcelona?" |

El título va **antes** que nada porque es lo único que Google muestra siempre.
Poner ahí la ciudad es el 80% del SEO local en una web de una sola página.

### Datos estructurados (Schema.org)

Un único bloque JSON-LD con cinco entidades enlazadas entre sí:

- **`Person`** — quién eres. Incluye `address` (Badalona), `homeLocation` con
  coordenadas, `workLocation` (Badalona, Barcelona, área metropolitana,
  Cataluña, España, remoto), `knowsAbout` (42 temas), `knowsLanguage`,
  `worksFor`, `hasOccupation` con el código oficial de analista de seguridad y
  tu trayectoria completa.
- **`WebSite`** — el sitio, atribuido a ti.
- **`ProfilePage`** — esta página es tu perfil profesional.
- **`FAQPage`** — las 8 preguntas. Es lo que puede hacer que Google muestre
  desplegables debajo de tu resultado.
- **`BreadcrumbList`** — migas de pan.

> Compruébalo cuando publiques:
> [Prueba de resultados enriquecidos](https://search.google.com/test/rich-results)
> y [validator.schema.org](https://validator.schema.org/).

### Señales geográficas

Etiquetas `geo.region` (ES-CT), `geo.placename` (Badalona, Barcelona),
`geo.position` e `ICBM` con las coordenadas del municipio. Google ya casi no
las usa, pero sí varios agregadores y buscadores de nicho, y no cuestan nada.

### Multiidioma bien resuelto

`hreflang` completo (es, es-ES, en, ca, ca-ES, x-default) en el `<head>` **y**
en el `sitemap.xml`. Sin esto, Google puede tomar las tres versiones por
contenido duplicado en vez de por traducciones.

### Para las IAs

- **`/llms.txt`** — resumen tuyo en texto plano, sin HTML: identidad,
  ubicación, especialidades, experiencia, certificaciones y las 8 preguntas
  frecuentes con sus respuestas. Es lo que lee un modelo de lenguaje cuando le
  preguntan por ti. Se genera solo al compilar, así que nunca se desactualiza.
- **`robots.txt`** — permite explícitamente a GPTBot, OAI-SearchBot,
  ChatGPT-User, ClaudeBot, PerplexityBot, Google-Extended, Applebot-Extended,
  CCBot y Meta AI. Y bloquea los rastreadores de SEO comercial (Semrush,
  Ahrefs, MJ12, Dot, Petal) que solo gastan ancho de banda.
- **La FAQ visible** — respuestas cortas y autosuficientes, que es el formato
  que las IAs citan bien.

### Sitemap que se actualiza solo

Antes era un archivo fijo sin `<lastmod>`; Google no sabía si algo había
cambiado. Ahora se genera en cada `npm run build` con la fecha del día.

### Rendimiento (que también es SEO)

Ya estaba bien y sigue igual: HTML estático, un único archivo JS de 4,5 KB,
tipografías autoalojadas con subset latino, imágenes con `loading="lazy"`,
caché larga en `.htaccess` y CDN de Cloudflare delante.

---

## Parte 2 · Lo que tienes que hacer tú (por orden de impacto)

### 1. Google Search Console — hazlo hoy

Sin esto Google puede tardar semanas en enterarse de que existes.

1. Entra en [search.google.com/search-console](https://search.google.com/search-console).
2. Añade la propiedad **`eduolihez.com`** (tipo *Dominio*, se verifica con un
   registro TXT en el DNS de Cloudflare).
3. **Sitemaps** → envía `sitemap.xml`.
4. **Inspección de URLs** → pega `https://eduolihez.com/` → **Solicitar
   indexación**. Repite con `/en/` y `/ca/`.
5. Vuelve en 2 semanas y mira **Rendimiento → Consultas**: ahí verás con qué
   palabras te está encontrando la gente de verdad.

### 2. Bing Webmaster Tools — 5 minutos, y alimenta a ChatGPT

Bing importa más de lo que parece: **ChatGPT y Copilot buscan a través del
índice de Bing**. Si no estás en Bing, no apareces ahí.

[bing.com/webmasters](https://www.bing.com/webmasters) → permite importar la
configuración directamente desde Search Console. Envía el sitemap igualmente.

### 3. LinkedIn — es tu backlink más valioso

Google usa `sameAs` para confirmar que la persona del perfil y la de la web son
la misma. Para que funcione, el enlace tiene que ir en los dos sentidos:

- Perfil de LinkedIn → sección **Contacto** → añade `https://eduolihez.com`.
- En el **titular**, escribe la ubicación de forma natural:
  *"SOC Analyst · Blue Team · Badalona/Barcelona"*.
- Ubicación del perfil: **Badalona, Cataluña, España** (no solo "España").
- Publica de vez en cuando enlazando a la web. Cada visita real desde LinkedIn
  es señal de que el sitio importa. La verás en **Panel → Analítica → Canales**.

### 4. GitHub — el segundo backlink gratis

En tu perfil de GitHub, campo **Website**: `https://eduolihez.com`.
En la **Bio**: "SOC Analyst · Blue Team · Badalona, Barcelona".

### 5. Perfil de empresa de Google (si algún día trabajas por tu cuenta)

Si en el futuro ofreces servicios de ciberseguridad como autónomo, un
[Perfil de Empresa de Google](https://business.google.com) con dirección en
Badalona es **con diferencia** lo que más te posiciona en búsquedas locales:
te mete en el mapa y en el paquete local de resultados.

Como empleado por cuenta ajena no aplica: no te lo montes solo por SEO,
Google verifica direcciones y no quieres una penalización.

### 6. Directorios y perfiles profesionales

Cada perfil con tu nombre + Badalona/Barcelona + enlace a la web refuerza la
señal. Prioriza calidad sobre cantidad:

- **Credly / Acclaim** — tus insignias de Fortinet, Microsoft y Trend Micro.
  Enlaza la web desde el perfil.
- **InfoJobs / LinkedIn Jobs** — perfil con la ubicación bien puesta.
- **Comunidades de ciberseguridad españolas** — foros, Discord, asociaciones
  catalanas del sector.
- **Meetups y charlas** — las páginas de eventos suelen enlazar a los ponentes.

> ⚠️ **No compres enlaces ni te des de alta en 200 directorios de golpe.**
> Google detecta los patrones y penaliza. Diez enlaces buenos valen más que
> doscientos malos.

### 7. Publica algo, aunque sea poco

Una web que nunca cambia se estanca. La forma más barata de dar señales de
actividad sin montar un blog:

- **Añade proyectos** desde el panel según los vayas terminando.
- **Añade certificaciones** en cuanto las saques.
- **Amplía la FAQ** (`src/data/faq.ts`) cuando te repitan una pregunta. Cada
  pregunta nueva es una consulta más por la que puedes salir, y una respuesta
  más que las IAs pueden citar.

La base de datos ya tiene una tabla `posts` preparada por si algún día quieres
notas técnicas. Escribir sobre análisis de phishing o detección con XDR sería
el siguiente salto real de posicionamiento, pero solo si vas a mantenerlo.

---

## Parte 3 · Cómo saber si está funcionando

Todo esto lo tienes en **Panel → Analítica**, sin Google Analytics ni cookies:

| Qué mirar | Dónde | Qué te dice |
|---|---|---|
| Canales de tráfico | Analítica → Canales | Cuánto llega por **Búsqueda** (Google/Bing) y cuánto por **IA / Chatbots** |
| Bots y rastreadores | Analítica → Bots | Si aparecen Googlebot, Bingbot, GPTBot o ClaudeBot: te están indexando |
| Países | Analítica → Países | Requiere Cloudflare activo |
| Páginas | Analítica → Páginas | Qué idioma se consulta más |
| Referrers | Analítica → Origen | Si LinkedIn te está trayendo gente |

La sección **IA / Chatbots** agrupa las visitas llegadas desde ChatGPT, Claude,
Perplexity, Gemini y Copilot. Cuando empiece a subir, es la prueba de que las
IAs están citando tu web.

### Plazos realistas

| Cuándo | Qué esperar |
|---|---|
| 1–3 días | Google indexa la web tras solicitar la indexación |
| 1–2 semanas | Empiezas a salir buscando tu nombre |
| 1–2 meses | Aparecen las primeras consultas locales en Search Console |
| 3–6 meses | Posiciones estables en "analista SOC Badalona" y similares |
| 2–6 meses | Las IAs empiezan a citarte (dependen de rastreos periódicos) |

Nadie posiciona en una semana. Quien te lo prometa, te está vendiendo humo.

---

## Comprobaciones rápidas

```
https://eduolihez.com/robots.txt      → permisos de rastreo
https://eduolihez.com/sitemap.xml     → <lastmod> con la fecha del último build
https://eduolihez.com/llms.txt        → tu resumen para las IAs
```

Herramientas:

- [Rich Results Test](https://search.google.com/test/rich-results) — que detecte `Person` y `FAQPage`
- [validator.schema.org](https://validator.schema.org/) — datos estructurados sin errores
- [PageSpeed Insights](https://pagespeed.web.dev/) — rendimiento y Core Web Vitals
- [metatags.io](https://metatags.io/) — cómo se ve la tarjeta al compartir el enlace
