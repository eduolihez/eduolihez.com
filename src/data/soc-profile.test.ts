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

import { pickSocArticles, blogPostPath, socArticleSlugs, authorByline } from './soc-profile';

describe('artículos y firma SOC', () => {
  it('blogPostPath respeta el prefijo de idioma', () => {
    expect(blogPostPath('es', 'x')).toBe('/blog/post/x/');
    expect(blogPostPath('ca', 'x')).toBe('/ca/blog/post/x/');
  });

  it('pickSocArticles devuelve solo los que existen, en orden curado', () => {
    const [a, b] = socArticleSlugs.es;
    const got = pickSocArticles('es', [{ slug: b }, { slug: 'otro' }, { slug: a }]);
    expect(got.map((p) => p.slug)).toEqual([a, b]);
  });

  it('pickSocArticles con API vacía o sin artículos en ese idioma da []', () => {
    expect(pickSocArticles('es', [])).toEqual([]);
    expect(pickSocArticles('en', [{ slug: socArticleSlugs.es[0] }])).toEqual([]);
  });

  it.each(langs)('%s: la firma tiene enlace y texto', (l) => {
    expect(authorByline[l].link.length).toBeGreaterThan(5);
    expect(authorByline[l].before).toMatch(/Eduardo Olivares/);
  });
});
