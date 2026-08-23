---
name: eduolihez.com
description: Consola de guardia en penumbra — verde señal escaso sobre negro azulado, mono para metadatos, superficie plana por capas tonales.
colors:
  signal-green: "#4ade80"
  signal-green-hover: "#22c55e"
  signal-green-soft: "#134e2a"
  probe-cyan: "#22d3ee"
  trace-violet: "#a78bfa"
  ink: "#0a0e14"
  ink-soft: "#0f141c"
  ink-card: "#141a24"
  hairline: "#1f2733"
  hairline-hover: "#2b3543"
  text-primary: "#e6edf3"
  text-title: "#f0f3f6"
  text-muted: "#9aa7b8"
  text-faint: "#78849a"
  danger: "#f87171"
  warn: "#f59e0b"
  veil: "rgb(3 5 8 / 0.7)"
  oss: "#10b981"
  wip: "#f59e0b"
  closed: "#60a5fa"
  print-paper: "#ffffff"
  print-ink: "#000000"
  print-rule: "#cccccc"
typography:
  display:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(1.875rem, 5vw, 3rem)"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(1.5rem, 3vw, 1.875rem)"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.025em"
  title:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1rem"
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: "normal"
  title-lg:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: "normal"
  body:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.625
    letterSpacing: "normal"
  subtitle:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.625
    letterSpacing: "normal"
  label:
    fontFamily: "JetBrains Mono, ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "0.75rem"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0.2em"
  meta:
    fontFamily: "JetBrains Mono, ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "0.6875rem"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  micro:
    fontFamily: "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "0.625rem"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "normal"
rounded:
  xs: "2px"
  sm: "4px"
  md: "6px"
  lg: "8px"
  xl: "12px"
  full: "9999px"
spacing:
  gutter: "20px"
  gutter-lg: "32px"
  grid-gap: "20px"
  card-pad: "20px"
  panel-pad: "24px"
  section-y: "80px"
  section-y-lg: "112px"
components:
  button-primary:
    backgroundColor: "{colors.signal-green}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "10px 16px"
    typography: "{typography.body}"
  button-primary-hover:
    backgroundColor: "{colors.signal-green-hover}"
    textColor: "{colors.ink}"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.text-muted}"
    rounded: "{rounded.md}"
    padding: "10px 16px"
    typography: "{typography.body}"
  button-ghost-hover:
    backgroundColor: "transparent"
    textColor: "{colors.text-primary}"
  card:
    backgroundColor: "{colors.ink-card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-pad}"
  input:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
    padding: "10px 14px"
    typography: "{typography.body}"
  chip:
    backgroundColor: "transparent"
    textColor: "{colors.text-muted}"
    rounded: "{rounded.sm}"
    padding: "2px 8px"
    typography: "{typography.meta}"
  status-pill:
    backgroundColor: "{colors.signal-green}"
    textColor: "{colors.ink}"
    rounded: "{rounded.full}"
    padding: "4px 12px"
    typography: "{typography.meta}"
  status-panel:
    backgroundColor: "{colors.ink-card}"
    textColor: "{colors.text-muted}"
    rounded: "{rounded.lg}"
    padding: "14px 16px"
    typography: "{typography.body}"
  status-panel-error:
    backgroundColor: "{colors.ink-card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.lg}"
    padding: "14px 16px"
---

# Design System: eduolihez.com

## Overview

**Creative North Star: "La Consola de Guardia"**

Un puesto de vigilancia de madrugada. La pantalla está en penumbra porque el turno
dura horas y la vista tiene que aguantar; todo se lee sin esfuerzo sobre un negro
azulado que nunca llega al negro puro. El verde no decora: aparece exactamente donde
algo está vivo, disponible o es accionable, igual que en un panel de operación. Cuando
todo está en calma, la pantalla está casi en blanco y negro.

El dialecto de terminal está presente pero contenido. El prompt `>_` en la marca, los
kickers de sección en mono versalita con `0.2em` de tracking, la línea
`Status: OPTIMIZING_CV // Severity: INFO` del modal de CV, el punto que late junto al
avatar cuando hay disponibilidad. Es una terminal ordenada y apagada, no una pantalla
de película: **ningún efecto simula ser algo que el sitio no es.** Esa contención es
coherente con la promesa del producto — si la web afirma algo, el repositorio lo
respalda — y se extiende a lo visual: nada aparenta profundidad, actividad o volumen
que no exista de verdad.

La densidad es media-alta pero respirada. Las secciones se separan por bloques de
80–112px y se distinguen por tono, no por marco: el fondo alterna entre `#0a0e14` y
`#0f141c`, y una hairline de 1px cierra cada bloque. La composición es de una sola
columna centrada a 1024px, con rejillas de dos o tres celdas dentro. Todo el trabajo
de jerarquía lo hacen el tono, el peso tipográfico y el espacio.

**Key Characteristics:**
- Negro azulado en tres capas tonales, jamás negro puro (`#0a0e14` → `#0f141c` → `#141a24`)
- Un solo verde señal (`#4ade80`), escaso por doctrina
- Inter para lo que se lee, JetBrains Mono exclusivamente para metadatos, etiquetas y código
- Superficie plana: separación por hairline de 1px y capa tonal, casi nunca por sombra
- Radio contenido y creciente con el tamaño de la superficie (2px → 12px)
- Movimiento mínimo: `fade-up` de entrada, transiciones de color de 150–300ms, nada más

## Colors

Paleta oscura y estrecha: cuatro escalones de fondo, cuatro de texto y un solo acento
cromático con dos secundarios reservados a un uso muy concreto.

### Primary

- **Verde Señal** (`#4ade80`): el único acento del sistema. Marca la acción primaria
  (`.btn-primary`), los enlaces (`.link-accent`), los kickers de sección, el rol en el
  hero, el contador de certificaciones, el foco visible y el estado "disponible para
  trabajar". Su trabajo es señalizar, no ambientar.
- **Verde Señal Intenso** (`#22c55e`): exclusivamente el hover del botón primario y de
  los enlaces del cuerpo del blog. Nunca es un color de reposo.
- **Verde Señal Tenue** (`#134e2a`): fondo de badge sobre oscuro, para cuando hace falta
  un plano verde sin gritar. En la práctica se usa poco: el patrón dominante es
  `signal-green` a `/5`–`/20` de opacidad sobre el fondo de la sección.

### Secondary

- **Cian de Sonda** (`#22d3ee`): acento secundario reservado a **"Sobre esta web"**,
  donde los bloques temáticos necesitan diferenciarse entre sí (`tone: 'cyan'`). No es
  un color de uso general.

### Tertiary

- **Violeta de Traza** (`#a78bfa`): tercer tono de la misma rotación de "Sobre esta web"
  (`tone: 'violet'`). Mismo alcance restringido que el cian.

### Neutral

- **Tinta** (`#0a0e14`): fondo principal del sitio y de las secciones impares. Negro
  azulado, nunca `#000`.
- **Tinta Suave** (`#0f141c`): fondo de las secciones alternas (proyectos, contacto,
  FAQ, blog). Es el mecanismo principal de separación entre bloques.
- **Tinta de Tarjeta** (`#141a24`): la tercera y última capa. Tarjetas, menús
  desplegables, modales, campos de código.
- **Hairline** (`#1f2733`): el borde de 1px que dibuja tarjetas, campos, chips y
  secciones. Es la herramienta de estructura por defecto de todo el sistema.
- **Hairline Activa** (`#2b3543`): la misma línea al pasar el ratón sobre una tarjeta.
- **Texto Principal** (`#e6edf3`): cuerpo y titulares de sección.
- **Texto de Titular** (`#f0f3f6`): un escalón por encima, reservado a los `h2`/`h3` del
  contenido del blog y a la marca del pie.
- **Texto Atenuado** (`#9aa7b8`): descripciones, subtítulos de sección, navegación en
  reposo, contenido secundario. Es el color de más superficie del sitio después del fondo.
- **Texto Tenue** (`#78849a`): metadatos, fechas, etiquetas de columna, pistas. Es el escalon mas tenue que aun cumple WCAG AA (4.63 sobre `ink-card`, el peor fondo); el valor anterior `#6b7688` se quedaba en 3.80.

### Status

- **Rojo de Fallo** (`#f87171`): el único rojo del sistema. Errores de carga, alertas
  y acciones destructivas, en el sitio público y en `/admin`. Se usa como texto sólido
  sobre fondo al 5% y borde al 30%.
- **Ámbar de Aviso** (`#f59e0b`): avisos y contenido retirado deliberadamente (la
  página 410, cuyo propio texto dice que no es un error). También el badge "En Desarrollo".

Tres badges de proyecto, siempre en el mismo patrón: texto sólido, fondo al 10%, borde al 20%.

- **Open Source** (`oss`, `#10b981`) · **En Desarrollo** (`wip`, `#f59e0b`) · **Código Privado** (`closed`, `#60a5fa`)

Son **tokens**, no literales de Tailwind. Se escriben `text-oss` / `bg-wip/10` /
`border-closed/20`. Antes se escribían `bg-emerald-500` y compañía: coincidían de valor,
pero no estaban atados al sistema, así que un cambio de token no habría llegado a la
interfaz. Contraste verificado: 7.07, 8.31 y 7.03 sobre el fondo del pie.

### Otros

- **Velo de Modal** (`rgb(3 5 8 / 0.7)`): el único uso de un negro más profundo que
  `ink`, y solo detrás de un modal, siempre con `backdrop-filter: blur(4px)`.
- **Impresión** (`print-paper` `#ffffff`, `print-ink` `#000000`, `print-rule` `#cccccc`):
  los únicos blancos y negros absolutos del sistema. Existen solo dentro de
  `@media print`, donde la web se convierte en un CV sobre papel y el contraste máximo
  deja de ser un problema para pasar a ser el objetivo.

### Named Rules (estado)

**La Regla del Verde que no Falla.** El verde significa "vivo, disponible, accionable".
Por eso **no puede significar también "ha fallado"**: un error nunca va del color de lo
que funciona. Todo fallo usa `danger`; todo aviso usa `warn`. Antes de esta regla la
página 404 anunciaba `ERROR: 404 ROUTE NOT FOUND` en verde.

**La Regla del Rojo Único.** Hay un solo rojo: `#f87171`. Históricamente el sitio
improvisó cinco (`red-300`, `red-400`, `red-500`, `red-600`, `rose-900`) más un naranja
y un amarillo, todos fuera de paleta. Un segundo rojo es deriva, no un matiz.

### Named Rules

**La Regla de la Señal Escasa.** El verde no supera aproximadamente el 10% de la
superficie visible de ninguna pantalla. Su rareza es exactamente lo que lo hace legible
como señal: si todo es verde, nada avisa. Antes de añadir un elemento verde a una
pantalla, comprueba qué otro deja de serlo.

**La Regla del Verde Único.** Hay un solo verde de marca: `#4ade80`. El panel `/admin`
usa hoy `#10b981` y un fondo `#090e16` propios: eso es **deriva, no un subsistema**. La
paleta de esta página es la normativa; cualquier trabajo en `/admin` converge hacia ella.

**La Regla del Tercer Tono.** El cian y el violeta tienen exactamente **dos** usos, y
ninguno más: separar los bloques temáticos de "Sobre esta web", y teñir los sellos de
emisor de la sección de certificaciones cuando una credencial no trae logotipo. Los dos
son decorativos, acotados y pequeños. Llevarlos a un titular, a un botón o a un enlace
rompe el sistema — el sitio tiene un acento, no tres.

*Nota de procedencia:* el segundo uso no estaba en la primera versión de este documento
porque no vi ese componente al escribirlo. La auditoría lo destapó: la paleta de sellos
tenía siete tonos, dos de ellos (`#f472b6` rosa y `#34d399` verde-400) fuera de la paleta
por completo. Se redujo a cuatro tokens del sistema y la regla se amplió para describir
lo que el código hace de verdad.

## Typography

**Display / Body Font:** Inter Variable (con `system-ui`, `-apple-system`, `Segoe UI`, `Roboto`)
**Label / Mono Font:** JetBrains Mono Variable (con `ui-monospace`, `SFMono-Regular`, `Menlo`)

Ambas autoalojadas con `@font-face` declaradas a mano, solo subconjuntos `latin` y
`latin-ext`, ejes variables completos (Inter 100–900, JetBrains Mono 100–800) y
`font-display: swap`. **No hay ninguna petición a un CDN de fuentes en el sitio público**,
y esa es una decisión de seguridad, no de rendimiento.

**Character:** un par funcional, no expresivo. Inter aporta neutralidad legible a
cualquier tamaño; JetBrains Mono aporta la voz de la máquina. La personalidad no está en
la elección de las familias sino en el reparto estricto entre ellas: la mono no es un
recurso estético, es una categoría semántica.

### Hierarchy

- **Display** (600, `1.875rem` → `3rem`, `tracking-tight`): el nombre en el hero. Una vez
  por página, nunca más.
- **Headline** (600, `1.5rem` → `1.875rem`, `tracking-tight`): títulos de sección
  (`.section-title`) y `h1` de las páginas interiores.
- **Title** (600, `1rem`–`1.125rem`): títulos de tarjeta, encabezados de modal, puestos
  del timeline.
- **Body** (400, `0.875rem`–`1rem`, `leading-relaxed` 1.625): párrafos, descripciones,
  subtítulos de sección (`.section-subtitle`, limitado a `max-w-2xl`).
- **Label** (mono, 500, `0.75rem`, `uppercase`, `tracking-[0.2em]`): los kickers de
  sección (`.section-kicker`) y los encabezados de columna del pie. Es la firma
  tipográfica más reconocible del sitio.
- **Meta** (mono, 400, `0.6875rem`–`0.75rem`): stacks de tecnología, fechas, contadores,
  la marca `>_ eduolihez`, la línea de estado del modal de CV.

### Named Rules

**La Regla del Mono como Metadato.** JetBrains Mono nunca compone prosa. Se reserva a
seis usos: la marca, los kickers de sección, los chips de tecnología, los números y
contadores, las etiquetas de estado y el código. Un párrafo en mono es un error del
sistema, no una variación.

**La Regla del Titular Ceñido.** Todo lo que sea Display o Headline lleva
`letter-spacing: -0.025em`. Todo lo que sea Label mono en versalitas lleva `0.2em`. No
hay tracking intermedio en el sistema: o se ciñe o se abre del todo.

## Layout

Una sola columna centrada. `.container-page` fija `max-width: 64rem` (1024px) con
gutters de `20px` en móvil, `24px` desde `sm` y `32px` desde `lg`. Dentro, las rejillas
son de dos columnas (contacto, hero) o de tres (proyectos, certificaciones, blog),
siempre colapsando a una en móvil con `gap: 20px`–`24px`.

El ritmo vertical es de `80px` de padding de sección, `112px` desde `sm`. La cabecera es
fija, mide `56px` de alto y el documento compensa con `scroll-padding-top: 5rem` para que
los anclajes no queden bajo ella. El hero es la única excepción al ritmo: `py-20` con
`pt-28`/`sm:pt-32` extra para librar la cabecera.

Breakpoints: los de Tailwind por defecto — `sm` 640px, `md` 768px, `lg` 1024px. `md` es
la frontera de la navegación (menú de escritorio ↔ hamburguesa); `lg` es donde el hero
pasa a dos columnas y los grids a tres.

Existe además un modo impresión completo: oculta cabecera, pie y formulario, invierte a
fondo blanco y texto negro, y convierte la home en un CV limpio con `break-inside: avoid`
por sección.

### Named Rules

**La Regla de la Alternancia Tonal.** Las secciones consecutivas alternan `ink` y
`ink-soft` y se cierran con `border-b` de `hairline`. Ese par —cambio de tono más línea
de 1px— es el único separador de sección del sistema. No se usan divisores decorativos,
ni ondas, ni degradados de transición.

*Nota de estado:* el token `--container-content: 72rem` está declarado en `@theme` pero
**ningún componente lo usa**; el ancho real lo fija `.container-page` a `64rem`. Está
registrado aquí para que nadie lo tome por normativo.

## Elevation & Depth

**Este apartado describe el estado observado, no una doctrina cerrada.** La profundidad
se construye hoy casi por completo con capa tonal y hairline: `ink` → `ink-soft` →
`ink-card`, cada plano separado por un borde de 1px. La inmensa mayoría de las superficies
son planas en reposo y responden al hover cambiando color de borde, no elevándose.

Las sombras existen, pero en un puñado de sitios contados y siempre con una razón:

### Shadow Vocabulary

- **Elevación de modal** (`shadow-2xl`, con `backdrop-filter: blur(4px)` y velo
  `rgb(3 5 8 / 0.7)`): la única elevación real del sistema. Separa el modal de proyecto y
  el de CV del documento que queda detrás.
- **Halo de disponibilidad** (`box-shadow: 0 0 15px rgba(74,222,128,0.4)`): el resplandor
  del badge "Disponible para trabajar" sobre el avatar. No es profundidad, es emisión: la
  única luz propia de toda la interfaz.
- **Realce de control** (`shadow-xs`): apoyo mínimo en los botones de filtro de proyectos
  y certificaciones, para despegarlos de la sección.
- **Velo de cabecera y pie** (`backdrop-blur-md` / `backdrop-blur-xs` con fondos a
  `/80` y `/40`): profundidad por translucidez, no por sombra.

*Decisión abierta:* no se ha fijado si "plano por defecto" es una prohibición o una
preferencia. Hasta que se decida, el estado anterior es la referencia: si una pantalla
nueva necesita una sombra, tiene que poder explicar por qué la capa tonal no bastaba.

## Shapes

Rectángulos de esquina blanda, sin excepción. No hay formas orgánicas, ni recortes, ni
siluetas irregulares en ningún punto del sistema. El vocabulario completo son seis pasos
de radio y una hairline de 1px.

- **2px** (`rounded-xs`): banderas del selector de idioma, micro-badges del pie.
- **4px** (`rounded-sm`): chips de tecnología, badges de estado de proyecto, `code` en línea.
- **6px** (`rounded-md`): botones, campos de formulario, elementos de menú, enlaces de navegación.
- **8px** (`rounded-lg`): tarjetas (`.card`), botones de filtro, iconos sociales del pie, imágenes del blog.
- **12px** (`rounded-xl`): las superficies grandes — el avatar, el panel del formulario de contacto, los modales.
- **9999px** (`rounded-full`): exclusivamente el badge de disponibilidad y los spinners de carga.

El borde por defecto es `1px solid` en `hairline`. Los estados de énfasis no engrosan el
borde: cambian su color (a `hairline-hover`, `text-faint/40` o `signal-green/40`).

### Named Rules

**La Regla del Radio Creciente.** El radio escala con la superficie: cuanto más grande el
contenedor, más blanda la esquina. Un chip a 12px o un modal a 4px rompen la escala. Si
dudas, mira el tamaño del elemento, no su importancia.

**La Regla de la Línea Única.** Toda estructura se dibuja con `1px`. No hay bordes de 2px
salvo el anillo de foco (`ring-2` en `signal-green`) y el aro que late alrededor del
avatar disponible — dos casos que son señal, no estructura.

## Components

### Buttons

- **Shape:** esquina de 6px (`rounded-md`), altura de 40px efectivos (`px-4 py-2.5`), `inline-flex` con `gap-2` para el icono.
- **Primary** (`.btn-primary`): plano de Verde Señal con texto en Tinta (`#0a0e14`), peso 500, `text-sm`. El contraste invertido es deliberado: el botón primario es la superficie más brillante de la página.
- **Ghost** (`.btn-ghost`): sin fondo, borde hairline, texto atenuado. Es el botón por defecto para todo lo que no sea la acción principal — en el hero conviven un primario y dos ghost.
- **Hover / Focus:** el primario transiciona a `#22c55e`; el ghost sube el borde a `text-faint` y el texto a `text-primary`. Solo transiciona el color (`transition-colors`); **nada se desplaza ni se escala**.
- **Foco:** `ring-2` en Verde Señal con `ring-offset-2` sobre el fondo, aplicado globalmente a `:focus-visible`.

### Chips

- **Tecnología** (`.badge`): borde hairline, sin fondo, mono `text-xs`, texto atenuado, radio 4px. Es el chip por defecto (experiencia, stack de proyecto).
- **Estado de proyecto:** texto sólido del color de estado, fondo del mismo color al 10%, borde al 20%, `text-[10px]` en peso 600. Tres variantes fijas: Open Source, En Desarrollo, Código Privado.
- **Filtro** (`.cert-filter-btn`, filtros de proyecto): radio 8px, fondo `ink-card`, `min-height: 2.5rem` para objetivo táctil. Activo = borde Verde Señal, fondo verde al 10%, texto verde.

### Cards / Containers

- **Corner Style:** 8px (`.card`), 12px en paneles grandes.
- **Background:** `ink-card` sobre secciones en `ink` o `ink-soft`.
- **Border:** hairline de 1px; al hover pasa a `text-faint/40`.
- **Shadow Strategy:** ninguna. Ver *Elevation & Depth*.
- **Internal Padding:** `20px` en tarjeta de proyecto, `24px`–`32px` en el panel del formulario.

### Inputs / Fields

- **Style:** fondo `ink` (más oscuro que la tarjeta que los contiene — el campo se hunde, no se levanta), borde hairline, radio 6px, `px-3.5 py-2.5`, `text-sm`, placeholder en `text-faint`.
- **Focus:** el borde pasa a Verde Señal y se anula el outline por defecto (`focus:outline-hidden`); el anillo global de `:focus-visible` cubre la navegación por teclado.
- **Label:** encima del campo, `text-sm` peso 500 en `text-primary`, con asterisco en Verde Señal cuando es obligatorio.

### Navigation

- **Cabecera:** fija, 56px, fondo `ink/80` con `backdrop-blur-md` y borde inferior `hairline/60`. Marca en mono con el prompt `>_` en verde. Enlaces en `text-muted` que suben a `text-primary` al hover — sin subrayado, sin indicador de sección activa.
- **Selector de idioma:** botón con borde hairline que muestra bandera SVG en línea + código de idioma; desplegable en `ink-card` con radio 6px y `shadow-xl`. El idioma activo se marca en Verde Señal.
- **Móvil (`< md`):** hamburguesa que despliega una lista a ancho completo sobre fondo `ink`, con enlaces de `44px` de alto (`py-2.5` + `text-base`).
- **Pie:** rejilla de cuatro columnas con encabezados mono en versalitas de `11px`, enlaces mono de `12px` y una línea superior en degradado de Verde Señal al 25% que se desvanece por los extremos.

### Status Panel (componente de firma)

Proyectos, certificaciones y blog piden su contenido a `/api/*.php` al cargar, así que
"cargando", "vacío" y "error" no son casos raros: son lo que ve cualquiera que entre
mientras el backend responde, o si se cae. Los tres estados viven en un solo componente
(`StatusPanel.astro`), y el JS solo cambia `data-state`.

- **Forma:** panel de 8px de radio, hairline de 1px, fondo `ink-card` al 60%, `14px 16px`.
- **Cargando:** spinner de 2px con el arco superior en Verde Señal.
- **Vacío:** icono `inbox` y borde discontinuo — el único uso de `border-dashed` del sistema.
- **Error:** icono `alert` en `danger`, borde `danger/30`, fondo `danger/5`, y un botón de
  reintento. Un error siempre nombra el problema **y** ofrece la salida.
- **Accesibilidad:** el contenedor lleva `role="status"` y `aria-live="polite"`, así que el
  cambio de estado se anuncia sin robar el foco.

### Reveal on scroll (componente de firma)

Toda sección entra con un `fade-up` de 18px en 500ms al cruzar el viewport. Lo distintivo
es el mecanismo: el ocultado inicial vive tras un gate `.js-reveal` que solo se aplica si
el script llega a ejecutarse. **Sin JavaScript, o si el script falla, el contenido está
siempre visible.** Es el patrón que debe imitar cualquier animación de entrada futura.

### Availability frame (componente de firma)

El avatar del hero es el único punto emisivo del sitio: aro verde al 20% desenfocado, aro
pulsante de 2px al 40%, y un badge en píldora con halo verde. Todo el conjunto se muestra
u oculta según `open_to_work` desde `/api/settings.php`, y **por defecto se muestra si la
petición falla**. Es la traducción visual del estado "en servicio" del North Star.

## Do's and Don'ts

### Do:

- **Do** separar bloques alternando `ink` / `ink-soft` más una `border-b` de `hairline`. Es el único separador de sección del sistema.
- **Do** encabezar cada sección con el trío `.section-kicker` (mono versalita, `0.2em`) → `.section-title` → `.section-subtitle` (limitado a `max-w-2xl`). Está en todas las secciones del sitio; romperlo se nota.
- **Do** usar `var(--color-*)` en los `<style>` de componentes Astro. Tailwind 4 publica cada token de `@theme` en `:root`; ese bloque no importa Tailwind y `theme()` ya no existe.
- **Do** dar a los controles táctiles un mínimo de `40px` de alto, como hace `.cert-filter-btn` con `min-height: 2.5rem`.
- **Do** poner cualquier animación de entrada tras un gate de JS, como `.js-reveal`: el contenido debe ser visible si el script no corre.
- **Do** diseñar contando con tres longitudes de texto. Los mismos botones y etiquetas se pintan en español, inglés y catalán.

### Don't:

- **Don't** introducir un segundo verde. `#10b981` en `/admin` es deriva conocida, no una escala hermana: la referencia es `#4ade80`.
- **Don't** llevar el cian (`#22d3ee`) ni el violeta (`#a78bfa`) fuera de "Sobre esta web". Existen solo para diferenciar los bloques de esa página.
- **Don't** componer prosa en JetBrains Mono. La mono es metadato: marca, kickers, chips, números, estados y código.
- **Don't** añadir sombras para dar jerarquía. La herramienta por defecto es la capa tonal más la hairline de 1px; la sombra queda para el modal y para el halo de disponibilidad.
- **Don't** mover ni escalar elementos en hover. El sistema transiciona color (150–300ms) y nada más; las dos únicas excepciones vigentes son los iconos sociales del pie (`-translate-y-0.5`) y la flecha de los enlaces de navegación del pie.
- **Don't** cargar fuentes, iconos, estilos o scripts desde un CDN. Las fuentes son `@font-face` locales con subconjuntos latinos; la CSP con hashes no admite otra cosa. `server/admin/partials/layout.php` autoaloja las mismas fuentes en `assets/fonts/` precisamente por esto — el panel llegó a enlazar Google Fonts, la CSP la bloqueaba en silencio, y se corrigió.
- **Don't** engrosar bordes para dar énfasis. La estructura es siempre `1px`; los únicos `2px` del sistema son el anillo de foco y el aro de disponibilidad, y ambos son señal.
- **Don't** pintar un error de verde ni inventar un rojo nuevo. `danger` (`#f87171`) para fallos, `warn` (`#f59e0b`) para avisos, y nada más.
- **Don't** dejar un estado de carga, vacío o error como una línea de texto suelta. Usa `<StatusPanel />`: tiene los tres estados, el icono, `role="status"` y la salida.
- **Don't** usar texto con degradado (`bg-clip-text`) ni halos de color sin desplazamiento (`drop-shadow` a 0 0). El énfasis sale del peso, el tamaño y el tono. Las cinco páginas de error los llevaban y se retiraron.
- **Don't** usar negro puro (`#000`) ni blanco puro (`#fff`) en pantalla. El sistema va de `#0a0e14` a `#f0f3f6`; el blanco y el negro absolutos están reservados a la hoja de impresión.
