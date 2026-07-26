/**
 * Configuracion de PostCSS.
 * ---------------------------------------------------------------------------
 * POR QUE EXISTE ESTE ARCHIVO:
 *
 * Hasta ahora Tailwind entraba por la integracion `@astrojs/tailwind`. Esa
 * integracion se quedo en Astro 5: su ultima version publicada (6.0.2) declara
 * como peer `astro@^3 || ^4 || ^5`, y este proyecto va por Astro 7. El
 * resultado era que `npm install` fallaba con ERESOLVE en un repositorio
 * recien clonado, aunque el node_modules que ya estaba en disco funcionara.
 *
 * No hay version futura que arregle eso: Astro dejo de mantener el paquete y
 * la via recomendada pasa a ser el plugin propio de Tailwind. Asi que el
 * puente se retira y Tailwind se engancha por PostCSS, que es un mecanismo de
 * Vite y no depende de la version de Astro.
 *
 * `src/styles/global.css` ya traia sus propias directivas @tailwind, asi que
 * el punto de entrada del CSS no cambia. La configuracion del tema sigue en
 * tailwind.config.mjs igual que antes.
 *
 * NOTA PARA MAS ADELANTE: Tailwind 4 mueve la configuracion a CSS (@theme) y
 * se instala como plugin de Vite (@tailwindcss/vite). Es la migracion que toca
 * en algun momento, pero cambia el formato del tema y el comportamiento de
 * theme(), que este proyecto usa en global.css. No es algo que convenga hacer
 * el mismo dia que se sube a produccion.
 */
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
