/**
 * Entrada del panel de administracion (PHP, sin Vite): reutiliza el mismo
 * tema y paleta de comandos que la web. Se empaqueta a
 * server/admin/assets/palette.js con `npm run admin:palette`.
 */
import { initPalette } from './palette';
import { initThemeToggle } from './theme';

initThemeToggle();
initPalette();
