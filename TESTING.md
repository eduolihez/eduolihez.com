# Testing

100% de cobertura de tests es el objetivo a largo plazo: los tests permiten
mover rápido y confiar en los cambios sin tener que releer todo el código cada
vez. Sin ellos, cualquier cambio en `config.ts`, `experience.ts`, `skills.ts`
o `faq.ts` puede romper en silencio lo que una IA lee sobre este perfil, y
nadie lo nota hasta que la respuesta ya salió mal.

## Framework

**Vitest**, vía el helper oficial `getViteConfig()` de Astro (`vitest.config.ts`).
Reutiliza el `vite.config` real del proyecto — sin configuración duplicada.

Cubre el lado **TypeScript/Astro** (`src/`). El backend en PHP (`server/`) no
tiene test runner todavía — sería una iniciativa aparte con Composer +
PHPUnit, no algo que Vitest pueda tocar.

## Cómo correr los tests

```bash
npm test
```

Corre en CI en cada push/PR a `master` (`.github/workflows/test.yml`).

## Capas de test

- **Unit / smoke tests** (`src/**/*.test.ts`): el endpoint `/llms.txt` —
  verifica que el texto generado incluye los datos reales de identidad, que
  ninguna interpolación queda como `undefined`/`[object Object]`, y que las
  secciones que dependen de arrays (experiencia, FAQ) no salen vacías. Y los
  scripts extraídos de Blog, Proyectos y Certificaciones (`blog.ts`,
  `projects.ts`, `certifications.ts`) — carga/vacío/error/reintento sin
  duplicar listeners, `safeUrl()` bloqueando esquemas ejecutables, y (en
  Certificaciones) agrupación por emisor y filtro de búsqueda.
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
