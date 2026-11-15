import { describe, it, expect } from 'vitest';
import { seoOverrides } from './seo-overrides';
import { TITLE_MAX, DESCRIPTION_MAX, postSeo } from '../lib/seoText';

describe('seoOverrides', () => {
  const entries = Object.entries(seoOverrides);

  it('no está vacío', () => {
    expect(entries.length).toBeGreaterThan(0);
  });

  it.each(entries)('%s: cabe en el SERP y no corta a mitad de frase', (_slug, o) => {
    if (o.title) expect(o.title.length).toBeLessThanOrEqual(TITLE_MAX);
    if (o.description) {
      expect(o.description.length).toBeLessThanOrEqual(DESCRIPTION_MAX);
      expect(o.description.length).toBeGreaterThan(80);
      expect(o.description).toMatch(/[.!?)]$/);
      expect(o.description).not.toContain('…');
    }
    expect(o.title || o.description).toBeTruthy();
  });
});

describe('postSeo', () => {
  const post = { slug: 's', title: 'Titular corto', summary: 'Resumen corto.' };

  it('sin override usa las reglas automáticas', () => {
    const r = postSeo(post, 'Edu', {});
    expect(r.title).toBe('Titular corto | Blog | Edu');
    expect(r.description).toBe('Resumen corto.');
  });

  it('el override manda, campo a campo', () => {
    expect(postSeo(post, 'Edu', { s: { title: 'T' } })).toEqual({ title: 'T', description: 'Resumen corto.' });
    expect(postSeo(post, 'Edu', { s: { description: 'D' } }).title).toBe('Titular corto | Blog | Edu');
  });
});
