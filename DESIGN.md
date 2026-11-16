---
name: eduolihez.com
description: Expediente — informe de incidente con evidencias numeradas. Gris frío de papel técnico (claro) o tinta azul noche (oscuro), acento de texto azul tinta, amarillo marcador solo como relleno. Web pública en modo Read, /admin en modo Operate, mismos tokens.
colors:
  bg: "#f3f5f8"
  bg-soft: "#e9edf2"
  bg-card: "#ffffff"
  bg-border: "#d5dbe4"
  bg-border-hover: "#b9c2cf"
  text: "#101828"
  text-title: "#0a1020"
  text-muted: "#475467"
  text-faint: "#5d6b7e"
  accent: "#2443b0"
  accent-hover: "#1a3390"
  accent-soft: "#e3e9fb"
  on-accent: "#ffffff"
  mark: "#f6c61b"
  mark-hover: "#e8b70c"
  mark-soft: "#fdf0c2"
  on-mark: "#101828"
  ink: "#0b1220"
  on-ink: "#f3f5f8"
  cyan: "#0e7490"
  violet: "#6d44d8"
  danger: "#b3261e"
  warn: "#8f5608"
  oss: "#0d7a54"
  wip: "#8f5608"
  closed: "#1b5cc0"
  dark-bg: "#0b1220"
  dark-bg-soft: "#0f1729"
  dark-bg-card: "#111a2c"
  dark-bg-border: "#1e2a40"
  dark-bg-border-hover: "#2c3a55"
  dark-text: "#e6ebf3"
  dark-text-title: "#f3f6fa"
  dark-text-muted: "#9aa8bd"
  dark-text-faint: "#8a98ae"
  dark-accent: "#8fb0ff"
  dark-accent-hover: "#b3c9ff"
  dark-accent-soft: "#16254a"
  dark-on-accent: "#0b1220"
  dark-mark-hover: "#ffd84d"
  dark-mark-soft: "#3a3112"
  dark-cyan: "#22d3ee"
  dark-violet: "#a78bfa"
  dark-danger: "#f87171"
  dark-warn: "#f59e0b"
  dark-oss: "#10b981"
  dark-wip: "#f59e0b"
  dark-closed: "#60a5fa"
typography:
  display:
    fontFamily: "Inter, Inter Fallback, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(1.875rem, 5vw, 3rem)"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "Inter, Inter Fallback, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.025em"
  body:
    fontFamily: "Inter, Inter Fallback, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.625
    letterSpacing: "normal"
  prose:
    fontFamily: "Inter, Inter Fallback, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.7
    letterSpacing: "normal"
  meta:
    fontFamily: "JetBrains Mono, JetBrains Mono Fallback, ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "0.75rem"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
rounded:
  sm: "4px"
  md: "6px"
  lg: "8px"
spacing:
  container: "64rem"
  gutter: "20px"
  gutter-lg: "32px"
  touch-target: "44px"
components:
  button-primary:
    backgroundColor: "{colors.mark}"
    textColor: "{colors.on-mark}"
    rounded: "{rounded.md}"
    padding: "10px 16px"
    typography: "{typography.body}"
  button-primary-hover:
    backgroundColor: "{colors.mark-hover}"
    textColor: "{colors.on-mark}"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "10px 16px"
    typography: "{typography.body}"
  card:
    backgroundColor: "{colors.bg-card}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
  chip:
    backgroundColor: "transparent"
    textColor: "{colors.text-muted}"
    rounded: "{rounded.sm}"
    padding: "2px 8px"
    typography: "{typography.meta}"
  hero-band:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-ink}"
  hero-status:
    backgroundColor: "{colors.mark}"
    textColor: "{colors.on-mark}"
    rounded: "{rounded.sm}"
  evidence-card:
    backgroundColor: "{colors.bg-card}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
    padding: "24px"
---

# Design System: eduolihez.com

## Overview

**Mundo visual: "Expediente".** La web es el expediente de un analista: un informe de
incidente con evidencias numeradas. Sustituye a las dos identidades anteriores ("La
Consola de Guardia", verde sobre negro; y el rediseño v2 de papel, mono y serif cursivo).
Se evitó a propósito la estética de consola hacker: la investigación del rediseño
(`.claude/flujo/ESTADO.md`) la desaconseja para el público que decide en menos de un minuto.

Dos modos con los mismos tokens:

- **Read** (web pública): una columna centrada a 64rem, escaneable arriba y profundizable
  abajo.
- **Operate** (`/admin`): uso repetitivo de un solo operador; sidebar, "Hoy", tablas que se
  vuelven tarjetas en móvil.

Principio rector heredado de `PRODUCT.md`: nada simula ser algo que el sitio no es. Sin
terminal falsa, sin datos en vivo inventados, sin testimonios ni métricas.

## Tema

- Sin elección guardada, el sitio sigue a `prefers-color-scheme`.
- El botón y la paleta guardan `light`/`dark` en `localStorage['theme']`; "Tema del
  sistema" lo borra. `public/theme-init.js` lo aplica antes del primer pintado (script
  externo, compatible con la CSP). Lógica y tests en `src/scripts/theme.ts`.
- Resolución: `<html data-theme>` explícito; si no, la media query. `tokens.css` tiene dos
  bloques oscuros (selector de atributo y media query) que `src/test/tokens.test.ts`
  obliga a ser idénticos.
- **Una fuente de verdad:** los valores viven en `src/styles/tokens.css` y se copian
  literalmente a `server/admin/assets/admin.css` (PHP estático, no importa la hoja de la
  web). El test de tokens comprueba la igualdad y el contraste. Si cambia un valor, cambia
  en los dos sitios.
- `global.css` publica los tokens como utilidades de Tailwind con `@theme inline`
  (`bg-bg-card`, `text-accent`, `bg-mark`…). **No se renombran clases ni tokens**: varios
  `src/scripts/*.ts` construyen clases Tailwind en cadenas y tienen tests. Una clase nueva
  se añade; no sustituye.

## Colors

La paleta tiene tres planos de fondo, cuatro de texto, un acento de texto, un amarillo de
relleno y una tinta fija. Valores de `tokens.css` (claro / oscuro):

| Token | Claro | Oscuro |
|---|---|---|
| `bg` / `bg-soft` / `bg-card` | `#f3f5f8` / `#e9edf2` / `#ffffff` | `#0b1220` / `#0f1729` / `#111a2c` |
| `bg-border` / `bg-border-hover` | `#d5dbe4` / `#b9c2cf` | `#1e2a40` / `#2c3a55` |
| `text` / `text-title` | `#101828` / `#0a1020` | `#e6ebf3` / `#f3f6fa` |
| `text-muted` / `text-faint` | `#475467` / `#5d6b7e` | `#9aa8bd` / `#8a98ae` |
| `accent` / `accent-hover` / `accent-soft` / `on-accent` | `#2443b0` / `#1a3390` / `#e3e9fb` / `#ffffff` | `#8fb0ff` / `#b3c9ff` / `#16254a` / `#0b1220` |
| `mark` / `mark-hover` / `mark-soft` / `on-mark` | `#f6c61b` / `#e8b70c` / `#fdf0c2` / `#101828` | `#f6c61b` / `#ffd84d` / `#3a3112` / `#101828` |
| `ink` / `on-ink` | `#0b1220` / `#f3f5f8` | `#0b1220` / `#f3f5f8` |
| `cyan` · `violet` | `#0e7490` · `#6d44d8` | `#22d3ee` · `#a78bfa` |
| `danger` · `warn` | `#b3261e` · `#8f5608` | `#f87171` · `#f59e0b` |
| `oss` · `wip` · `closed` | `#0d7a54` · `#8f5608` · `#1b5cc0` | `#10b981` · `#f59e0b` · `#60a5fa` |
| `scrim` | `rgb(16 24 40 / 0.55)` | `rgb(3 6 12 / 0.72)` |
| `selection` | `rgb(246 198 27 / 0.45)` | `rgb(246 198 27 / 0.3)` |

También hay `grid-line`, `glow` y `shadow-card` por tema (ver `tokens.css`). El front
matter lista claro y oscuro; los tokens sin prefijo `dark-` son los del tema claro.

### Reglas de color

**`--mark` es solo relleno.** El amarillo marcador va siempre como fondo con `--on-mark`
encima (≥ 7:1): botón primario, insignia de disponibilidad, barrido de la evidencia,
contadores del admin, selección de texto. Nunca texto amarillo sobre fondo claro.

**`--accent` es el color de texto y enlace.** Es un azul tinta (`#2443b0` en claro,
`#8fb0ff` en oscuro) porque se usa como texto y tiene que cumplir ≥ 4.5:1 sobre `bg` y
`bg-card`. Enlaces (`.link-accent`, `.ev-verify`), estado activo del admin, cursor de
escritura.

**`--ink` es la banda de portada.** `#0b1220` fijo en los dos temas: el hero es oscuro
también en claro (color comprometido, no solo un acento). La columna izquierda del hero
(`.hero-ink`) redefine los tokens de texto con los valores del tema oscuro para que el
texto, `btn-ghost` y el foco sean legibles sobre la tinta. La ficha de evidencias queda
fuera de ese ámbito y usa los tokens del tema activo.

**Un solo rojo, y no es el acento.** Un fallo usa `--danger`, un aviso `--warn`. El
amarillo no significa aviso ni fallo.

**`--cyan` y `--violet`** son decorativos y acotados: bloques de "Sobre esta web" y sellos
de emisor de certificaciones sin logotipo. No van a titulares, botones ni enlaces.

**Estado de proyecto:** `oss`, `wip`, `closed` como texto sólido sobre fondo al 10 % y
borde al 20 % (`text-oss`, `bg-wip/10`, `border-closed/20`).

**Contraste:** lo comprueba `src/test/tokens.test.ts`: texto y acento ≥ 4.5:1 sobre `bg`
y `bg-card`; `--on-mark` sobre `--mark` ≥ 7:1. El halo del foco en `--mark` sobre claro
queda en 1,48:1; el 3:1 lo aporta el anillo `--text` (ver Foco).

## Typography

Dos familias web, autoalojadas, solo subconjuntos `latin` y `latin-ext`, ejes variables,
`font-display: swap`. Sin petición a CDN de fuentes (decisión de seguridad ligada a la CSP).

- **Inter** (100–900): cuerpo y titulares. `h1`, `h2`, `h3` y `.section-title` en peso
  **700 con `letter-spacing: -0.025em`** (`h3` −0.015em), `text-wrap: balance`. Display
  `clamp(1.875rem, 5vw, 3rem)` una vez por página; títulos de sección `text-2xl`/`text-3xl`.
- **JetBrains Mono** (100–800): **solo metadato**: IDs de evidencia (E-nn), años, fechas,
  chips de tecnología, contadores, código y el editor del admin. Nunca prosa.
- **Prosa del blog** (`.prose`): Inter 1.0625rem / 1.7, `max-width: 37rem`. Medida medida
  en el rediseño: 71–72 caracteres por línea en ES/EN/CA.

Se descartó Schibsted Grotesk para titulares: con ella los woff2 `latin` del home sumaban
~132 KB frente a un presupuesto de 120 KB (`ESTADO.md`, `registro.md`). El carácter
editorial sale del peso y del tracking, no de una tercera familia. `--font-serif` se
conserva como variable (el marcado aún la referencia) pero apunta a la pila de Inter.

### Excepción deliberada: fuentes "Inter Fallback" y "JetBrains Mono Fallback"

`global.css` declara dos `@font-face` locales que no son familias de marca:

| Familia | `src` | `size-adjust` | `ascent` / `descent` / `line-gap` |
|---|---|---|---|
| `Inter Fallback` | `local('Arial')` | 107.12 % | 90.44 % / 22.52 % / 0 % |
| `JetBrains Mono Fallback` | `local('Courier New')` | 100.33 % | 101.66 % / 29.9 % / 0 % |

Existen para que el texto pintado con la fuente del sistema ocupe lo mismo que con el
woff2 y el cambio no provoque CLS. Van en la pila entre la fuente real y `system-ui`.
Cuentan como ajustes de métrica, no como tercera familia: el límite sigue siendo dos
familias web. **El hook de impeccable las marca como fuentes no declaradas; es un falso
positivo conocido y no se añade un ignore.**

## Layout

Una columna centrada: `.container-page` a `max-width: 64rem` (`max-w-5xl`), gutters de 20 px
en móvil, 24 px desde `sm` y 32 px desde `lg`. Secciones separadas por `border-b` de
`bg-border` y relleno de 3.5–4 rem. `scroll-padding-top: 5rem` por la cabecera fija.
`--container-content: 72rem` está declarado en `@theme` pero ningún componente lo usa.

**Orden de la home** (`PortfolioSections.astro`): Hero, StackStrip, Experience, Projects,
Certifications, Skills, BlogPreview, Faq, Contact. StackStrip queda tras el Hero
(desviación aceptada respecto al plan inicial).

Hay modo impresión (`@media print`): oculta cabecera, pie y formulario, fondo blanco, y
`.no-print` para lo que sobra; la home sale como CV.

## Firma: la cadena de evidencias (E-nn)

Cada afirmación verificable del hero lleva una etiqueta **E-01, E-02…** en JetBrains Mono,
enlazada a su fuente real (credencial en Credly, PDF en `/certificaciones/`, archivo de
`about-tech.ts`).

- **Datos:** campo estático `evidence` en `src/config.ts`. Si una afirmación no tiene
  fuente, no lleva etiqueta. `src/test/evidence.test.ts` falla si una ruta local no existe
  en `public/`. Paridad de E-nn en ES/EN/CA.
- **Ficha** (`.ev-card`, `EvidenceCard.astro`): hoja del expediente sobre la banda de
  tinta. Fila = `E-nn` (mono, `.ev-id`), texto con año en mono en línea propia, y enlace
  "Verificar" (`.ev-verify`, `--accent`, subrayado).
- **Barrido de marcador:** al pasar el ratón, enfocar (`:focus-within`) o llegar por
  ancla (`:target`) a una fila, la etiqueta (`.ev-label`) se rellena de `--mark` y el texto
  pasa a `--on-mark`. Es un relleno sólido animado por `background-size` (0.45 s), no un
  degradado decorativo; con `prefers-reduced-motion` no hay transición.
- **Cada E-nn es un permalink** (`ev-row` con `scroll-margin-top`).

## Patrones por sección (modo Read)

- **Hero con banda tinta** (`.hero-band`, `.hero-layout`): nombre, rol, una frase y tres
  CTA (contacto con `btn-primary`, CV y LinkedIn con `btn-ghost`), cada uno ≥ 44 px. En
  móvil: principal, ficha, metadato. Desde 1024 px: dos columnas, la ficha ocupa las dos
  filas de la derecha (24rem). Insignia de disponibilidad (`.hero-status`, relleno
  `--mark`) en un hueco de altura fija: ocultarla no desplaza nada. Es dinámica (ajuste
  `open_to_work` del panel) y se oculta si el ajuste está a 0; no se fija en el código.
- **StackStrip:** una línea estática de tecnologías reales (`src/data/skills.ts`),
  recortada por elemento si no cabe. Sin carrusel ni JS.
- **Experiencia:** compacta, datos de `src/data/experience.ts`; chips y metadato en mono.
- **Evidencia (Projects, Certifications):** tarjetas `.card` (8 px, borde 1 px, sin
  sombra). Filtros con objetivo ≥ 44 px. El estado "cargando / vacío / error" vive en
  `StatusPanel.astro` (`data-state`); el error nombra el problema y ofrece reintento.
- **Habilidades:** lista de definición agrupada por categoría con icono; las habilidades
  fluyen en una línea (`.dot-list`). Sin marquee, sin ventana, sin muro de píldoras.
- **FAQ:** `<details>` nativos. Las preguntas siguen todas en el DOM (alimentan `FAQPage` y
  `llms.txt`); se pliegan visualmente en un bloque "ver más".
- **Blog en modo Read:** índice en filas (`.blog-entry`) y artículo con `.prose` a medida
  de lectura, tabla de contenidos (`.post-toc`) y código legible. Contraste ≥ 6,5:1
  medido en el rediseño.
- **Páginas de error** (`ErrorPage.astro`, 400/403/404/410/500): una columna estrecha,
  qué pasó y qué hacer; la primera acción es la principal; el código HTTP va como metadato
  en mono al pie. Un error usa `--danger`, nunca el acento. Siguen en inglés (servidas
  por Apache, sin selector de idioma).
- **Páginas auxiliares:** "Sobre esta web" como lista de definición de dos columnas con
  el archivo de cada control; `/projects` en filas.

## Admin: modo Operate

Mismos tokens, sin serif ni portada. Inter 700 para títulos (`-0.015em`), mono solo para
IDs, fechas y metadato. El CSS es **`server/admin/assets/admin.css`**, un fichero externo
enlazado desde `server/admin/partials/layout.php` (antes se describía como embebido).
Las fuentes se autoalojan en `server/admin/assets/fonts/` (latin).

- **Navegación:** sidebar fija en escritorio; barra inferior de cinco ítems bajo 1024 px
  (`.bottom-nav`, ítems de 56 px de alto, insignia en `--mark`), con "Más" que abre el
  cajón lateral.
- **Hoy** (`index.php`): primera vista; lista de lo que pide acción (contadores
  `.today-count`, relleno `--mark` si hay pendientes) y métricas. Solo con datos que la
  página ya tiene.
- **Tablas a tarjetas:** `table.stack` con `data-label` por celda; bajo 768 px cada fila es
  una tarjeta y la etiqueta sale de CSS; la cabecera se oculta solo de forma visual.
- **Formularios:** validación inline accesible (`aria-invalid`, `.field-error` asociado
  con `aria-describedby`), barra de acciones fija (`.form-actions`, queda sobre la barra
  inferior en móvil), editor con medida de 80 ch.
- **Paleta de comandos** (Ctrl/Cmd+K): mismo módulo que la web, empaquetado en
  `server/admin/assets/palette.js` (`npm run admin:palette`, también en `npm run build`).
- **Foco:** anillo `--accent` de 2 px con offset 2 px.
- **Objetivos táctiles de 44 px** en menú, botones (táctil o < 768 px), campos y casillas.
- El token `--faint-ui` es propio del admin (`#8592a6` / `#6b7a92`) para bordes de
  componente, no para texto.

## Elevación y forma

Superficies planas: capa tonal más borde de 1 px. Sombra solo donde separa de verdad:
la ficha del hero (`.ev-card`), la paleta y los modales (con `scrim` y desenfoque de
fondo), y `--shadow-card` en el admin. Radios: **4 px** chips e insignias, **6 px**
botones y campos, **8 px** tarjetas, **12 px** paneles grandes y paleta del admin.

## Foco y movimiento

- **Foco global** (`:focus-visible`): hueco de 2 px del color de fondo, anillo `--text` de
  2 px (≥ 3:1 en ambos temas) y halo `--mark` de 7 px. Lleva un `outline` transparente de
  2 px para el modo de alto contraste de Windows, que anula los `box-shadow`.
- **Movimiento:** transiciones de color cortas y el barrido de la evidencia. Con
  `prefers-reduced-motion: reduce`, animaciones y transiciones quedan a ~0 ms. El reveal
  al scroll solo oculta contenido tras el gate `.js-reveal`: sin JS todo es visible.

## Reglas duras

- **Sin cursiva ni serif.** Ninguna `italic` ni familia serif en la interfaz. Los
  `<em>` del anuncio llevan `not-italic font-semibold`.
- **Sin tarjetas anidadas.** Una tarjeta no contiene otra tarjeta con borde y fondo.
- **Sin kickers.** No hay etiquetas pequeñas en versalitas sobre los títulos de sección.
  `.section-kicker` sigue definida en `global.css` pero ninguna sección la usa; no se
  reintroduce.
- **Objetivos táctiles ≥ 44 px** en móvil (24 px es el mínimo WCAG; 44 es la meta del
  proyecto). Los CTA del hero, los filtros y todo el admin táctil cumplen 44.
- **Sin terminal falsa** ni efectos que aparenten datos en vivo.
- **Máximo dos familias web.** Las `Fallback` son ajustes de métrica (ver Typography).
- **CSP intacta.** Sin `unsafe-inline` en `script-src`, sin CDN de scripts, fuentes ni
  estilos, sin `<script>` inyectado en runtime. En el admin, sin `<script>` ni `<style>`
  dinámicos nuevos. `e2e/csp.spec.cjs` lo comprueba.
- **Los tokens son idénticos** en `tokens.css` y `admin.css`; los comprueba
  `src/test/tokens.test.ts`.
- **El amarillo es relleno; el azul es texto; el rojo es fallo.**
- **Tres longitudes de texto.** Todo se diseña para ES, EN y CA; sin scroll horizontal a
  360, 390, 768, 1024 ni 1440 px.
- **Tests de `src/pages/`** van en `src/test/pages/`, no junto a la ruta.

## Cosas por verificar

Estado conocido tras el rediseño, sin presentar como resuelto:

- Lighthouse (LCP/CLS/INP) y axe sin repetir en el cierre (tarea T8).
- Lector de pantalla real en el admin sin probar; solape del `.form-actions` fijo a 1440
  px sin captura.
- Contraste de `--text-faint` en texto de 0,8–0,875 rem (`.spec-term--meta`, `.about-note`)
  sin calcular en píxeles.
- Objetivos de 40 px en 1440 de algún elemento del shell (`min-h-10`).
- El título del admin sigue como "Resumen global" en la vista multi-sitio, y "Resumen" en
  el menú, frente a "Hoy" en la vista principal (los e2e exigen la etiqueta).
