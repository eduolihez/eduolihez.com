# Testing

100% de cobertura de tests es el objetivo a largo plazo: los tests permiten
mover rápido y confiar en los cambios sin tener que releer todo el código cada
vez. Sin ellos, cualquier cambio en `config.ts`, `experience.ts`, `skills.ts`
o `faq.ts` puede romper en silencio lo que una IA lee sobre este perfil, y
nadie lo nota hasta que la respuesta ya salió mal.

## Framework

**Vitest**, vía el helper oficial `getViteConfig()` de Astro (`vitest.config.ts`).
Reutiliza el `vite.config` real del proyecto — sin configuración duplicada.
Cubre el lado **TypeScript/Astro** (`src/`).

El backend en PHP (`server/`) usa **PHPUnit** (`composer.json` +
`phpunit.xml`, raíz del repo) — instalación e iniciativa separadas de Vitest,
sin relación entre ambos runners. Cubre solo código SIN dependencias externas
(de momento: `server/lib/text.php`, `server/lib/validate.php` y la lógica
de espacios del panel, `server/admin/partials/spaces.php` e `icons.php`) —
`server/tests/bootstrap.php` deja claro por qué no arranca
`server/lib/http.php` ni `config.php`: eso abriría una conexión real a MySQL
de producción, que no existe (ni debe existir) en un entorno de test o CI, y
`db()` corta el proceso entero con `exit;` si lo intenta. Testear algo que sí
necesite DB requeriría una base de datos de test propia, inyectada aparte.

## Cómo correr los tests

```bash
npm test              # TypeScript/Astro (Vitest)
composer install       # PHP: instala PHPUnit (solo la primera vez)
composer test          # PHP (PHPUnit)
```

`npm test` corre en CI en cada push/PR a `master`
(`.github/workflows/test.yml`, check "Vitest"). La suite de PHPUnit **no**
está todavía en ese workflow — se montó en esta misma sesión sin un entorno
PHP a mano para verificarla en ejecución real, así que antes de darla por
buena en CI hay que correr `composer test` una vez en una máquina con PHP
8.1+ y confirmar que pasa.

### PHP en local sin Composer

```bash
bash scripts/php-test.sh
```

Necesita un PHP local y `.superpowers/tools/phpunit.phar`. Si falta el phar,
el script imprime el comando de descarga:

```bash
mkdir -p .superpowers/tools && curl -sSfL -o .superpowers/tools/phpunit.phar https://phar.phpunit.de/phpunit-10.5.66.phar
```

El script fija la versión (PHPUnit 10.5.66) y su SHA-256
(`42bcac97bbf9fb1aecf5a7d6a1b37123a11e7e295458978f0e268999f6d9e50f`) y se
niega a ejecutar un phar que no coincida. Al fijarlo se comprobó también la
firma GPG de `phpunit-10.5.66.phar.asc` (clave de Sebastian Bergmann,
huella `D840 6D0D 8294 7747 2937 7831 4AA3 9408 6372 C20A`). Para subir de
versión: descarga la nueva, verifica su firma y actualiza `PHPUNIT_VERSION` y
`PHPUNIT_SHA256` en `scripts/php-test.sh`.

`composer test` sigue funcionando donde haya Composer. En ambos casos los
tests de `server/tests/` no deben cargar `auth.php`, `http.php` ni `db.php`
(ver el comentario de `server/tests/bootstrap.php`). Por eso
`server/admin/partials/spaces.php` y `icons.php` son puras: sin dependencias
de esos archivos, se pueden testear (`SpacesTest`).

## Capas de test

- **Unit / smoke tests** (`src/**/*.test.ts`): el endpoint `/llms.txt` —
  verifica que el texto generado incluye los datos reales de identidad, que
  ninguna interpolación queda como `undefined`/`[object Object]`, y que las
  secciones que dependen de arrays (experiencia, FAQ) no salen vacías.
  `src/scripts/shared.ts` (`safeUrl()`, `fetchWithRetry()`,
  `setStatusPanel()` — compartidas por Blog, Proyectos y Certificaciones):
  esquemas bloqueados/permitidos incluidos los bypass de `\`/`//`/tabulador
  incrustado en la URL (ver el comentario del propio archivo), número exacto
  de reintentos en fallo total (regresión del bug de cascada). Y los scripts
  de cada isla (`blog.ts`, `projects.ts`, `certifications.ts`): carga/vacío/
  error/reintento (incluido el rechazo directo de `fetch()`, no solo
  `!res.ok`) sin duplicar listeners, apertura/cierre de modal (foco,
  backdrop, Escape) en Proyectos, y en Certificaciones los 5 filtros por
  categoría, drill-down de emisor con migas de pan, y paginación
  ("cargar más").
- **PHPUnit** (`server/tests/*.php`): `to_plain_text()` (limpieza HTML→texto
  de los artículos del blog) y `validate_public_url()` (el esquema de URL
  permitido en los formularios de `/admin`, incluidos los mismos bypass de
  `\`/`//`/tabulador que en `safeUrl()` — misma regla, dos implementaciones
  independientes que no comparten fuente). También la lógica pura de
  espacios del panel admin (`server/admin/partials/spaces.php`, en
  `server/tests/SpacesTest.php`).
- **Integration / E2E:** no hay todavía. El sitio es principalmente
  contenido estático + un backend PHP que no se puede correr en local sin
  PHP instalado (ver `PRODUCT.md`, sección "Operating Context").

## Convenciones

- Un archivo de test por cada archivo fuente que se testea: `foo.ts` →
  `foo.test.ts`, en el mismo directorio — **excepto dentro de `src/pages/`**
  (ver aviso justo abajo).
- **`src/pages/` es zona prohibida para archivos de test.** Astro trata
  CUALQUIER archivo dentro de `src/pages/` como una ruta a compilar. Un
  `describe()`/`it()` de Vitest ahí dentro rompe `npm run build` en
  silencio durante el prerender (Astro intenta evaluar el módulo de test
  como si fuera un endpoint). Los tests de algo que vive en `src/pages/`
  van en `src/test/pages/`, con la misma ruta relativa (ej.
  `src/pages/llms.txt.ts` → `src/test/pages/llms.txt.test.ts`). Antes de
  dar por bueno un cambio en los tests, corre `npm run build` además de
  `npm test` — un test roto falla ruidoso, pero esto fallaba en silencio.
- `describe()` con el nombre del endpoint/función; `it()` en español,
  describiendo el comportamiento esperado, no la implementación.
- No mockear `src/config.ts`/`data/*.ts` a propósito en los smoke tests del
  contenido generado: el riesgo real que se quiere cubrir es que esos
  archivos cambien de forma y rompan el output, así que el test debe usar
  los datos reales para detectarlo.
- Nunca importar secretos o credenciales en un archivo de test.
