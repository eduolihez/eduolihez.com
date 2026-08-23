# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Dos públicos con **el mismo peso**; ninguno se sacrifica por el otro.

**1. Reclutador / hiring manager.** Llega desde LinkedIn, de un proceso de selección
abierto o de una búsqueda con nombre propio. Escanea: rol actual, certificaciones,
años de experiencia, stack. Quiere resolver "¿encaja en la vacante?" en menos de un
minuto y salir con el CV o una vía de contacto. Puede no ser perfil técnico: lee
FortiGate y Trend Micro como sellos, no como detalle.

**2. Comunidad técnica y pares** (analistas SOC, blue teamers, gente del sector).
Llegan por el blog, por búsqueda o por "Sobre esta web". No vienen a contratar:
vienen a valorar criterio técnico. Leen a fondo, abren el repositorio y comprueban
si lo que se afirma se sostiene.

**3. Usuario administrador (Eduardo, un solo operador).** Entra a `/admin` desde
escritorio y móvil para publicar proyectos, certificaciones y artículos, leer
mensajes del formulario y consultar analítica propia. Uso frecuente y repetitivo;
sin formación ni onboarding porque es el mismo dueño del producto.

## Product Purpose

Sitio personal y portfolio profesional de Eduardo Olivares Hernández, analista SOC /
Blue Team con base en Badalona (Barcelona), disponible en español, inglés y catalán.

Existe para conseguir oportunidades profesionales y, a la vez, construir autoridad
técnica pública. El éxito no es una sola conversión: **las cuatro señales cuentan y
ninguna es descartable** — que escriban por el formulario de contacto, que descarguen
el CV (PDF en ES/EN/CA), que conecten en LinkedIn, y que lean a fondo o citen el
contenido (incluidas las IAs y buscadores, vía `llms.txt`, FAQPage y datos
estructurados).

## Positioning

Posición **compuesta y jerarquizada**. El orden importa: cuando dos decisiones
choquen, gana la de arriba.

1. **La web es la demostración, no el relato.** Cada afirmación técnica del sitio es
   auditable en el repositorio público: CSP con hashes SHA-256 recalculados en cada
   build (sin `unsafe-inline`), salida 100% estática, hardening por cabecera, panel
   sin dependencias de CDN, analítica propia con IP hasheada. La página
   `/sobre-esta-web` enumera cada control **con el archivo donde vive**. Un perfil
   vecino no puede copiar esto sin construirlo de verdad. **Ningún trabajo futuro
   debe romper esa promesa: si el sitio afirma algo, el repositorio tiene que
   respaldarlo.**
2. **Perfil SOC + IA aplicada.** Detección de amenazas e investigación asistida por
   IA (Trend Micro Vision One / TrendAI), automatización de informes y scripts de
   seguridad en Python, administración Fortinet — con certificación Fortinet NSE y
   Azure AI Fundamentals.
3. **Alcance trilingüe y local.** ES/EN/CA completo más SEO local (Badalona, área
   metropolitana de Barcelona, Cataluña, remoto) y contenido estructurado para ser
   citado por IAs. Cobertura a la que la mayoría de perfiles del sector no llega.

## Operating Context

- **Lectura pública:** la mayoría de las visitas son de escaneo rápido en escritorio
  o móvil, muchas veces desde un enlace de LinkedIn o un resultado de búsqueda. El
  contenido dinámico (proyectos, certificaciones, artículos, estado "disponible para
  trabajar", banner de anuncio) se pinta en cliente vía `fetch` al API PHP: **en
  local sin PHP esas secciones fallan de forma controlada y muestran su mensaje de
  error — es el comportamiento esperado, no un bug.**
- **Publicación:** contenido fijo (foto, textos, experiencia, skills, FAQ, diseño)
  vive en el código y exige `npm run build` + subida por FTP. Contenido dinámico se
  gestiona desde `/admin` sin recompilar. Esa frontera es una decisión deliberada y
  debe quedar clara para quien edite.
- **Despliegue:** hosting CDMON con Apache/cPanel + PHP 8 + MySQL/MariaDB, detrás de
  Cloudflare. `dist/` y `server/` conviven bajo el mismo dominio (sin CORS cruzado).
  No hay Node en producción.

## Capabilities and Constraints

**Stack (codebase existente).** Astro 7 en salida `static` con i18n nativo
(`es` en `/`, `en` en `/en/`, `ca` en `/ca/`), Tailwind CSS 4 vía plugin de Vite con
el tema en `@theme` dentro de `src/styles/global.css` (no hay `tailwind.config`).
Backend propio en PHP 8 + MySQL. Tipografías autoalojadas (Inter Variable, JetBrains
Mono Variable) — sin CDN de fuentes.

**Superficies públicas.** Home de una página (hero, experiencia, habilidades,
proyectos, certificaciones, FAQ, contacto) ×3 idiomas · blog índice + artículo ×3
idiomas · `/projects` · `/sobre-esta-web` (`/en/about-this-website`,
`/ca/sobre-aquesta-web`) · páginas de error 400/403/404/410/500 · `sitemap.xml` ·
`llms.txt`.

**Superficie privada.** Panel `/admin` en PHP: panel, proyectos, certificaciones,
blog, mensajes (con contador de no leídos), analítica, seguridad, ajustes y backup.
Autenticación con registro de intentos de login y log de actividad.

**API pública (solo lectura + telemetría).** `projects`, `certifications`, `posts`,
`post`, `settings`, `contact`, `visit`.

**Datos.** Tablas `admin_users`, `login_attempts`, `activity_log`, `projects`,
`certifications`, `posts`, `messages`, `visits`, `settings`. Esquema idempotente con
migración incluida.

**Restricciones duras que todo trabajo futuro debe respetar:**

- **CSP estricta con hashes.** No se puede inyectar `<script>` desde JavaScript en
  runtime, ni cargar scripts, fuentes o estilos desde ningún CDN. Nada de
  `unsafe-inline` en `script-src`.
- **Sin build en el panel.** El CSS de `/admin` va embebido en
  `server/admin/partials/layout.php` para que el panel sea autónomo. Cualquier
  rediseño del panel se hace dentro de esa restricción, no añadiendo un pipeline.
- **Sin terceros de analítica.** La analítica es propia y la IP se guarda hasheada
  con sal. No se introducen scripts de seguimiento externos.
- **`format: 'directory'`** en el build (compatibilidad Apache/cPanel) y
  case-sensitivity del servidor: las URLs importan.
- El catalán usa los textos dinámicos en español como respaldo (decisión asumida).
- Tailwind escanea solo `/src` (`source(none)`): los micrositios de `/public/projects`
  tienen su propia hoja compilada aparte (`npm run css:promptmaster`).

**Alcance de diseño acordado:** sitio público **y** panel `/admin`. Los micrositios
de proyecto en `/public/projects` quedan fuera por ahora.

**Sin decidir (no inventar):** Cloudflare Turnstile está cableado pero desactivado
(`turnstileSiteKey: ''`); `worksFor.url` está vacío.

## Brand Commitments

- Nombre y dominio: **eduolihez.com** · Eduardo Olivares Hernández · "Edu Olivares" ·
  `SOC Analyst · Blue Team`.
- Trilingüe ES/EN/CA con paridad real de contenido estático; el idioma por defecto
  (ES) no lleva prefijo de ruta.
- Voz: técnica, verificable y sin marketing hueco. La regla escrita en
  `src/data/about-tech.ts` es vinculante y aplica a todo el sitio: *"cada afirmación
  describe algo realmente implementado, con el archivo donde vive; una línea de
  marketing que no se sostenga al abrir el repositorio hace más daño que no decir
  nada."*
- Repositorio público bajo licencia MIT, con CodeQL y Semgrep en CI, `security.txt`
  y `humans.txt`. La transparencia del código forma parte de la marca.

## Evidence on Hand

Todo lo siguiente es real y verificable; nada debe fabricarse ni ampliarse.

- **Experiencia** (`src/data/experience.ts`): Dagram — SOC / Cybersecurity Analyst
  (abr 2026 – presente) y Cybersecurity Technician L1/L2 (ene–abr 2026); Institució
  Cultural Laietània — Técnico IT, soporte a más de 100 usuarios (oct 2024 – abr
  2025); Escola del Vent — Instructor de fitness (may–sep 2024).
- **Certificaciones destacadas** (`src/config.ts`): Fortinet NSE (2026), Microsoft
  Certified: Azure AI Fundamentals (2026), Trend Micro Vision One Platform — Advanced
  (2024), TryHackMe Pre-Security (2023), Fundamentos profesionales en ciberseguridad
  — Microsoft/LinkedIn (2023), Cambridge First Certificate in English B2 (2021). El
  listado completo y verificable vive en base de datos, con enlaces de verificación
  e insignias en Credly.
- **Reconocimiento**: ganador de la 8ª Hackathon TecnoCampus (2025) con *Dewi*,
  prototipo web de monitorización de consumo de agua en tiempo real.
- **Idiomas**: español (nativo), catalán (nativo), inglés B2 acreditado.
- **Activos**: foto `/img/eduardo.webp`, CV en tres idiomas (`/cv/`), vCard
  descargable, portada OG, PDFs de certificaciones en `/certificaciones`.
- **Contenido propio**: FAQ trilingüe (`src/data/faq.ts`) que alimenta a la vez la
  sección visible, el `FAQPage` de Schema.org y `llms.txt`; y la documentación
  técnica de `src/data/about-tech.ts`, donde cada control cita su archivo.
- **Ausencias que no se rellenan con ficción**: no hay testimonios, ni clientes, ni
  casos de estudio, ni métricas de negocio, ni notas de prensa. Cualquier prueba
  social futura debe salir de aquí, no inventarse.

## Product Principles

1. **Lo que se afirma se puede abrir.** Cada afirmación técnica del sitio tiene un
   archivo detrás. Antes que una frase impresionante sin respaldo, ninguna frase.
2. **Un minuto para el que contrata, una hora para el que audita.** La misma página
   sirve a los dos: escaneable arriba, profundizable abajo. Ninguna capa estorba a la
   otra.
3. **Las cuatro conversiones son válidas.** Contacto, CV, LinkedIn y lectura citada.
   Optimizar una a costa de enterrar las otras es un error de diseño.
4. **Trilingüe de verdad.** ES/EN/CA no es un adorno: nada se diseña de forma que
   solo funcione con la longitud de texto del español.
5. **La seguridad es la restricción de diseño, no un obstáculo a rodear.** CSP
   estricta, cero CDN, cero terceros y analítica anónima acotan las soluciones
   posibles; se diseña dentro de esos límites, nunca relajándolos.

## Accessibility & Inclusion

**Compromiso duro: WCAG 2.2 AA** en el sitio público y en el panel `/admin`. Todo
trabajo futuro se audita contra ese nivel: contraste de texto y de componentes de
interfaz, foco visible y no oscurecido, navegación completa por teclado, objetivos
táctiles suficientes, texto redimensionable y `prefers-reduced-motion` respetado.

Base ya existente sobre la que construir: enlace de salto al contenido en
`BaseLayout.astro` y dos bloques de `prefers-reduced-motion` en
`src/styles/global.css`. Aún **no auditado** contra AA de forma sistemática — el
compromiso es el objetivo, no un estado verificado.
