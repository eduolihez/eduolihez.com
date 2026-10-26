// Empaqueta src/scripts/admin-boot.ts (tema + paleta) en un unico JS sin
// dependencias para el panel PHP, que no pasa por Vite. El resultado se
// versiona: el hosting compartido no compila nada.
import { build } from 'esbuild';

await build({
  entryPoints: ['src/scripts/admin-boot.ts'],
  outfile: 'server/admin/assets/palette.js',
  bundle: true,
  minify: true,
  format: 'iife',
  target: 'es2020',
  legalComments: 'none',
  banner: { js: '/* Generado desde src/scripts/ con `npm run admin:palette`. No editar a mano. */' },
});
