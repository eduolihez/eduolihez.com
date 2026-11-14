import { describe, it, expect } from 'vitest';
import { socProfile, socAlternates } from './soc-profile';

const langs = ['es', 'en', 'ca'] as const;

describe('socProfile', () => {
  it.each(langs)('%s: rutas coherentes con los hreflang', (l) => {
    expect(socProfile[l].path).toBe(socAlternates[l]);
    expect(socAlternates[l].endsWith('/')).toBe(true);
  });

  it.each(langs)('%s: title y description caben en el SERP y llevan SOC + Barcelona', (l) => {
    const p = socProfile[l];
    expect(p.title.length).toBeLessThanOrEqual(65);
    expect(p.description.length).toBeLessThanOrEqual(165);
    expect(p.title).toMatch(/SOC/);
    expect(p.title).toMatch(/Barcelona/);
    expect(p.title).toMatch(/Badalona/);
  });

  it.each(langs)('%s: respuesta directa, secciones y FAQ no vacías', (l) => {
    const p = socProfile[l];
    expect(p.answer.length).toBeGreaterThan(80);
    expect(p.sections.length).toBeGreaterThan(0);
    for (const s of p.sections) expect(s.items.length).toBeGreaterThan(0);
    expect(p.faq.length).toBeGreaterThanOrEqual(3);
  });
});
