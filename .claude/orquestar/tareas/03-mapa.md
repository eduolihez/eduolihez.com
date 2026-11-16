# T3 · Mapa bloque → sección (analytics.php)

Líneas "antes" = commit 2860486. "Después" = analytics.php tras T3. Ningún bloque se pierde.

| # | Bloque actual | Líneas antes | Condicional / estado | Sección destino | Línea después |
|---|---|---|---|---|---|
| 0 | Aviso app sin analítica (`$appSlug` sin fila en `apps`) + `exit` | 55-62 | sale antes de render | (antes de secciones, intacto) | 55-62 |
| 0b | Aviso "no se encontró ninguna app" (inalcanzable tras el exit) | 460-464 | `$appSlug !== '' && $appId === null` | cabecera (intacto, bajo page_header) | 525-529 |
| F | Botones de rango, bots y CSV en page-header | 450-459 | — | CSV en acciones de `page_header` (519); rango `.seg` + bots `.toggle` + hidden days/space + Aplicar en `filter_bar` dentro de `<form method="get">` (531-544); `section_nav` (545) | 519-545 |
| 1 | KPIs fila 1: visitas (+delta), únicos (+pág/visitante), hoy (+mejor día), bots (+humanas total) | 466-485 | — | Resumen | 549-568 |
| 2 | KPIs fila 2: rebote, duración media, scroll medio | 487-500 | — | Resumen | 570-583 |
| 3 | Visitas por día (gráfico) | 550-568 | vacío → "Sin datos" | Resumen | 585-602 |
| 4 | Visitantes con cookie opt-in (cálculo + tarjeta) | 502-548 | `$hasVisitorCol` (sin columna no se pinta); `$optVisitors === 0` → vacío | Audiencia (cálculo movido a 446-475 con las consultas intactas (solo cambia `if (...):` por `if (...) {` y "seccion"→"tarjeta" en el comentario), antes del render; envuelto en `.t11-optin`) | 668-684 |
| 5 | Países | 675-689 | vacío → aviso Cloudflare | Audiencia | 608-619 |
| 6 | Idioma de la página | 609-618 | vacío | Audiencia | 620-626 |
| 7 | Idioma del navegador | 622-632 | vacío | Audiencia | 630-637 |
| 8 | Tamaño de pantalla | 633-641 | vacío | Audiencia | 638-643 |
| 9 | Dispositivos | 694-702 | vacío | Audiencia | 647-653 |
| 10 | Navegadores | 703-711 | vacío | Audiencia | 654-659 |
| 11 | Sistemas operativos | 712-720 | vacío | Audiencia | 660-665 |
| 12 | Páginas más vistas | 666-674 | vacío | Contenido | 690-695 |
| 13 | Páginas de entrada | 645-653 | vacío | Contenido | 696-701 |
| 14 | Páginas de salida | 654-662 | vacío | Contenido | 702-707 |
| 15 | Lectura por post (tabla + nota) | 723-748 | vacío | Contenido | 710-734 |
| 16 | Páginas 404 (tabla + nota) | 793-817 | `$eventsUnavailable` → mensaje en fila vacía; vacío; LIMIT 20 | Contenido (top 10 + `<details>`) | 736-749 |
| 17 | Canales de tráfico | 596-608 | vacío | Adquisición | 754-762 |
| 18 | Origen del tráfico (referrers) | 845-864 | vacío; LIMIT 12 | Adquisición (top 10 + `<details>`) | 764-773 |
| 19 | Atribución (UTM) | 819-843 | vacío; LIMIT 12 | Adquisición (top 10 + `<details>`) | 775-789 |
| 20 | Franja horaria | 570-585 | — | Comportamiento | 795-806 |
| 21 | Día de la semana | 586-593 | — | Comportamiento | 807-811 |
| 22 | Eventos (nota "toda la web" + totales + desglose por destino) | 750-791 | `$eventsUnavailable` → tarjeta "Eventos" con mensaje (816), si no 2 tarjetas "Eventos" / "Eventos por destino" | Comportamiento | 814-850 |
| 23 | Bots y rastreadores (tabla + nota) | 866-890 | vacío; LIMIT 8 → nunca hay `<details>` | Bots (top 10 + `<details>`) | 855-868 |
| 24 | Nota de privacidad | 892-899 | — | pie, tras las 6 secciones (intacto) | 871-878 |

Anclas: las 6 secciones se pintan siempre (todas tienen al menos un bloque con estado vacío propio), así que `section_nav` lleva las 6.
