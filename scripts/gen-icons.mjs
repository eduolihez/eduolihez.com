/**
 * gen-icons.mjs — Genera los iconos PNG del sitio SIN dependencias externas.
 * Dibuja el logo ">_" (mismo estilo que favicon.svg) sobre fondo oscuro y los
 * codifica como PNG usando solo modulos nativos de Node (zlib).
 *
 * Uso:  node scripts/gen-icons.mjs   (o  npm run icons)
 * Salida: public/favicon-32.png, public/img/{apple-touch-icon,icon-192,icon-512,og-cover}.png
 *
 * Nota: og-cover.png es un PLACEHOLDER de marca (sin texto). Sustituyelo por
 * una imagen 1200x630 con tu foto/nombre cuando la tengas (ver public/img/LEEME.txt).
 */
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

// --- Colores (RGBA) ---
const BG = [10, 14, 20, 255]; // #0a0e14
const GREEN = [74, 222, 128, 255]; // #4ade80
const GRID = [31, 39, 51, 255]; // #1f2733

/** Lienzo RGBA sencillo. */
function canvas(w, h, fill) {
  const buf = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    buf[i * 4] = fill[0];
    buf[i * 4 + 1] = fill[1];
    buf[i * 4 + 2] = fill[2];
    buf[i * 4 + 3] = fill[3];
  }
  return { w, h, buf };
}

function setPx(c, x, y, col) {
  x = Math.round(x);
  y = Math.round(y);
  if (x < 0 || y < 0 || x >= c.w || y >= c.h) return;
  const i = (y * c.w + x) * 4;
  c.buf[i] = col[0];
  c.buf[i + 1] = col[1];
  c.buf[i + 2] = col[2];
  c.buf[i + 3] = col[3];
}

/** Pincel cuadrado de radio r. */
function stamp(c, x, y, r, col) {
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      setPx(c, x + dx, y + dy, col);
    }
  }
}

/** Linea gruesa (Bresenham + pincel). */
function line(c, x0, y0, x1, y1, r, col) {
  x0 = Math.round(x0); y0 = Math.round(y0);
  x1 = Math.round(x1); y1 = Math.round(y1);
  const dx = Math.abs(x1 - x0), dy = Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  let err = dx - dy;
  for (;;) {
    stamp(c, x0, y0, r, col);
    if (x0 === x1 && y0 === y1) break;
    const e2 = 2 * err;
    if (e2 > -dy) { err -= dy; x0 += sx; }
    if (e2 < dx) { err += dx; y0 += sy; }
  }
}

function rect(c, x0, y0, x1, y1, col) {
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) setPx(c, x, y, col);
}

/** Dibuja el glifo ">_" escalado (coordenadas base sobre viewBox 32). */
function drawGlyph(c, size, ox = 0, oy = 0) {
  const f = size / 32;
  const r = Math.max(1, Math.round(1.3 * f));
  const p = (x, y) => [ox + x * f, oy + y * f];
  // chevron  >
  line(c, ...p(7, 11.5), ...p(12.5, 16), r, GREEN);
  line(c, ...p(12.5, 16), ...p(7, 20.5), r, GREEN);
  // underscore  _
  line(c, ...p(15, 20.8), ...p(24, 20.8), r, GREEN);
}

/** Icono cuadrado tipo app. */
function appIcon(size) {
  const c = canvas(size, size, BG);
  drawGlyph(c, size);
  return c;
}

/** Portada Open Graph 1200x630 (placeholder de marca, sin texto). */
function ogCover() {
  const W = 1200, H = 630;
  const c = canvas(W, H, BG);
  // rejilla sutil
  for (let x = 0; x < W; x += 48) rect(c, x, 0, x, H - 1, GRID);
  for (let y = 0; y < H; y += 48) rect(c, 0, y, W - 1, y, GRID);
  // barra de acento a la izquierda
  rect(c, 0, 0, 10, H - 1, GREEN);
  // glifo grande a la izquierda-centro
  drawGlyph(c, 320, 120, 150);
  // regla verde bajo el glifo
  rect(c, 128, 500, 128 + 360, 505, GREEN);
  return c;
}

// ---- Codificador PNG (RGBA, sin dependencias) ----
function crc32(buf) {
  let crc = ~0;
  for (let i = 0; i < buf.length; i++) {
    crc ^= buf[i];
    for (let j = 0; j < 8; j++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (~crc) >>> 0;
}
function chunk(type, data) {
  const t = Buffer.from(type, 'ascii');
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
}
function encodePNG(c) {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(c.w, 0);
  ihdr.writeUInt32BE(c.h, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // color type RGBA
  // Scanlines con filtro 0
  const raw = Buffer.alloc(c.h * (c.w * 4 + 1));
  for (let y = 0; y < c.h; y++) {
    raw[y * (c.w * 4 + 1)] = 0;
    c.buf.copy(raw, y * (c.w * 4 + 1) + 1, y * c.w * 4, (y + 1) * c.w * 4);
  }
  const idat = deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}

// ---- Generar ----
mkdirSync(join(root, 'public', 'img'), { recursive: true });
const out = [
  ['public/favicon-32.png', appIcon(32)],
  ['public/img/icon-192.png', appIcon(192)],
  ['public/img/icon-512.png', appIcon(512)],
  ['public/img/apple-touch-icon.png', appIcon(180)],
  ['public/img/og-cover.png', ogCover()],
];
for (const [rel, c] of out) {
  writeFileSync(join(root, rel), encodePNG(c));
  console.log('  ✓', rel, `(${c.w}x${c.h})`);
}
console.log('Iconos generados.');
