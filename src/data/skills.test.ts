import { describe, expect, it } from 'vitest';
import { skillGroups } from './skills';

describe('skillGroups', () => {
  it('has unique items and a title in every language', () => {
    const all = skillGroups.flatMap((g) => g.items);
    expect(new Set(all).size).toBe(all.length);
    for (const g of skillGroups) {
      expect(g.category.es && g.category.en && g.category.ca).toBeTruthy();
    }
  });
});

import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { evidence } from '../config';
import { skillRefHref } from './skills';

describe('skill refs (mapa de evidencias)', () => {
  const refs = skillGroups.flatMap((g) => g.refs ?? []);
  it('every evidence ref points at a real E-nn', () => {
    for (const r of refs) if (r.kind === 'evidence') expect(evidence.map((e) => e.id)).toContain(r.id);
  });
  it('every page ref exists in src/pages or public', () => {
    for (const r of refs) {
      if (r.kind !== 'page') continue;
      for (const p of [r.path, r.enPath].filter(Boolean) as string[]) {
        const base = join(process.cwd(), 'src/pages', p.replace(/\/$/, ''));
        const pub = join(process.cwd(), 'public', p);
        expect(existsSync(`${base}.astro`) || existsSync(join(base, 'index.astro')) || existsSync(join(pub, 'index.html')) || existsSync(join(base, '..', '[slug].astro'))).toBe(true);
      }
    }
  });
  it('unbacked skills are real items of their group', () => {
    for (const g of skillGroups) for (const u of g.unbacked ?? []) expect(g.items).toContain(u);
  });
  it('builds hrefs per language', () => {
    expect(skillRefHref({ kind: 'evidence', id: 'E-03', label: 'x' }, 'en')).toBe('/en/evidence/#e-03');
    expect(skillRefHref({ kind: 'repo', repo: 'r', label: 'x' }, 'es')).toBe('https://github.com/eduolihez/r');
    const page = { kind: 'page', path: '/a/', enPath: '/en/a/', label: 'x' } as const;
    expect(skillRefHref(page, 'en')).toBe('/en/a/');
    expect(skillRefHref(page, 'ca')).toBe('/a/');
    expect(skillRefHref({ kind: 'page', path: '/b/', label: 'x' }, 'en')).toBe('/b/');
  });
});
