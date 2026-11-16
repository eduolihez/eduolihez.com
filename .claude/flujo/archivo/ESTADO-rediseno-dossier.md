# Flujo · Rediseño visual y UX (portfolio + admin)

**Fase:** 7/7 Finalizado (pendiente: OK de Edu para push/despliegue)
**Tamaño:** L
**Inicio:** 2026-11-16

## Objetivo
Rediseñar de cero la interfaz pública y el panel `/admin` bajo la dirección B "Dossier de analista", maximizando claridad para reclutadores (<1 min), credibilidad para pares técnicos, UX, responsive y rendimiento.

## Criterios de hecho
Ver `rubrica.md`.

## Fuera de alcance
- Micrositios de `/public/projects` y `/public/lab-app`.
- Cambios de backend/BD, salvo lo imprescindible para el admin (p. ej. borrado diferido si se decide).
- Contenido nuevo inventado (testimonios, métricas, clientes, datos "en vivo").

## Decisiones
- 2026-11-16 Dirección **B · Dossier de analista** — la investigación desaconseja la estética "hacker" y pide evidencia verificable; encaja con la regla "cada afirmación tiene un archivo". Elegida por Edu.
- 2026-11-16 Admin en modo Operate: misma familia y tokens que la web, sobrio, sin serif decorativo.
- 2026-11-16 MariaDB local (winget) aprobada por Edu solo para BD `_test` en localhost.

## Investigación
- Impresión visual en ~50 ms con efecto halo — Lindgaard 2006 (nature.com/news/2006/060109).
- El diseño fue el factor de credibilidad más citado (46 %) — Stanford Web Credibility (bokardo.com/archives/web_credibility).
- El 79 % escanea; lo clave arriba a la izquierda — NN/g (how-users-read-on-the-web, f-shaped-pattern).
- Reclutadores: ~6 s por CV, 80 % del tiempo en nombre, cargos, fechas, formación — TheLadders 2012 (solo prensa; hipótesis para portfolios).
- Claro tiene ligera ventaja de legibilidad; ofrecer ambos con prefers-color-scheme — NN/g dark-mode.
- Admin: sidebar en escritorio / barra inferior en móvil, "Hoy", deshacer antes que confirmar, validación inline con aria-describedby — Material, Primer, Polaris, WCAG 2.2.
- No verificado: Linear/Vercel/Stripe, autoguardado con fuente primaria, la mayoría de portfolios de referencia.

## Diagnóstico del estado actual (home, 1440 px, datos reales)
- ~13.500 px de alto, 7 secciones con el mismo ritmo de tarjetas.
- Hero con terminal falsa (`$ whoami`), desaconsejada por la investigación.
- Habilidades: ~35 pastillas planas sin evidencia.
- FAQ de 10 preguntas pesa mucho para el escaneo.
- Reveal al scroll deja secciones vacías en capturas completas (no es bug; verificar con movimiento reducido).

## Mundo visual afinado: "Expediente"
Para esquivar el cliché (crema + serif + mono) y el de "consola hacker": el mundo es el **expediente de un analista**: informe de incidente con evidencias numeradas.
- **Ground:** gris frío de papel técnico (claro) / tinta azul noche (oscuro). Banda de portada en tinta azul noche también en claro (color comprometido, no solo acento).
- **Acento único:** amarillo marcador (relleno con texto tinta; nunca texto amarillo sobre claro). Rojo solo para fallo. Foco = anillo tinta + halo marcador.
- **Tipos:** titulares en una grotesca con carácter editorial (candidata `@fontsource-variable/schibsted-grotesk`), cuerpo Inter, JetBrains Mono solo para IDs de evidencia y metadato. Se elimina el serif cursivo y toda la terminal falsa. Máx. 3 familias.
- **Firma:** "cadena de evidencias": cada afirmación del hero lleva una etiqueta E-01… enlazada a su fuente real (credencial en Credly, repo, archivo de `about-tech.ts`). Al enfocar/hover la afirmación y su evidencia se resaltan con barrido de marcador. Solo se usan fuentes que ya existen en datos.
- **Hero (1440×900 y 390×844):** nombre + rol + una frase + CTA contacto (marcador) + CV + LinkedIn; a la derecha "ficha" con puesto actual, 3 certificaciones con año y enlace de verificación, ubicación/idiomas y disponibilidad.
- **Home más corta:** Hero → Experiencia compacta → Evidencia (proyectos + certificaciones destacadas) → Habilidades agrupadas (sin marquee ni muro de pastillas) → Blog → FAQ (5 visibles, resto plegado) → Contacto. Objetivo ≤ 8.000 px a 1440.
- **Admin (Operate):** mismos tokens, sin serif ni portada; Inter + mono. Sidebar fija en escritorio y barra inferior en móvil, "Hoy" como inicio, tablas que pasan a tarjetas en móvil, deshacer en lugar de confirmar donde sea reversible, validación inline accesible.

## Plan (propietario de ficheros por tarea)
- [ ] T1 Fundación: `tokens.css` (3 bloques), fuentes (`package.json`, `global.css` @font-face, preload en `BaseLayout`), capas base/componentes de `global.css`. Hecho cuando: build verde, contraste AA verificado por script.
- [ ] T2 Shell: `Header`, `Footer`, `Palette`, `CvModal`, `Announcement`, `theme*`. Hecho cuando: navegación teclado + móvil sin solapes ES/EN/CA.
- [ ] T3 Hero + `StackStrip` + ficha de evidencias (datos reales de `config.ts`, `experience.ts`). Hecho cuando: criterio 6 de la rúbrica.
- [ ] T4 Secciones: `Experience`, `Skills` (+`skills.ts`), `Projects`+`projects.ts`, `Certifications`+`certifications.ts`, `BlogPreview`+`blog.ts`, `Faq`, `Contact`, `PortfolioSections`. Actualiza `*.test.ts` afectados. Hecho cuando: tests verdes y home ≤ 8.000 px.
- [ ] T5 Lectura: blog índice/post, `.prose`, `BlogPostBody`. Hecho cuando: medida 60-75 ch, contraste AA, código legible.
- [ ] T6 Auxiliares: `sobre-esta-web`/`AboutTech`, 400-500, `AppPage`, `ProjectLanding`, `/projects`.
- [ ] T7 Admin: `admin.css`/`auth.css`, `layout.php`, `index.php` ("Hoy"), tablas, formularios, editor, fuentes en `assets/fonts`, regenerar `palette.js`; BD `_test` local en MariaDB para e2e. Hecho cuando: e2e verdes + capturas claro/oscuro ×(360, 768, 1440).
- [ ] T8 Verificación y cierre: CSP, axe, Lighthouse móvil, matriz responsive ES/EN/CA, `DESIGN.md` por documenter.
Orden: T1 → (T2, T3) → T4 → (T5, T6) ; T7 en paralelo a partir de T1 (tokens ya fijados).
Riesgos: clases Tailwind construidas en `src/scripts/*.ts` (renombrar tokens rompe tests y pintado); `palette.js` es bundle versionado; reveal oculta contenido sin JS solo si `js-reveal`.

## Ajustes tras la crítica (puerta 2)
- **Datos de evidencias (T0):** nuevo campo estático `evidence` en `src/config.ts` con URL real tomada de la BD de producción: Azure AI (Credly badge), Fortinet (perfil Credly), Trend Micro Advanced y TryHackMe (PDF en `/certificaciones/`). Test: cada ruta local existe en `public/`. Si una afirmación no tiene fuente, no lleva etiqueta E-nn.
- **Disponibilidad:** `open_to_work` está a `0` en producción. La insignia sigue siendo dinámica (ajuste real del panel) con hueco de altura fija; no se hardcodea.
- **Clases en `src/scripts/*.ts`:** regla dura: no renombrar clases Tailwind ni tokens (`bg-bg-card`, etc.); solo cambian los valores en `tokens.css`. Cualquier clase nueva se añade, no sustituye, y se actualizan los `*.test.ts`.
- **`palette-*`:** se estila en `global.css` y `admin.css`; T2 y T7a la sincronizan. `palette.js` se regenera con `npm run build` (efecto de T2, no tarea).
- **FAQ:** las 10 preguntas siguen en el DOM (`<details>`); solo se pliegan visualmente 5. `llms.txt` y `FAQPage` sin cambios.
- **Marquee:** se elimina el marquee de habilidades; se borran `marquee.ts` y su test, no se dejan huérfanos.
- **Fuentes:** peso total ≤ 120 KB en el home, latin + latin-ext, `size-adjust`. Si Schibsted Grotesk no cabe, usar Inter para titulares con peso/tracking distintos.
- **Plan revisado:** T0 esquema de evidencias + línea base Lighthouse/capturas · T1 · T2 · T3 · T4a (Experience, Skills, Faq, Contact) · T4b (Projects, Certifications, Blog + scripts + tests) · T5 · T6 · T7a (tokens, shell, sidebar/bottom-nav, "Hoy") · T7b (tablas, formularios, editor, e2e, MariaDB `_test`) · T8 continuo con `npm run verify` creado en T1.
- **Añadido (S):** permalink por E-nn ("copiar enlace") y `@media print` de la ficha del hero.
- **Línea base:** pendiente de medir en T0.

## Revisión (fase 4)
| Tipo | Hallazgo | Esfuerzo | ¿Entra? |
|---|---|---|---|

## Tests (fase 6)
- (pendiente)

## Siguiente paso
Puerta 2: Edu aprueba el plan revisado (T0-T8). Tras el visto bueno: pasar a fase 3 con `orquestar` (briefs pequeños, `git commit -- <paths>`), empezando por T0 (esquema de evidencias + línea base) y T1.


## Fase 4 cerrada (puerta): Edu dijo "Implementalo todo, y contempla el uso de cookies para tener mas datos"
Entra: todos los Arreglar (A1-A9), Mejoras M1-M9, Nuevas N1-N3, recortes del crítico (StackStrip, filtros /projects, Ctrl K visible, FAQ visible 5) y cookies.
Decisiones mías (revisables): (a) NO borrar habilidades de Edu sin respaldo (Penetration Testing, Red Teaming, Next.js): el mapa de evidencias las marca y se lista aparte; (b) motivo del formulario = prefijo en el asunto, sin cambio de esquema; (c) cookies = OPT-IN: sin consentimiento o con DNT se mantiene la analítica sin cookies tal cual; con consentimiento, cookie propia `eo_vid` (aleatoria, 180 días, SameSite=Lax, Secure) -> visitante nuevo/recurrente; migración SQL escrita pero NO aplicada a producción; hay que actualizar los textos públicos que dicen "sin cookies".
Tareas: T9a (web: certs/hero/form/header/tokens) -> T9b (web: blog, huérfanos, rss, imágenes, habilidades, recortes, /evidencias, dossier PDF) -> T10 (admin) -> T11 (cookies+consentimiento+admin analytics+textos) -> fase 6.

## Fase 6 cerrada
- 461 tests, build 105 páginas, e2e admin 101/101 (antes de los 2 últimos cambios menores de PHP), `php -l` OK; PHPUnit no corrió (sin composer).
- Medido en navegador: 0 scroll horizontal en 110 combos; home 1440 = 7.988/7.897/7.988 px; sin JS OK (41 certs); fuentes 86,6 KiB cargadas; axe sin fallos persistentes tras arreglar `--oss` y bylines; Lighthouse móvil A11y 100, SEO 100, BP 77 (404 de API en estático + extensión), Perf 80 (servidor local sin compresión).
- Rúbrica: 14/14 con evidencia repartida entre revisor ciego y mediciones.
- Abiertos para Edu: home en móvil 12.987 px (Proyectos 4.464 px); skills sin respaldo (Penetration Testing, Red Teaming, Next.js); M2 sin datos; migración `visitor_id` NO aplicada; `lab-app/` en dist; decisiones de cookies (180 días, 6 meses); banner tapa la fila E-01 hasta elegir; PHPUnit; `.stack-strip` CSS huérfano; `docs/seo/` sin commit.
