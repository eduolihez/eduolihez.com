# Rúbrica — Rediseño visual y UX (portfolio + admin)
_Criterios comprobables. La evalúa `reviewer` en contexto limpio (fases 4 y 6), máx. 3 vueltas. "Bloqueante" = si falla no se cierra; "importante" = se corrige o se justifica; "deseable" = bonus._

| # | Criterio | Cómo se comprueba | Peso |
|---|---|---|---|
| 1 | `npm test` y `npm run build` pasan; tests nuevos para funciones/ramas nuevas | `npm test`, `npm run build` | bloqueante |
| 2 | CSP intacta: sin `unsafe-inline` en `script-src` (web: `security.csp` en `astro.config.mjs`; admin: cabecera en `server/admin/auth.php` L31-33), sin CDN, sin `<script>`/`<style>` ni `style=""` dinámicos nuevos en el admin | `astro preview` sin violaciones CSP + `e2e/csp.spec.cjs` en verde | bloqueante |
| 3 | Fuentes autoalojadas (`@fontsource`) con subsets `latin` y `latin-ext`, `font-display: swap` + `size-adjust`/preload sin CLS; copiadas a `server/admin/assets/fonts` si las usa el admin; máx. 3 familias; peso total de fuentes del home ≤ 120 KB | `grep` de URLs externas = 0; suma de bytes de woff2 cargados en Playwright | bloqueante |
| 4 | Tokens idénticos en `tokens.css` y `admin.css` y contraste AA de los pares reales (texto/fondo, marcador+tinta, foco ≥ 3:1) en claro y oscuro | test automático `src/test/tokens.test.ts` (igualdad + contraste) | bloqueante |
| 5 | Sin scroll horizontal ni solapes a 360, 390, 768, 1024, 1440 px en ES/EN/CA | capturas Playwright por ancho e idioma + `scrollWidth <= innerWidth` | bloqueante |
| 6 | Home: en el primer viewport (1440×900 y 390×844) se ven nombre, rol, ≥ 3 certificaciones con enlace de verificación, y CTA contacto + CV + LinkedIn | captura de ambos viewports | bloqueante |
| 7 | Evidencias: cada etiqueta E-nn sale de un campo de datos con URL o ruta; el build/test falla si una ruta local no existe en `public/` o si falta el campo. Sin terminal falsa, sin testimonios/métricas/casos inventados. Paridad de E-nn en ES/EN/CA | `src/test/evidence.test.ts` + revisión del diff | bloqueante |
| 8 | Rendimiento en `astro preview` (móvil emulado, mediana de 3 ejecuciones): LCP ≤ 2,5 s, CLS ≤ 0,1, INP ≤ 200 ms; no empeora la línea base de `ESTADO.md` | Lighthouse ×3 | importante |
| 9 | Accesibilidad: foco visible, teclado completo, `prefers-reduced-motion`, objetivos táctiles ≥ 24 px (44 px en móvil como meta), enlace de salto, axe sin errores en home, blog, post y admin | axe + recorrido con teclado en Playwright | bloqueante |
| 10 | SEO/IA intactos: JSON-LD, `FAQPage` (las 10 preguntas siguen en el DOM), `llms.txt`, sitemap y hreflang idénticos al estado base | diff de snapshot antes/después | bloqueante |
| 11 | Funciona sin JS y sin PHP: contenido estático legible, los fallos de `fetch` muestran estado de error/vacío sin saltos de layout (CLS ≤ 0,1) | Playwright con JS desactivado y API bloqueada | importante |
| 12 | Home ≤ 8.000 px de alto a 1440 y HTML + CSS no mayores que la línea base | medición Playwright + `du` de `dist/` | importante |
| 13 | Admin: navegación lateral (escritorio) y barra inferior (móvil), vista "Hoy", tablas que pasan a tarjetas en móvil, formularios con validación inline accesible, estados vacío/error; e2e en verde | `e2e/` contra BD `_test` + capturas claro/oscuro × 360/768/1440 | bloqueante |
| 14 | `DESIGN.md` y `PRODUCT.md` actualizados (nueva identidad; corregir que el CSS del admin es `admin.css` externo) | leer ambos ficheros | deseable |

Reglas: cada criterio se comprueba sin preguntar al autor · nada de "buena UX" sin medida.
