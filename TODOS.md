# TODOS

## SEO / Visibilidad IA

### Caché de servidor para llms-blog.php si se dispara el umbral

**What:** Añadir una caché de fichero con TTL corto (5-10 min) a
`server/llms-blog.php` si el umbral de ~50 peticiones/día no provenientes de un
bot de IA reconocido (definido en `docs/designs/seo-ai-visibility.md`, sección
Open Questions) se llega a disparar.

**Why:** El archivo regenera el texto íntegro del blog en cada request (consulta
DB completa + regex de limpieza), sin caché de servidor — solo 1h de
`Cache-Control` de cliente, que no ayuda al tráfico de crawler. Evita tener que
tocar el archivo en caliente sin plan si el umbral se cumple.

**Context:** Decisión tomada durante la revisión de `/plan-eng-review` del
2026-08-23: no tocar el archivo ahora porque el plan de verificación (Approach A
del documento de diseño) decidió desplegar las 4 piezas de contenido-IA tal cual
hasta tener evidencia real de si hacen falta. `server/llms-blog.php` ya maneja
bien el fallo de DB (try/catch → 503 + Retry-After, sin exponer stack trace) —
esto es puramente una optimización de carga, no un fix de fiabilidad.

**Effort:** S
**Priority:** P3
**Depends on:** Resultado de Approach A en `docs/designs/seo-ai-visibility.md` —
solo tiene sentido revisar esto si el umbral realmente se dispara.

### Cobertura de tests para los endpoints que generan contenido para IA

**What:** Añadir un smoke test (Vitest, encaja con el stack Astro/Vite ya
existente) para `src/pages/llms.txt.ts` y `server/llms-blog.php` que verifique
que el output no rompe con datos vacíos o nulos.

**Why:** Son las dos piezas centrales de la apuesta de citabilidad-IA del
proyecto y hoy tienen cero red de seguridad. Un cambio futuro en `config.ts`, en
`experience.ts`/`skills.ts`/`faq.ts`, o en el esquema de la tabla `posts` podría
romper el output sin que nadie lo note hasta que una IA reciba una respuesta
rota o vacía.

**Context:** El proyecto no tiene framework de test en absoluto hoy (verificado
2026-08-23: sin `jest.config`/`vitest.config`/`playwright.config`, sin script
`test` en `package.json`, cero archivos de test en el repo). Instalar Vitest y
escribir estos dos smoke tests es el primer paso razonable, no una migración
completa a testing.

**Effort:** M
**Priority:** P2
**Depends on:** Ninguno.

### Sesión de diagnóstico para el público técnico SOC

**What:** Correr `/office-hours` (o una sesión dedicada) enfocada en el segundo
público de `PRODUCT.md` — comunidad técnica SOC/blue team — que
`docs/designs/seo-ai-visibility.md` dejó explícitamente fuera de alcance.

**Why:** `PRODUCT.md` declara los dos públicos (reclutador y comunidad técnica)
con el mismo peso, pero el diagnóstico de la sesión del 2026-08-23 se centró
solo en reclutador/citación-IA. El público técnico podría tener necesidades
distintas (ej. cómo se descubre y valora el repositorio público) sin
diagnosticar todavía.

**Context:** Ver "Target User & Narrowest Wedge" y "Open Questions" en
`docs/designs/seo-ai-visibility.md` para el razonamiento completo de por qué se
dejó fuera de esa sesión.

**Effort:** S
**Priority:** P3
**Depends on:** Ninguno — puede correr en paralelo a Approach A/B.

## Seguridad

### Validar esquema de logo_url / image_url en cert-edit.php y project-edit.php

**What:** `server/admin/cert-edit.php` y `server/admin/project-edit.php` guardan
`logo_url`/`image_url` como texto libre (solo `trim()` + tope de longitud), sin
validar que sea una URL http(s)/ruta relativa como ya hace `announcement_url`
en `server/admin/settings.php`.

**Why:** Auditoría VibeSec del 2026-08-23: un admin autenticado podría guardar
un `javascript:` URI. Hoy no es explotable porque `e()` escapa el valor en el
contexto de atributo HTML tanto en las vistas de `/admin` como (a confirmar) en
el frontend público — pero no se verificó el lado público en esta pasada.

**Context:** Antes de arreglar, confirmar cómo se renderiza `logo_url`/
`image_url` en el frontend público (`src/components/Certifications.astro`,
`src/components/Projects.astro`) — si ya usa `src={...}`/`href={...}` de Astro
(que escapa por defecto), el riesgo real es aún menor y el fix es solo higiene.

**Effort:** S
**Priority:** P3
**Depends on:** Ninguno.

### Confirmación adicional para el modo "replace" de backup.php

**What:** El import de `server/admin/backup.php` en modo `replace` borra sin
condición todos los proyectos/certificaciones existentes, protegido solo por
CSRF + un `confirm()` de JavaScript en el cliente.

**Why:** Auditoría VibeSec del 2026-08-23: no hay un segundo factor
server-side (ej. "escribe BORRAR para confirmar") para una operación
destructiva e irreversible. Riesgo bajo (app de un solo admin, ya protegida
por CSRF+login), pero es una herramienta de restauración explícitamente
destructiva.

**Effort:** S
**Priority:** P4
**Depends on:** Ninguno.

## Rendimiento

### fetchWithRetry() reintenta más de lo previsto en fallo total

**What:** `src/scripts/projects.ts` y `src/scripts/certifications.ts` (extraído
de la lógica inline original) definen `fetchWithRetry()` encadenando
`.then().catch()` en cada nivel de recursión. Cuando el intento más profundo
falla, ese rechazo sube por cada `.then()` padre, y cada `.catch()` propio
vuelve a aplicar SU presupuesto de reintentos (ya gastado), así que un fallo
total tarda notablemente más que los 3 reintentos previstos.

**Why:** Descubierto escribiendo los tests de reintento con temporizadores
reales — tardaban tanto que hubo que pasar a `vi.useFakeTimers()` para que el
test terminara en tiempo razonable. No es un bucle infinito (termina,
confirmado con `vi.runAllTimersAsync()`), pero la latencia real del camino de
fallo es peor de lo que sugiere leer el código.

**Context:** Arreglo: que el `.then()` de cada nivel NO tenga su propio
`.catch()` — solo el nivel más externo debería capturar el rechazo final. No
se arregla aquí porque cambia el comportamiento de timing real, fuera de
alcance de un refactor de extracción para tests.

**Effort:** S
**Priority:** P3
**Depends on:** Ninguno.
