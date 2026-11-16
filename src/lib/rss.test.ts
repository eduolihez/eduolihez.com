import { describe, expect, it } from 'vitest';
import { buildRss, rfc822 } from './rss';
import type { PostSummary } from './posts';

const post = (o: Partial<PostSummary> = {}): PostSummary => ({
  id: 1, title: 'A & B <x>', slug: 'a-b', summary: 'Resumen "uno"', cover_url: null,
  tags: [], category: null, lang: 'es', published_at: '2026-09-04 10:00:00', ...o,
});
const site = { domain: 'https://x.test', title: 'Blog', description: 'Desc' };

describe('rfc822', () => {
  it('formats a date and rejects garbage', () => {
    expect(rfc822('2026-09-04 10:00:00')).toBe('Fri, 04 Sep 2026 10:00:00 GMT');
    expect(rfc822('2026-09-04T10:00:00Z')).toBe('Fri, 04 Sep 2026 10:00:00 GMT');
    expect(rfc822('nope')).toBe('');
  });
});

describe('buildRss', () => {
  it('escapes and links each post', () => {
    const xml = buildRss([post()], site);
    expect(xml).toContain('<title>A &amp; B &lt;x&gt;</title>');
    expect(xml).toContain('<link>https://x.test/blog/post/a-b/</link>');
    expect(xml).toContain('<pubDate>Fri, 04 Sep 2026 10:00:00 GMT</pubDate>');
  });
  it('omits pubDate when the date is invalid and handles no posts', () => {
    expect(buildRss([post({ published_at: 'x', summary: '' })], site)).not.toContain('<pubDate>');
    expect(buildRss([], site)).not.toContain('<item>');
  });
});
