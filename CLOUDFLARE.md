# ☁️ Guía de Cloudflare (opcional pero recomendado)

Cloudflare se pone **por delante** de tu hosting CDMON y te da, gratis:

- **CDN global** → tu web carga más rápido en todo el mundo.
- **Protección DDoS** y **WAF** (cortafuegos de aplicaciones).
- **SSL** universal y **"Always HTTPS"**.
- **País del visitante** (cabecera `CF-IPCountry`) → aparece en tu analítica.
- **IP real del visitante** de forma fiable (cabecera `CF-Connecting-IP`).

No es obligatorio: la web funciona perfectamente sin Cloudflare. Pero si lo
usas, sigue estos pasos y activa las dos opciones del final.

---

## 1. Conectar tu dominio a Cloudflare

1. Crea una cuenta gratis en <https://dash.cloudflare.com>.
2. **Add a site** → escribe `eduolihez.com` → plan **Free**.
3. Cloudflare escanea tus DNS. Revisa que estén tus registros (A/CNAME de CDMON).
4. Te dará **2 nameservers** (p.ej. `dana.ns.cloudflare.com`).
5. Entra en el panel donde gestionas el dominio (CDMON o tu registrador) y
   **cambia los nameservers** por los de Cloudflare. Puede tardar unas horas.
6. En Cloudflare, asegúrate de que los registros de tu web tienen la **nube
   naranja activada** (proxy ON).

## 2. Ajustes recomendados en Cloudflare

- **SSL/TLS → Overview**: modo **Full (strict)** (requiere el SSL de CDMON activo).
- **SSL/TLS → Edge Certificates**: activa **Always Use HTTPS** y **Automatic HTTPS Rewrites**.
- **Speed / Caching**: deja el caché por defecto. Si quieres afinar, crea una
  regla para **NO cachear** rutas dinámicas:
  - **Rules → Cache Rules**: si la URL contiene `/api/` o `/admin/` → **Bypass cache**.
- **Security → Bots**: deja el modo por defecto (Free ya filtra bots básicos).

> Como Cloudflare ya fuerza HTTPS, puedes dejar el redirect del `.htaccess`
> activo sin problema (se complementan).

### HSTS: actívalo en UN solo sitio

El `.htaccess` del proyecto ya envía la cabecera
`Strict-Transport-Security: max-age=31536000; includeSubDomains`, así que en
Cloudflare **no hace falta** activar HSTS otra vez (SSL/TLS → Edge Certificates
→ HSTS). Si lo activas en los dos, la cabecera se duplica: no rompe nada, pero
tener el mismo ajuste en dos sitios es la mejor forma de olvidarse de uno.

Elige uno y déjalo documentado. Recomendación: **déjalo en el `.htaccess`**,
que viaja con el código; si algún día quitas Cloudflare, la protección sigue.

> ⚠️ **No actives "preload"** (ni aquí ni en Cloudflare) salvo que sepas lo que
> implica: entra en una lista que llevan los navegadores y sacar un dominio de
> ella tarda meses. Para un portfolio no compensa.

### No caches el panel ni el API

Es el ajuste que más problemas evita. Sin él, Cloudflare puede servirle a un
visitante una respuesta cacheada del panel:

- **Rules → Cache Rules** → si el URI contiene `/api/` **o** `/admin/` →
  **Bypass cache**.

El backend ya envía `Cache-Control: no-store` en todas las respuestas del API,
pero la regla en el borde es cinturón y tirantes.

### Deja pasar a los rastreadores de IA

En **Security → Bots** (o en las reglas de WAF), asegúrate de no bloquear
`GPTBot`, `ClaudeBot`, `PerplexityBot`, `OAI-SearchBot` ni `Google-Extended`.
El `robots.txt` del proyecto los permite a propósito: son los que hacen que
ChatGPT o Claude puedan hablar de ti cuando alguien pregunta por un analista
SOC en Barcelona. Si Cloudflare los bloquea en el borde, el `robots.txt` da
igual porque nunca llegan a leerlo.

> Cloudflare tiene un interruptor **"Block AI Scrapers and Crawlers"**
> (Security → Bots). Para este sitio debe estar **desactivado**.

---

## 3. ⚙️ IMPORTANTE: activa la IP real (para rate-limit y países)

Cuando usas Cloudflare, la IP que ve tu servidor es la de Cloudflare, no la del
visitante. La IP real llega en la cabecera `CF-Connecting-IP`. Para que el
anti-spam y la analítica por países funcionen bien:

1. Abre `server/config.php` en tu hosting.
2. Cambia:

```php
'trust_proxy' => true,   // estabas en false
```

Con esto, `client_ip()` usará `CF-Connecting-IP` (fiable, porque solo Cloudflare
puede ponerla) y la analítica empezará a registrar el país de cada visita.

> ⚠️ Pon `trust_proxy => true` **solo si TODO tu tráfico pasa por Cloudflare**.
> Si algún día quitas Cloudflare, vuelve a ponerlo en `false`.

---

## 4. 🛡️ (Opcional) Captcha invisible con Turnstile

Turnstile es el "captcha" de Cloudflare: invisible o de un solo clic, sin fotos
de semáforos. Añade una capa extra anti-bots al formulario de contacto.

### 4.1. Crear el widget
1. En Cloudflare: **Turnstile → Add widget**.
2. Dominio: `eduolihez.com`. Modo: **Managed** (recomendado).
3. Copia las dos claves: **Site Key** (pública) y **Secret Key** (privada).

### 4.2. Configurar las claves
- **Frontend** — en `src/config.ts`:
  ```ts
  turnstileSiteKey: '0x4AAAAAAA...tu_site_key',
  ```
- **Backend** — en `server/config.php`:
  ```php
  'turnstile' => [
      'site_key'   => '0x4AAAAAAA...tu_site_key',
      'secret_key' => '0x4AAAAAAA...tu_secret_key',
  ],
  ```

### 4.3. Permitir Turnstile en la CSP
El sitio tiene una CSP estricta que bloquea scripts externos. Hay que autorizar
el dominio de Turnstile. En `astro.config.mjs`, dentro de `experimental.csp`:

```js
experimental: {
  csp: {
    directives: [
      "default-src 'self'",
      "img-src 'self' data: https:",
      "font-src 'self'",
      // añade challenges.cloudflare.com a connect y frame:
      "connect-src 'self' https://formspree.io https://challenges.cloudflare.com",
      "form-action 'self' https://formspree.io",
      "frame-src https://challenges.cloudflare.com",
      "base-uri 'self'",
      "object-src 'none'",
    ],
    scriptDirective: {
      // permite cargar el script de Turnstile:
      resources: ["'self'", 'https://challenges.cloudflare.com'],
    },
    styleDirective: {
      resources: ["'self'", "'unsafe-inline'"],
    },
  },
},
```

### 4.4. Recompilar y subir
```bash
npm run build
```
Sube de nuevo el contenido de `dist/`. El formulario mostrará el widget de
Turnstile y el backend (`contact.php`) verificará el token automáticamente.
Si dejas las claves vacías, todo sigue funcionando sin Turnstile (honeypot +
rate-limit siguen activos).

---

## Resumen

| Quiero... | Acción |
|---|---|
| Web más rápida y protegida | Pasos 1–2 |
| Que el anti-spam y los países funcionen bien | Paso 3 (`trust_proxy => true`) |
| Captcha invisible en el contacto | Paso 4 |
