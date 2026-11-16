/**
 * rss.ts - Construye el feed RSS 2.0 del blog (ES) a partir de los resumenes
 * de articulos que ya se leen en build-time (src/lib/posts.ts).
 */
import type { PostSummary } from './posts';

const esc = (v: string): string =>
  v.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** "2026-09-04 10:00:00" -> fecha RFC 822; si no se puede leer, cadena vacia. */
export function rfc822(raw: string): string {
  const d = new Date(raw.replace(' ', 'T') + (/[zZ]|[+-]\d\d:?\d\d$/.test(raw) ? '' : 'Z'));
  return Number.isNaN(d.getTime()) ? '' : d.toUTCString();
}

export function buildRss(
  posts: PostSummary[],
  site: { domain: string; title: string; description: string },
): string {
  const items = posts
    .map((p) => {
      const url = `${site.domain}/blog/post/${p.slug}/`;
      const date = rfc822(p.published_at);
      return [
        '    <item>',
        `      <title>${esc(p.title)}</title>`,
        `      <link>${esc(url)}</link>`,
        `      <guid isPermaLink="true">${esc(url)}</guid>`,
        date ? `      <pubDate>${date}</pubDate>` : '',
        `      <description>${esc(p.summary || '')}</description>`,
        '    </item>',
      ]
        .filter(Boolean)
        .join('\n');
    })
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>${esc(site.title)}</title>
    <link>${esc(site.domain)}/blog/</link>
    <description>${esc(site.description)}</description>
    <language>es</language>
    <atom:link href="${esc(site.domain)}/blog/rss.xml" rel="self" type="application/rss+xml" />
${items}
  </channel>
</rss>
`;
}
