import { describe, it, expect, vi, afterEach } from 'vitest';
import { sourceType, linkAttrs, evidenceAnchor, permalink, initEvidenceCopy } from './evidence';

describe('linkAttrs()', () => {
  it('externo https: pestana nueva con noopener noreferrer', () => {
    expect(linkAttrs('https://www.credly.com/x')).toEqual({
      external: true,
      target: '_blank',
      rel: 'noopener noreferrer',
    });
  });
  it('archivo local: misma pestana y sin rel', () => {
    expect(linkAttrs('/certificaciones/a.pdf')).toEqual({ external: false });
  });
});

describe('evidenceAnchor() / permalink()', () => {
  it('pasa el id a minusculas', () => {
    expect(evidenceAnchor('E-03')).toBe('e-03');
  });
  it('sustituye un hash previo', () => {
    expect(permalink('https://eduolihez.com/en/#contacto', 'E-01')).toBe('https://eduolihez.com/en/#e-01');
  });
  it('anade el hash si no habia', () => {
    expect(permalink('https://eduolihez.com/', 'E-02')).toBe('https://eduolihez.com/#e-02');
  });
});

function setup(live = true) {
  document.body.innerHTML = `
    <a id="a" href="#e-01" data-evidence-copy="E-01">E-01</a>
    <a id="b" href="#e-02" data-evidence-copy="E-02">E-02</a>
    ${live ? '<p data-evidence-live data-copied-text="Copiado:"></p>' : ''}
  `;
}
const flush = () => new Promise((r) => setTimeout(r, 0));

describe('initEvidenceCopy()', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('copia el permalink y lo anuncia en la region viva', async () => {
    setup();
    const writeText = vi.fn().mockResolvedValue(undefined);
    expect(initEvidenceCopy(document, { writeText })).toBe(2);
    document.getElementById('b')!.click();
    await flush();
    expect(writeText).toHaveBeenCalledWith(permalink(window.location.href, 'E-02'));
    expect(document.querySelector('[data-evidence-live]')!.textContent).toBe(
      `Copiado: ${permalink(window.location.href, 'E-02')}`,
    );
  });

  it('es idempotente: no duplica oyentes', async () => {
    setup();
    const writeText = vi.fn().mockResolvedValue(undefined);
    initEvidenceCopy(document, { writeText });
    expect(initEvidenceCopy(document, { writeText })).toBe(0);
    document.getElementById('a')!.click();
    await flush();
    expect(writeText).toHaveBeenCalledTimes(1);
  });

  it('si el portapapeles rechaza, no anuncia nada', async () => {
    setup();
    const writeText = vi.fn().mockRejectedValue(new Error('denied'));
    initEvidenceCopy(document, { writeText });
    document.getElementById('a')!.click();
    await flush();
    expect(document.querySelector('[data-evidence-live]')!.textContent).toBe('');
  });

  it('sin portapapeles no hace nada (el ancla sigue funcionando)', () => {
    setup();
    initEvidenceCopy(document, undefined);
    expect(() => document.getElementById('a')!.click()).not.toThrow();
    expect(document.querySelector('[data-evidence-live]')!.textContent).toBe('');
  });

  it('sin region viva copia igual', async () => {
    setup(false);
    const writeText = vi.fn().mockResolvedValue(undefined);
    initEvidenceCopy(document, { writeText });
    document.getElementById('a')!.click();
    await flush();
    expect(writeText).toHaveBeenCalledTimes(1);
  });

  it('usa document y navigator.clipboard por defecto', () => {
    setup();
    expect(initEvidenceCopy()).toBe(2);
  });
});

describe('sourceType()', () => {
  it('Credly para credly.com (https)', () => {
    expect(sourceType('https://www.credly.com/badges/abc')).toBe('Credly');
  });
  it('PDF para archivos .pdf locales o remotos', () => {
    expect(sourceType('/certificaciones/THM-R3JSJHVXSI.pdf')).toBe('PDF');
    expect(sourceType('https://x.com/a.PDF#page=2')).toBe('PDF');
  });
  it('null si no es ninguna de las dos (no inventa tipo)', () => {
    expect(sourceType('https://example.com/x')).toBeNull();
    expect(sourceType('http://www.credly.com/x')).toBeNull();
    expect(sourceType('')).toBeNull();
  });
});
