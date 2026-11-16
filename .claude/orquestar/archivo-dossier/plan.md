# Plan de orquestación · Rediseño "Expediente"
Fuente de verdad del diseño: `.claude/flujo/ESTADO.md` + `.claude/flujo/rubrica.md`. Ejecución secuencial (ficheros compartidos: `global.css`, `tokens.css`, `BaseLayout`).

## Restricciones globales
- CSP intacta (rúbrica 2). Nada de CDN, `<script>`/`<style>` inline nuevos en admin.
- NO renombrar clases ni tokens que usan `src/scripts/*.ts` y sus tests; solo cambian valores. Clase nueva = se añade.
- Tests de `src/pages/` van en `src/test/pages/`. Test nuevo por función/rama nueva.
- Commits con `git commit -- <paths>`; nunca `git add -A`. Sin push.
- Sin datos inventados: cada E-nn sale de un campo con URL/ruta real.
- Texto visible nuevo en ES/EN/CA con paridad.
- Briefs largos con Write, no heredocs.

## Tareas (en orden)
| # | Tarea | Ficheros dueños | Dif. | Dep. |
|---|---|---|---|---|
| T0 | Esquema `evidence` + test + línea base (SEO snapshot, peso, altura home) | `src/config.ts`, `src/test/evidence.test.ts`, `.claude/flujo/baseline/*` | normal | – |
| T1 | Fundación: tokens, fuentes, base/componentes CSS, `npm run verify`, `tokens.test.ts` | `src/styles/tokens.css`, `src/styles/global.css`, `package.json`, `src/layouts/BaseLayout.astro`, `scripts/verify.mjs`, `src/test/tokens.test.ts` | diseño | T0 |
| T2 | Shell: Header, Footer, Palette, CvModal, Announcement, theme | componentes shell + `theme*` + tests | normal | T1 |
| T3 | Hero + StackStrip + ficha de evidencias | `Hero*`, `StackStrip*`, i18n del hero | diseño | T1, T0 |
| T4a | Experience, Skills(+`skills.ts`, quitar marquee), Faq, Contact | sus componentes + tests | normal | T2, T3 |
| T4b | Projects, Certifications, BlogPreview (+scripts) + `PortfolioSections` | sus componentes + scripts + tests | normal | T4a |
| T5 | Lectura: blog índice/post, `.prose` | páginas blog, `BlogPostBody` | normal | T4b |
| T6 | Auxiliares: sobre-esta-web, 400-500, AppPage, ProjectLanding, /projects | esas páginas | mecánica | T4b |
| T7a | Admin base: tokens, shell, sidebar/bottom-nav, "Hoy" | `admin.css`, `auth.css`, `layout.php`, `index.php`, fuentes admin | diseño | T1 |
| T7b | Admin: tablas→tarjetas, formularios, editor, e2e + MariaDB `_test` | `messages/projects/posts.php`, e2e | normal | T7a |
| T8 | Verificación continua + `DESIGN.md`/`PRODUCT.md` | docs | normal | todas |

## Criterio de hecho global
`.claude/flujo/rubrica.md`.
