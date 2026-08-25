# TODOS

## SEO / Visibilidad IA

### Caché de servidor para llms-blog.php si se dispara el umbral

**What:** Añadir una caché de fichero con TTL corto (5-10 min) a
`server/llms-blog.php` si el umbral de ~50 peticiones/día no provenientes de un
bot de IA reconocido (definido en [la wiki](https://github.com/eduolihez/eduolihez.com/wiki/SEO-AI-Visibility-Plan), sección
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
**Depends on:** Resultado de Approach A en [la wiki](https://github.com/eduolihez/eduolihez.com/wiki/SEO-AI-Visibility-Plan) —
solo tiene sentido revisar esto si el umbral realmente se dispara.

### Sesión de diagnóstico para el público técnico SOC

**What:** Correr `/office-hours` (o una sesión dedicada) enfocada en el segundo
público de `PRODUCT.md` — comunidad técnica SOC/blue team — que
[la wiki](https://github.com/eduolihez/eduolihez.com/wiki/SEO-AI-Visibility-Plan) dejó explícitamente fuera de alcance.

**Why:** `PRODUCT.md` declara los dos públicos (reclutador y comunidad técnica)
con el mismo peso, pero el diagnóstico de la sesión del 2026-08-23 se centró
solo en reclutador/citación-IA. El público técnico podría tener necesidades
distintas (ej. cómo se descubre y valora el repositorio público) sin
diagnosticar todavía.

**Context:** Ver "Target User & Narrowest Wedge" y "Open Questions" en
[la wiki](https://github.com/eduolihez/eduolihez.com/wiki/SEO-AI-Visibility-Plan) para el razonamiento completo de por qué se
dejó fuera de esa sesión.

**Effort:** S
**Priority:** P3
**Depends on:** Ninguno — puede correr en paralelo a Approach A/B.

## Seguridad

### Validar esquema de URL en el import JSON de backup.php

**What:** `server/admin/backup.php` en modo importación escribe `image_url`,
`repo_url`, `demo_url`, `store_url`, `credential_url` y `logo_url`
directamente desde el JSON subido (solo `mb_substr()` de longitud, sin pasar
por `validate_public_url()`), tanto en modo `add` como `replace`.

**Why:** Adversarial review de `/ship` del 2026-08-25: hoy no es explotable
porque el frontend público (`safeUrl()` en `src/scripts/shared.ts`) filtra
estos campos igualmente antes de usarlos como `href`/`src` — pero si algún
día una vista de `/admin` imprime alguno de estos campos sin pasar por ahí,
o si se usa el import con un archivo de backup no confiable, deja de estar
cubierto. Es la única vía de escritura de estos campos que no pasa por la
validación que sí tienen `project-edit.php`/`cert-edit.php`.

**Context:** El fix natural es llamar a `validate_public_url()` (o saltar la
fila) por cada campo de URL dentro del `foreach` de proyectos/certificaciones
del import. No se hizo en la misma sesión que introdujo `validate_public_url()`
para no seguir ampliando un diff ya grande con cambios en el flujo
transaccional de una operación destructiva.

**Effort:** S
**Priority:** P3
**Depends on:** Ninguno.

## Completed

### Validar esquema de logo_url / image_url en cert-edit.php y project-edit.php
Añadida la misma regla que ya usaba `announcement_url` en settings.php —
consolidada en `server/lib/validate.php` (`validate_public_url()`) para que
las tres copias no diverjan, con tests de PHPUnit en
`server/tests/ValidateTest.php`. La revisión de `/ship` encontró un bypass
real en el check inicial: un valor como `/\evil.example/x` empieza por `/`
(pasaba la regla), pero los navegadores tratan `\` como `/` al parsear un
esquema especial (compat heredada de IE, parte del estándar WHATWG URL), así
que se resuelve como `//evil.example/x` — dominio externo, no ruta interna.
Corregido bloqueando barra invertida y `//` inicial antes del check de
esquema; mismo fix aplicado a `safeUrl()` en `src/scripts/shared.ts`
(afecta también al frontend público). El Red Team de la misma revisión
encontró una segunda variante del mismo bypass: el parser WHATWG también
quita tabulador/salto de línea/retorno de carro de *cualquier* posición de
la URL (no solo de los extremos, que `trim()` ya cubría) antes de
interpretarla — `/\t/evil.example/x` no tenía `\` literal ni empezaba por
`//` tal cual, pero el navegador lo reduce a `//evil.example/x` igual que el
primer caso. Corregido en los mismos dos sitios, con tests para las tres
variantes (`\t`, `\n`, `\r`).
**Completed:** pendiente de versión (2026-08-25)

### Confirmación adicional para el modo "replace" de backup.php
Segundo factor server-side: hay que escribir `BORRAR` en un campo nuevo para
que el modo "reemplazar" se ejecute; sin eso, ni siquiera se toca el archivo
subido.
**Completed:** pendiente de versión (2026-08-25)

### fetchWithRetry() reintenta más de lo previsto en fallo total
Arreglado como parte de la extracción a `src/scripts/shared.ts`: un solo
`.catch()` por nivel de recursión en vez de uno por cada `.then()` padre.
Test de regresión que fija el número exacto de llamadas (`retries + 1`, ni
una más) en `shared.test.ts`.
**Completed:** pendiente de versión (2026-08-25)

### Cobertura de tests para modal, filtros y drill-down de emisor
Añadidos: apertura/cierre de modal (foco, backdrop, Escape), filtro por badge
en Proyectos; los 5 filtros por categoría, drill-down de emisor (entrar/salir
con migas) y paginación ("cargar más") en Certificaciones.
**Completed:** pendiente de versión (2026-08-25)

### Huecos menores de cobertura: reintento sin red, paginación y listeners de test
Los 3 arreglados: rechazo de red testeado en los 3 módulos (antes solo
blog.test.ts), paginación ejercida con un fixture de 15 elementos, y el
listener `keydown` de Proyectos ya no se acumula (ver el TODO de módulo
compartido — el fix vive ahí) — más un test que lo demuestra llamando a
`initProjects()` dos veces seguidas.
**Completed:** pendiente de versión (2026-08-25)

### Extraer safeUrl()/fetchWithRetry()/setState() a un módulo compartido
Nuevo `src/scripts/shared.ts`; `blog.ts`/`projects.ts`/`certifications.ts` lo
importan y re-exportan `safeUrl` para no romper los tests existentes. De
paso, `initProjects()` dejó de acumular un listener `keydown` en `document`
en cada re-init (guardado con una variable de módulo).
**Completed:** pendiente de versión (2026-08-25)

### Extraer el patrón `max(array_column($rows, 'c'))` en server/admin/analytics.php
Nuevo helper `max_count(array $rows): int`; sustituidas las 13 instancias.
**Completed:** pendiente de versión (2026-08-25)

### Cobertura de tests para server/llms-blog.php
Bootstrapeado PHPUnit desde cero (`composer.json`, `phpunit.xml`,
`server/tests/`) — la iniciativa que este TODO daba por "aparte". Extraída
`to_plain_text()` (la lógica real de limpieza HTML→texto, y la pieza con más
superficie de fallo del archivo) a `server/lib/text.php`, con 11 tests que
cubren string vacía, script/style, bloques→salto de línea, listas,
entidades, colapso de líneas en blanco y un artículo realista combinado.
**No** cubre el resto del script (la consulta SQL en sí, el manejo de fallo
de DB) — eso necesitaría una base de datos de test, fuera de alcance de un
smoke test. Sin PHP disponible en el entorno de esta sesión para ejecutar la
suite: revisar corriendo `composer install && composer test` antes de darla
por buena.
**Completed:** pendiente de versión (2026-08-25)
