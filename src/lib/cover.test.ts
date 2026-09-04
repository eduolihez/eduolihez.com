import { describe, it, expect } from 'vitest';
import { wrapText, buildCoverSvg } from './cover';

describe('wrapText()', () => {
  it('deja un titulo corto en una sola linea', () => {
    const lines = wrapText('Blog', 58, 1072, 4);
    expect(lines).toEqual(['Blog']);
  });

  it('reparte un titulo largo en varias lineas sin cortar palabras', () => {
    const title = 'El desacuerdo entre clasificadores pierde contra algo mucho mas simple';
    const lines = wrapText(title, 58, 1072, 4);
    expect(lines.length).toBeGreaterThan(1);
    // Con 4 lineas de margen y un titulo de este largo, cabe entero: unir
    // las lineas debe reconstruir el texto original sin ellipsis ni palabras
    // perdidas.
    expect(lines.join(' ')).toBe(title);
  });

  it('trunca con ellipsis cuando el texto no cabe en maxLines', () => {
    const longTitle = Array(30).fill('palabra').join(' ');
    const lines = wrapText(longTitle, 58, 400, 2);
    expect(lines.length).toBe(2);
    expect(lines[1].endsWith('…')).toBe(true);
  });

  it('no rompe con una sola palabra mas larga que el ancho disponible', () => {
    const lines = wrapText('supercalifragilisticoespialidoso', 58, 100, 2);
    expect(lines.length).toBeGreaterThan(0);
    expect(lines[0].length).toBeGreaterThan(0);
  });
});

describe('buildCoverSvg()', () => {
  const base = { title: 'Titulo de prueba', kicker: 'Blog', meta: '4 sept 2026 · 4 min', tags: ['python', 'soc'] };

  it('genera un documento SVG valido con las dimensiones OG estandar', () => {
    const svg = buildCoverSvg(base);
    expect(svg).toMatch(/^<svg xmlns="http:\/\/www\.w3\.org\/2000\/svg" width="1200" height="630"/);
    expect(svg.trim().endsWith('</svg>')).toBe(true);
  });

  it('escapa caracteres especiales del titulo para no romper el XML', () => {
    const svg = buildCoverSvg({ ...base, title: 'Node <script> & "cosas"' });
    expect(svg).not.toContain('<script>');
    expect(svg).toContain('&lt;script&gt;');
    expect(svg).toContain('&amp;');
  });

  it('pinta como maximo 3 chips de etiqueta aunque el post tenga mas', () => {
    const svg = buildCoverSvg({ ...base, tags: ['a', 'b', 'c', 'd', 'e'] });
    const chipCount = (svg.match(/font-family="'JetBrains Mono','Courier New',monospace" font-size="15"/g) || [])
      .length;
    expect(chipCount).toBe(3);
  });

  it('no revienta con cero etiquetas', () => {
    expect(() => buildCoverSvg({ ...base, tags: [] })).not.toThrow();
  });
});
