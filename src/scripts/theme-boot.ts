import { initThemeToggle } from './theme';

initThemeToggle();
document.addEventListener('astro:page-load', initThemeToggle);
