# 📥 Exports de Google Search Console

Buzón de entrada para los datos de Search Console. Tú dejas aquí los archivos
tal cual los descarga Google; Claude los lee desde el repositorio y trabaja con
números reales en vez de a ojo.

**Nada de lo que dejes aquí se sube a git.** El [`.gitignore`](.gitignore) de
esta carpeta ignora todo el contenido excepto este README, así que puedes soltar
los ZIP sin descomprimir y sin pensar en qué llevan dentro.

---

## Qué exportar

Tres exports. El primero es el importante; los otros dos cuestan un clic más y
cierran el diagnóstico.

### 1. Rendimiento — el que de verdad sirve

`Search Console → Rendimiento → Resultados de búsqueda`

> ⚠️ **Antes de exportar, activa las cuatro métricas de arriba: Clics,
> Impresiones, CTR y Posición media.** Por defecto Google trae las dos primeras
> apagadas a medias y **el export respeta lo que tengas activado en pantalla**:
> si no las enciendes, el CSV sale sin CTR ni posición, que son justo las dos
> columnas que dicen qué hay que tocar.

1. Rango de fechas → **Últimos 12 meses** (o los 3 últimos si la web es nueva).
2. Botón **Exportar** (arriba a la derecha) → **Descargar CSV**.
3. Baja un ZIP tipo `eduolihez.com-Performance-on-Search-2026-08-06.zip`.
4. Déjalo aquí sin descomprimir.

Dentro vienen `Consultas`, `Páginas`, `Países`, `Dispositivos`, `Fechas` y
`Apariencia en la búsqueda`.

### 2. Páginas indexadas — por qué Google deja fuera lo que deja fuera

`Search Console → Indexación → Páginas → Exportar`

Es el que destapa los `noindex` no intencionados, los 404 que siguen enlazados,
los duplicados sin canónica y las URLs rastreadas pero no indexadas.

### 3. Sitemaps — captura de pantalla basta

`Search Console → Sitemaps`

Aquí solo importa un dato: cuántas URLs ha descubierto frente a las que
[`sitemap.xml.ts`](../../src/pages/sitemap.xml.ts) genera. Si no cuadran, hay
algo roto entre el build y lo que Google ve.

---

## Cómo dejar los archivos

Suelta y ya está. No hace falta renombrar nada: el nombre que pone Google ya
lleva la fecha y el tipo de informe, que es todo lo que necesito para saber qué
es cada cosa y cuál es más reciente.

```
seo/gsc/
├── README.md
├── .gitignore
├── eduolihez.com-Performance-on-Search-2026-08-06.zip
└── eduolihez.com-Coverage-Drilldown-2026-08-06.zip
```

Si exportas varias veces, **no borres los anteriores**: comparar dos ventanas
del mismo informe es la única forma de distinguir una mejora real de una
fluctuación estacional.

---

## Qué se hace con cada cosa

| Dato del export | Qué se saca de ahí |
|---|---|
| Consultas con muchas impresiones y CTR bajo | Reescribir `<title>` y meta descripción de esa página: sales pero no te clican |
| Consultas en posición 8–20 | El terreno barato. Se gana ajustando contenido, no con backlinks |
| Consultas que no esperabas | Palabras por las que ya te encuentran y que aún no aparecen en la web |
| Páginas con 0 impresiones | O no están indexadas, o nadie busca eso. El informe de Indexación lo aclara |
| Comparativa ES / EN / CA | Si un idioma se hunde, suele ser el `hreflang` |
| Motivos de exclusión | Trabajo concreto de código: canónicas, redirecciones, `noindex` |

El plan de acción de fondo está en [`SEO.md`](../../SEO.md); estos exports
sirven para saber **por dónde empezar** de todo lo que hay ahí.

---

## Cada cuánto

Search Console guarda **16 meses** de histórico y luego lo tira. Exportar cada
2–3 meses te construye una serie propia que Google ya no te va a poder dar.

Antes de eso no merece la pena: [`SEO.md`](../../SEO.md#plazos-realistas) ya
avisa de que las primeras consultas locales tardan 1–2 meses en aparecer, y
mirar los datos cada semana solo genera ruido.
