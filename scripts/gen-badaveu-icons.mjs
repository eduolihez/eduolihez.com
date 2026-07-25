/**
 * gen-badaveu-icons.mjs — Iconos PWA de BadaVeu, sin dependencias.
 * ---------------------------------------------------------------------------
 * POR QUE EXISTE: manifest.json declara assets/img/icon-192.png y icon-512.png,
 * pero esos archivos no estaban en el repositorio. Los generaba
 * generate-icons.php, un script PHP publico y sin autenticacion que se
 * ejecutaba desde el navegador y se borraba solo; se elimino por seguridad.
 * Sin al menos un icono de 192 px valido, Chrome no ofrece instalar la PWA.
 *
 * Esto hace lo mismo en local y en tiempo de compilacion, no en el servidor.
 *
 * Uso:  npm run icons:badaveu
 * Sale: public/projects/badaveu/assets/img/{icon-192,icon-512}.png
 */
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'public', 'projects', 'badaveu', 'assets', 'img');

const BG = [0, 45, 90, 255];        // #002D5A, azul corporativo de BadaVeu
const FG = [255, 255, 255, 255];    // blanco

// Fuente de mapa de bits 5x7 para las dos unicas letras que hacen falta.
const GLYPHS = {
  B: [
    '11110',
    '10001',
    '10001',
    '11110',
    '10001',
    '10001',
    '11110',
  ],
  V: [
    '10001',
    '10001',
    '10001',
    '10001',
    '10001',
    '01010',
    '00100',
  ],
};

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

function fillRect(c, x0, y0, w, h, col) {
  for (let y = y0; y < y0 + h; y++) {
    for (let x = x0; x < x0 + w; x++) {
      if (x < 0 || y < 0 || x >= c.w || y >= c.h) continue;
      const i = (y * c.w + x) * 4;
      c.buf[i] = col[0];
      c.buf[i + 1] = col[1];
      c.buf[i + 2] = col[2];
      c.buf[i + 3] = col[3];
    }
  }
}

/** Dibuja "BV" centrado, escalando cada pixel del mapa de bits. */
function drawBV(c, size) {
  const letters = ['B', 'V'];
  const cols = 5, rows = 7, gap = 1;
  const totalCols = letters.length * cols + gap;      // 11 columnas
  // 55% del lienzo: deja margen de sobra para el recorte "maskable".
  const px = Math.max(1, Math.floor((size * 0.55) / totalCols));
  const textW = totalCols * px;
  const textH = rows * px;
  const ox = Math.round((size - textW) / 2);
  const oy = Math.round((size - textH) / 2);

  letters.forEach((ch, li) => {
    const g = GLYPHS[ch];
    for (let r = 0; r < rows; r++) {
      for (let col = 0; col < cols; col++) {
        if (g[r][col] !== '1') continue;
        fillRect(c, ox + (li * (cols + gap) + col) * px, oy + r * px, px, px, FG);
      }
    }
  });
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
  ihdr[8] = 8; // profundidad de bits
  ihdr[9] = 6; // RGBA
  const raw = Buffer.alloc(c.h * (c.w * 4 + 1));
  for (let y = 0; y < c.h; y++) {
    raw[y * (c.w * 4 + 1)] = 0; // filtro 0
    c.buf.copy(raw, y * (c.w * 4 + 1) + 1, y * c.w * 4, (y + 1) * c.w * 4);
  }
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

mkdirSync(outDir, { recursive: true });
for (const size of [192, 512]) {
  const c = canvas(size, size, BG);
  drawBV(c, size);
  const file = join(outDir, `icon-${size}.png`);
  writeFileSync(file, encodePNG(c));
  console.log(`  ✓ icon-${size}.png (${size}x${size})`);
}
console.log('Iconos de BadaVeu generados.');
