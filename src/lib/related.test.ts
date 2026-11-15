import { describe, it, expect } from 'vitest';
import { relatedPosts } from './related';

const mk = (slug: string, tags: string[], d: string) => ({ slug, tags, published_at: d });

describe('relatedPosts', () => {
  const cur = mk('cur', ['SOC', 'xdr'], '2026-01-01');
  const all = [
    cur,
    mk('a', ['soc'], '2026-02-01'),
    mk('b', ['soc', 'XDR'], '2026-01-05'),
    mk('c', [], '2026-03-01'),
    mk('d', [], '2026-02-15'),
  ];

  it('excluye el propio y ordena por etiquetas en común, sin distinguir mayúsculas', () => {
    expect(relatedPosts(cur, all, 2).map((p) => p.slug)).toEqual(['b', 'a']);
  });

  it('sin etiquetas en común cae a los más recientes', () => {
    expect(relatedPosts(mk('x', [], '2026-01-01'), all, 2).map((p) => p.slug)).toEqual(['c', 'd']);
  });

  it('tolera tags ausentes y devuelve [] si no hay otros', () => {
    expect(relatedPosts({ slug: 'x', published_at: '', tags: undefined as unknown as string[] }, [], 3)).toEqual([]);
  });

  it('por defecto devuelve hasta 3', () => {
    expect(relatedPosts(cur, all)).toHaveLength(3);
  });
});
