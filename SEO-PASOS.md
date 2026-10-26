# Guía SEO paso a paso (actualizada 26 oct 2026, v2)

Qué cambió respecto a la v1: el blog ya tiene versión catalana completa (29
artículos) y 6 artículos nuevos en español, todo dentro de `database/schema.sql`.
Hay que desplegarlo **en un orden concreto** (paso 1) y tocar un par de cosas
en Cloudflare (paso 2).

> Objetivo realista: dominar tu nombre, "analista SOC / ciberseguridad /
> IAM Barcelona-Badalona" y temas concretos (Entra ID, Microsoft 365, NIS2,
> Vision One, phishing), en español y catalán. No "Barcelona" a secas.

---

## Paso 1 · Desplegar (orden obligatorio, 30 min)

El build de Astro lee los artículos de la API en producción
(`/api/posts.php`). Si compilas **antes** de importar el SQL, `/ca/blog/`
sale vacío y los artículos nuevos no existen. Por eso:

1. **Copia de seguridad.** Admin → Copia de seguridad (JSON) y, en
   phpMyAdmin, Exportar la tabla `posts`.
2. **Importa el SQL.** phpMyAdmin (CDMON) → tu base → Importar →
   `database/schema.sql`. Es idempotente: solo inserta lo que no existe
   (35 artículos: 6 ES nuevos + 29 CA). No toca los 23 que ya tienes.
3. **Comprueba** (navegador privado):
   - `https://eduolihez.com/api/posts.php?lang=ca` → lista de 29 artículos.
   - `https://eduolihez.com/api/posts.php?lang=es` → 29 artículos (23 + 6).
4. **Compila**: `npm run build` (debe decir "53 page(s)" o más, sin errores;
   con los 29 CA saldrán ~88).
5. **Sube por FTP** el contenido de `dist/` y **también `server/.htaccess`**
   (lleva el cambio que deja de redirigir `/ca/blog/` a `/ca/`). Es el
   `.htaccess` de `public_html/`; no pises `config.php`.
6. **Prueba**: `https://eduolihez.com/ca/blog/` debe cargar el listado, no
   redirigir. Un artículo CA debe tener enlaces a su versión en español
   (mira el código fuente: `hreflang="es"` y `hreflang="ca"`).

Si subes el código sin haber importado el SQL, `/ca/blog/` aparece vacío y el
sitemap lo anuncia: vuelve al paso 2 y repite el 4 y el 5.

## Paso 2 · Cloudflare (15 min)

Comprobado en vivo: Cloudflare **no bloquea** a Googlebot, Bingbot, GPTBot ni
ClaudeBot, no inyecta scripts (Rocket Loader / ofuscación de email están
fuera, que es lo correcto con tu CSP) y **no cachea el HTML** (`DYNAMIC`), así
que las páginas nuevas se ven al instante. Lo único que hay que hacer:

1. **Purgar caché** tras subir: Caching → Configuration → Purge Cache →
   *Custom Purge* con estas URLs:
   - `https://eduolihez.com/robots.txt` (se cachea 4 h)
   - `https://eduolihez.com/sitemap.xml`
   - `https://eduolihez.com/sitemap-posts.xml`
   - `https://eduolihez.com/llms.txt`
   - `https://eduolihez.com/llms-blog.txt`
   - `https://eduolihez.com/ca/blog/`
2. **Activar Crawler Hints** (Caching → Configuration → Crawler Hints). Avisa
   a Bing/Yandex (IndexNow) cuando cambia tu contenido. Bing alimenta a
   ChatGPT y Copilot.
3. **Mantén tal cual** (no toques): Bot Fight Mode en modo por defecto, la
   regla de *Bypass cache* para `/api/`, `/admin/`, `/lab-app/`, y HSTS solo
   en el `.htaccess` (ver `CLOUDFLARE.md`).
4. **Redirección cacheada en tu navegador**: el 301 antiguo de `/ca/blog/`
   puede quedar guardado en tu Chrome. Pruébalo siempre en ventana privada.
5. Si algún día pones una regla *Cache Everything* en HTML, excluye `/ca/blog/`
   y `/blog/` o tendrás que purgar en cada artículo nuevo.

## Paso 3 · Search Console (20 min)

1. **Sitemaps**: reenvía `sitemap.xml` y `sitemap-posts.xml`. El segundo
   debe pasar de 23 a 58 URLs (29 ES + 29 CA).
2. **Inspección de URLs → Solicitar indexación** (límite diario, empieza por
   las más valiosas):
   - `https://eduolihez.com/ca/blog/`
   - `https://eduolihez.com/blog/post/que-hace-un-analista-soc-un-dia-de-trabajo-real/`
   - `https://eduolihez.com/blog/post/ciberseguridad-para-pymes-en-barcelona-diez-medidas/`
   - `https://eduolihez.com/blog/post/he-hecho-clic-en-un-phishing-que-hacer-ahora/`
   - `https://eduolihez.com/blog/post/ransomware-que-hacer-en-las-primeras-24-horas/`
   - `https://eduolihez.com/blog/post/certificaciones-para-empezar-como-analista-soc/`
   - `https://eduolihez.com/blog/post/auditar-permisos-de-microsoft-365-en-una-tarde/`
   - Después, `/ca/blog/post/...` de dos o tres artículos catalanes.
3. En **Configuración → Segmentación internacional** no hay nada que tocar:
   el `hreflang` ya va en el HTML.
4. **Exporta datos nuevos** a `seo/gsc/` en 4–6 semanas (con los datos de
   agosto como comparación) y pásamelos.

## Paso 4 · Bing Webmaster Tools (10 min)

Reenvía los dos sitemaps y pide la indexación de `/ca/blog/`. (Si activaste
Crawler Hints, Bing ya se entera solo, pero no sobra.)

## Paso 5 · Revisa los 6 artículos nuevos antes de promocionarlos

Están escritos en tu nombre. Léelos una vez (en `/admin` o en la web) y
corrige lo que no suene a ti o no sea cierto en tu día a día. Especialmente:

- `que-hace-un-analista-soc-...` (cita Vision One, como tú).
- `ciberseguridad-para-pymes-...`: menciona INCIBE (017) y la Agència de
  Ciberseguretat de Catalunya; comprueba que el nombre y el teléfono siguen
  vigentes.
- `certificaciones-para-empezar-...`: los precios los dejé sin cifra a
  propósito; si añades alguno, fecha el dato.

Si algo no te encaja, se edita desde `/admin` sin recompilar (el HTML
estático se actualiza en el siguiente build; el `/llms-blog.txt` y la API,
al instante).

## Paso 6 · Perfiles y enlaces (una sola vez)

- **LinkedIn**: web en Contacto, ubicación "Badalona, Cataluña, España",
  titular con ciudad.
- **GitHub**: Website y Bio con ciudad.
- **Credly**: tus insignias enlazando a la web.
- Comparte cada artículo nuevo en LinkedIn con el enlace directo. Los de
  pymes y phishing son los más compartibles; los de catalán, en comunidades
  tech catalanas.

## Paso 7 · Mantener el ritmo

Un artículo al mes en español y su traducción al catalán. Cada vez que
publiques desde `/admin` un artículo CA nuevo, dime su slug o añade la línea
en `src/lib/postTranslations.ts` (mapa ES → CA) para que salga el `hreflang`;
sin esa línea el artículo funciona igual, solo pierde el enlace entre idiomas.

## Paso 8 · Medir (cada 2–3 meses)

1. Search Console → exportar → `seo/gsc/`.
2. Panel → Analítica → Canales (Búsqueda e IA) y Bots.
3. Mírame las consultas en posición 8–20: ahí se gana con ajustes de título.

Plazos honestos: marca y nombre, 1–2 meses; "analista SOC Barcelona", 3–6 meses
y solo con contenido y enlaces; temas concretos del blog, según competencia.

---

## Lo que NO hay que hacer

- No des por buenas las traducciones sin leerlas: las 29 de catalán las traduje yo (no hay traductor automático de por medio),
  pero conviene que un hablante nativo las repase antes de promocionarlas.
- No copiar los artículos a LinkedIn Pulse o Medium sin canonical: compiten
  con tu propia web.
- No activar *Cache Everything* en HTML ni Rocket Loader en Cloudflare.
