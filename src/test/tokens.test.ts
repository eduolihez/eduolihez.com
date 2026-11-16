import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Parsea src/styles/tokens.css y comprueba (1) que los dos bloques oscuros
// ([data-theme='dark'] y la media query del sistema) son identicos y declaran
// los mismos tokens que el claro, y (2) el contraste WCAG de los pares que de
// verdad se pintan, en claro y en oscuro.

const css = readFileSync(join(process.cwd(), 'src/styles/tokens.css'), 'utf8');

type Tokens = Record<string, string>;

/** Cuerpo del primer bloque `{...}` que sigue a `selector` (llaves anidadas). */
function blockAfter(source: string, selector: string): string {
  const start = source.indexOf(selector);
  if (start < 0) throw new Error(`selector no encontrado: ${selector}`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    else if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  throw new Error(`bloque sin cerrar: ${selector}`);
}

function parseTokens(body: string): Tokens {
  const out: Tokens = {};
  const clean = body.replace(/\/\*[\s\S]*?\*\//g, '');
  for (const m of clean.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) out[m[1]] = m[2].trim();
  return out;
}

/** Luminancia relativa WCAG 2.x de un #rrggbb (o #rgb). */
function luminance(hex: string): number {
  const m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) throw new Error(`color no soportado: ${hex}`);
  const h = m[1].length === 3 ? [...m[1]].map((c) => c + c).join('') : m[1];
  const [r, g, b] = [0, 2, 4].map((i) => {
    const v = parseInt(h.slice(i, i + 2), 16) / 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrast(a: string, b: string): number {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}

const light = parseTokens(blockAfter(css, ':root {'));
const darkAttr = parseTokens(blockAfter(css, ":root[data-theme='dark']"));
const darkMedia = parseTokens(
  blockAfter(blockAfter(css, '@media (prefers-color-scheme: dark)'), ":root:not([data-theme='light'])"),
);

describe('helper de contraste', () => {
  it('negro sobre blanco es 21:1 y es simetrico', () => {
    expect(contrast('#000000', '#ffffff')).toBeCloseTo(21, 5);
    expect(contrast('#fff', '#000')).toBeCloseTo(21, 5);
    expect(contrast('#777777', '#777777')).toBe(1);
  });
  it('falla con colores que no son hex (rgb(), nombres, vacio)', () => {
    expect(() => contrast('rgb(0 0 0)', '#fff')).toThrow(/no soportado/);
    expect(() => contrast('red', '#fff')).toThrow(/no soportado/);
    expect(() => luminance('')).toThrow(/no soportado/);
  });
  it('blockAfter falla si el selector no existe', () => {
    expect(() => blockAfter(css, '.no-existe')).toThrow(/no encontrado/);
  });
  it('blockAfter falla si el bloque no se cierra', () => {
    expect(() => blockAfter('.a { --x: 1;', '.a')).toThrow(/sin cerrar/);
  });
});

describe('tokens.css: bloques', () => {
  it('los dos bloques oscuros son identicos', () => {
    expect(Object.keys(darkAttr).length).toBeGreaterThan(20);
    expect(darkMedia).toEqual(darkAttr);
  });
  it('claro y oscuro declaran el mismo conjunto de tokens', () => {
    expect(Object.keys(darkAttr).sort()).toEqual(Object.keys(light).sort());
  });
  it('incluye los tokens nuevos de marcador y tinta', () => {
    for (const k of ['--mark', '--mark-soft', '--on-mark', '--ink']) {
      expect(light[k], k).toBeDefined();
    }
  });
  it('--ink es el mismo azul noche en ambos temas', () => {
    expect(darkAttr['--ink']).toBe(light['--ink']);
  });
});

const themes: [string, Tokens][] = [
  ['claro', light],
  ['oscuro', darkAttr],
];

describe.each(themes)('contraste WCAG (%s)', (_name, t) => {
  const aa: [string, string][] = [
    ['--text', '--bg'],
    ['--text', '--bg-card'],
    ['--text-muted', '--bg'],
    ['--accent', '--bg'],
    ['--accent', '--bg-card'],
    ['--on-accent', '--accent'],
  ];
  it.each(aa)('%s sobre %s >= 4.5:1', (fg, bg) => {
    expect(contrast(t[fg], t[bg])).toBeGreaterThanOrEqual(4.5);
  });

  it('--on-mark sobre --mark >= 7:1', () => {
    expect(contrast(t['--on-mark'], t['--mark'])).toBeGreaterThanOrEqual(7);
  });

  // El indicador de foco es el anillo --text (global.css :focus-visible); el
  // halo --mark es refuerzo y en claro no llega a 3:1 sobre el papel.
  it.each(['--bg', '--bg-card'])('anillo de foco (--text) sobre %s >= 3:1', (bg) => {
    expect(contrast(t['--text'], t[bg])).toBeGreaterThanOrEqual(3);
  });
});
