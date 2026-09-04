/**
 * cover.ts - Genera la portada de un articulo del blog como SVG, en build
 * time (ver src/pages/blog/covers/[slug].png.ts).
 * ---------------------------------------------------------------------------
 * POR QUE EXISTE: ninguno de los 13 articulos publicados tiene cover_url, asi
 * que las 13 tarjetas del indice mostraban el mismo icono generico "</>", y
 * compartir un articulo en LinkedIn/Twitter no generaba ninguna imagen. La
 * alternativa habitual (una imagen de IA "de portada", genérica y fotografica)
 * es justo lo que DESIGN.md prohibe: "ningun efecto simula ser algo que el
 * sitio no es". Esta tarjeta usa solo lo que el sistema de diseno ya define
 * -- tono, hairline, Inter/JetBrains Mono, un unico verde -- para que la
 * portada sea una extension del sitio, no un elemento pegado encima.
 *
 * Logica de ajuste de linea separada en wrapText() a proposito: es la unica
 * parte con matices (aproximacion de ancho de caracter, truncado con
 * ellipsis) y se puede testear sin tocar SVG ni fuentes.
 */

const WIDTH = 1200;
const HEIGHT = 630;
const PAD = 64;

// Tokens de src/styles/global.css (:root), copiados a mano: este modulo corre
// en Node durante el build, fuera del navegador, asi que no hay CSS del que
// leer var(--color-*).
const COLORS = {
  bg: '#0a0e14',
  bgCard: '#141a24',
  border: '#1f2733',
  textTitle: '#f0f3f6',
  textMuted: '#9aa7b8',
  accent: '#4ade80',
};

/**
 * Ancho medio de un caracter en Inter Bold, como fraccion del tamano de
 * fuente. Inter es proporcional (no monoespaciada); 0.56 es una aproximacion
 * razonable para mayusculas/minusculas mixtas en espanol/ingles/catalan, lo
 * bastante conservadora para no desbordar el ancho de la tarjeta.
 */
const AVG_CHAR_WIDTH_RATIO = 0.56;

/**
 * Reparte `text` en como maximo `maxLines` lineas que quepan en `maxWidth`
 * px a `fontSize` px. Si no cabe todo, trunca la ultima linea con "...".
 * Exportada aparte para poder testear el ajuste sin generar SVG.
 */
export function wrapText(
  text: string,
  fontSize: number,
  maxWidth: number,
  maxLines: number,
): string[] {
  const charsPerLine = Math.max(1, Math.floor(maxWidth / (fontSize * AVG_CHAR_WIDTH_RATIO)));
  const words = text.trim().split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let current = '';

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length <= charsPerLine) {
      current = candidate;
      continue;
    }
    if (current) lines.push(current);
    current = word;
    if (lines.length === maxLines) break;
  }
  if (lines.length < maxLines && current) lines.push(current);

  if (lines.length === maxLines) {
    const last = lines[maxLines - 1];
    const consumed = lines.slice(0, -1).join(' ').length + (maxLines > 1 ? 1 : 0);
    const remainingWords = words.join(' ').slice(consumed).trim();
    if (remainingWords.length > last.length) {
      // Sobraba texto: la ultima linea visible se trunca con ellipsis en vez
      // de cortarse a mitad de palabra sin avisar de que hay mas titulo.
      const maxLastLine = Math.max(1, charsPerLine - 1);
      lines[maxLines - 1] =
        last.length > maxLastLine ? `${last.slice(0, maxLastLine).trimEnd()}…` : `${last}…`;
    }
  }

  return lines;
}

/** Escapa texto para incrustarlo en un nodo <text> de SVG. */
function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

export interface CoverData {
  title: string;
  kicker: string;
  meta: string;
  tags: string[];
}

/** Construye el SVG completo de la portada 1200x630 (ratio OG estandar). */
export function buildCoverSvg({ title, kicker, meta, tags }: CoverData): string {
  const contentWidth = WIDTH - PAD * 2;
  const titleFontSize = 58;
  const titleLines = wrapText(title, titleFontSize, contentWidth, 4);
  const titleLineHeight = titleFontSize * 1.18;

  // El bloque de titulo se centra verticalmente en el espacio entre el
  // kicker (arriba) y el pie de meta/tags (abajo), no en el lienzo entero:
  // con 1, 2 o 4 lineas el punto medio real cambia, y centrar en el
  // contenedor completo dejaria descompensado un titulo corto.
  const titleBlockTop = 230;
  const titleBlockHeight = HEIGHT - 170 - titleBlockTop;
  const titleStartY =
    titleBlockTop + (titleBlockHeight - titleLines.length * titleLineHeight) / 2 + titleFontSize;

  const titleTspans = titleLines
    .map((line, i) => `<tspan x="${PAD}" y="${titleStartY + i * titleLineHeight}">${escapeXml(line)}</tspan>`)
    .join('');

  // Chips de etiqueta: como maximo 3, mismo patron visual que .badge en el
  // sitio (borde hairline, sin relleno, mono, radio pequeno).
  const shownTags = tags.slice(0, 3);
  let chipX = PAD;
  const chipY = HEIGHT - 96;
  const chipHeight = 34;
  const chips = shownTags
    .map((tag) => {
      const label = escapeXml(tag);
      const chipWidth = label.length * 8.2 + 28;
      const chip = `<rect x="${chipX}" y="${chipY}" width="${chipWidth}" height="${chipHeight}" rx="4" fill="none" stroke="${COLORS.border}" stroke-width="1"/><text x="${chipX + chipWidth / 2}" y="${chipY + chipHeight / 2 + 5}" font-family="'JetBrains Mono','Courier New',monospace" font-size="15" fill="${COLORS.textMuted}" text-anchor="middle">${label}</text>`;
      chipX += chipWidth + 12;
      return chip;
    })
    .join('');

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="${COLORS.bg}"/>
  <rect x="0.5" y="0.5" width="${WIDTH - 1}" height="${HEIGHT - 1}" fill="none" stroke="${COLORS.border}" stroke-width="1"/>

  <text x="${PAD}" y="112" font-family="'JetBrains Mono','Courier New',monospace" font-size="20" font-weight="600" letter-spacing="4" fill="${COLORS.accent}">${escapeXml(kicker.toUpperCase())}</text>
  <line x1="${PAD}" y1="140" x2="${WIDTH - PAD}" y2="140" stroke="${COLORS.border}" stroke-width="1"/>

  <text font-family="Inter,'Segoe UI',Arial,sans-serif" font-size="${titleFontSize}" font-weight="700" letter-spacing="-1" fill="${COLORS.textTitle}">${titleTspans}</text>

  ${chips}
  <text x="${PAD}" y="${HEIGHT - 40}" font-family="'JetBrains Mono','Courier New',monospace" font-size="16" fill="${COLORS.textMuted}">${escapeXml(meta)}</text>

  <text x="${WIDTH - PAD}" y="${HEIGHT - 40}" font-family="'JetBrains Mono','Courier New',monospace" font-size="16" fill="${COLORS.accent}" text-anchor="end">&gt;_ eduolihez.com</text>
</svg>`;
}
