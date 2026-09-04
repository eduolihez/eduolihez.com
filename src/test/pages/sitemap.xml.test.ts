import { describe, it, expect } from 'vitest';
import { GET } from '../../pages/sitemap.xml';
import type { APIContext } from 'astro';

// No mockeamos git log a proposito: igual que llms.txt.test.ts no mockea
// config/experience/skills/faq, aqui el riesgo real es que gitLastMod() deje
// de encontrar el repo o alguno de los paths que le pasa sitemap.xml.ts
// cambie de sitio -- eso solo se nota si la prueba corre contra el git de
// verdad, no contra un mock que siempre "funciona".

describe('GET /sitemap.xml', () => {
  it('responde XML valido con cache publica', async () => {
    const response = GET({} as APIContext);
    expect(response).toBeInstanceOf(Response);
    expect(response.headers.get('Content-Type')).toContain('application/xml');
    expect(response.headers.get('Cache-Control')).toContain('public');
  });

  it('declara hreflang es/en/ca/x-default en las paginas traducidas', async () => {
    const body = await GET({} as APIContext).text();
    expect(body).toContain('<loc>https://eduolihez.com/</loc>');
    expect(body).toContain('hreflang="es"');
    expect(body).toContain('hreflang="en"');
    expect(body).toContain('hreflang="ca"');
    expect(body).toContain('hreflang="x-default"');
  });

  it('NO declara hreflang para /blog/ (un solo idioma, en/ca redirigen a la home)', async () => {
    const body = await GET({} as APIContext).text();
    const blogEntry = body.slice(body.indexOf('<loc>https://eduolihez.com/blog/</loc>'), body.indexOf('<loc>https://eduolihez.com/blog/</loc>') + 200);
    expect(blogEntry).not.toContain('hreflang');
    expect(body).not.toContain('https://eduolihez.com/en/blog/');
    expect(body).not.toContain('https://eduolihez.com/ca/blog/');
  });

  it('no emite priority ni changefreq (deprecados, Google los ignora)', async () => {
    const body = await GET({} as APIContext).text();
    expect(body).not.toContain('<priority>');
    expect(body).not.toContain('<changefreq>');
  });

  it('cada URL lleva un lastmod con formato YYYY-MM-DD', async () => {
    const body = await GET({} as APIContext).text();
    const lastmods = [...body.matchAll(/<lastmod>([^<]+)<\/lastmod>/g)].map((m) => m[1]);
    expect(lastmods.length).toBeGreaterThan(0);
    for (const d of lastmods) expect(d).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('incluye las paginas de proyecto', async () => {
    const body = await GET({} as APIContext).text();
    expect(body).toContain('<loc>https://eduolihez.com/projects/</loc>');
    expect(body).toContain('<loc>https://eduolihez.com/projects/passwdcentinel/</loc>');
  });
});
