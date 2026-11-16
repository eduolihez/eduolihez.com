# Rúbrica · Rediseño del panel /admin (estructura + Analítica)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 1 | Navegación agrupada por zonas con nombre (p. ej. Resumen, Tráfico, Contenido, Sistema); la zona activa se distingue y no hay más de ~7 entradas sueltas | Captura del panel en escritorio y móvil; lectura de `layout.php` |
| 2 | Barra lateral fija en escritorio y menú plegable en móvil (≤768 px); sin scroll horizontal | Playwright/navegador a 390, 768 y 1440 px |
| 3 | Plantilla común de página: cabecera (título, descripción, acciones), contenido en tarjetas/secciones con título y espaciado consistente | Todas las pantallas que usan el layout muestran la cabecera; revisión visual |
| 4 | Analítica reorganizada en secciones claras (Resumen, Audiencia, Contenido, Adquisición, Eventos, Técnico…) con tarjetas KPI arriba, índice o pestañas de anclas, y nada de muros de listas | Captura a pantalla completa de `analytics.php`; todas las secciones actuales siguen presentes |
| 5 | Tema claro y oscuro correctos (contraste AA en texto y estados) | Contraste medido con navegador/axe en ambos temas |
| 6 | Sin pérdida de funcionalidad: filtros de rango, bots, exportar CSV, paleta de comandos, atajos y enlaces existentes siguen funcionando | Prueba manual en navegador + tests existentes |
| 7 | Sin romper CSP: sin errores de CSP en consola, `AdminCspTest` verde | `read_console_messages` + test |
| 8 | Accesibilidad básica: foco visible, navegación por teclado en menú, `aria-current` en la entrada activa, landmarks | Recorrido con teclado + revisión de HTML |
| 9 | `npm test` y `npm run build` verdes; `php -l` limpio en los PHP tocados; tests PHP del helper con shim | Comandos con salida |
| 10 | Nada a producción ni push sin OK de Edu | Estado de git y de FTP |

Fuera de alcance: rediseñar el resto de pantallas (posts, proyectos, certs, seguridad, ajustes…) más allá de heredar layout y cabecera; cambiar la web pública; cambiar datos o consultas SQL.
